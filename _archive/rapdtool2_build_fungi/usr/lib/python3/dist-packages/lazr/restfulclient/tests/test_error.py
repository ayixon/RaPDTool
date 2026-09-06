# Copyright 2009 Canonical Ltd.

# This file is part of lazr.restfulclient.
#
# lazr.restfulclient is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, version 3 of the
# License.
#
# lazr.restfulclient is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with lazr.restfulclient. If not, see <http://www.gnu.org/licenses/>.

"""Tests for the error_for helper function."""

__metaclass__ = type

import unittest

from lazr.restfulclient.errors import (
    ClientError, Conflict, MethodNotAllowed, NotFound,
    PreconditionFailed, ResponseError, ServerError, Unauthorized, error_for)


class DummyRequest(object):
    """Just enough of a request to fool error_for()."""
    def __init__(self, status):
        self.status = status


class TestErrorFor(unittest.TestCase):

    def error_for_status(self, status, expected_error, content=''):
        """Make sure error_for returns the right HTTPError subclass."""
        request = DummyRequest(status)
        error = error_for(request, content)
        if expected_error is None:
            self.assertIsNone(error)
        else:
            self.assertTrue(isinstance(error, expected_error))
            self.assertEqual(content, error.content)

    def test_no_error_for_2xx(self):
        """Make sure a 2xx response code yields no error."""
        for status in (200, 201, 209, 299):
            self.error_for_status(status, None)

    def test_no_error_for_3xx(self):
        """Make sure a 3xx response code yields no error."""
        for status in (301, 302, 303, 304, 399):
            self.error_for_status(status, None)

    def test_error_for_400(self):
        """Make sure a 400 response code yields ResponseError."""
        self.error_for_status(400, ResponseError, "error message")

    def test_error_for_401(self):
        """Make sure a 401 response code yields Unauthorized."""
        self.error_for_status(401, Unauthorized, "error message")

    def test_error_for_404(self):
        """Make sure a 404 response code yields Not Found."""
        self.error_for_status(404, NotFound, "error message")

    def test_error_for_405(self):
        """Make sure a 405 response code yields MethodNotAllowed."""
        self.error_for_status(405, MethodNotAllowed, "error message")

    def test_error_for_409(self):
        """Make sure a 409 response code yields Conflict."""
        self.error_for_status(409, Conflict, "error message")

    def test_error_for_412(self):
        """Make sure a 412 response code yields PreconditionFailed."""
        self.error_for_status(412, PreconditionFailed, "error message")

    def test_error_for_4xx(self):
        """Make sure an unrexognized 4xx response code yields ClientError."""
        self.error_for_status(499, ClientError, "error message")

    def test_no_error_for_5xx(self):
        """Make sure a 5xx response codes yields ServerError."""
        for status in (500, 502, 503, 599):
            self.error_for_status(status, ServerError)
