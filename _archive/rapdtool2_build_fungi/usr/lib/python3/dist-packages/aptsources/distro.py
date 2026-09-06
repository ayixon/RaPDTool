#  distro.py - Provide a distro abstraction of the sources.list
#
#  Copyright (c) 2004-2009 Canonical Ltd.
#  Copyright (c) 2006-2007 Sebastian Heinlein
#  Copyright (c) 2016 Harald Sitter
#
#  Authors: Sebastian Heinlein <glatzor@ubuntu.com>
#           Michael Vogt <mvo@debian.org>
#           Harald Sitter <sitter@kde.org>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA

import gettext
import logging
import re
import shlex
import os

from xml.etree.ElementTree import ElementTree

from apt_pkg import gettext as _


class NoDistroTemplateException(Exception):
    pass


class Distribution(object):

    def __init__(self, id, codename, description, release, is_like=[]):
        """ Container for distribution specific informations """
        # LSB information
        self.id = id
        self.codename = codename
        self.description = description
        self.release = release
        self.is_like = is_like

        self.binary_type = "deb"
        self.source_type = "deb-src"

    def get_sources(self, sourceslist):
        """
        Find the corresponding template, main and child sources
        for the distribution
        """

        self.sourceslist = sourceslist
        # corresponding sources
        self.source_template = None
        self.child_sources = []
        self.main_sources = []
        self.disabled_sources = []
        self.cdrom_sources = []
        self.download_comps = []
        self.enabled_comps = []
        self.cdrom_comps = []
        self.used_media = []
        self.get_source_code = False
        self.source_code_sources = []

        # location of the sources
        self.default_server = ""
        self.main_server = ""
        self.nearest_server = ""
        self.used_servers = []

        # find the distro template
        for template in self.sourceslist.matcher.templates:
            if (self.is_codename(template.name) and
                    template.distribution == self.id):
                #print "yeah! found a template for %s" % self.description
                #print template.description, template.base_uri, \
                #    template.components
                self.source_template = template
                break
        if self.source_template is None:
            raise NoDistroTemplateException(
                "Error: could not find a distribution template for %s/%s" %
                (self.id, self.codename))

        # find main and child sources
        media = []
        comps = []
        cdrom_comps = []
        enabled_comps = []
        #source_code = []
        for source in self.sourceslist.list:
            if (not source.invalid and
                    self.is_codename(source.dist) and
                    source.template and
                    source.template.official and
                    self.is_codename(source.template.name)):
                #print "yeah! found a distro repo:  %s" % source.line
                # cdroms need do be handled differently
                if (source.uri.startswith("cdrom:") and
                        not source.disabled):
                    self.cdrom_sources.append(source)
                    cdrom_comps.extend(source.comps)
                elif (source.uri.startswith("cdrom:") and
                          source.disabled):
                    self.cdrom_sources.append(source)
                elif (source.type == self.binary_type and
                          not source.disabled):
                    self.main_sources.append(source)
                    comps.extend(source.comps)
                    media.append(source.uri)
                elif (source.type == self.binary_type and
                          source.disabled):
                    self.disabled_sources.append(source)
                elif (source.type == self.source_type and
                          not source.disabled):
                    self.source_code_sources.append(source)
                elif (source.type == self.source_type and
                          source.disabled):
                    self.disabled_sources.append(source)
            if (not source.invalid and
                    source.template in self.source_template.children):
                if (not source.disabled and
                    source.type == self.binary_type):
                    self.child_sources.append(source)
                elif (not source.disabled and
                      source.type == self.source_type):
                    self.source_code_sources.append(source)
                else:
                    self.disabled_sources.append(source)
        self.download_comps = set(comps)
        self.cdrom_comps = set(cdrom_comps)
        enabled_comps.extend(comps)
        enabled_comps.extend(cdrom_comps)
        self.enabled_comps = set(enabled_comps)
        self.used_media = set(media)
        self.get_mirrors()

    def get_mirrors(self, mirror_template=None):
        """
        Provide a set of mirrors where you can get the distribution from
        """
        # the main server is stored in the template
        self.main_server = self.source_template.base_uri

        # other used servers
        for medium in self.used_media:
            if not medium.startswith("cdrom:"):
                # seems to be a network source
                self.used_servers.append(medium)

        if len(self.main_sources) == 0:
            self.default_server = self.main_server
        else:
            self.default_server = self.main_sources[0].uri

        # get a list of country codes and real names
        self.countries = {}
        fname = "/usr/share/xml/iso-codes/iso_3166.xml"
        if os.path.exists(fname):
            et = ElementTree(file=fname)
            # python2.6 compat, the next two lines can get removed
            # once we do not use py2.6 anymore
            if getattr(et, "iter", None) is None:
                et.iter = et.getiterator
            it = et.iter('iso_3166_entry')
            for elm in it:
                try:
                    descr = elm.attrib["common_name"]
                except KeyError:
                    descr = elm.attrib["name"]
                try:
                    code = elm.attrib["alpha_2_code"]
                except KeyError:
                    code = elm.attrib["alpha_3_code"]
                self.countries[code.lower()] = gettext.dgettext('iso_3166',
                                                                descr)

        # try to guess the nearest mirror from the locale
        self.country = None
        self.country_code = None
        locale = os.getenv("LANG", default="en_UK")
        a = locale.find("_")
        z = locale.find(".")
        if z == -1:
            z = len(locale)
        country_code = locale[a + 1:z].lower()

        if mirror_template:
            self.nearest_server = mirror_template % country_code

        if country_code in self.countries:
            self.country = self.countries[country_code]
            self.country_code = country_code

    def _get_mirror_name(self, server):
        ''' Try to get a human readable name for the main mirror of a country
            Customize for different distributions '''
        country = None
        i = server.find("://")
        li = server.find(".archive.ubuntu.com")
        if i != -1 and li != -1:
            country = server[i + len("://"):li]
        if country in self.countries:
            # TRANSLATORS: %s is a country
            return _("Server for %s") % self.countries[country]
        else:
            return("%s" % server.rstrip("/ "))

    def get_server_list(self):
        ''' Return a list of used and suggested servers '''

        def compare_mirrors(mir1, mir2):
            ''' Helper function that handles comaprision of mirror urls
                that could contain trailing slashes'''
            return re.match(mir1.strip("/ "), mir2.rstrip("/ "))

        # Store all available servers:
        # Name, URI, active
        mirrors = []
        if (len(self.used_servers) < 1 or
            (len(self.used_servers) == 1 and
             compare_mirrors(self.used_servers[0], self.main_server))):
            mirrors.append([_("Main server"), self.main_server, True])
            if self.nearest_server:
                mirrors.append([self._get_mirror_name(self.nearest_server),
                                self.nearest_server, False])
        elif (len(self.used_servers) == 1 and not
              compare_mirrors(self.used_servers[0], self.main_server)):
            mirrors.append([_("Main server"), self.main_server, False])
            # Only one server is used
            server = self.used_servers[0]

            # Append the nearest server if it's not already used
            if self.nearest_server:
                if not compare_mirrors(server, self.nearest_server):
                    mirrors.append([self._get_mirror_name(self.nearest_server),
                                    self.nearest_server, False])
            if server:
                mirrors.append([self._get_mirror_name(server), server, True])

        elif len(self.used_servers) > 1:
            # More than one server is used. Since we don't handle this case
            # in the user interface we set "custom servers" to true and
            # append a list of all used servers
            mirrors.append([_("Main server"), self.main_server, False])
            if self.nearest_server:
                mirrors.append([self._get_mirror_name(self.nearest_server),
                                self.nearest_server, False])
            mirrors.append([_("Custom servers"), None, True])
            for server in self.used_servers:
                mirror_entry = [self._get_mirror_name(server), server, False]
                if (compare_mirrors(server, self.nearest_server) or
                        compare_mirrors(server, self.main_server)):
                    continue
                elif mirror_entry not in mirrors:
                    mirrors.append(mirror_entry)

        return mirrors

    def add_source(self, type=None,
                 uri=None, dist=None, comps=None, comment=""):
        """
        Add distribution specific sources
        """
        if uri is None:
            # FIXME: Add support for the server selector
            uri = self.default_server
        if dist is None:
            dist = self.codename
        if comps is None:
            comps = list(self.enabled_comps)
        if type is None:
            type = self.binary_type
        new_source = self.sourceslist.add(type, uri, dist, comps, comment)
        # if source code is enabled add a deb-src line after the new
        # source
        if self.get_source_code and type == self.binary_type:
            self.sourceslist.add(
                self.source_type, uri, dist, comps, comment,
                file=new_source.file,
                pos=self.sourceslist.list.index(new_source) + 1)

    def enable_component(self, comp):
        """
        Enable a component in all main, child and source code sources
        (excluding cdrom based sources)

        comp:         the component that should be enabled
        """
        comps = set([comp])
        # look for parent components that we may have to add
        for source in self.main_sources:
            for c in source.template.components:
                if c.name == comp and c.parent_component:
                    comps.add(c.parent_component)
        for c in comps:
            self._enable_component(c)

    def _enable_component(self, comp):

        def add_component_only_once(source, comps_per_dist):
            """
            Check if we already added the component to the repository, since
            a repository could be splitted into different apt lines. If not
            add the component
            """
            # if we don't have that distro, just return (can happen for e.g.
            # dapper-update only in deb-src
            if source.dist not in comps_per_dist:
                return
            # if we have seen this component already for this distro,
            # return (nothing to do)
            if comp in comps_per_dist[source.dist]:
                return
            # add it
            source.comps.append(comp)
            comps_per_dist[source.dist].add(comp)

        sources = []
        sources.extend(self.main_sources)
        sources.extend(self.child_sources)
        # store what comps are enabled already per distro (where distro is
        # e.g. "dapper", "dapper-updates")
        comps_per_dist = {}
        comps_per_sdist = {}
        for s in sources:
            if s.type == self.binary_type:
                if s.dist not in comps_per_dist:
                    comps_per_dist[s.dist] = set()
                for c in s.comps:
                    comps_per_dist[s.dist].add(c)
        for s in self.source_code_sources:
            if s.type == self.source_type:
                if s.dist not in comps_per_sdist:
                    comps_per_sdist[s.dist] = set()
                for c in s.comps:
                    comps_per_sdist[s.dist].add(c)

        # check if there is a main source at all
        if len(self.main_sources) < 1:
            # create a new main source
            self.add_source(comps=["%s" % comp])
        else:
            # add the comp to all main, child and source code sources
            for source in sources:
                add_component_only_once(source, comps_per_dist)

            for source in self.source_code_sources:
                add_component_only_once(source, comps_per_sdist)

        # check if there is a main source code source at all
        if self.get_source_code:
            if len(self.source_code_sources) < 1:
                # create a new main source
                self.add_source(type=self.source_type, comps=["%s" % comp])
            else:
                # add the comp to all main, child and source code sources
                for source in self.source_code_sources:
                    add_component_only_once(source, comps_per_sdist)

    def disable_component(self, comp):
        """
        Disable a component in all main, child and source code sources
        (excluding cdrom based sources)
        """
        sources = []
        sources.extend(self.main_sources)
        sources.extend(self.child_sources)
        sources.extend(self.source_code_sources)
        if comp in self.cdrom_comps:
            sources = []
            sources.extend(self.main_sources)
        for source in sources:
            if comp in source.comps:
                source.comps.remove(comp)
                if len(source.comps) < 1:
                    self.sourceslist.remove(source)

    def change_server(self, uri):
        ''' Change the server of all distro specific sources to
            a given host '''

        def change_server_of_source(source, uri, seen):
            # Avoid creating duplicate entries
            source.uri = uri
            for comp in source.comps:
                if [source.uri, source.dist, comp] in seen:
                    source.comps.remove(comp)
                else:
                    seen.append([source.uri, source.dist, comp])
            if len(source.comps) < 1:
                self.sourceslist.remove(source)

        seen_binary = []
        seen_source = []
        self.default_server = uri
        for source in self.main_sources:
            change_server_of_source(source, uri, seen_binary)
        for source in self.child_sources:
            # Do not change the forces server of a child source
            if (source.template.base_uri is None or
                    source.template.base_uri != source.uri):
                change_server_of_source(source, uri, seen_binary)
        for source in self.source_code_sources:
            change_server_of_source(source, uri, seen_source)

    def is_codename(self, name):
        ''' Compare a given name with the release codename. '''
        if name == self.codename:
            return True
        else:
            return False


class DebianDistribution(Distribution):
    ''' Class to support specific Debian features '''

    def is_codename(self, name):
        ''' Compare a given name with the release codename and check if
            if it can be used as a synonym for a development releases '''
        if name == self.codename or self.release in ("testing", "unstable"):
            return True
        else:
            return False

    def _get_mirror_name(self, server):
        ''' Try to get a human readable name for the main mirror of a country
            Debian specific '''
        country = None
        i = server.find("://ftp.")
        li = server.find(".debian.org")
        if i != -1 and li != -1:
            country = server[i + len("://ftp."):li]
        if country in self.countries:
            # TRANSLATORS: %s is a country
            return _("Server for %s") % gettext.dgettext(
                "iso_3166", self.countries[country].rstrip()).rstrip()
        else:
            return("%s" % server.rstrip("/ "))

    def get_mirrors(self):
        Distribution.get_mirrors(
            self, mirror_template="http://ftp.%s.debian.org/debian/")


class UbuntuDistribution(Distribution):
    ''' Class to support specific Ubuntu features '''

    def get_mirrors(self):
        Distribution.get_mirrors(
            self, mirror_template="http://%s.archive.ubuntu.com/ubuntu/")


class UbuntuRTMDistribution(UbuntuDistribution):
    ''' Class to support specific Ubuntu RTM features '''

    def get_mirrors(self):
        self.main_server = self.source_template.base_uri


def _lsb_release():
    """Call lsb_release --idrc and return a mapping."""
    from subprocess import Popen, PIPE
    import errno
    result = {'Codename': 'sid', 'Distributor ID': 'Debian',
              'Description': 'Debian GNU/Linux unstable (sid)',
              'Release': 'unstable'}
    try:
        out = Popen(['lsb_release', '-idrc'], stdout=PIPE).communicate()[0]
        # Convert to unicode string, needed for Python 3.1
        out = out.decode("utf-8")
        result.update(line.split(":\t") for line in out.split("\n")
                                        if ':\t' in line)
    except OSError as exc:
        if exc.errno != errno.ENOENT:
            logging.warning('lsb_release failed, using defaults:' % exc)
    return result


def _system_image_channel():
    """Get the current channel from system-image-cli -i if possible."""
    from subprocess import Popen, PIPE
    import errno
    try:
        from subprocess import DEVNULL
    except ImportError:
        # no DEVNULL in 2.7
        DEVNULL = os.open(os.devnull, os.O_RDWR)
    try:
        out = Popen(
            ['system-image-cli', '-i'], stdout=PIPE, stderr=DEVNULL,
            universal_newlines=True).communicate()[0]
        for line in out.splitlines():
            if line.startswith('channel: '):
                return line.split(': ', 1)[1]
    except OSError as exc:
        if exc.errno != errno.ENOENT:
            logging.warning(
                'system-image-cli failed, using defaults: %s' % exc)
    return None


class _OSRelease:

    DEFAULT_OS_RELEASE_FILE = '/etc/os-release'
    OS_RELEASE_FILE = '/etc/os-release'

    def __init__(self, lsb_compat=True):
        self.result = {}
        self.valid = False
        self.file = _OSRelease.OS_RELEASE_FILE

        if not os.path.isfile(self.file):
            return

        self.parse()
        self.valid = True

        if lsb_compat:
            self.inject_lsb_compat()

    def inject_lsb_compat(self):
        self.result['Distributor ID'] = self.result['ID']
        self.result['Description'] = self.result['PRETTY_NAME']
        # Optionals as per os-release spec.
        self.result['Codename'] = self.result.get('VERSION_CODENAME')
        if not self.result['Codename']:
            # Transient Ubuntu 16.04 field (LP: #1598212)
            self.result['Codename'] = self.result.get('UBUNTU_CODENAME')
        self.result['Release'] = self.result.get('VERSION_ID')

    def parse(self):
        f = open(self.file, 'r')
        for line in f:
            line = line.strip()
            if not line:
                continue
            self.parse_entry(*line.split('=', 1))
        f.close()

    def parse_entry(self, key, value):
        value = self.parse_value(value)  # Values can be shell strings...
        if key == "ID_LIKE" and isinstance(value, str):
            # ID_LIKE is specified as quoted space-separated list. This will
            # be parsed as string that we need to split manually.
            value = value.split(' ')
        self.result[key] = value

    def parse_value(self, value):
        values = shlex.split(value)
        if len(values) == 1:
            return values[0]
        return values


def get_distro(id=None, codename=None, description=None, release=None,
               is_like=[]):
    """
    Check the currently used distribution and return the corresponding
    distriubtion class that supports distro specific features.

    If no paramter are given the distro will be auto detected via
    a call to lsb-release
    """
    # make testing easier
    if not (id and codename and description and release):
        os_release = _OSRelease()
        os_result = []
        lsb_result = _lsb_release()
        if os_release.valid:
            os_result = os_release.result
        # TODO: We cannot presently use os-release to fully replace lsb_release
        #       because os-release's ID, VERSION_ID and VERSION_CODENAME fields
        #       are specified as lowercase. In lsb_release they can be upcase
        #       or captizalized. So, switching to os-release would consitute
        #       a behavior break a which point lsb_release support should be
        #       fully removed.
        #       This in particular is a problem for template matching, as this
        #       matches against Distribution objects and depends on string
        #       case.
        lsb_result = _lsb_release()
        id = lsb_result['Distributor ID']
        codename = lsb_result['Codename']
        description = lsb_result['Description']
        release = lsb_result['Release']
        # Not available with LSB, use get directly.
        is_like = os_result.get('ID_LIKE', [])
        if id == "Ubuntu":
            channel = _system_image_channel()
            if channel is not None and "ubuntu-rtm/" in channel:
                id = "Ubuntu-RTM"
                codename = channel.rsplit("/", 1)[1].split("-", 1)[0]
                description = codename
                release = codename
    if id == "Ubuntu":
        return UbuntuDistribution(id, codename, description, release, is_like)
    if id == "Ubuntu-RTM":
        return UbuntuRTMDistribution(
            id, codename, description, release, is_like)
    elif id == "Debian":
        return DebianDistribution(id, codename, description, release, is_like)
    else:
        return Distribution(id, codename, description, release, is_like)
