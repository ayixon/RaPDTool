# -*- coding: utf-8 -*-
#
# D-Bus based interface for software-properties
#
# Copyright © 2010 Harald Sitter <apachelogger@ubuntu.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

from gi.repository import GLib

import dbus.service
import logging
import subprocess
import tempfile
import sys

from aptsources.sourceslist import SourceEntry

from dbus.mainloop.glib import DBusGMainLoop
from softwareproperties.SoftwareProperties import SoftwareProperties

DBUS_BUS_NAME = 'com.ubuntu.SoftwareProperties'
DBUS_PATH = '/'
DBUS_INTERFACE_NAME = 'com.ubuntu.SoftwareProperties'

DBusGMainLoop(set_as_default=True)

def _to_unicode(string):
  if sys.version < '3':
    return string.encode('utf-8')
  else:
    return string

class PermissionDeniedByPolicy(dbus.DBusException):
    _dbus_error_name = 'com.ubuntu.SoftwareProperties.PermissionDeniedByPolicy'

class SoftwarePropertiesDBus(dbus.service.Object, SoftwareProperties):

    def __init__(self, bus, options=None, datadir=None, rootdir="/"):
        # init software properties
        SoftwareProperties.__init__(self, options=options, datadir=datadir, rootdir=rootdir)
        # used in _check_policykit_priviledge
        self.dbus_info = None
        self.polkit = None
        # init dbus service
        bus_name = dbus.service.BusName(DBUS_INTERFACE_NAME, bus=bus)
        dbus.service.Object.__init__(self, bus_name, DBUS_PATH)
        # useful for testing
        self.enforce_polkit = True
        logging.debug("waiting for connections")

    # override set_modified_sourceslist to emit a signal
    def save_sourceslist(self):
        super(SoftwarePropertiesDBus, self).save_sourceslist()
        self.SourcesListModified()
    def write_config(self):
        super(SoftwarePropertiesDBus, self).write_config()
        self.ConfigModified()

    # ------------------ SIGNALS
    @dbus.service.signal(dbus_interface=DBUS_INTERFACE_NAME, signature='')
    def SourcesListModified(self):
        """ emit signal when the sources.list got modified """
        logging.debug("SourcesListModified signal")

    @dbus.service.signal(dbus_interface=DBUS_INTERFACE_NAME, signature='')
    def ConfigModified(self):
        """ emit signal when the sources.list got modified """
        logging.debug("ConfigModified signal")

    @dbus.service.signal(dbus_interface=DBUS_INTERFACE_NAME, signature='')
    def KeysModified(self):
        """ emit signal when the apt keys got modified """
        logging.debug("KeysModified signal")

    @dbus.service.signal(dbus_interface=DBUS_INTERFACE_NAME, signature='')
    def AuthFailed(self):
        """ emit signal when the policykit authentication failed """
        logging.debug("Auth signal")

    @dbus.service.signal(dbus_interface=DBUS_INTERFACE_NAME, signature='')
    def CdromScanFailed(self):
        """ emit signal when adding a cdrom failed """
        logging.debug("Cdrom scan failed signal")

    # ------------------ METHODS

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def Revert(self, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.revert()

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def Reload(self, sender=None, conn=None):
        self.reload_sourceslist()

    # Enabler/Disablers
    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def EnableChildSource(self, template, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.enable_child_source(_to_unicode(template))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def DisableChildSource(self, template, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.disable_child_source(_to_unicode(template))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def EnableComponent(self, component, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.enable_component(_to_unicode(component))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def DisableComponent(self, component, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.disable_component(_to_unicode(component))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def EnableSourceCodeSources(self, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.enable_source_code_sources()

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def DisableSourceCodeSources(self, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.disable_source_code_sources()
        self.save_sourceslist()

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def ToggleSourceUse(self, source, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.toggle_source_use(_to_unicode(source))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='ss', out_signature='b')
    def ReplaceSourceEntry(self, old, new, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        return self.replace_source_entry(
            _to_unicode(old), _to_unicode(new))

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def ChangeMainDownloadServer(self, server, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.change_main_download_server(_to_unicode(server))


    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='')
    def AddCdromSource(self, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self._add_cdrom_source()

    def _add_cdrom_source(self):
        """ add a (already inserted) cdrom """
        tmp = tempfile.NamedTemporaryFile()    
        # need to call it here because python-apt does not support
        # AutoDetect mode yet
        cmd = ["apt-cdrom", "add",
               "-o", "Debug::aptcdrom=1",
               "-o", "Debug::identcdrom=1",
               "-o", "acquire::cdrom::AutoDetect=1",
               "-o", "acquire::cdrom::NoMount=1",
               "-o", "Dir::Etc::sourcelist=%s" % tmp.name,
               ]
        p = subprocess.Popen(cmd)
        # wait for the process to finish
        GLib.timeout_add(500, self._wait_for_cdrom_scan_finish, p, tmp)

    def _wait_for_cdrom_scan_finish(self, p, tmp):
        """ glib timeout helper to wait for the cdrom scanner to finish """
        # keep the timeout running
        if p.poll() is None:
            return True
        # else we have a return code
        res = p.poll()
        if res != 0:
            self.CdromScanFailed()
            return False
        # read tmp file with source name 
        line = ""
        # (read only last line)
        for x in open(tmp.name):
            line = x
        if line != "":
            self.sourceslist.list.insert(0, SourceEntry(line))
            self.set_modified_sourceslist()
        return False

    # Setters
    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='b', out_signature='')
    def SetPopconPariticipation(self, participates, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.set_popcon_pariticipation(participates)

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='i', out_signature='')
    def SetUpdateAutomationLevel(self, state, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.set_update_automation_level(state)

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='i', out_signature='')
    def SetReleaseUpgradesPolicy(self, state, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.set_release_upgrades_policy(state)

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='i', out_signature='')
    def SetUpdateInterval(self, days, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.set_update_interval(int(days))

    # Sources

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def AddSourceFromLine(self, sourceLine, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.add_source_from_line(_to_unicode(sourceLine))
        self.KeysModified()

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='')
    def RemoveSource(self, source, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        self.remove_source(_to_unicode(source))

    # GPG Keys

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='b')
    def AddKey(self, path, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        res = self.add_key(path)
        if res:
            self.KeysModified()
        return res

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='b')
    def AddKeyFromData(self, keyData, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        res = self.add_key_from_data(keyData)
        if res:
            self.KeysModified()
        return res

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='s', out_signature='b')
    def RemoveKey(self, keyid, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        res = self.remove_key(keyid)
        if res:
            self.KeysModified()
        return res

    @dbus.service.method(DBUS_INTERFACE_NAME,
                         sender_keyword="sender", connection_keyword="conn",
                         in_signature='', out_signature='b')
    def UpdateKeys(self, sender=None, conn=None):
        self._check_policykit_privilege(
            sender, conn, "com.ubuntu.softwareproperties.applychanges")
        res = self.update_keys()
        if res:
            self.KeysModified()
        return res

    # helper from jockey
    def _check_policykit_privilege(self, sender, conn, privilege):
        '''Verify that sender has a given PolicyKit privilege.

        sender is the sender's (private) D-BUS name, such as ":1:42"
        (sender_keyword in @dbus.service.methods). conn is
        the dbus.Connection object (connection_keyword in
        @dbus.service.methods). privilege is the PolicyKit privilege string.

        This method returns if the caller is privileged, and otherwise throws a
        PermissionDeniedByPolicy exception.
        '''
        if sender is None and conn is None:
            # called locally, not through D-BUS
            return
        if not self.enforce_polkit:
            # that happens for testing purposes when running on the session
            # bus, and it does not make sense to restrict operations here
            return

        # get peer PID
        if self.dbus_info is None:
            self.dbus_info = dbus.Interface(conn.get_object('org.freedesktop.DBus',
                '/org/freedesktop/DBus/Bus', False), 'org.freedesktop.DBus')
        pid = self.dbus_info.GetConnectionUnixProcessID(sender)

        # query PolicyKit
        if self.polkit is None:
            self.polkit = dbus.Interface(dbus.SystemBus().get_object(
                'org.freedesktop.PolicyKit1',
                '/org/freedesktop/PolicyKit1/Authority', False),
                'org.freedesktop.PolicyKit1.Authority')
        try:
            # we don't need is_challenge return here, since we call with AllowUserInteraction
            (is_auth, _, details) = self.polkit.CheckAuthorization(
                    ('system-bus-name', {'name': dbus.String(sender, variant_level = 1)}),
                    privilege, {'': ''}, dbus.UInt32(1), '', timeout=600)
        except dbus.DBusException as e:
            if e._dbus_error_name == 'org.freedesktop.DBus.Error.ServiceUnknown':
                # polkitd timed out, connect again
                self.polkit = None
                return self._check_polkit_privilege(sender, conn, privilege)
            else:
                raise

        if not is_auth:
            logging.debug('_check_polkit_privilege: sender %s on connection %s pid %i is not authorized for %s: %s' %
                    (sender, conn, pid, privilege, str(details)))
            self.AuthFailed()
            raise PermissionDeniedByPolicy(privilege)
