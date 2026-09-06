# Copyright 2009 Canonical Ltd.

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

"""Classes to authorize lazr.restfulclient with various web services.

This module includes an authorizer classes for HTTP Basic Auth,
as well as a base-class authorizer that does nothing.

A set of classes for authorizing with OAuth is located in the 'oauth'
module.
"""

__metaclass__ = type
__all__ = [
    'BasicHttpAuthorizer',
    'HttpAuthorizer',
    ]

import base64


class HttpAuthorizer:
    """Handles authentication for HTTP requests.

    There are two ways to authenticate.

    The authorize_session() method is called once when the client is
    initialized. This works for authentication methods like Basic
    Auth.  The authorize_request is called for every HTTP request,
    which is useful for authentication methods like Digest and OAuth.

    The base class is a null authorizer which does not perform any
    authentication at all.
    """
    def authorizeSession(self, client):
        """Set up credentials for the entire session."""
        pass

    def authorizeRequest(self, absolute_uri, method, body, headers):
        """Set up credentials for a single request.

        This probably involves setting the Authentication header.
        """
        pass

    @property
    def user_agent_params(self):
        """Any parameters necessary to identify this user agent.

        By default this is an empty dict (because authentication
        details don't contain any information about the application
        making the request), but when a resource is protected by
        OAuth, the OAuth consumer name is part of the user agent.
        """
        return {}


class BasicHttpAuthorizer(HttpAuthorizer):
    """Handles authentication for services that use HTTP Basic Auth."""

    def __init__(self, username, password):
        """Constructor.

        :param username: User to send as authorization for all requests.
        :param password: Password to send as authorization for all requests.
        """
        self.username = username
        self.password = password

    def authorizeRequest(self, absolute_uri, method, body, headers):
        """Set up credentials for a single request.

        This sets the authorization header with the username/password.
        """
        headers['authorization'] = 'Basic ' + base64.b64encode(
            "%s:%s" % (self.username, self.password)).strip()

    def authorizeSession(self, client):
        client.add_credentials(self.username, self.password)
