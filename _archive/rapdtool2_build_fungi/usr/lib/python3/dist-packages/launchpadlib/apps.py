# Copyright 2009 Canonical Ltd.

# This file is part of launchpadlib.
#
# launchpadlib is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, version 3 of the License.
#
# launchpadlib is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
# for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with launchpadlib. If not, see <http://www.gnu.org/licenses/>.

"""Command-line applications for Launchpadlib.

This module contains the code for various applications. The applications
themselves are kept in bin/.
"""

__all__ = [
    "RequestTokenApp",
]

import json

from launchpadlib.credentials import Credentials
from launchpadlib.uris import lookup_web_root


class RequestTokenApp(object):
    """An application that creates request tokens."""

    def __init__(self, web_root, consumer_name, context):
        """Initialize."""
        self.web_root = lookup_web_root(web_root)
        self.credentials = Credentials(consumer_name)
        self.context = context

    def run(self):
        """Get a request token and return JSON information about it."""
        token = self.credentials.get_request_token(
            self.context,
            self.web_root,
            token_format=Credentials.DICT_TOKEN_FORMAT,
        )
        return json.dumps(token)
