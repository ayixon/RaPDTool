# Copyright 2008 Canonical Ltd.

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

"""lazr.restfulclient errors."""

__metaclass__ = type
__all__ = [
    'BadRequest',
    'Conflict',
    'ClientError',
    'CredentialsError',
    'CredentialsFileError',
    'HTTPError',
    'MethodNotAllowed',
    'NotFound',
    'PreconditionFailed',
    'RestfulError',
    'ResponseError',
    'ServerError',
    'Unauthorized',
    'UnexpectedResponseError',
    ]


class RestfulError(Exception):
    """Base error for the lazr.restfulclient API library."""


class CredentialsError(RestfulError):
    """Base credentials/authentication error."""


class CredentialsFileError(CredentialsError):
    """Error in credentials file."""


class ResponseError(RestfulError):
    """Error in response."""

    def __init__(self, response, content):
        RestfulError.__init__(self)
        self.response = response
        self.content = content


class UnexpectedResponseError(ResponseError):
    """An unexpected response was received."""

    def __str__(self):
        return '%s: %s' % (self.response.status, self.response.reason)


class HTTPError(ResponseError):
    """An HTTP non-2xx response code was received."""

    def __str__(self):
        """Show the error code, response headers, and response body."""
        headers = "\n".join(["%s: %s" % pair
                             for pair in sorted(self.response.items())])
        return ("HTTP Error %s: %s\n"
                "Response headers:\n---\n%s\n---\n"
                "Response body:\n---\n%s\n---\n") % (
            self.response.status, self.response.reason, headers, self.content)


class ClientError(HTTPError):
    """An exception representing a client-side error."""


class Unauthorized(ClientError):
    """An exception representing an authentication failure."""


class NotFound(ClientError):
    """An exception representing a nonexistent resource."""


class MethodNotAllowed(ClientError):
    """An exception raised when you use an unsupported HTTP method.

    This is most likely because you tried to delete a resource that
    can't be deleted.
    """


class BadRequest(ClientError):
    """An exception representing a problem with a client request."""


class Conflict(ClientError):
    """An exception representing a conflict with another client."""


class PreconditionFailed(ClientError):
    """An exception representing the failure of a conditional PUT/PATCH.

    The most likely explanation is that another client changed this
    object while you were working on it, and your version of the
    object is now out of date.
    """

class ServerError(HTTPError):
    """An exception representing a server-side error."""


def error_for(response, content):
    """Turn an HTTP response into an HTTPError subclass.

    :return: None if the response code is 1xx, 2xx or 3xx. Otherwise,
    an instance of an appropriate HTTPError subclass (or HTTPError
    if nothing else is appropriate.
    """
    http_errors_by_status_code = {
        400 : BadRequest,
        401 : Unauthorized,
        404 : NotFound,
        405 : MethodNotAllowed,
        409 : Conflict,
        412 : PreconditionFailed,
    }

    if response.status // 100 <= 3:
        # 1xx, 2xx and 3xx are not considered errors.
        return None
    else:
        cls = http_errors_by_status_code.get(response.status, HTTPError)
    if cls is HTTPError:
        if response.status // 100 == 5:
            cls = ServerError
        elif response.status // 100 == 4:
            cls = ClientError
    return cls(response, content)
