# Copyright 2009-2018 Canonical Ltd.

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

"""Tests for the OAuth-aware classes."""

__metaclass__ = type


import os
import os.path
import stat
import unittest

from fixtures import (
    MockPatch,
    TempDir,
    )
from testtools import TestCase

from lazr.restfulclient.authorize.oauth import (
    AccessToken,
    Consumer,
    OAuthAuthorizer,
    SystemWideConsumer,
    )


class TestConsumer(TestCase):

    def test_data_fields(self):
        consumer = Consumer("key", "secret", "application")
        self.assertEqual(consumer.key, "key")
        self.assertEqual(consumer.secret, "secret")
        self.assertEqual(consumer.application_name, "application")

    def test_default_application_name(self):
        # Application name defaults to None
        consumer = Consumer("key", "secret")
        self.assertEqual(consumer.application_name, None)


class TestAccessToken(TestCase):

    def test_data_fields(self):
        access_token = AccessToken("key", "secret", "context")
        self.assertEqual(access_token.key, "key")
        self.assertEqual(access_token.secret, "secret")
        self.assertEqual(access_token.context, "context")

    def test_default_context(self):
        # Context defaults to None.
        access_token = AccessToken("key", "secret")
        self.assertIsNone(access_token.context)

    def test___str__(self):
        access_token = AccessToken("lock&key", "secret=password")
        self.assertEqual(
            "oauth_token_secret=secret%3Dpassword&oauth_token=lock%26key",
            str(access_token))

    def test_from_string(self):
        access_token = AccessToken.from_string(
            "oauth_token_secret=secret%3Dpassword&oauth_token=lock%26key")
        self.assertEqual(access_token.key, "lock&key")
        self.assertEqual(access_token.secret, "secret=password")


class TestSystemWideConsumer(TestCase):

    def test_useful_distro_name(self):
        # If distro.name returns a useful string, as it does on Ubuntu,
        # we'll use the first string for the system type.
        self.useFixture(MockPatch('distro.name', return_value='Fooix'))
        self.useFixture(MockPatch('platform.system', return_value='FooOS'))
        self.useFixture(MockPatch('socket.gethostname', return_value='foo'))
        consumer = SystemWideConsumer("app name")
        self.assertEqual(
            consumer.key, 'System-wide: Fooix (foo)')

    def test_empty_distro_name(self):
        # If distro.name returns an empty string, as it does on Windows and
        # Mac OS X, we fall back to the result of platform.system().
        self.useFixture(MockPatch('distro.name', return_value=''))
        self.useFixture(MockPatch('platform.system', return_value='BarOS'))
        self.useFixture(MockPatch('socket.gethostname', return_value='bar'))
        consumer = SystemWideConsumer("app name")
        self.assertEqual(
            consumer.key, 'System-wide: BarOS (bar)')

    def test_broken_distro_name(self):
        # If distro.name raises an exception, we fall back to the result of
        # platform.system().
        self.useFixture(
            MockPatch('distro.name', side_effect=Exception('Oh noes!')))
        self.useFixture(MockPatch('platform.system', return_value='BazOS'))
        self.useFixture(MockPatch('socket.gethostname', return_value='baz'))
        consumer = SystemWideConsumer("app name")
        self.assertEqual(
            consumer.key, 'System-wide: BazOS (baz)')


class TestOAuthAuthorizer(TestCase):
    """Test for the OAuth Authorizer."""

    def test_save_to_and_load_from__path(self):
        # Credentials can be saved to and loaded from a file using
        # save_to_path() and load_from_path().
        temp_dir = self.useFixture(TempDir()).path
        credentials_path = os.path.join(temp_dir, 'credentials')
        credentials = OAuthAuthorizer(
            'consumer.key', consumer_secret='consumer.secret',
            access_token=AccessToken('access.key', 'access.secret'))
        credentials.save_to_path(credentials_path)
        self.assertTrue(os.path.exists(credentials_path))

        # Make sure the file is readable and writable by the user, but
        # not by anyone else.
        self.assertEqual(stat.S_IMODE(os.stat(credentials_path).st_mode),
                          stat.S_IREAD | stat.S_IWRITE)

        loaded_credentials = OAuthAuthorizer.load_from_path(credentials_path)
        self.assertEqual(loaded_credentials.consumer.key, 'consumer.key')
        self.assertEqual(
            loaded_credentials.consumer.secret, 'consumer.secret')
        self.assertEqual(
            loaded_credentials.access_token.key, 'access.key')
        self.assertEqual(
            loaded_credentials.access_token.secret, 'access.secret')


def test_suite():
    return unittest.TestLoader().loadTestsFromName(__name__)
