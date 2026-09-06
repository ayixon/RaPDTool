#  Copyright (c) 2019 Canonical Ltd.
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

from softwareproperties.extendedsourceslist import SourceEntry

from softwareproperties.shortcuthandler import (ShortcutHandler, InvalidShortcutException)

from urllib.parse import urlparse


SOURCESLIST_FILE_PREFIX = "archive_uri"

class SourcesListShortcutHandler(ShortcutHandler):
    def __init__(self, shortcut, **kwargs):
        super(SourcesListShortcutHandler, self).__init__(shortcut, **kwargs)

        entry = SourceEntry(shortcut)
        if entry.invalid:
            raise InvalidShortcutException(_("Invalid sources.list line: '%s'") % shortcut)

        uri = entry.uri
        if not self.is_valid_uri(uri):
            raise InvalidShortcutException(_("Invalid URI: '%s'") % uri)

        self.components = list(set(self.components) | set(entry.comps))

        parsed = urlparse(uri)

        self._username = parsed.username
        self._password = parsed.password

        entry.uri = self.uri_strip_auth(entry.uri)
        # must set _filebase first; _set_source_entry uses it to set entry.file
        self._filebase = f"{SOURCESLIST_FILE_PREFIX}-{entry.uri}"
        self._set_source_entry(str(entry))


# vi: ts=4 expandtab
