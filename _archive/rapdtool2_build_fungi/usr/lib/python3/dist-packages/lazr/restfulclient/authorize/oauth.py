# Copyright 2009-2018 Canonical Ltd.

# This file is part of lazr.restfulclient.
#
# lazr.restfulclient is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# lazr.restfulclient is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with lazr.restfulclient.  If not, see
# <http://www.gnu.org/licenses/>.

"""OAuth classes for use with lazr.restfulclient."""


try:
    # Python 3, SafeConfigParser was renamed to just ConfigParser.
    from configparser import ConfigParser as SafeConfigParser
except ImportError:
    from ConfigParser import SafeConfigParser
import os
import platform
import stat
import socket

from oauthlib import oauth1
import six
from six.moves.urllib.parse import (
    parse_qs,
    urlencode,
    )

from lazr.restfulclient.authorize import HttpAuthorizer
from lazr.restfulclient.errors import CredentialsFileError

__metaclass__ = type
__all__ = [
    'AccessToken',
    'Consumer',
    'OAuthAuthorizer',
    'SystemWideConsumer',
    ]


CREDENTIALS_FILE_VERSION = '1'


# For compatibility, Consumer and AccessToken are defined using terminology
# from the older oauth library rather than the newer oauthlib.
class Consumer:
    """An OAuth consumer (application)."""

    def __init__(self, key, secret='', application_name=None):
        """Initialize

        :param key: The OAuth consumer key
        :param secret: The OAuth consumer secret. Don't use this. It's
            a misfeature, and lazr.restful doesn't expect it.
        :param application_name: An application name, if different
            from the consumer key. If present, this will be used in
            the User-Agent header.
        """
        self.key = key
        self.secret = secret
        self.application_name = application_name


class AccessToken:
    """An OAuth access token."""

    def __init__(self, key, secret='', context=None):
        self.key = key
        self.secret = secret
        self.context = context

    def to_string(self):
        return urlencode([
            ("oauth_token_secret", self.secret),
            ("oauth_token", self.key),
            ])

    __str__ = to_string

    @classmethod
    def from_string(cls, s):
        params = parse_qs(s, keep_blank_values=False)
        key = params["oauth_token"][0]
        secret = params["oauth_token_secret"][0]
        return cls(key, secret)


class TruthyString(six.text_type):
    """A Unicode string which is always true."""

    def __bool__(self):
        return True

    __nonzero__ = __bool__


class SystemWideConsumer(Consumer):
    """A consumer associated with the logged-in user rather than an app.

    This can be used to share a single OAuth token among multiple
    desktop applications. The OAuth consumer key will be derived from
    system information (platform and hostname).
    """
    KEY_FORMAT = "System-wide: %s (%s)"

    def __init__(self, application_name, secret=''):
        """Constructor.

        :param application_name: An application name. This will be
            used in the User-Agent header.
        :param secret: The OAuth consumer secret. Don't use this. It's
            a misfeature, and lazr.restful doesn't expect it.
        """
        super(SystemWideConsumer, self).__init__(
            self.consumer_key, secret, application_name)

    @property
    def consumer_key(self):
        """The system-wide OAuth consumer key for this computer.

        This key identifies the platform and the computer's
        hostname. It does not identify the active user.
        """
        try:
            import distro
            distname = distro.name()
        except Exception:
            # This can happen due to various kinds of failures with the data
            # sources used by the distro module.
            distname = ''
        if distname == '':
            distname = platform.system() # (eg. "Windows")
        return self.KEY_FORMAT % (distname, socket.gethostname())


class OAuthAuthorizer(HttpAuthorizer):
    """A client that signs every outgoing request with OAuth credentials."""

    def __init__(self, consumer_name=None, consumer_secret='',
                 access_token=None, oauth_realm="OAuth",
                 application_name=None):
        self.consumer = None
        if consumer_name is not None:
            self.consumer = Consumer(
                consumer_name, consumer_secret, application_name)
        self.access_token = access_token
        self.oauth_realm = oauth_realm

    @property
    def user_agent_params(self):
        """Any information necessary to identify this user agent.

        In this case, the OAuth consumer name.
        """
        params = {}
        if self.consumer is None:
            return params
        params['oauth_consumer'] = self.consumer.key
        if self.consumer.application_name is not None:
            params['application'] =  self.consumer.application_name
        return params

    def load(self, readable_file):
        """Load credentials from a file-like object.

        This overrides the consumer and access token given in the constructor
        and replaces them with the values read from the file.

        :param readable_file: A file-like object to read the credentials from
        :type readable_file: Any object supporting the file-like `read()`
            method
        """
        # Attempt to load the access token from the file.
        parser = SafeConfigParser()
        reader = getattr(parser, 'read_file', parser.readfp)
        reader(readable_file)
        # Check the version number and extract the access token and
        # secret.  Then convert these to the appropriate instances.
        if not parser.has_section(CREDENTIALS_FILE_VERSION):
            raise CredentialsFileError('No configuration for version %s' %
                                       CREDENTIALS_FILE_VERSION)
        consumer_key = parser.get(
            CREDENTIALS_FILE_VERSION, 'consumer_key')
        consumer_secret = parser.get(
            CREDENTIALS_FILE_VERSION, 'consumer_secret')
        self.consumer = Consumer(consumer_key, consumer_secret)
        access_token = parser.get(
            CREDENTIALS_FILE_VERSION, 'access_token')
        access_secret = parser.get(
            CREDENTIALS_FILE_VERSION, 'access_secret')
        self.access_token = AccessToken(access_token, access_secret)

    @classmethod
    def load_from_path(cls, path):
        """Convenience method for loading credentials from a file.

        Open the file, create the Credentials and load from the file,
        and finally close the file and return the newly created
        Credentials instance.

        :param path: In which file the credential file should be saved.
        :type path: string
        :return: The loaded Credentials instance.
        :rtype: `Credentials`
        """
        credentials = cls()
        credentials_file = open(path, 'r')
        credentials.load(credentials_file)
        credentials_file.close()
        return credentials

    def save(self, writable_file):
        """Write the credentials to the file-like object.

        :param writable_file: A file-like object to write the credentials to
        :type writable_file: Any object supporting the file-like `write()`
            method
        :raise CredentialsFileError: when there is either no consumer or no
            access token
        """
        if self.consumer is None:
            raise CredentialsFileError('No consumer')
        if self.access_token is None:
            raise CredentialsFileError('No access token')

        parser = SafeConfigParser()
        parser.add_section(CREDENTIALS_FILE_VERSION)
        parser.set(CREDENTIALS_FILE_VERSION,
                   'consumer_key', self.consumer.key)
        parser.set(CREDENTIALS_FILE_VERSION,
                   'consumer_secret', self.consumer.secret)
        parser.set(CREDENTIALS_FILE_VERSION,
                   'access_token', self.access_token.key)
        parser.set(CREDENTIALS_FILE_VERSION,
                   'access_secret', self.access_token.secret)
        parser.write(writable_file)

    def save_to_path(self, path):
        """Convenience method for saving credentials to a file.

        Create the file, call self.save(), and close the
        file. Existing files are overwritten. The resulting file will
        be readable and writable only by the user.

        :param path: In which file the credential file should be saved.
        :type path: string
        """
        credentials_file = os.fdopen(
            os.open(path, (os.O_CREAT | os.O_TRUNC | os.O_WRONLY),
                    (stat.S_IREAD | stat.S_IWRITE)), 'w')
        self.save(credentials_file)
        credentials_file.close()

    def authorizeRequest(self, absolute_uri, method, body, headers):
        """Sign a request with OAuth credentials."""
        client = oauth1.Client(
            self.consumer.key,
            client_secret=self.consumer.secret,
            resource_owner_key=TruthyString(self.access_token.key or ''),
            resource_owner_secret=self.access_token.secret,
            signature_method=oauth1.SIGNATURE_PLAINTEXT,
            realm=self.oauth_realm)
        # The older oauth library (which may still be used on the server)
        # requires the oauth_token parameter to be present and will fail
        # authentication if it isn't.  This hack forces it to be present
        # even if its value is the empty string.
        client.resource_owner_key = TruthyString(client.resource_owner_key)
        _, signed_headers, _ = client.sign(absolute_uri)
        for key, value in signed_headers.items():
            # client.sign returns Unicode headers; convert these to native
            # strings.
            if six.PY2:
                key = key.encode('UTF-8')
                value = value.encode('UTF-8')
            headers[key] = value
