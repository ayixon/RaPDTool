# Copyright 2008-2009 Canonical Ltd.  All rights reserved.

# This file is part of wadllib.
#
# wadllib is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# wadllib is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with wadllib.  If not, see
# <http://www.gnu.org/licenses/>.

import sys

try:
    import importlib.metadata as importlib_metadata
except ImportError:
    import importlib_metadata

__version__ = importlib_metadata.version("wadllib")

if sys.version_info[0] >= 3:
    _string_types = str
    def _make_unicode(b):
        if hasattr(b, 'decode'):
            return b.decode()
        else:
            return str(b)
else:
    _string_types = basestring
    _make_unicode = unicode
