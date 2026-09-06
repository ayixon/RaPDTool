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

from softwareproperties.extendedsourceslist import SourceEntry
from softwareproperties.sourceslist import SourcesListShortcutHandler


class URIShortcutHandler(SourcesListShortcutHandler):
    def __init__(self, shortcut, **kwargs):
        (uri, _, line_comps) = shortcut.strip().partition(' ')

        line_comps = set(line_comps.split() if line_comps else [])
        param_comps = set(kwargs.get('components', []))
        comps = list(line_comps | param_comps)

        if not comps:
            # if no comps provided, we default to 'main'
            comps = ['main']

        kwargs['components'] = comps

        suite = kwargs.get('codename')
        pocket = kwargs.get('pocket')
        line = SourceEntry.create_line(uri, suite=suite, pocket=pocket)

        super(URIShortcutHandler, self).__init__(line, **kwargs)


# vi: ts=4 expandtab
