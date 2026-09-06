# Copyright 2010-2011 Canonical Ltd.

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

"""Tests for the credential store classes."""

import os
import tempfile
import unittest

from base64 import b64decode

if bytes is str:
    # Python 2
    unicode_type = unicode  # noqa: F821
else:
    unicode_type = str

from launchpadlib.testing.helpers import (
    fake_keyring,
    InMemoryKeyring,
)

from launchpadlib.credentials import (
    AccessToken,
    Credentials,
    KeyringCredentialStore,
    UnencryptedFileCredentialStore,
)


class TestAccessToken(unittest.TestCase):
    """Tests for the AccessToken class."""

    def test_from_string(self):
        access_token = AccessToken.from_string(
            "oauth_token_secret=secret%3Dpassword&oauth_token=lock%26key"
        )
        self.assertEqual("lock&key", access_token.key)
        self.assertEqual("secret=password", access_token.secret)
        self.assertIsNone(access_token.context)

    def test_from_string_with_context(self):
        access_token = AccessToken.from_string(
            "oauth_token_secret=secret%3Dpassword&oauth_token=lock%26key&"
            "lp.context=firefox"
        )
        self.assertEqual("lock&key", access_token.key)
        self.assertEqual("secret=password", access_token.secret)
        self.assertEqual("firefox", access_token.context)


class CredentialStoreTestCase(unittest.TestCase):
    def make_credential(self, consumer_key):
        """Helper method to make a fake credential."""
        return Credentials(
            "app name",
            consumer_secret="consumer_secret:42",
            access_token=AccessToken(consumer_key, "access_secret:168"),
        )


class TestUnencryptedFileCredentialStore(CredentialStoreTestCase):
    """Tests for the UnencryptedFileCredentialStore class."""

    def setUp(self):
        ignore, self.filename = tempfile.mkstemp()
        self.store = UnencryptedFileCredentialStore(self.filename)

    def tearDown(self):
        if os.path.exists(self.filename):
            os.remove(self.filename)

    def test_save_and_load(self):
        # Make sure you can save and load credentials to a file.
        credential = self.make_credential("consumer key")
        self.store.save(credential, "unique key")
        credential2 = self.store.load("unique key")
        self.assertEqual(credential.consumer.key, credential2.consumer.key)

    def test_unique_id_doesnt_matter(self):
        # If a file contains a credential, that credential will be
        # accessed no matter what unique ID you specify.
        credential = self.make_credential("consumer key")
        self.store.save(credential, "some key")
        credential2 = self.store.load("some other key")
        self.assertEqual(credential.consumer.key, credential2.consumer.key)

    def test_file_only_contains_one_credential(self):
        # A credential file may contain only one credential. If you
        # write two credentials with different unique IDs to the same
        # file, the first credential will be overwritten with the
        # second.
        credential1 = self.make_credential("consumer key")
        credential2 = self.make_credential("consumer key2")
        self.store.save(credential1, "unique key 1")
        self.store.save(credential1, "unique key 2")
        loaded = self.store.load("unique key 1")
        self.assertEqual(loaded.consumer.key, credential2.consumer.key)


class TestKeyringCredentialStore(CredentialStoreTestCase):
    """Tests for the KeyringCredentialStore class."""

    def setUp(self):
        self.keyring = InMemoryKeyring()
        self.store = KeyringCredentialStore()

    def test_save_and_load(self):
        # Make sure you can save and load credentials to a keyring.
        with fake_keyring(self.keyring):
            credential = self.make_credential("consumer key")
            self.store.save(credential, "unique key")
            credential2 = self.store.load("unique key")
            self.assertEqual(credential.consumer.key, credential2.consumer.key)

    def test_lookup_by_unique_key(self):
        # Credentials in the keyring are looked up by the unique ID
        # under which they were stored.
        with fake_keyring(self.keyring):
            credential1 = self.make_credential("consumer key1")
            self.store.save(credential1, "key 1")

            credential2 = self.make_credential("consumer key2")
            self.store.save(credential2, "key 2")

            loaded1 = self.store.load("key 1")
            self.assertTrue(loaded1)
            self.assertEqual(credential1.consumer.key, loaded1.consumer.key)

            loaded2 = self.store.load("key 2")
            self.assertEqual(credential2.consumer.key, loaded2.consumer.key)

    def test_reused_unique_id_overwrites_old_credential(self):
        # Writing a credential to the keyring with a given unique ID
        # will overwrite any credential stored under that ID.

        with fake_keyring(self.keyring):
            credential1 = self.make_credential("consumer key1")
            self.store.save(credential1, "the only key")

            credential2 = self.make_credential("consumer key2")
            self.store.save(credential2, "the only key")

            loaded = self.store.load("the only key")
            self.assertEqual(credential2.consumer.key, loaded.consumer.key)

    def test_bad_unique_id_returns_none(self):
        # Trying to load a credential without providing a good unique
        # ID will get you None.
        with fake_keyring(self.keyring):
            self.assertIsNone(self.store.load("no such key"))

    def test_keyring_returns_unicode(self):
        # Kwallet is reported to sometimes return Unicode, which broke the
        # credentials parsing.  This test ensures a Unicode password is
        # handled correctly.  (See bug lp:877374)
        class UnicodeInMemoryKeyring(InMemoryKeyring):
            def get_password(self, service, username):
                password = super(UnicodeInMemoryKeyring, self).get_password(
                    service, username
                )
                if isinstance(password, unicode_type):
                    password = password.encode("utf-8")
                return password

        self.keyring = UnicodeInMemoryKeyring()
        with fake_keyring(self.keyring):
            credential = self.make_credential("consumer key")
            self.assertTrue(credential)
            # Shouldn't this test actually use a unicodish key?!
            self.store.save(credential, "unique key")
            credential2 = self.store.load("unique key")
            self.assertTrue(credential2)
            self.assertEqual(credential.consumer.key, credential2.consumer.key)
            self.assertEqual(
                credential.consumer.secret, credential2.consumer.secret
            )

    def test_nonencoded_key_handled(self):
        # For backwards compatibility with keys that are not base 64 encoded.

        class UnencodedInMemoryKeyring(InMemoryKeyring):
            def get_password(self, service, username):
                pw = super(UnencodedInMemoryKeyring, self).get_password(
                    service, username
                )
                return b64decode(pw[5:])

        self.keyring = UnencodedInMemoryKeyring()
        with fake_keyring(self.keyring):
            credential = self.make_credential("consumer key")
            self.store.save(credential, "unique key")
            credential2 = self.store.load("unique key")
            self.assertEqual(credential.consumer.key, credential2.consumer.key)
            self.assertEqual(
                credential.consumer.secret, credential2.consumer.secret
            )

    def test_corrupted_key_handled(self):
        # A corrupted password results in None being returned.

        class CorruptedInMemoryKeyring(InMemoryKeyring):
            def get_password(self, service, username):
                return "bad"

        self.keyring = CorruptedInMemoryKeyring()
        with fake_keyring(self.keyring):
            credential = self.make_credential("consumer key")
            self.store.save(credential, "unique key")
            credential2 = self.store.load("unique key")
            self.assertIsNone(credential2)
