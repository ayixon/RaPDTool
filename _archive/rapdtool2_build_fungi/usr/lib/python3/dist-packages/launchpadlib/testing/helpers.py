# Copyright 2008 Canonical Ltd.

# This file is part of launchpadlib.
#
# launchpadlib is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# launchpadlib is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with launchpadlib.  If not, see
# <http://www.gnu.org/licenses/>.

"""launchpadlib testing helpers."""


__metaclass__ = type
__all__ = [
    "BadSaveKeyring",
    "fake_keyring",
    "FauxSocketModule",
    "InMemoryKeyring",
    "NoNetworkAuthorizationEngine",
    "NoNetworkLaunchpad",
    "TestableLaunchpad",
    "nopriv_read_nonprivate",
    "salgado_read_nonprivate",
    "salgado_with_full_permissions",
]

from contextlib import contextmanager

import launchpadlib
from launchpadlib.launchpad import Launchpad
from launchpadlib.credentials import (
    AccessToken,
    Credentials,
    RequestTokenAuthorizationEngine,
)


missing = object()


def assert_keyring_not_imported():
    assert (
        getattr(launchpadlib.credentials, "keyring", missing) is missing
    ), "During tests the real keyring module should never be imported."


class NoNetworkAuthorizationEngine(RequestTokenAuthorizationEngine):
    """An authorization engine that doesn't open a web browser.

    You can use this to test the creation of Launchpad objects and the
    storing of credentials. You can't use it to interact with the web
    service, since it only pretends to authorize its OAuth request tokens.
    """

    ACCESS_TOKEN_KEY = "access_key:84"

    def __init__(self, *args, **kwargs):
        super(NoNetworkAuthorizationEngine, self).__init__(*args, **kwargs)
        # Set up some instrumentation.
        self.request_tokens_obtained = 0
        self.access_tokens_obtained = 0

    def get_request_token(self, credentials):
        """Pretend to get a request token from the server.

        We do this by simply returning a static token ID.
        """
        self.request_tokens_obtained += 1
        return "request_token:42"

    def make_end_user_authorize_token(self, credentials, request_token):
        """Pretend to exchange a request token for an access token.

        We do this by simply setting the access_token property.
        """
        credentials.access_token = AccessToken(
            self.ACCESS_TOKEN_KEY, "access_secret:168"
        )
        self.access_tokens_obtained += 1


class NoNetworkLaunchpad(Launchpad):
    """A Launchpad instance for tests with no network access.

    It's only useful for making sure that certain methods were called.
    It can't be used to interact with the API.
    """

    def __init__(
        self,
        credentials,
        authorization_engine,
        credential_store,
        service_root,
        cache,
        timeout,
        proxy_info,
        version,
    ):
        self.credentials = credentials
        self.authorization_engine = authorization_engine
        self.credential_store = credential_store
        self.passed_in_args = dict(
            service_root=service_root,
            cache=cache,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
        )

    @classmethod
    def authorization_engine_factory(cls, *args):
        return NoNetworkAuthorizationEngine(*args)


class TestableLaunchpad(Launchpad):
    """A base class for talking to the testing root service."""

    def __init__(
        self,
        credentials,
        authorization_engine=None,
        credential_store=None,
        service_root="test_dev",
        cache=None,
        timeout=None,
        proxy_info=None,
        version=Launchpad.DEFAULT_VERSION,
    ):
        """Provide test-friendly defaults.

        :param authorization_engine: Defaults to None, since a test
            environment can't use an authorization engine.
        :param credential_store: Defaults to None, since tests
            generally pass in fully-formed Credentials objects.
        :param service_root: Defaults to 'test_dev'.
        """
        super(TestableLaunchpad, self).__init__(
            credentials,
            authorization_engine,
            credential_store,
            service_root=service_root,
            cache=cache,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
        )


@contextmanager
def fake_keyring(fake):
    """A context manager which injects a testing keyring implementation."""
    # The real keyring package should never be imported during tests.
    assert_keyring_not_imported()
    launchpadlib.credentials.keyring = fake
    launchpadlib.credentials.NoKeyringError = RuntimeError
    try:
        yield
    finally:
        del launchpadlib.credentials.keyring
        del launchpadlib.credentials.NoKeyringError


class FauxSocketModule:
    """A socket module replacement that provides a fake hostname."""

    def gethostname(self):
        return "HOSTNAME"


class BadSaveKeyring:
    """A keyring that generates errors when saving passwords."""

    def get_password(self, service, username):
        return None

    def set_password(self, service, username, password):
        raise RuntimeError


class InMemoryKeyring:
    """A keyring that saves passwords only in memory."""

    def __init__(self):
        self.data = {}

    def set_password(self, service, username, password):
        self.data[service, username] = password

    def get_password(self, service, username):
        return self.data.get((service, username))


class KnownTokens:
    """Known access token/secret combinations."""

    def __init__(self, token_string, access_secret):
        self.token_string = token_string
        self.access_secret = access_secret
        self.token = AccessToken(token_string, access_secret)
        self.credentials = Credentials(
            consumer_name="launchpad-library", access_token=self.token
        )

    def login(
        self,
        cache=None,
        timeout=None,
        proxy_info=None,
        version=Launchpad.DEFAULT_VERSION,
    ):
        """Create a Launchpad object using these credentials."""
        return TestableLaunchpad(
            self.credentials,
            cache=cache,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
        )


salgado_with_full_permissions = KnownTokens("salgado-change-anything", "test")
salgado_read_nonprivate = KnownTokens("salgado-read-nonprivate", "secret")
nopriv_read_nonprivate = KnownTokens("nopriv-read-nonprivate", "mystery")
