#  software-properties PPA support, using launchpadlib
#
#  Copyright (c) 2019 Canonical Ltd.
#
#  Original Author: Michael Vogt <mvo@debian.org>
#  Rewrite: Dan Streetman <ddstreet@canonical.com>
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

from gettext import gettext as _

from launchpadlib.launchpad import Launchpad
from lazr.restfulclient.errors import (NotFound, BadRequest, Unauthorized)

from softwareproperties.shortcuthandler import (ShortcutHandler, ShortcutException,
                                                InvalidShortcutException)
from softwareproperties.sourceslist import SourcesListShortcutHandler
from softwareproperties.uri import URIShortcutHandler

from urllib.parse import urlparse


PPA_URI_FORMAT = 'https://ppa.launchpadcontent.net/{team}/{ppa}/ubuntu/'
PRIVATE_PPA_URI_FORMAT = 'https://private-ppa.launchpadcontent.net/{team}/{ppa}/ubuntu/'
PPA_VALID_HOSTNAMES = [
    urlparse(PPA_URI_FORMAT).hostname,
    urlparse(PRIVATE_PPA_URI_FORMAT).hostname,
    # Old hostnames.
    'ppa.launchpad.net',
    'private-ppa.launchpad.net',
]

PPA_VALID_COMPS = ['main', 'main/debug']


class PPAShortcutHandler(ShortcutHandler):
    def __init__(self, shortcut, login=False, **kwargs):
        super(PPAShortcutHandler, self).__init__(shortcut, **kwargs)
        self._lp_anon = not login
        self._signing_key_data = None

        self._lp = None                     # LP object
        self._lpteam = None                 # Person/Team LP object
        self._lpppa = None                  # PPA Archive LP object

        self._is_sourceslist = False

        # one of these will set teamname and ppaname, and maybe _source_entry
        if not any((self._match_ppa(shortcut),
                    self._match_uri(shortcut),
                    self._match_sourceslist(shortcut))):
            msg = (_("ERROR: '%s' is not a valid ppa format") % shortcut)
            raise InvalidShortcutException(msg)

        self._filebase = "%s-ubuntu-%s" % (self.teamname, self.ppaname)
        self._set_auth()

        # Make sure we can find/access the PPA, lp:#1965180
        if self._is_sourceslist:
            try:
                self.lpppa
            except ShortcutException:
                raise InvalidShortcutException(_("ERROR: Can't find ppa"))

        if not self._source_entry:
            comps = self.components
            if not comps:
                comps = ['main']
                if self.lpppa.publish_debug_symbols:
                    print("PPA publishes dbgsym, you may need to include 'main/debug' component")
                    # comps += ['main/debug']

            uri_format = PRIVATE_PPA_URI_FORMAT if self.lpppa.private else PPA_URI_FORMAT
            uri = uri_format.format(team=self.teamname, ppa=self.ppaname)
            line = ('%s %s %s %s' % (self.binary_type, uri, self.dist, ' '.join(comps)))
            self._set_source_entry(line)

    @property
    def lp(self):
        if not self._lp:
            if self._lp_anon:
                login_func = Launchpad.login_anonymously
            else:
                login_func = Launchpad.login_with
            self._lp = login_func("%s.%s" % (self.__module__, self.__class__.__name__),
                                  service_root='production',
                                  version='devel')
        return self._lp

    @property
    def lpteam(self):
        if not self._lpteam:
            try:
                self._lpteam = self.lp.people(self.teamname)
            except NotFound:
                msg = (_("ERROR: user/team '%s' not found (use --login if private)") % self.teamname)
                raise ShortcutException(msg)
            except Unauthorized:
                msg = (_("ERROR: invalid user/team name '%s'") % self.teamname)
                raise ShortcutException(msg)
        return self._lpteam

    @property
    def lpppa(self):
        if not self._lpppa:
            try:
                self._lpppa = self.lpteam.getPPAByName(name=self.ppaname)
            except NotFound:
                msg = (_("ERROR: ppa '%s/%s' not found (use --login if private)") %
                       (self.teamname, self.ppaname))
                raise ShortcutException(msg)
            except BadRequest:
                msg = (_("ERROR: invalid ppa name '%s'") % self.ppaname)
                raise ShortcutException(msg)
        return self._lpppa

    @property
    def description(self):
        return self.lpppa.description

    @property
    def web_link(self):
        return self.lpppa.web_link

    @property
    def trustedparts_content(self):
        if not self._signing_key_data:
            key = self.lpppa.getSigningKeyData()
            fingerprint = self.lpppa.signing_key_fingerprint

            if not fingerprint:
                print(_("Warning: could not get PPA signing_key_fingerprint from LP, using anyway"))
            elif 'redacted' in fingerprint:
                print(_("Private PPA fingerprint redacted, using key anyway (LP: #1879781)"))
            elif not fingerprint in self.fingerprints(key):
                msg = (_("Fingerprints do not match, not importing: '%s' != '%s'") %
                       (fingerprint, ','.join(self.fingerprints(key))))
                raise ShortcutException(msg)

            self._signing_key_data = key
        return self._signing_key_data

    def SourceEntry(self, pkgtype=None):
        entry = super(PPAShortcutHandler, self).SourceEntry(pkgtype=pkgtype)
        if pkgtype != self.source_type or self.components:
            return entry

        # 'main/debug' is needed to get dbgsyms from ppas,
        # but it's not a valid component for ppa deb-src lines.
        # Sigh.
        entry.comps = list(set(entry.comps) - set(['main/debug']))
        return entry

    def _set_source_entry(self, line):
        super(PPAShortcutHandler, self)._set_source_entry(line)

        invalid_comps = set(self.SourceEntry().comps) - set(PPA_VALID_COMPS)
        if invalid_comps:
            print(_("Warning: components '%s' not valid for PPA") % ' '.join(invalid_comps))

    def _match_ppa(self, shortcut):
        (prefix, _, ppa) = shortcut.rpartition(':')
        if not prefix.lower() == 'ppa':
            return False

        (teamname, _, ppaname) = ppa.partition('/')
        teamname = teamname.lstrip('~')
        if '/' in ppaname:
            (ubuntu, _, ppaname) = ppaname.partition('/')
            if ubuntu.lower() != 'ubuntu':
                # PPAs only support ubuntu
                return False
            if '/' in ppaname:
                # Path is too long for valid ppa
                return False

        self.teamname = teamname
        self.ppaname = ppaname or 'ppa'
        return True

    def _match_uri(self, shortcut):
        try:
            return self._match_handler(URIShortcutHandler(shortcut))
        except InvalidShortcutException:
            return False

    def _match_sourceslist(self, shortcut):
        try:
            handler = self._match_handler(SourcesListShortcutHandler(shortcut))
        except InvalidShortcutException:
            return False
        self._is_sourceslist = True
        return handler

    def _match_handler(self, handler):
        parsed = urlparse(handler.SourceEntry().uri)
        if not parsed.hostname in PPA_VALID_HOSTNAMES:
            return False

        path = parsed.path.strip().strip('/').split('/')
        if len(path) < 2:
            return False
        self.teamname = path[0]
        self.ppaname = path[1]

        self._username = handler.username
        self._password = handler.password

        self._set_source_entry(handler.SourceEntry().line)
        return True

    def _set_auth(self):
        if self._lp_anon or not self.lpppa.private:
            return

        if self._username and self._password:
            return

        for url in self.lp.me.getArchiveSubscriptionURLs():
            parsed = urlparse(url)
            if parsed.path.startswith(f'/{self.teamname}/{self.ppaname}/ubuntu'):
                self._username = parsed.username
                self._password = parsed.password
                break
        else:
            msg = (_("Could not find PPA subscription for ppa:%s/%s, you may need to request access") %
                   (self.teamname, self.ppaname))
            raise ShortcutException(msg)
