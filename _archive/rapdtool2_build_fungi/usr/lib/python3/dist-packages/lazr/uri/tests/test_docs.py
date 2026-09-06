# Copyright 2009 Canonical Ltd.  All rights reserved.
#
# This file is part of lazr.uri
#
# lazr.uri is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# lazr.uri is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with lazr.uri.  If not, see <http://www.gnu.org/licenses/>.

"""Test harness for doctests."""

from __future__ import print_function

__metaclass__ = type
__all__ = [
    'load_tests',
    ]

import atexit
import doctest
import os

from pkg_resources import (
    cleanup_resources,
    resource_exists,
    resource_filename,
    resource_listdir,
    )


DOCTEST_FLAGS = (
    doctest.ELLIPSIS |
    doctest.NORMALIZE_WHITESPACE |
    doctest.REPORT_NDIFF)


def find_doctests(suffix):
    """Find doctests matching a certain suffix."""
    doctest_files = []
    # Match doctests against the suffix.
    if resource_exists('lazr.uri', 'docs'):
        for name in resource_listdir('lazr.uri', 'docs'):
            if name.endswith(suffix):
                doctest_files.append(
                    os.path.abspath(
                        resource_filename('lazr.uri', 'docs/%s' % name)))
    return doctest_files


def load_tests(loader, tests, pattern):
    """Load all the doctests."""
    atexit.register(cleanup_resources)
    tests.addTest(doctest.DocFileSuite(
        *find_doctests('.rst'),
        module_relative=False, optionflags=DOCTEST_FLAGS,
        globs={"print_function": print_function}))
    return tests
