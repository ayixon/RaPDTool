#  software-properties backend
#
#  Copyright (c) 2004-2018 Canonical Ltd.
#                2004-2005 Michiel Sikkes
#
#  Author: Michiel Sikkes <michiel@eyesopened.nl>
#          Michael Vogt <mvo@debian.org>
#          Sebastian Heinlein <glatzor@ubuntu.com>
#          Andrea Azzarone <andrea.azzarone@canonical.com>
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

from __future__ import absolute_import, print_function

import apt_pkg
import copy
from hashlib import md5
import re
import os
import glob
import shutil
import threading
import atexit
import tempfile
try:
  from string import maketrans
except ImportError:
  maketrans = str.maketrans
import stat

try:
  import queue
except ImportError:
  import Queue as queue

from tempfile import NamedTemporaryFile
from xml.sax.saxutils import escape
try:
  from configparser import ConfigParser
except ImportError:
  from ConfigParser import ConfigParser
from gettext import gettext as _

import aptsources
import aptsources.distro
import softwareproperties

from .AptAuth import AptAuth
from aptsources.sourceslist import (SourcesList, SourceEntry)
from softwareproperties.shortcuthandler import InvalidShortcutException
from softwareproperties.shortcuts import shortcut_handler

from gi.repository import Gio


class SoftwareProperties(object):

  # known (whitelisted) channels
  CHANNEL_PATH="/usr/share/app-install/channels/"

  # release upgrades policy
  RELEASE_UPGRADES_CONF = "/etc/update-manager/release-upgrades"
  #RELEASE_UPGRADES_CONF = "/tmp/release-upgrades"
  (
    RELEASE_UPGRADES_NORMAL,
    RELEASE_UPGRADES_LTS,
    RELEASE_UPGRADES_NEVER
  ) = list(range(3))
  release_upgrades_policy_map = {
    RELEASE_UPGRADES_NORMAL : 'normal',
    RELEASE_UPGRADES_LTS    : 'lts',
    RELEASE_UPGRADES_NEVER  : 'never',
  }

  def __init__(self, datadir=None, options=None, rootdir="/"):
    """ Provides the core functionality to configure the used software 
        repositories, the corresponding authentication keys and 
        update automation """
    self.popconfile = rootdir+"/etc/popularity-contest.conf"

    self.rootdir = rootdir
    if rootdir != "/":
      apt_pkg.config.set("Dir", rootdir)

    # FIXME: some saner way is needed here
    if datadir == None:
      datadir = "/usr/share/software-properties/"
    self.options = options
    self.datadir = datadir

    self.sourceslist = SourcesList()
    self.distro = aptsources.distro.get_distro()
    
    self.seen_server = []
    self.modified_sourceslist = False

    self.reload_sourceslist()
    self.backup_sourceslist()

    self.backup_apt_conf()

    # FIXME: we need to store this value in a config option
    #self.custom_mirrors = ["http://adasdwww.de/ubuntu"]
    self.custom_mirrors= []

    # Queue to push/pop results from threads
    self.myqueue = queue.Queue()

    # apt-key stuff
    self.apt_key = AptAuth(rootdir=rootdir)

    self.cancellable = Gio.Cancellable()

    atexit.register(self.wait_for_threads)

  def wait_for_threads(self):
    " wait for all running threads (PPA key fetchers) to exit "
    for t in threading.enumerate():
      if t.ident != threading.current_thread().ident:
        t.join()

  def backup_apt_conf(self):
    """Backup all apt configuration options"""
    self.apt_conf_backup = {}
    for option in softwareproperties.CONF_MAP.keys():
        value = apt_pkg.config.find_i(softwareproperties.CONF_MAP[option])
        self.apt_conf_backup[option] = value

  def restore_apt_conf(self):
    """Restore the stored apt configuration"""
    for option in self.apt_conf_backup.keys():
        apt_pkg.config.set(softwareproperties.CONF_MAP[option],
                           str(self.apt_conf_backup[option]))
    self.write_config()

  def get_update_automation_level(self):
    """ Parse the apt cron configuration. Try to fit a predefined use case 
        and return it. Special case: if the user made a custom 
        configurtation, that we cannot represent it will return None """
    if apt_pkg.config.find_i(softwareproperties.CONF_MAP["autoupdate"]) > 0:
        # Autodownload
        if apt_pkg.config.find_i(softwareproperties.CONF_MAP["unattended"]) == 1\
           and os.path.exists("/usr/bin/unattended-upgrade"):
            return softwareproperties.UPDATE_INST_SEC
        elif apt_pkg.config.find_i(softwareproperties.CONF_MAP["autodownload"]) == 1 and  \
             apt_pkg.config.find_i(softwareproperties.CONF_MAP["unattended"]) == 0:
            return softwareproperties.UPDATE_DOWNLOAD
        elif apt_pkg.config.find_i(softwareproperties.CONF_MAP["unattended"]) == 0 and \
             apt_pkg.config.find_i(softwareproperties.CONF_MAP["autodownload"]) == 0:
            return softwareproperties.UPDATE_NOTIFY
        else:
            return None
    elif apt_pkg.config.find_i(softwareproperties.CONF_MAP["unattended"]) == 0 and \
         apt_pkg.config.find_i(softwareproperties.CONF_MAP["autodownload"]) == 0:
        return softwareproperties.UPDATE_MANUAL
    else:
        return None

  def set_update_automation_level(self, state):
    """ Set the apt periodic configurtation to the selected 
        update automation level. To synchronize the cache update and the 
        actual upgrading function, the upgrade function, e.g. unattended, 
        will run every day, if enabled. """
    if state == softwareproperties.UPDATE_INST_SEC:
        apt_pkg.config.set(softwareproperties.CONF_MAP["unattended"], str(1))
        apt_pkg.config.set(softwareproperties.CONF_MAP["autodownload"], str(1))
    elif state == softwareproperties.UPDATE_DOWNLOAD:
        apt_pkg.config.set(softwareproperties.CONF_MAP["autodownload"], str(1))
        apt_pkg.config.set(softwareproperties.CONF_MAP["unattended"], str(0))
    elif state == softwareproperties.UPDATE_NOTIFY:
        apt_pkg.config.set(softwareproperties.CONF_MAP["autodownload"], str(0))
        apt_pkg.config.set(softwareproperties.CONF_MAP["unattended"], str(0))
    else:
        apt_pkg.config.set(softwareproperties.CONF_MAP["autoupdate"], str(0))
        apt_pkg.config.set(softwareproperties.CONF_MAP["unattended"], str(0))
        apt_pkg.config.set(softwareproperties.CONF_MAP["autodownload"], str(0))
    self.set_modified_config()

  def set_update_interval(self, days):
      """Set the interval in which we check for available updates"""
      # Only write the key if it has changed
      if not days == apt_pkg.config.find_i(softwareproperties.CONF_MAP["autoupdate"]):
          apt_pkg.config.set(softwareproperties.CONF_MAP["autoupdate"], str(days))
          self.set_modified_config()

  def get_update_interval(self):
    """ Returns the interval of the apt periodic cron job """
    return apt_pkg.config.find_i(softwareproperties.CONF_MAP["autoupdate"])

  def get_release_upgrades_policy(self):
    """
    return the release upgrade policy:
     RELEASE_UPGRADES_NORMAL,
     RELEASE_UPGRADES_LTS,
     RELEASE_UPGRADES_NEVER
    """
    # default (if no option is set) is NORMAL
    if not os.path.exists(self.RELEASE_UPGRADES_CONF):
      return self.RELEASE_UPGRADES_NORMAL
    parser = ConfigParser()
    parser.read(self.RELEASE_UPGRADES_CONF)
    if parser.has_option("DEFAULT","Prompt"):
      type = parser.get("DEFAULT","Prompt").lower()
      for k, v in self.release_upgrades_policy_map.items():
        if v == type:
          return k
    return self.RELEASE_UPGRADES_NORMAL

  def set_release_upgrades_policy(self, i):
    """
    set the release upgrade policy:
     RELEASE_UPGRADES_NORMAL,
     RELEASE_UPGRADES_LTS,
     RELEASE_UPGRADES_NEVER
     """
    # we are note using ConfigParser.write() as it removes comments
    if not os.path.exists(self.RELEASE_UPGRADES_CONF):
      with open(self.RELEASE_UPGRADES_CONF,"w") as f:
        f.write("[DEFAULT]\nPrompt=%s\n"% self.release_upgrades_policy_map[i])
      return True
    with open(self.RELEASE_UPGRADES_CONF,"r") as f, NamedTemporaryFile(mode="w+") as out:
      for line in f:
        line = line.strip()
        if line.lower().startswith("prompt"):
          out.write("Prompt=%s\n" % self.release_upgrades_policy_map[i])
        else:
          out.write(line+"\n")
      out.flush()
      shutil.copymode(self.RELEASE_UPGRADES_CONF, out.name)
      shutil.copy(out.name, self.RELEASE_UPGRADES_CONF)
    return True

  def get_popcon_participation(self):
    """ Will return True if the user wants to participate in the popularity 
        contest. Otherwise it will return False. Special case: if no 
        popcon is installed it will return False """
    if os.path.exists(self.popconfile):
        with open(self.popconfile) as f:
          lines = f.read().split("\n")
        for line in lines:
            try:
                (key,value) = line.split("=")
                if key == "PARTICIPATE" and value.strip('"').lower() == "yes":
                    return True
            except ValueError:
                continue
    return False

  def set_popcon_pariticipation(self, is_helpful):
    """ Enable or disable the participation in the popularity contest """
    if is_helpful == True:
        value = "yes"
    else:
        value = "no"
    if os.path.exists(self.popconfile):
        # read the current config and replace the corresponding settings
        # FIXME: should we check the other values, too?
        with open(self.popconfile, "r") as popconfile:
            lines = [re.sub(r'^(PARTICIPATE=)(".+?")', '\\1"%s"' % value, line)
                     for line in popconfile]
    else:
        # create a new popcon config file
        m = md5()
        with open("/dev/urandom", "rb") as f:
            m.update(f.read(1024))
        id = m.hexdigest()
        lines = []
        lines.append("MY_HOSTID=\"%s\"\n" % id)
        lines.append("PARTICIPATE=\"%s\"\n" % str(value))
        lines.append("USE_HTTP=\"yes\"\n")
    with open(self.popconfile, "w") as f:
        f.writelines(lines)

  def get_source_code_state(self):
    """Return True if all distro componets are also available as 
       source code. Otherwise return Flase. Special case: If the
       configuration cannot be represented return None"""
  
    if len(self.distro.source_code_sources) < 1:
        # we don't have any source code sources, so
        # uncheck the button
        self.distro.get_source_code = False
        return False
    else:
        # there are source code sources, so we check the button
        self.distro.get_source_code = True
        # check if there is a corresponding source code source for
        # every binary source. if not set the checkbutton to inconsistent
        templates = {}
        sources = []
        sources.extend(self.distro.main_sources)
        sources.extend(self.distro.child_sources)
        for source in sources:
            if source.template in templates:
                for comp in source.comps:
                    templates[source.template].add(comp)
            else:
                templates[source.template] = set(source.comps)
        # add fake http sources for the cdrom, since the sources
        # for the cdrom are only available in the internet
        if len(self.distro.cdrom_sources) > 0:
            templates[self.distro.source_template] = self.distro.cdrom_comps
        for source in self.distro.source_code_sources:
            if source.template not in templates or \
               (source.template in templates and not \
                (len(set(templates[source.template]) ^ set(source.comps)) == 0\
                 or (len(set(source.comps) ^ self.distro.enabled_comps) == 0))):
                self.distro.get_source_code = False
                return None
                break
    return True

  def print_source_entry(self, source):
    """Print the data of a source entry to the command line"""
    for (label, value) in [("URI:", source.uri),
                           ("Comps:", source.comps),
                           ("Enabled:", not source.disabled),
                           ("Valid:", not source.invalid)]:
        print(" %s %s" % (label, value))
    if source.template:
        for (label, value) in [("MatchURI:", source.template.match_uri),
                               ("BaseURI:", source.template.base_uri)]:
            print(" %s %s" % (label, value))
    print("\n")

  def massive_debug_output(self):
    """Print the complete sources.list""" 
    print("START SOURCES.LIST:")
    for source in self.sourceslist:
        print(source.str())
    print("END SOURCES.LIST\n")

  def change_main_download_server(self, server):
    """ change the main download server """
    self.distro.default_server = server
    res = self.distro.change_server(server)
    self.set_modified_sourceslist()
    return res

  def enable_component(self, comp):
    """Enable a component of the distro"""
    self.distro.enable_component(comp) 
    self.set_modified_sourceslist()

  def disable_component(self, comp):
    """Disable a component of the distro"""
    self.distro.disable_component(comp) 
    self.set_modified_sourceslist()

  def _find_template_from_string(self, name):
    for template in self.distro.source_template.children:
      if template.name == name:
        return template

  def disable_child_source(self, template):
    """Enable a child repo of the distribution main repository"""
    if isinstance(template, str):
      template = self._find_template_from_string(template)

    for source in self.distro.child_sources:
        if source.template == template:
            self.sourceslist.remove(source)
    for source in self.distro.source_code_sources:
        if source.template == template:
            self.sourceslist.remove(source)
    self.set_modified_sourceslist()

  def enable_child_source(self, template):
    """Enable a child repo of the distribution main repository"""
    if isinstance(template, str):
      template = self._find_template_from_string(template)

    # Use the currently selected mirror only if the child source
    # did not override the server
    if template.base_uri == None:
        child_uri = self.distro.default_server
    else:
        child_uri = template.base_uri
    self.distro.add_source(uri=child_uri, dist=template.name)
    self.set_modified_sourceslist()

  def disable_source_code_sources(self):
    """Remove all distro source code sources"""
    sources = []
    sources.extend(self.distro.main_sources)
    sources.extend(self.distro.child_sources)
    # remove all exisiting sources
    for source in self.distro.source_code_sources:
        self.sourceslist.remove(source)
    self.set_modified_sourceslist()
  
  def enable_source_code_sources(self):
    """Enable source code source for all distro sources"""
    sources = []
    sources.extend(self.distro.main_sources)
    sources.extend(self.distro.child_sources)

    # remove all exisiting sources
    for source in self.distro.source_code_sources:
        self.sourceslist.remove(source)

    for source in sources:
        self.sourceslist.add("deb-src",
                             source.uri,
                             source.dist,
                             source.comps,
                             "Added by software-properties",
                             self.sourceslist.list.index(source)+1,
                             source.file)
    for source in self.distro.cdrom_sources:
        self.sourceslist.add("deb-src",
                             self.distro.source_template.base_uri,
                             self.distro.source_template.name,
                             source.comps,
                             "Added by software-properties",
                             self.sourceslist.list.index(source)+1,
                             source.file)
    self.set_modified_sourceslist()

  def backup_sourceslist(self):
    """Store a backup of the source.list in memory"""
    self.sourceslist_backup = []
    for source in self.sourceslist.list:
        source_bkp = SourceEntry(line=source.line,file=source.file)
        self.sourceslist_backup.append(source_bkp)
  
  def _find_source_from_string(self, line):
    # ensure that we have a current list, it might have been changed underneath
    # us
    self.reload_sourceslist()

    for source in self.sourceslist.list:
      if str(source) == line:
        return source
    return None

  def toggle_source_use(self, source):
    """Enable or disable the selected channel"""
    #FIXME cdroms need to disable the comps in the childs and sources
    if isinstance(source, str):
      source = self._find_source_from_string(source)
    source.disabled = not source.disabled
    self.set_modified_sourceslist()

  def replace_source_entry(self, old_entry, new_entry):
    # find and replace, then write
    for (index, entry) in enumerate(self.sourceslist.list):
      if str(entry) == old_entry:
        file = self.sourceslist.list[index].file
        self.sourceslist.list[index] = SourceEntry(new_entry, file)
        self.set_modified_sourceslist()
        return True
    return False

  def revert(self):
    """Revert all settings to the state when software-properties 
       was launched"""
    #FIXME: GPG keys are still missing
    self.restore_apt_conf()
    self.revert_sourceslist()

  def revert_sourceslist(self):
    """Restore the source list from the startup of the dialog"""
    self.sourceslist.list = []
    for source in self.sourceslist_backup:
        source_reset = SourceEntry(line=source.line,file=source.file)
        self.sourceslist.list.append(source_reset)
    self.save_sourceslist()
    self.reload_sourceslist()

  def set_modified_sourceslist(self):
    """The sources list was changed and now needs to be saved and reloaded"""
    self.modified_sourceslist = True
    if self.options and self.options.massive_debug:
        self.massive_debug_output()
    self.save_sourceslist()
    self.reload_sourceslist()

  def set_modified_config(self):
    """Write the changed apt configuration to file"""
    self.write_config()

  def render_source(self, source):
    """Render a nice output to show the source in a treeview"""
    if source.template == None:
        if source.comment:
            contents = "<b>%s</b> %s" % (escape(source.comment).strip(),
                                         source.dist)
            # Only show the components if there are more than one
            if len(source.comps) > 1:
                for c in source.comps:
                    contents += " %s" % c
            if source.type in ("deb-src", "rpm-src"):
                contents += " %s" % _("(Source Code)")
            contents += "\n%s" % source.uri
        else:
            contents = "<b>%s %s</b>" % (source.uri, source.dist)
            for c in source.comps:
                contents += " %s" % c
            if source.type in ("deb-src", "rpm-src"):
                contents += " %s" % _("(Source Code)")
        return contents
    else:
        # try to make use of a corresponding template
        contents = "<b>%s</b>" % source.template.description
        if source.type in ("deb-src", "rpm-src"):
            contents += " (%s)" % _("Source Code")
        if source.comment:
            contents +=" %s" % source.comment
        if source.template.child == False:
            for comp in source.comps:
                if source.template.has_component(comp):
                    # fixme: move something like this into distinfo.Template
                    #        (why not use a dictionary again?)
                    for c in source.template.components:
                        if c.name == comp:
                            contents += "\n%s" % c.description
                else:
                    contents += "\n%s" % comp
        return contents

  def get_comparable(self, source):
      """extract attributes to sort the sources"""
      cur_sys = 1
      has_template = 1
      has_comment = 1
      is_source = 1
      revert_numbers = maketrans("0123456789", "9876543210")
      if source.template:
        has_template = 0
        desc = source.template.description
        if source.template.distribution == self.distro:
            cur_sys = 0
      else:
          desc = "%s %s %s" % (source.uri, source.dist, source.comps)
          if source.comment:
              has_comment = 0
      if source.type.find("src"):
          is_source = 0
      return (cur_sys, has_template, has_comment, is_source,
              desc.translate(revert_numbers))

  def get_isv_sources(self):
    """Return a list of sources that are not part of the distribution"""
    isv_sources = []
    for source in self.sourceslist.list:
        if not source.invalid and\
           (source not in self.distro.main_sources and\
            source not in self.distro.cdrom_sources and\
            source not in self.distro.child_sources and\
            source not in self.distro.disabled_sources) and\
           source not in self.distro.source_code_sources:
            isv_sources.append(source)
    return isv_sources

  def get_cdrom_sources(self):
    """Return the list of CDROM based distro sources"""
    return self.distro.cdrom_sources
      
  def get_comp_download_state(self, comp):
    """Return a tuple: the first value describes if a component is enabled
       in the Internet repositories. The second value describes if the
       first value is inconsistent."""
    #FIXME: also return a correct inconsistent value
    return (comp.name in self.distro.download_comps, False)

  def get_comp_child_state(self, template):
    """Return a tuple: the first value describes if a component is enabled
       in one of the child source that matcth the given template. 
       The second value describes if the first value is inconsistent."""
    comps = []
    for child in self.distro.child_sources:
        if child.template == template:
            comps.extend(child.comps)
    if len(comps) > 0 and \
        len(self.distro.enabled_comps ^ set(comps)) == 0:
        # All enabled distro components are also enabled for the child source
        return (True, False)
    elif len(comps) > 0 and\
        len(self.distro.enabled_comps ^ set(comps)) != 0:
        # A matching child source does exist but doesn't include all 
        # enabled distro components
        return(False, True)
    else:
        # There is no corresponding child source at all
        return (False, False)
  
  def reload_sourceslist(self):
    self.sourceslist.refresh()
    self.sourceslist_visible=[]
    self.distro.get_sources(self.sourceslist)    

  def write_config(self):
    """Write the current apt configuration to file"""
    # update the adept file as well if it is there
    conffiles = [self.rootdir+"/etc/apt/apt.conf.d/10periodic",
                 self.rootdir+"/etc/apt/apt.conf.d/20auto-upgrades",
                 self.rootdir+"/etc/apt/apt.conf.d/15adept-periodic-update"]

    # check (beforehand) if one exists, if not create one
    for f in conffiles:
      if os.path.isfile(f):
        break
    else:
      print("No config found, creating one")
      with open(conffiles[0], "w") as f:
        f.write("")

    # ensure /etc/cron.daily/apt is executable
    ac = "/etc/cron.daily/apt"
    if os.path.exists(ac):
      perm = os.stat(ac)[stat.ST_MODE]
      if not (perm & stat.S_IXUSR):
        print("file '%s' not executable, fixing" % ac)
        os.chmod(ac, 0o755)

    # now update them
    for periodic in conffiles:
      # read the old content first
      content = []
      if os.path.isfile(periodic):
        with open(periodic, "r") as f:
          content = f.readlines()
        cnf = apt_pkg.config.subtree("APT::Periodic")

        # then write a new file without the updated keys
        with open(periodic, "w") as f:
          for line in content:
            for key in cnf.list():
              if line.find("APT::Periodic::%s" % (key)) >= 0:
                break
            else:
              f.write(line)

          # and append the updated keys
          for i in cnf.list():
            f.write("APT::Periodic::%s \"%s\";\n" % (i, cnf.find_i(i)))

  def save_sourceslist(self):
    """Backup the existing sources.list files and write the current 
       configuration"""
    self.sourceslist.backup(".save")
    self.sourceslist.save()

  def _is_line_in_whitelisted_channel(self, srcline):
    """
    helper that checks if a given line is in the source list
    return the channel name or None if not found
    """
    srcentry = SourceEntry(srcline)
    if os.path.exists(self.CHANNEL_PATH):
      for filename in glob.glob("%s/*.list" % self.CHANNEL_PATH):
        with open(filename) as f:
          for line in f:
            if line.strip().startswith("#"):
              continue
            if srcentry == SourceEntry(line):
              return os.path.splitext(os.path.basename(filename))[0]
    return None

  def check_and_add_key_for_whitelisted_shortcut(self, shortcut):
    """
    helper that adds the gpg key of the channel to the apt
    keyring *if* the channel is in the whitelist
    /usr/share/app-install/channels
    """
    srcline = shortcut.SourceEntry().line
    channel = self._is_line_in_whitelisted_channel(srcline)
    if channel:
      keyp = "%s/%s.key" % (self.CHANNEL_PATH, channel)
      self.add_key(keyp)
      return True
    return False

  def update_interface(self):
    " abstract interface to keep the UI alive "

  def expand_http_line(self, line):
    """
    short cut - this:
      apt-add-repository http://packages.medibuntu.org free non-free
    same as
      apt-add-repository 'deb http://packages.medibuntu.org/ '$(lsb_release -cs)' free non-free'
    """
    if not line.startswith("http"):
      return line
    repo = line.split()[0]
    try:
        areas = line.split(" ",1)[1]
    except IndexError:
        areas = "main"
    line = "deb %s %s %s" % ( repo, self.distro.codename, areas )
    return line

  def add_source_from_line(self, line, enable_source_code=False):
    """
    Add a source for the given line.
    """
    try:
        shortcut = shortcut_handler(line.strip())
    except InvalidShortcutException:
      return False

    return self.add_source_from_shortcut(shortcut, enable_source_code)

  def add_source_from_shortcut(self, shortcut, enable_source_code=False):
    """
    Add a source with the given shortcut and add the signing key if the
    site is in whitelist or the shortcut implementer adds it.
    """

    deb_line = shortcut.SourceEntry().line
    file = shortcut.sourceparts_file
    deb_line = self.expand_http_line(deb_line)
    debsrc_entry_type = 'deb-src' if enable_source_code else '# deb-src'
    debsrc_line = debsrc_entry_type + deb_line[3:]
    new_deb_entry = SourceEntry(deb_line, file)
    new_debsrc_entry = SourceEntry(debsrc_line, file)
    if new_deb_entry.invalid or new_debsrc_entry.invalid:
      return False
    if not self.check_and_add_key_for_whitelisted_shortcut(shortcut):
      shortcut.add_key()
    self.sourceslist.add(new_deb_entry.type,
                         new_deb_entry.uri,
                         new_deb_entry.dist,
                         new_deb_entry.comps,
                         comment=new_deb_entry.comment,
                         file=new_deb_entry.file,
                         architectures=new_deb_entry.architectures)
    self.sourceslist.add(debsrc_entry_type,
                         new_debsrc_entry.uri,
                         new_debsrc_entry.dist,
                         new_debsrc_entry.comps,
                         comment=new_debsrc_entry.comment,
                         file=new_debsrc_entry.file,
                         architectures=new_debsrc_entry.architectures)
    self.set_modified_sourceslist()
    if self.options and self.options.update:
        import apt
        cache = apt.Cache()
        cache.update(sources_list=new_debsrc_entry.file)
    return True

  def remove_source(self, source, remove_source_code=True):
    """Remove the given source"""
    if remove_source_code:
      if isinstance(source, str):
        # recall this method giving a SourceEntry as an argument
        source = self._find_source_from_string(source)
        self.remove_source(source, True)
      elif source is not None:
        self.remove_source(source, False)
        # remove the deb-src lines (enabled or not) associated to
        # this source entry
        source = copy.copy(source)
        source.type = 'deb-src'
        source.disabled = True
        self.remove_source(source, False)
        source.disabled = False
        self.remove_source(source, False)
      return

    # first find the source object if we got a string
    if isinstance(source, str):
      source = self._find_source_from_string(source)
    if source is None:
      return
    # if its a sources.list.d file and it contains only a single line
    # (the line that we just remove), then all references to that
    # file are gone and the file is not saved. we work around that
    # here
    if source.file != apt_pkg.config.find_file("Dir::Etc::sourcelist"):
      self.sourceslist.list.append(SourceEntry("", file=source.file))
    try:
      self.sourceslist.remove(source)
    except ValueError:
      # this exception is raised if trying to remove an entry that does
      # not exist. in this case we suppress the error because there's no
      # need to propagate it (the aim of this method is to ensure that
      # the given entries are not listed in the sourceslist)
      pass
    self.set_modified_sourceslist()

  def add_key(self, path):
    """Add a gnupg key to the list of trusted software vendors"""
    if not os.path.exists(path):
        return False
    try:
        res = self.apt_key.add(path)
        return res
    except:
        return False

  def add_key_from_data(self, keydata):
    "Add a gnupg key from a utf-8 data string (e.g. copy-n-paste)"
    tmp = tempfile.NamedTemporaryFile()
    tmp.write(keydata.encode("utf-8"))
    tmp.flush()
    return self.add_key(tmp.name)

  def remove_key(self, keyid):
    """Remove a gnupg key from the list of trusted software vendors"""
    try:
        self.apt_key.rm(keyid)
        return True
    except:
        return False

  def update_keys(self):
    """ Run apt-key update """
    try:
      self.apt_key.update()
      return True
    except:
      return False

  def get_package_id(self, apt_cache, pkg):
    """ Return the PackageKit package id """
    assert isinstance(pkg, apt_pkg.Package)
    cur_ver = pkg.current_ver
    if cur_ver:
        ver = cur_ver.ver_str
        arch = cur_ver.arch
    else:
        depcache = apt_pkg.DepCache(apt_cache)
        candidate = depcache.get_candidate_ver(pkg)
        ver = candidate.ver_str
        arch = candidate.arch
    return "%s;%s;%s;" % (pkg.name, ver, arch)

  @staticmethod
  def get_dependencies(apt_cache, package, pattern=None):
    """ Get the package dependencies, which can be filtered out by a pattern """
    depcache = apt_pkg.DepCache(apt_cache)
    candidate = depcache.get_candidate_ver(package)

    dependencies = []
    try:
        for dep_list in candidate.depends_list_str.get('Depends'):
            for dep_name, dep_ver, dep_op in dep_list:
                if dep_name.find(pattern) != -1:
                    dependencies.append(apt_cache[dep_name])
    except (KeyError, TypeError):
        return []

    return dependencies


if __name__ == "__main__":
  sp = SoftwareProperties()
  print(sp.get_release_upgrades_policy())
  sp.set_release_upgrades_policy(0)
