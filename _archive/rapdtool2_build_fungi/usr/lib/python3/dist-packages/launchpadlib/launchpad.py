# Copyright 2008-2009 Canonical Ltd.

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

"""Root Launchpad API class."""

__metaclass__ = type
__all__ = [
    "Launchpad",
]

import errno
import os

try:
    from urllib.parse import urlsplit
except ImportError:
    from urlparse import urlsplit
import warnings

try:
    from httplib2 import proxy_info_from_environment
except ImportError:
    from httplib2 import ProxyInfo

    proxy_info_from_environment = ProxyInfo.from_environment

from lazr.restfulclient.resource import (  # noqa: F401
    CollectionWithKeyBasedLookup,
    HostedFile,  # Re-import for client convenience
    ScalarValue,  # Re-import for client convenience
    ServiceRoot,
)
from lazr.restfulclient.authorize.oauth import SystemWideConsumer
from lazr.restfulclient._browser import RestfulHttp
from launchpadlib.credentials import (
    AccessToken,
    AnonymousAccessToken,
    AuthorizeRequestTokenWithBrowser,
    AuthorizeRequestTokenWithURL,
    Consumer,
    Credentials,
    MemoryCredentialStore,
    KeyringCredentialStore,
    UnencryptedFileCredentialStore,
)
from launchpadlib import uris


# Import old constants for backwards compatibility
from launchpadlib.uris import (  # noqa: F401
    STAGING_SERVICE_ROOT,
    EDGE_SERVICE_ROOT,
)

OAUTH_REALM = "https://api.launchpad.net"


class PersonSet(CollectionWithKeyBasedLookup):
    """A custom subclass capable of person lookup by username."""

    def _get_url_from_id(self, key):
        """Transform a username into the URL to a person resource."""
        return str(self._root._root_uri.ensureSlash()) + "~" + str(key)

    # The only way to determine whether a string corresponds to a
    # person or a team object is to ask the server, so looking up an
    # entry from the PersonSet always requires making an HTTP request.
    collection_of = "team"


class BugSet(CollectionWithKeyBasedLookup):
    """A custom subclass capable of bug lookup by bug ID."""

    def _get_url_from_id(self, key):
        """Transform a bug ID into the URL to a bug resource."""
        return str(self._root._root_uri.ensureSlash()) + "bugs/" + str(key)

    collection_of = "bug"


class PillarSet(CollectionWithKeyBasedLookup):
    """A custom subclass capable of lookup by pillar name.

    Projects, project groups, and distributions are all pillars.
    """

    def _get_url_from_id(self, key):
        """Transform a project name into the URL to a project resource."""
        return str(self._root._root_uri.ensureSlash()) + str(key)

    # The subclasses for projects, project groups, and distributions
    # all define this property differently.
    collection_of = None


class ProjectSet(PillarSet):
    """A custom subclass for accessing the collection of projects."""

    collection_of = "project"


class ProjectGroupSet(PillarSet):
    """A custom subclass for accessing the collection of project groups."""

    collection_of = "project_group"


class DistributionSet(PillarSet):
    """A custom subclass for accessing the collection of project groups."""

    collection_of = "distribution"


class LaunchpadOAuthAwareHttp(RestfulHttp):
    """Detects expired/invalid OAuth tokens and tries to get a new token."""

    def __init__(self, launchpad, authorization_engine, *args):
        self.launchpad = launchpad
        self.authorization_engine = authorization_engine
        super(LaunchpadOAuthAwareHttp, self).__init__(*args)

    def _bad_oauth_token(self, response, content):
        """Helper method to detect an error caused by a bad OAuth token."""
        return response.status == 401 and (
            content.startswith(b"Expired token")
            or content.startswith(b"Invalid token")
            or content.startswith(b"Unknown access token")
        )

    def _request(self, *args):
        response, content = super(LaunchpadOAuthAwareHttp, self)._request(
            *args
        )
        return self.retry_on_bad_token(response, content, *args)

    def retry_on_bad_token(self, response, content, *args):
        """If the response indicates a bad token, get a new token and retry.

        Otherwise, just return the response.
        """
        if (
            self._bad_oauth_token(response, content)
            and self.authorization_engine is not None
        ):
            # This access token is bad. Scrap it and create a new one.
            self.launchpad.credentials.access_token = None
            self.authorization_engine(
                self.launchpad.credentials, self.launchpad.credential_store
            )
            # Retry the request with the new credentials.
            return self._request(*args)
        return response, content


class Launchpad(ServiceRoot):
    """Root Launchpad API class.

    :ivar credentials: The credentials instance used to access Launchpad.
    :type credentials: `Credentials`
    """

    DEFAULT_VERSION = "1.0"

    RESOURCE_TYPE_CLASSES = {
        "bugs": BugSet,
        "distributions": DistributionSet,
        "people": PersonSet,
        "project_groups": ProjectGroupSet,
        "projects": ProjectSet,
    }
    RESOURCE_TYPE_CLASSES.update(ServiceRoot.RESOURCE_TYPE_CLASSES)

    def __init__(
        self,
        credentials,
        authorization_engine,
        credential_store,
        service_root=uris.STAGING_SERVICE_ROOT,
        cache=None,
        timeout=None,
        proxy_info=proxy_info_from_environment,
        version=DEFAULT_VERSION,
    ):
        """Root access to the Launchpad API.

        :param credentials: The credentials used to access Launchpad.
        :type credentials: `Credentials`
        :param authorization_engine: The object used to get end-user input
            for authorizing OAuth request tokens. Used when an OAuth
            access token expires or becomes invalid during a
            session, or is discovered to be invalid once launchpadlib
            starts up.
        :type authorization_engine: `RequestTokenAuthorizationEngine`
        :param service_root: The URL to the root of the web service.
        :type service_root: string
        """
        service_root = uris.lookup_service_root(service_root)
        if service_root.endswith(version) or service_root.endswith(
            version + "/"
        ):
            error = (
                "It looks like you're using a service root that "
                "incorporates the name of the web service version "
                '("%s"). Please use one of the constants from '
                "launchpadlib.uris instead, or at least remove "
                "the version name from the root URI." % version
            )
            raise ValueError(error)

        self.credential_store = credential_store

        # We already have an access token, but it might expire or
        # become invalid during use. Store the authorization engine in
        # case we need to authorize a new token during use.
        self.authorization_engine = authorization_engine

        super(Launchpad, self).__init__(
            credentials, service_root, cache, timeout, proxy_info, version
        )

    def httpFactory(self, credentials, cache, timeout, proxy_info):
        return LaunchpadOAuthAwareHttp(
            self,
            self.authorization_engine,
            credentials,
            cache,
            timeout,
            proxy_info,
        )

    @classmethod
    def _is_sudo(cls):
        return {"SUDO_USER", "SUDO_UID", "SUDO_GID"} & set(os.environ.keys())

    @classmethod
    def authorization_engine_factory(cls, *args):
        if cls._is_sudo():
            # Do not try to open browser window under sudo;
            # we probably don't have access to the X session,
            # and some browsers (e.g. chromium) won't run as root
            # LP: #1825014
            return AuthorizeRequestTokenWithURL(*args)
        return AuthorizeRequestTokenWithBrowser(*args)

    @classmethod
    def credential_store_factory(cls, credential_save_failed):
        if cls._is_sudo():
            # Do not try to store credentials under sudo;
            # it can be problematic with shared sudo access,
            # and we may not have access to the normal keyring provider
            # LP: #1862948
            return MemoryCredentialStore(credential_save_failed)
        return KeyringCredentialStore(credential_save_failed, fallback=True)

    @classmethod
    def login(
        cls,
        consumer_name,
        token_string,
        access_secret,
        service_root=uris.STAGING_SERVICE_ROOT,
        cache=None,
        timeout=None,
        proxy_info=proxy_info_from_environment,
        authorization_engine=None,
        allow_access_levels=None,
        max_failed_attempts=None,
        credential_store=None,
        credential_save_failed=None,
        version=DEFAULT_VERSION,
    ):
        """Convenience method for setting up access credentials.

        When all three pieces of credential information (the consumer
        name, the access token and the access secret) are available, this
        method can be used to quickly log into the service root.

        This method is deprecated as of launchpadlib version
        1.9.0. You should use Launchpad.login_anonymously() for
        anonymous access, and Launchpad.login_with() for all other
        purposes.

        :param consumer_name: the application name.
        :type consumer_name: string
        :param token_string: the access token, as appropriate for the
            `AccessToken` constructor
        :type token_string: string
        :param access_secret: the access token's secret, as appropriate for
            the `AccessToken` constructor
        :type access_secret: string
        :param service_root: The URL to the root of the web service.
        :type service_root: string
        :param authorization_engine: See `Launchpad.__init__`. If you don't
            provide an authorization engine, a default engine will be
            constructed using your values for `service_root` and
            `credential_save_failed`.
        :param allow_access_levels: This argument is ignored, and only
            present to preserve backwards compatibility.
        :param max_failed_attempts: This argument is ignored, and only
            present to preserve backwards compatibility.
        :return: The web service root
        :rtype: `Launchpad`
        """
        cls._warn_of_deprecated_login_method("login")
        access_token = AccessToken(token_string, access_secret)
        credentials = Credentials(
            consumer_name=consumer_name, access_token=access_token
        )
        if authorization_engine is None:
            authorization_engine = cls.authorization_engine_factory(
                service_root, consumer_name, allow_access_levels
            )
        if credential_store is None:
            credential_store = cls.credential_store_factory(
                credential_save_failed
            )
        return cls(
            credentials,
            authorization_engine,
            credential_store,
            service_root,
            cache,
            timeout,
            proxy_info,
            version,
        )

    @classmethod
    def get_token_and_login(
        cls,
        consumer_name,
        service_root=uris.STAGING_SERVICE_ROOT,
        cache=None,
        timeout=None,
        proxy_info=proxy_info_from_environment,
        authorization_engine=None,
        allow_access_levels=[],
        max_failed_attempts=None,
        credential_store=None,
        credential_save_failed=None,
        version=DEFAULT_VERSION,
    ):
        """Get credentials from Launchpad and log into the service root.

        This method is deprecated as of launchpadlib version
        1.9.0. You should use Launchpad.login_anonymously() for
        anonymous access and Launchpad.login_with() for all other
        purposes.

        :param consumer_name: Either a consumer name, as appropriate for
            the `Consumer` constructor, or a premade Consumer object.
        :type consumer_name: string
        :param service_root: The URL to the root of the web service.
        :type service_root: string
        :param authorization_engine: See `Launchpad.__init__`. If you don't
            provide an authorization engine, a default engine will be
            constructed using your values for `service_root` and
            `credential_save_failed`.
        :param allow_access_levels: This argument is ignored, and only
            present to preserve backwards compatibility.
        :return: The web service root
        :rtype: `Launchpad`
        """
        cls._warn_of_deprecated_login_method("get_token_and_login")
        return cls._authorize_token_and_login(
            consumer_name,
            service_root,
            cache,
            timeout,
            proxy_info,
            authorization_engine,
            allow_access_levels,
            credential_store,
            credential_save_failed,
            version,
        )

    @classmethod
    def _authorize_token_and_login(
        cls,
        consumer_name,
        service_root,
        cache,
        timeout,
        proxy_info,
        authorization_engine,
        allow_access_levels,
        credential_store,
        credential_save_failed,
        version,
    ):
        """Authorize a request token. Log in with the resulting access token.

        This is the private, non-deprecated implementation of the
        deprecated method get_token_and_login(). Once
        get_token_and_login() is removed, this code can be streamlined
        and moved into its other call site, login_with().
        """
        if isinstance(consumer_name, Consumer):
            consumer = consumer_name
        else:
            # Create a system-wide consumer. lazr.restfulclient won't
            # do this automatically, but launchpadlib's default is to
            # do a desktop-wide integration.
            consumer = SystemWideConsumer(consumer_name)

        # Create the credentials with no Consumer, then set its .consumer
        # property directly.
        credentials = Credentials(None)
        credentials.consumer = consumer
        if authorization_engine is None:
            authorization_engine = cls.authorization_engine_factory(
                service_root, consumer_name, None, allow_access_levels
            )
        if credential_store is None:
            credential_store = cls.credential_store_factory(
                credential_save_failed
            )
        else:
            # A credential store was passed in, so we won't be using
            # any provided value for credential_save_failed. But at
            # least make sure we weren't given a conflicting value,
            # since that makes the calling code look confusing.
            cls._assert_login_argument_consistency(
                "credential_save_failed",
                credential_save_failed,
                credential_store.credential_save_failed,
                "credential_store",
            )

        # Try to get the credentials out of the credential store.
        cached_credentials = credential_store.load(
            authorization_engine.unique_consumer_id
        )
        if cached_credentials is None:
            # They're not there. Acquire new credentials using the
            # authorization engine.
            credentials = authorization_engine(credentials, credential_store)
        else:
            # We acquired credentials. But, the application name
            # wasn't stored along with the credentials, because in a
            # desktop integration scenario, a single set of
            # credentials may be shared by many applications. We need
            # to set the application name for this specific instance
            # of the credentials.
            credentials = cached_credentials
            credentials.consumer.application_name = (
                authorization_engine.application_name
            )

        return cls(
            credentials,
            authorization_engine,
            credential_store,
            service_root,
            cache,
            timeout,
            proxy_info,
            version,
        )

    @classmethod
    def login_anonymously(
        cls,
        consumer_name,
        service_root=uris.STAGING_SERVICE_ROOT,
        launchpadlib_dir=None,
        timeout=None,
        proxy_info=proxy_info_from_environment,
        version=DEFAULT_VERSION,
    ):
        """Get access to Launchpad without providing any credentials."""
        (
            service_root,
            launchpadlib_dir,
            cache_path,
            service_root_dir,
        ) = cls._get_paths(service_root, launchpadlib_dir)
        token = AnonymousAccessToken()
        credentials = Credentials(consumer_name, access_token=token)
        return cls(
            credentials,
            None,
            None,
            service_root=service_root,
            cache=cache_path,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
        )

    @classmethod
    def login_with(
        cls,
        application_name=None,
        service_root=uris.STAGING_SERVICE_ROOT,
        launchpadlib_dir=None,
        timeout=None,
        proxy_info=proxy_info_from_environment,
        authorization_engine=None,
        allow_access_levels=None,
        max_failed_attempts=None,
        credentials_file=None,
        version=DEFAULT_VERSION,
        consumer_name=None,
        credential_save_failed=None,
        credential_store=None,
    ):
        """Log in to Launchpad, possibly acquiring and storing credentials.

        Use this method to get a `Launchpad` object. If the end-user
        has no cached Launchpad credential, their browser will open
        and they'll be asked to log in and authorize a desktop
        integration. The authorized Launchpad credential will be
        stored securely: in the GNOME keyring, the KDE Wallet, or in
        an encrypted file on disk.

        The next time your program (or any other program run by that
        user on the same computer) invokes this method, the end-user
        will be prompted to unlock their keyring (or equivalent), and
        the credential will be retrieved from local storage and
        reused.

        You can customize this behavior in three ways:

        1. Pass in a filename to `credentials_file`. The end-user's
           credential will be written to that file, and on subsequent
           runs read from that file. Alternatively the filename can be
           given in the LP_CREDENTIALS_FILE environment variable.

        2. Subclass `CredentialStore` and pass in an instance of the
           subclass as `credential_store`. This lets you change how
           the end-user's credential is stored and retrieved locally.

        3. Subclass `RequestTokenAuthorizationEngine` and pass in an
           instance of the subclass as `authorization_engine`. This
           lets you change change what happens when the end-user needs
           to authorize the Launchpad credential.

        :param application_name: The application name. This is *not*
            the OAuth consumer name. Unless a consumer_name is also
            provided, the OAuth consumer will be a system-wide
            consumer representing the end-user's computer as a whole.
        :type application_name: string

        :param service_root: The URL to the root of the web service.
        :type service_root: string.  Can either be the full URL to a service
            or one of the short service names.

        :param launchpadlib_dir: The directory used to store cached
           data obtained from Launchpad. The cache is shared by all
           consumers, and each Launchpad service root has its own
           cache.
        :type launchpadlib_dir: string

        :param authorization_engine: A strategy for getting the
            end-user to authorize an OAuth request token, for
            exchanging the request token for an access token, and for
            storing the access token locally so that it can be
            reused. By default, launchpadlib will open the end-user's
            web browser to have them authorize the request token.
        :type authorization_engine: `RequestTokenAuthorizationEngine`

        :param allow_access_levels: The acceptable access levels for
            this application.

            This argument is used to construct the default
            `authorization_engine`, so if you pass in your own
            `authorization_engine` any value for this argument will be
            ignored. This argument will also be ignored unless you
            also specify `consumer_name`.

        :type allow_access_levels: list of strings

        :param max_failed_attempts: Ignored; only present for
            backwards compatibility.

        :param credentials_file: The path to a file in which to store
            this user's OAuth access token.

        :param version: The version of the Launchpad web service to use.

        :param consumer_name: The consumer name, as appropriate for
            the `Consumer` constructor. You probably don't want to
            provide this, since providing it will prevent you from
            taking advantage of desktop-wide integration.
        :type consumer_name: string

        :param credential_save_failed: a callback that is called upon
           a failure to save the credentials locally. This argument is
           used to construct the default `credential_store`, so if
           you pass in your own `credential_store` any value for
           this argument will be ignored.
        :type credential_save_failed: A callable

        :param credential_store: A strategy for storing an OAuth
            access token locally. By default, tokens are stored in the
            GNOME keyring (or equivalent). If `credentials_file` is
            provided, then tokens are stored unencrypted in that file.
        :type credential_store: `CredentialStore`

        :return: A web service root authorized as the end-user.
        :rtype: `Launchpad`

        """
        (
            service_root,
            launchpadlib_dir,
            cache_path,
            service_root_dir,
        ) = cls._get_paths(service_root, launchpadlib_dir)

        if (
            application_name is None
            and consumer_name is None
            and authorization_engine is None
        ):
            raise ValueError(
                "At least one of application_name, consumer_name, or "
                "authorization_engine must be provided."
            )

        if credentials_file is None:
            credentials_file = os.environ.get("LP_CREDENTIALS_FILE")

        if credentials_file is not None and credential_store is not None:
            raise ValueError(
                "At most one of credentials_file and credential_store "
                "must be provided."
            )

        if credential_store is None:
            if credentials_file is not None:
                # The end-user wants credentials stored in an
                # unencrypted file.
                credential_store = UnencryptedFileCredentialStore(
                    credentials_file, credential_save_failed
                )
            else:
                credential_store = cls.credential_store_factory(
                    credential_save_failed
                )
        else:
            # A credential store was passed in, so we won't be using
            # any provided value for credential_save_failed. But at
            # least make sure we weren't given a conflicting value,
            # since that makes the calling code look confusing.
            cls._assert_login_argument_consistency(
                "credential_save_failed",
                credential_save_failed,
                credential_store.credential_save_failed,
                "credential_store",
            )
            credential_store = credential_store

        if authorization_engine is None:
            authorization_engine = cls.authorization_engine_factory(
                service_root,
                application_name,
                consumer_name,
                allow_access_levels,
            )
        else:
            # An authorization engine was passed in, so we won't be
            # using any provided values for application_name,
            # consumer_name, or allow_access_levels. But at least make
            # sure we weren't given conflicting values, since that
            # makes the calling code look confusing.
            cls._assert_login_argument_consistency(
                "application_name",
                application_name,
                authorization_engine.application_name,
            )

            cls._assert_login_argument_consistency(
                "consumer_name",
                consumer_name,
                authorization_engine.consumer.key,
            )

            cls._assert_login_argument_consistency(
                "allow_access_levels",
                allow_access_levels,
                authorization_engine.allow_access_levels,
            )

        return cls._authorize_token_and_login(
            authorization_engine.consumer,
            service_root,
            cache_path,
            timeout,
            proxy_info,
            authorization_engine,
            allow_access_levels,
            credential_store,
            credential_save_failed,
            version,
        )

    @classmethod
    def _warn_of_deprecated_login_method(cls, name):
        warnings.warn(
            (
                "The Launchpad.%s() method is deprecated. You should use "
                "Launchpad.login_anonymous() for anonymous access and "
                "Launchpad.login_with() for all other purposes."
            )
            % name,
            DeprecationWarning,
        )

    @classmethod
    def _assert_login_argument_consistency(
        cls,
        argument_name,
        argument_value,
        object_value,
        object_name="authorization engine",
    ):
        """Helper to find conflicting values passed into the login methods.

        Many of the arguments to login_with are used to build other
        objects--the authorization engine or the credential store. If
        these objects are provided directly, many of the arguments
        become redundant. We'll allow redundant arguments through, but
        if a argument *conflicts* with the corresponding value in the
        provided object, we raise an error.
        """
        inconsistent_value_message = (
            "Inconsistent values given for %s: "
            "(%r passed in, versus %r in %s). "
            "You don't need to pass in %s if you pass in %s, "
            "so just omit that argument."
        )
        if argument_value is not None and argument_value != object_value:
            raise ValueError(
                inconsistent_value_message
                % (
                    argument_name,
                    argument_value,
                    object_value,
                    object_name,
                    argument_name,
                    object_name,
                )
            )

    @classmethod
    def _get_paths(cls, service_root, launchpadlib_dir=None):
        """Locate launchpadlib-related user paths and ensure they exist.

        This is a helper function used by login_with() and
        login_anonymously().

        :param service_root: The service root the user wants to
            connect to. This may be an alias (which will be
            dereferenced to a URL and returned) or a URL (which will
            be returned as is).
        :param launchpadlib_dir: The user's base launchpadlib
            directory, if known. This may be modified, expanded, or
            determined from the environment if missing. A definitive
            value will be returned.

        :return: A 4-tuple:
            (service_root_uri, launchpadlib_dir, cache_dir, service_root_dir)
        """
        if launchpadlib_dir is None:
            launchpadlib_dir = os.path.join("~", ".launchpadlib")
        launchpadlib_dir = os.path.expanduser(launchpadlib_dir)
        if launchpadlib_dir[:1] == "~":
            raise ValueError(
                "Must set $HOME or pass 'launchpadlib_dir' to "
                "indicate location to store cached data"
            )
        try:
            os.makedirs(launchpadlib_dir, 0o700)
        except OSError as err:
            if err.errno != errno.EEXIST:
                raise
        os.chmod(launchpadlib_dir, 0o700)
        # Determine the real service root.
        service_root = uris.lookup_service_root(service_root)
        # Each service root has its own cache and credential dirs.
        scheme, host_name, path, query, fragment = urlsplit(service_root)
        service_root_dir = os.path.join(launchpadlib_dir, host_name)
        cache_path = os.path.join(service_root_dir, "cache")
        try:
            os.makedirs(cache_path, 0o700)
        except OSError as err:
            if err.errno != errno.EEXIST:
                raise
        return (service_root, launchpadlib_dir, cache_path, service_root_dir)
