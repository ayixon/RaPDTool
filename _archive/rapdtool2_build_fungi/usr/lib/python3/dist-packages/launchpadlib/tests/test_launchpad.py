# Copyright 2009, 2011 Canonical Ltd.

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

"""Tests for the Launchpad class."""

__metaclass__ = type

from contextlib import contextmanager
import os
import shutil
import socket
import stat
import tempfile
import unittest

try:
    from unittest.mock import patch
except ImportError:
    from mock import patch
import warnings

from lazr.restfulclient.resource import ServiceRoot

from launchpadlib.credentials import (
    AccessToken,
    Credentials,
)

from launchpadlib import uris
import launchpadlib.launchpad
from launchpadlib.launchpad import Launchpad
from launchpadlib.credentials import UnencryptedFileCredentialStore
from launchpadlib.testing.helpers import (
    assert_keyring_not_imported,
    BadSaveKeyring,
    fake_keyring,
    FauxSocketModule,
    InMemoryKeyring,
    NoNetworkAuthorizationEngine,
    NoNetworkLaunchpad,
)
from launchpadlib.credentials import (
    KeyringCredentialStore,
)

# A stub service root for use in tests
SERVICE_ROOT = "http://api.example.com/"


class TestResourceTypeClasses(unittest.TestCase):
    """launchpadlib must know about restfulclient's resource types."""

    def test_resource_types(self):
        # Make sure that Launchpad knows about every special resource
        # class defined by lazr.restfulclient.
        for name, cls in ServiceRoot.RESOURCE_TYPE_CLASSES.items():
            self.assertEqual(Launchpad.RESOURCE_TYPE_CLASSES[name], cls)


class TestNameLookups(unittest.TestCase):
    """Test the utility functions in the 'uris' module."""

    def setUp(self):
        self.aliases = sorted(
            [
                "production",
                "qastaging",
                "staging",
                "dogfood",
                "dev",
                "test_dev",
                "edge",
            ]
        )

    @contextmanager
    def edge_deprecation_error(self):
        # Run some code and assert that a deprecation error was issued
        # due to attempted access to the edge server.
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            yield

            self.assertEqual(len(caught), 1)
            (warning,) = caught
            self.assertTrue(issubclass(warning.category, DeprecationWarning))
            self.assertIn("no longer exists", str(warning))

    def test_short_names(self):
        # Ensure the short service names are all supported.
        self.assertEqual(sorted(uris.service_roots.keys()), self.aliases)
        self.assertEqual(sorted(uris.web_roots.keys()), self.aliases)

    def test_edge_service_root_is_production(self):
        # The edge server no longer exists, so if the client wants
        # edge we give them production.
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_service_root("edge"),
                uris.lookup_service_root("production"),
            )

    def test_edge_web_root_is_production(self):
        # The edge server no longer exists, so if the client wants
        # edge we give them production.
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_web_root("edge"),
                uris.lookup_web_root("production"),
            )

    def test_edge_service_root_url_becomes_production(self):
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_service_root(uris.EDGE_SERVICE_ROOT),
                uris.lookup_service_root("production"),
            )

    def test_edge_web_root_url_becomes_production(self):
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_web_root(uris.EDGE_WEB_ROOT),
                uris.lookup_web_root("production"),
            )

    def test_top_level_edge_constant_becomes_production(self):
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_service_root(uris.EDGE_SERVICE_ROOT),
                uris.lookup_service_root("production"),
            )

    def test_edge_server_equivalent_string_becomes_production(self):
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_service_root("https://api.edge.launchpad.net/"),
                uris.lookup_service_root("production"),
            )

    def test_edge_web_server_equivalent_string_becomes_production(self):
        with self.edge_deprecation_error():
            self.assertEqual(
                uris.lookup_web_root("https://edge.launchpad.net/"),
                uris.lookup_web_root("production"),
            )

    def test_lookups(self):
        """Ensure that short service names turn into long service names."""

        # If the service name is a known alias, lookup methods convert
        # it to a URL.
        with self.edge_deprecation_error():
            for alias in self.aliases:
                self.assertEqual(
                    uris.lookup_service_root(alias), uris.service_roots[alias]
                )

        with self.edge_deprecation_error():
            for alias in self.aliases:
                self.assertEqual(
                    uris.lookup_web_root(alias), uris.web_roots[alias]
                )

        # If the service name is a valid URL, lookup methods let it
        # through.
        other_root = "http://some-other-server.com"
        self.assertEqual(uris.lookup_service_root(other_root), other_root)
        self.assertEqual(uris.lookup_web_root(other_root), other_root)

        # Otherwise, lookup methods raise an exception.
        not_a_url = "not-a-url"
        self.assertRaises(ValueError, uris.lookup_service_root, not_a_url)
        self.assertRaises(ValueError, uris.lookup_web_root, not_a_url)


class TestServiceNameWithEmbeddedVersion(unittest.TestCase):
    """Reject service roots that include the version at the end of the URL.

    If the service root is "http://api.launchpad.net/beta/" and the
    version is "beta", the launchpadlib constructor will raise an
    exception.

    This happens with scripts that were written against old versions
    of launchpadlib. The alternative is to try to silently fix it (the
    fix will eventually break as new versions of the web service are
    released) or to go ahead and make a request to
    http://api.launchpad.net/beta/beta/, and cause an unhelpful 404
    error.
    """

    def test_service_name_with_embedded_version(self):
        # Basic test. If there were no exception raised here,
        # launchpadlib would make a request to
        # /version-foo/version-foo.
        version = "version-foo"
        root = uris.service_roots["staging"] + version
        try:
            Launchpad(None, None, None, service_root=root, version=version)
        except ValueError as e:
            self.assertTrue(
                str(e).startswith(
                    "It looks like you're using a service root that "
                    "incorporates the name of the web service version "
                    '("version-foo")'
                )
            )
        else:
            raise AssertionError("Expected a ValueError that was not thrown!")

        # Make sure the problematic URL is caught even if it has a
        # slash on the end.
        root += "/"
        self.assertRaises(
            ValueError,
            Launchpad,
            None,
            None,
            None,
            service_root=root,
            version=version,
        )

        # Test that the default version has the same problem
        # when no explicit version is specified
        default_version = NoNetworkLaunchpad.DEFAULT_VERSION
        root = uris.service_roots["staging"] + default_version + "/"
        self.assertRaises(
            ValueError, Launchpad, None, None, None, service_root=root
        )


class TestRequestTokenAuthorizationEngine(unittest.TestCase):
    """Tests for the RequestTokenAuthorizationEngine class."""

    def test_app_must_be_identified(self):
        self.assertRaises(
            ValueError, NoNetworkAuthorizationEngine, SERVICE_ROOT
        )

    def test_application_name_identifies_app(self):
        NoNetworkAuthorizationEngine(SERVICE_ROOT, application_name="name")

    def test_consumer_name_identifies_app(self):
        NoNetworkAuthorizationEngine(SERVICE_ROOT, consumer_name="name")

    def test_conflicting_app_identification(self):
        # You can't specify both application_name and consumer_name.
        self.assertRaises(
            ValueError,
            NoNetworkAuthorizationEngine,
            SERVICE_ROOT,
            application_name="name1",
            consumer_name="name2",
        )

        # This holds true even if you specify the same value for
        # both. They're not the same thing.
        self.assertRaises(
            ValueError,
            NoNetworkAuthorizationEngine,
            SERVICE_ROOT,
            application_name="name",
            consumer_name="name",
        )


class TestLaunchpadLoginWithCredentialsFile(unittest.TestCase):
    """Tests for Launchpad.login_with() with a credentials file."""

    def test_filename(self):
        ignore, filename = tempfile.mkstemp()
        launchpad = NoNetworkLaunchpad.login_with(
            application_name="not important", credentials_file=filename
        )

        # The credentials are stored unencrypted in the file you
        # specify.
        credentials = Credentials.load_from_path(filename)
        self.assertEqual(
            credentials.consumer.key, launchpad.credentials.consumer.key
        )
        os.remove(filename)

    def test_cannot_specify_both_filename_and_store(self):
        ignore, filename = tempfile.mkstemp()
        store = KeyringCredentialStore()
        self.assertRaises(
            ValueError,
            NoNetworkLaunchpad.login_with,
            application_name="not important",
            credentials_file=filename,
            credential_store=store,
        )
        os.remove(filename)


class TestLaunchpadLoginWithCredentialsFileFromEnvVariable(unittest.TestCase):
    # Tests for Launchpad.login_with() with a credentials file from
    # LP_CREDENTIALS_FILE environment variable.

    def test_filename(self):
        ignore, filename = tempfile.mkstemp()
        os.environ["LP_CREDENTIALS_FILE"] = filename

        launchpad = NoNetworkLaunchpad.login_with(
            application_name="not important"
        )

        self.assertIsInstance(
            launchpad.credential_store, UnencryptedFileCredentialStore
        )

        self.assertEqual(launchpad.credential_store.filename, filename)

        os.unsetenv("LP_CREDENTIALS_FILE")  # does not update os.environ array
        del os.environ["LP_CREDENTIALS_FILE"]
        self.assertIsNone(os.environ.get("LP_CREDENTIALS_FILE"))

        os.remove(filename)


class KeyringTest(unittest.TestCase):
    """Base class for tests that use the keyring."""

    def setUp(self):
        # The real keyring package should never be imported during tests.
        assert_keyring_not_imported()
        # For these tests we want to use a sample keyring implementation
        # that only stores data in memory.
        launchpadlib.credentials.keyring = InMemoryKeyring()

    def tearDown(self):
        # Remove the fake keyring module we injected during setUp.
        del launchpadlib.credentials.keyring


class TestLaunchpadLoginWith(KeyringTest):
    """Tests for Launchpad.login_with()."""

    def setUp(self):
        super(TestLaunchpadLoginWith, self).setUp()
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        super(TestLaunchpadLoginWith, self).tearDown()
        shutil.rmtree(self.temp_dir)

    def test_dirs_created(self):
        # The path we pass into login_with() is the directory where
        # cache for all service roots are stored.
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        NoNetworkLaunchpad.login_with(
            "not important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
        )
        # The 'launchpadlib' dir got created.
        self.assertTrue(os.path.isdir(launchpadlib_dir))
        # A directory for the passed in service root was created.
        service_path = os.path.join(launchpadlib_dir, "api.example.com")
        self.assertTrue(os.path.isdir(service_path))
        # Inside the service root directory, there is a 'cache'
        # directory.
        self.assertTrue(os.path.isdir(os.path.join(service_path, "cache")))

        # In older versions there was also a 'credentials' directory,
        # but no longer.
        credentials_path = os.path.join(service_path, "credentials")
        self.assertFalse(os.path.isdir(credentials_path))

    def test_dirs_created_are_changed_to_secure(self):
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        # Verify a newly created-by-hand directory is insecure
        os.mkdir(launchpadlib_dir)
        os.chmod(launchpadlib_dir, 0o755)
        self.assertTrue(os.path.isdir(launchpadlib_dir))
        statinfo = os.stat(launchpadlib_dir)
        mode = stat.S_IMODE(statinfo.st_mode)
        self.assertNotEqual(mode, stat.S_IWRITE | stat.S_IREAD | stat.S_IEXEC)
        NoNetworkLaunchpad.login_with(
            "not important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
        )
        # Verify the mode has been changed to 0700
        statinfo = os.stat(launchpadlib_dir)
        mode = stat.S_IMODE(statinfo.st_mode)
        self.assertEqual(mode, stat.S_IWRITE | stat.S_IREAD | stat.S_IEXEC)

    def test_dirs_created_are_secure(self):
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        NoNetworkLaunchpad.login_with(
            "not important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
        )
        self.assertTrue(os.path.isdir(launchpadlib_dir))
        # Verify the mode is safe
        statinfo = os.stat(launchpadlib_dir)
        mode = stat.S_IMODE(statinfo.st_mode)
        self.assertEqual(mode, stat.S_IWRITE | stat.S_IREAD | stat.S_IEXEC)

    def test_version_is_propagated(self):
        # Make sure the login_with() method conveys the 'version'
        # argument all the way to the Launchpad object. The
        # credentials will be cached to disk.
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        launchpad = NoNetworkLaunchpad.login_with(
            "not important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
            version="foo",
        )
        self.assertEqual(launchpad.passed_in_args["version"], "foo")

        # Now execute the same test a second time. This time, the
        # credentials are loaded from disk and a different code path
        # is executed. We want to make sure this code path propagates
        # the 'version' argument.
        launchpad = NoNetworkLaunchpad.login_with(
            "not important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
            version="bar",
        )
        self.assertEqual(launchpad.passed_in_args["version"], "bar")

    def test_application_name_is_propagated(self):
        # Create a Launchpad instance for a given application name.
        # Credentials are stored, but they don't include the
        # application name, since multiple applications may share a
        # single system-wide credential.
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        launchpad = NoNetworkLaunchpad.login_with(
            "very important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
        )
        self.assertEqual(
            launchpad.credentials.consumer.application_name, "very important"
        )

        # Now execute the same test a second time. This time, the
        # credentials are loaded from disk and a different code path
        # is executed. We want to make sure this code path propagates
        # the application name, instead of picking an empty one from
        # disk.
        launchpad = NoNetworkLaunchpad.login_with(
            "very important",
            service_root=SERVICE_ROOT,
            launchpadlib_dir=launchpadlib_dir,
        )
        self.assertEqual(
            launchpad.credentials.consumer.application_name, "very important"
        )

    def test_authorization_engine_is_propagated(self):
        # You can pass in a custom authorization engine, which will be
        # used to get a request token and exchange it for an access
        # token.
        engine = NoNetworkAuthorizationEngine(SERVICE_ROOT, "application name")
        NoNetworkLaunchpad.login_with(authorization_engine=engine)
        self.assertEqual(engine.request_tokens_obtained, 1)
        self.assertEqual(engine.access_tokens_obtained, 1)

    def test_login_with_must_identify_application(self):
        # If you call login_with without identifying your application
        # you'll get an error.
        self.assertRaises(ValueError, NoNetworkLaunchpad.login_with)

    def test_application_name_identifies_app(self):
        # If you pass in application_name, that's good enough to identify
        # your application.
        NoNetworkLaunchpad.login_with(application_name="name")

    def test_consumer_name_identifies_app(self):
        # If you pass in consumer_name, that's good enough to identify
        # your application.
        NoNetworkLaunchpad.login_with(consumer_name="name")

    def test_inconsistent_application_name_rejected(self):
        """Catch an attempt to specify inconsistent application_names."""
        engine = NoNetworkAuthorizationEngine(
            SERVICE_ROOT, "application name1"
        )
        self.assertRaises(
            ValueError,
            NoNetworkLaunchpad.login_with,
            "application name2",
            authorization_engine=engine,
        )

    def test_inconsistent_consumer_name_rejected(self):
        """Catch an attempt to specify inconsistent application_names."""
        engine = NoNetworkAuthorizationEngine(
            SERVICE_ROOT, None, consumer_name="consumer_name1"
        )

        self.assertRaises(
            ValueError,
            NoNetworkLaunchpad.login_with,
            "consumer_name2",
            authorization_engine=engine,
        )

    def test_inconsistent_allow_access_levels_rejected(self):
        """Catch an attempt to specify inconsistent allow_access_levels."""
        engine = NoNetworkAuthorizationEngine(
            SERVICE_ROOT, consumer_name="consumer", allow_access_levels=["FOO"]
        )

        self.assertRaises(
            ValueError,
            NoNetworkLaunchpad.login_with,
            None,
            consumer_name="consumer",
            allow_access_levels=["BAR"],
            authorization_engine=engine,
        )

    def test_inconsistent_credential_save_failed(self):
        # Catch an attempt to specify inconsistent callbacks for
        # credential save failure.
        def callback1():
            pass

        store = KeyringCredentialStore(credential_save_failed=callback1)

        def callback2():
            pass

        self.assertRaises(
            ValueError,
            NoNetworkLaunchpad.login_with,
            "app name",
            credential_store=store,
            credential_save_failed=callback2,
        )

    def test_non_desktop_integration(self):
        # When doing a non-desktop integration, you must specify a
        # consumer_name. You can pass a list of allowable access
        # levels into login_with().
        launchpad = NoNetworkLaunchpad.login_with(
            consumer_name="consumer", allow_access_levels=["FOO"]
        )
        self.assertEqual(launchpad.credentials.consumer.key, "consumer")
        self.assertEqual(launchpad.credentials.consumer.application_name, None)
        self.assertEqual(
            launchpad.authorization_engine.allow_access_levels, ["FOO"]
        )

    def test_desktop_integration_doesnt_happen_without_consumer_name(self):
        # The only way to do a non-desktop integration is to specify a
        # consumer_name. If you specify application_name instead, your
        # value for allow_access_levels is ignored, and a desktop
        # integration is performed.
        launchpad = NoNetworkLaunchpad.login_with(
            "application name", allow_access_levels=["FOO"]
        )
        self.assertEqual(
            launchpad.authorization_engine.allow_access_levels,
            ["DESKTOP_INTEGRATION"],
        )

    def test_no_credentials_creates_new_credential(self):
        # If no credentials are found, a desktop-wide credential is created.
        timeout = object()
        proxy_info = object()
        launchpad = NoNetworkLaunchpad.login_with(
            "app name",
            launchpadlib_dir=self.temp_dir,
            service_root=SERVICE_ROOT,
            timeout=timeout,
            proxy_info=proxy_info,
        )
        # Here's the new credential.
        self.assertEqual(
            launchpad.credentials.access_token.key,
            NoNetworkAuthorizationEngine.ACCESS_TOKEN_KEY,
        )
        self.assertEqual(
            launchpad.credentials.consumer.application_name, "app name"
        )
        self.assertEqual(
            launchpad.authorization_engine.allow_access_levels,
            ["DESKTOP_INTEGRATION"],
        )
        # The expected arguments were passed in to the Launchpad
        # constructor.
        expected_arguments = dict(
            service_root=SERVICE_ROOT,
            cache=os.path.join(self.temp_dir, "api.example.com", "cache"),
            timeout=timeout,
            proxy_info=proxy_info,
            version=NoNetworkLaunchpad.DEFAULT_VERSION,
        )
        self.assertEqual(launchpad.passed_in_args, expected_arguments)

    def test_anonymous_login(self):
        """Test the anonymous login helper function."""
        launchpad = NoNetworkLaunchpad.login_anonymously(
            "anonymous access",
            launchpadlib_dir=self.temp_dir,
            service_root=SERVICE_ROOT,
        )
        self.assertEqual(launchpad.credentials.access_token.key, "")
        self.assertEqual(launchpad.credentials.access_token.secret, "")

        # Test that anonymous credentials are not saved.
        credentials_path = os.path.join(
            self.temp_dir, "api.example.com", "credentials", "anonymous access"
        )
        self.assertFalse(os.path.exists(credentials_path))

    def test_existing_credentials_arguments_passed_on(self):
        # When re-using existing credentials, the arguments login_with
        # is called with are passed on the the __init__() method.
        os.makedirs(
            os.path.join(self.temp_dir, "api.example.com", "credentials")
        )
        credentials_file_path = os.path.join(
            self.temp_dir, "api.example.com", "credentials", "app name"
        )
        credentials = Credentials(
            "app name",
            consumer_secret="consumer_secret:42",
            access_token=AccessToken("access_key:84", "access_secret:168"),
        )
        credentials.save_to_path(credentials_file_path)

        timeout = object()
        proxy_info = object()
        version = "foo"
        launchpad = NoNetworkLaunchpad.login_with(
            "app name",
            launchpadlib_dir=self.temp_dir,
            service_root=SERVICE_ROOT,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
        )
        expected_arguments = dict(
            service_root=SERVICE_ROOT,
            timeout=timeout,
            proxy_info=proxy_info,
            version=version,
            cache=os.path.join(self.temp_dir, "api.example.com", "cache"),
        )
        for key, expected in expected_arguments.items():
            actual = launchpad.passed_in_args[key]
            self.assertEqual(actual, expected)

    def test_None_launchpadlib_dir(self):
        # If no launchpadlib_dir is passed in to login_with,
        # $HOME/.launchpadlib is used.
        old_home = os.environ.get("HOME")
        os.environ["HOME"] = self.temp_dir
        launchpad = NoNetworkLaunchpad.login_with(
            "app name", service_root=SERVICE_ROOT
        )
        # Reset the environment to the old value.
        if old_home is not None:
            os.environ["HOME"] = old_home
        else:
            del os.environ["HOME"]

        cache_dir = launchpad.passed_in_args["cache"]
        launchpadlib_dir = os.path.abspath(os.path.join(cache_dir, "..", ".."))
        self.assertEqual(
            launchpadlib_dir, os.path.join(self.temp_dir, ".launchpadlib")
        )
        self.assertTrue(
            os.path.exists(
                os.path.join(launchpadlib_dir, "api.example.com", "cache")
            )
        )

    def test_short_service_name(self):
        # A short service name is converted to the full service root URL.
        launchpad = NoNetworkLaunchpad.login_with("app name", "staging")
        self.assertEqual(
            launchpad.passed_in_args["service_root"],
            "https://api.staging.launchpad.net/",
        )

        # A full URL as the service name is left alone.
        launchpad = NoNetworkLaunchpad.login_with(
            "app name", uris.service_roots["staging"]
        )
        self.assertEqual(
            launchpad.passed_in_args["service_root"],
            uris.service_roots["staging"],
        )

        # A short service name that does not match one of the
        # pre-defined service root names, and is not a valid URL,
        # raises an exception.
        launchpad = ("app name", "https://")
        self.assertRaises(
            ValueError, NoNetworkLaunchpad.login_with, "app name", "foo"
        )

    def test_max_failed_attempts_accepted(self):
        # You can pass in a value for the 'max_failed_attempts'
        # argument, even though that argument doesn't do anything.
        NoNetworkLaunchpad.login_with("not important", max_failed_attempts=5)


class TestDeprecatedLoginMethods(KeyringTest):
    """Make sure the deprecated login methods still work."""

    def test_login_is_deprecated(self):
        # login() works but triggers a deprecation warning.
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            warnings.simplefilter("ignore", PendingDeprecationWarning)
            NoNetworkLaunchpad.login("consumer", "token", "secret")
            self.assertEqual(len(caught), 1)
            self.assertEqual(caught[0].category, DeprecationWarning)

    def test_get_token_and_login_is_deprecated(self):
        # get_token_and_login() works but triggers a deprecation warning.
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            warnings.simplefilter("ignore", PendingDeprecationWarning)
            warnings.filterwarnings(
                "ignore", r".*next release of cryptography"
            )
            NoNetworkLaunchpad.get_token_and_login("consumer")
            self.assertEqual(len(caught), 1)
            self.assertEqual(caught[0].category, DeprecationWarning)


class TestCredenitialSaveFailedCallback(unittest.TestCase):
    # There is a callback which will be called if saving the credentials
    # fails.

    def setUp(self):
        # launchpadlib.launchpad uses the socket module to look up the
        # hostname, obviously that can vary so we replace the socket module
        # with a fake that returns a fake hostname.
        launchpadlib.launchpad.socket = FauxSocketModule()
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        launchpadlib.launchpad.socket = socket
        shutil.rmtree(self.temp_dir)

    @patch.object(NoNetworkLaunchpad, "_is_sudo", staticmethod(lambda: False))
    def test_credentials_save_failed(self):
        # If saving the credentials did not succeed and a callback was
        # provided, it is called.

        callback_called = []

        def callback():
            # Since we can't rebind "callback_called" here, we'll have to
            # settle for mutating it to signal success.
            callback_called.append(None)

        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        service_root = "http://api.example.com/"
        with fake_keyring(BadSaveKeyring()):
            NoNetworkLaunchpad.login_with(
                "not important",
                service_root=service_root,
                launchpadlib_dir=launchpadlib_dir,
                credential_save_failed=callback,
            )
            self.assertEqual(len(callback_called), 1)

    @patch.object(NoNetworkLaunchpad, "_is_sudo", staticmethod(lambda: False))
    def test_default_credentials_save_failed_is_to_raise_exception(self):
        # If saving the credentials did not succeed and no callback was
        # provided, the underlying exception is raised.
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        service_root = "http://api.example.com/"
        with fake_keyring(BadSaveKeyring()):
            self.assertRaises(
                RuntimeError,
                NoNetworkLaunchpad.login_with,
                "not important",
                service_root=service_root,
                launchpadlib_dir=launchpadlib_dir,
            )

    @patch.object(NoNetworkLaunchpad, "_is_sudo", staticmethod(lambda: True))
    def test_credentials_save_fail_under_sudo_does_not_raise_exception(self):
        # When running under sudo, Launchpad will not attempt to use
        # the keyring, so credential save failure will never happen
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        service_root = "http://api.example.com/"
        with fake_keyring(BadSaveKeyring()):
            NoNetworkLaunchpad.login_with(
                "not important",
                service_root=service_root,
                launchpadlib_dir=launchpadlib_dir,
            )


class TestMultipleSites(unittest.TestCase):
    # If the same application name (consumer name) is used to access more than
    # one site, the credentials need to be stored seperately.  Therefore, the
    # "username" passed ot the keyring includes the service root.

    def setUp(self):
        # launchpadlib.launchpad uses the socket module to look up the
        # hostname, obviously that can vary so we replace the socket module
        # with a fake that returns a fake hostname.
        launchpadlib.launchpad.socket = FauxSocketModule()
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        launchpadlib.launchpad.socket = socket
        shutil.rmtree(self.temp_dir)

    @patch.object(NoNetworkLaunchpad, "_is_sudo", staticmethod(lambda: False))
    def test_components_of_application_key(self):
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        keyring = InMemoryKeyring()
        service_root = "http://api.example.com/"
        application_name = "Super App 3000"
        with fake_keyring(keyring):
            launchpad = NoNetworkLaunchpad.login_with(
                application_name,
                service_root=service_root,
                launchpadlib_dir=launchpadlib_dir,
            )
            consumer_name = launchpad.credentials.consumer.key

        application_key = list(keyring.data.keys())[0][1]

        # Both the consumer name (normally the name of the application) and
        # the service root (the URL of the service being accessed) are
        # included in the key when storing credentials.
        self.assertIn(service_root, application_key)
        self.assertIn(consumer_name, application_key)

        # The key used to store the credentials is of this structure (and
        # shouldn't change between releases or stored credentials will be
        # "forgotten").
        self.assertEqual(application_key, consumer_name + "@" + service_root)

    @patch.object(NoNetworkLaunchpad, "_is_sudo", staticmethod(lambda: False))
    def test_same_app_different_servers(self):
        launchpadlib_dir = os.path.join(self.temp_dir, "launchpadlib")
        keyring = InMemoryKeyring()
        # Be paranoid about the keyring starting out empty.
        assert not keyring.data, "oops, a fresh keyring has data in it"
        with fake_keyring(keyring):
            # Create stored credentials for the same application but against
            # two different sites (service roots).
            NoNetworkLaunchpad.login_with(
                "application name",
                service_root="http://alpha.example.com/",
                launchpadlib_dir=launchpadlib_dir,
            )
            NoNetworkLaunchpad.login_with(
                "application name",
                service_root="http://beta.example.com/",
                launchpadlib_dir=launchpadlib_dir,
            )

        # There should only be two sets of stored credentials (this assertion
        # is of the test mechanism, not a test assertion).
        assert len(keyring.data.keys()) == 2

        application_key_1 = list(keyring.data.keys())[0][1]
        application_key_2 = list(keyring.data.keys())[1][1]
        self.assertNotEqual(application_key_1, application_key_2)


def test_suite():
    return unittest.TestLoader().loadTestsFromName(__name__)
