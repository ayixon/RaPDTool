#  software-properties cloud-archive support
#
#  Copyright (c) 2013 Canonical Ltd.
#
#  Author: Scott Moser <smoser@ubuntu.org>
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

from __future__ import print_function

import os
import subprocess

from gettext import gettext as _

from softwareproperties.shortcuthandler import (ShortcutHandler, ShortcutException,
                                                InvalidShortcutException)
from softwareproperties.sourceslist import SourcesListShortcutHandler
from softwareproperties.uri import URIShortcutHandler

from urllib.parse import urlparse


RELEASE_MAP = {
    'folsom': 'precise',
    'grizzly': 'precise',
    'havana': 'precise',
    'icehouse': 'precise',
    'juno': 'trusty',
    'kilo': 'trusty',
    'liberty': 'trusty',
    'mitaka': 'trusty',
    'newton': 'xenial',
    'ocata': 'xenial',
    'pike': 'xenial',
    'queens': 'xenial',
    'rocky': 'bionic',
    'stein': 'bionic',
    'train': 'bionic',
    'ussuri': 'bionic',
    'victoria': 'focal',
    'wallaby': 'focal',
    'xena': 'focal',
    'yoga': 'focal',
    'zed': 'jammy',
}
UCA = "Ubuntu Cloud Archive"
WEB_LINK = 'https://wiki.ubuntu.com/OpenStack/CloudArchive'

UCA_ARCHIVE = "http://ubuntu-cloud.archive.canonical.com/ubuntu"
UCA_PREFIXES = ['cloud-archive', 'uca']
UCA_VALID_POCKETS = ['updates', 'proposed']
UCA_DEFAULT_POCKET = UCA_VALID_POCKETS[0]

UCA_KEYRING_PACKAGE = 'ubuntu-cloud-keyring'


class CloudArchiveShortcutHandler(ShortcutHandler):
    def __init__(self, shortcut, **kwargs):
        super(CloudArchiveShortcutHandler, self).__init__(shortcut, **kwargs)
        self.caname = None

        # one of these will set caname and pocket, and maybe _source_entry
        if not any((self._match_uca(shortcut),
                    self._match_uri(shortcut),
                    self._match_sourceslist(shortcut))):
            msg = (_("not a valid cloud-archive format: '%s'") % shortcut)
            raise InvalidShortcutException(msg)

        self.caname = self.caname.lower()

        self._filebase = "cloudarchive-%s" % self.caname

        self.pocket = self.pocket.lower()
        if not self.pocket in UCA_VALID_POCKETS:
            msg = (_("not a valid cloud-archive pocket: '%s'") % self.pocket)
            raise ShortcutException(msg)

        if not self.caname in RELEASE_MAP:
            msg = (_("not a valid cloud-archive: '%s'") % self.caname)
            raise ShortcutException(msg)

        codename = RELEASE_MAP[self.caname]
        validnames = set((codename, os.getenv("CA_ALLOW_CODENAME") or codename))
        if self.codename not in validnames:
            msg = (_("cloud-archive for %s only supported on %s") %
                   (self.caname.capitalize(), codename.capitalize()))
            raise ShortcutException(msg)

        self._description = f'{UCA} for OpenStack {self.caname.capitalize()}'
        if self.pocket == 'proposed':
            self._description += ' [proposed]'

        if not self._source_entry:
            dist = f'{self.codename}-{self.pocket}/{self.caname}'
            comps = ' '.join(self.components) or 'main'
            line = f'{self.binary_type} {UCA_ARCHIVE} {dist} {comps}'
            self._set_source_entry(line)

    @property
    def description(self):
        return self._description

    @property
    def web_link(self):
        return WEB_LINK

    def add_key(self):
        # UCA provides its repo keys in a package
        subprocess.run(f'apt-get install -y {UCA_KEYRING_PACKAGE}'.split(), check=True)

    def _encode_filebase(self, suffix=None):
        # ignore suffix
        return super(CloudArchiveShortcutHandler, self)._encode_filebase()

    def _match_uca(self, shortcut):
        (prefix, _, uca) = shortcut.rpartition(':')
        if not prefix.lower() in UCA_PREFIXES:
            return False

        (caname, _, pocket) = uca.partition('-')
        if not caname:
            return False

        self.caname = caname
        self.pocket = pocket or self.pocket or UCA_DEFAULT_POCKET
        return True

    def _match_uri(self, shortcut):
        try:
            return self._match_handler(URIShortcutHandler(shortcut))
        except InvalidShortcutException:
            return False

    def _match_sourceslist(self, shortcut):
        try:
            return self._match_handler(SourcesListShortcutHandler(shortcut))
        except InvalidShortcutException:
            return False

    def _match_handler(self, handler):
        parsed = urlparse(handler.SourceEntry().uri)
        if parsed.hostname != urlparse(UCA_ARCHIVE).hostname:
            return False

        (codename, _, caname) = handler.SourceEntry().dist.partition('/')
        (codename, _, pocket) = codename.partition('-')

        if not all((codename, caname)):
            return False

        self.caname = caname
        self.pocket = pocket or self.pocket or UCA_DEFAULT_POCKET

        self._set_source_entry(handler.SourceEntry().line)
        return True

