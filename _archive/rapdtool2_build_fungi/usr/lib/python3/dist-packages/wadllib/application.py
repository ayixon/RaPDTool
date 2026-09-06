# Copyright 2008-2018 Canonical Ltd.  All rights reserved.

# This file is part of wadllib.
#
# wadllib is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# wadllib is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with wadllib. If not, see <http://www.gnu.org/licenses/>.

"""Navigate the resources exposed by a web service.

The wadllib library helps a web client navigate the resources
exposed by a web service. The service defines its resources in a
single WADL file. wadllib parses this file and gives access to the
resources defined inside. The client code can see the capabilities of
a given resource and make the corresponding HTTP requests.

If a request returns a representation of the resource, the client can
bind the string representation to the wadllib Resource object.
"""

__metaclass__ = type

__all__ = [
    'Application',
    'Link',
    'Method',
    'NoBoundRepresentationError',
    'Parameter',
    'RepresentationDefinition',
    'ResponseDefinition',
    'Resource',
    'ResourceType',
    'WADLError',
    ]

import datetime
from email.utils import quote
import io
import json
import random
import re
import sys
import time
try:
    from urllib.parse import urlencode
except ImportError:
    from urllib import urlencode
try:
    import xml.etree.cElementTree as ET
except ImportError:
    import xml.etree.ElementTree as ET

from lazr.uri import URI, merge

from wadllib import (
    _make_unicode,
    _string_types,
    )
from wadllib.iso_strptime import iso_strptime

NS_MAP = "xmlns:map"
XML_SCHEMA_NS_URI = 'http://www.w3.org/2001/XMLSchema'

def wadl_tag(tag_name):
    """Scope a tag name with the WADL namespace."""
    return '{http://research.sun.com/wadl/2006/10}' + tag_name


def wadl_xpath(tag_name):
    """Turn a tag name into an XPath path."""
    return './' + wadl_tag(tag_name)


def _merge_dicts(*dicts):
    """Merge any number of dictionaries, some of which may be None."""
    final = {}
    for dict in dicts:
        if dict is not None:
            final.update(dict)
    return final


class WADLError(Exception):
    """An exception having to do with the state of the WADL application."""
    pass


class NoBoundRepresentationError(WADLError):
    """An unbound resource was used where wadllib expected a bound resource.

    To obtain the value of a resource's parameter, you first must bind
    the resource to a representation. Otherwise the resource has no
    idea what the value is and doesn't even know if you've given it a
    parameter name that makes sense.
    """


class UnsupportedMediaTypeError(WADLError):
    """A media type was given that's not supported in this context.

    A resource can only be bound to media types it has representations
    of.
    """


class WADLBase(object):
    """A base class for objects that contain WADL-derived information."""


class HasParametersMixin:
    """A mixin class for objects that have associated Parameter objects."""

    def params(self, styles, resource=None):
        """Find subsidiary parameters that have the given styles."""
        if resource is None:
            resource = self.resource
        if resource is None:
            raise ValueError("Could not find any particular resource")
        if self.tag is None:
            return []
        param_tags = self.tag.findall(wadl_xpath('param'))
        if param_tags is None:
            return []
        return [Parameter(resource, param_tag)
                for param_tag in param_tags
                if param_tag.attrib.get('style') in styles]

    def validate_param_values(self, params, param_values,
                              enforce_completeness=True, **kw_param_values):
        """Make sure the given valueset is valid.

        A valueset might be invalid because it contradicts a fixed
        value or (if enforce_completeness is True) because it lacks a
        required value.

        :param params: A list of Parameter objects.
        :param param_values: A dictionary of parameter values. May include
           paramters whose names are not valid Python identifiers.
        :param enforce_completeness: If True, this method will raise
           an exception when the given value set lacks a value for a
           required parameter.
        :param kw_param_values: A dictionary of parameter values.
        :return: A dictionary of validated parameter values.
        """
        param_values = _merge_dicts(param_values, kw_param_values)
        validated_values = {}
        for param in params:
            name = param.name
            if param.fixed_value is not None:
                if (name in param_values
                    and param_values[name] != param.fixed_value):
                    raise ValueError(("Value '%s' for parameter '%s' "
                                      "conflicts with fixed value '%s'")
                                     % (param_values[name], name,
                                        param.fixed_value))
                param_values[name] = param.fixed_value
            options = [option.value for option in param.options]
            if (len(options) > 0 and name in param_values
                and param_values[name] not in options):
                raise ValueError(("Invalid value '%s' for parameter '%s': "
                                  'valid values are: "%s"') % (
                        param_values[name], name, '", "'.join(options)))
            if (enforce_completeness and param.is_required
                and not name in param_values):
                raise ValueError("No value for required parameter '%s'"
                                 % name)
            if name in param_values:
                validated_values[name] = param_values[name]
                del param_values[name]
        if len(param_values) > 0:
            raise ValueError("Unrecognized parameter(s): '%s'"
                             % "', '".join(param_values.keys()))
        return validated_values


class WADLResolvableDefinition(WADLBase):
    """A base class for objects whose definitions may be references."""

    def __init__(self, application):
        """Initialize with a WADL application.

        :param application: A WADLDefinition. Relative links are
            assumed to be relative to this object's URL.
        """
        self._definition = None
        self.application = application

    def resolve_definition(self):
        """Return the definition of this object, wherever it is.

        Resource is a good example. A WADL <resource> tag
        may contain a large number of nested tags describing a
        resource, or it may just contain a 'type' attribute that
        references a <resource_type> which contains those same
        tags. Resource.resolve_definition() will return the original
        Resource object in the first case, and a
        ResourceType object in the second case.
        """
        if self._definition is not None:
            return self._definition
        object_url = self._get_definition_url()
        if object_url is None:
            # The object contains its own definition.
            # XXX leonardr 2008-05-28:
            # This code path is not tested in Launchpad.
            self._definition = self
            return self
        # The object makes reference to some other object. Resolve
        # its URL and return it.
        xml_id = self.application.lookup_xml_id(object_url)
        definition = self._definition_factory(xml_id)
        if definition is None:
            # XXX leonardr 2008-06-
            # This code path is not tested in Launchpad.
            # It requires an invalid WADL file that makes
            # a reference to a nonexistent tag within the
            # same WADL file.
            raise KeyError('No such XML ID: "%s"' % object_url)
        self._definition = definition
        return definition

    def _definition_factory(self, id):
        """Transform an XML ID into a wadllib wrapper object.

        Which kind of object it is depends on the subclass.
        """
        raise NotImplementedError()

    def _get_definition_url(self):
        """Find the URL that identifies an external reference.

        How to do this depends on the subclass.
        """
        raise NotImplementedError()


class Resource(WADLResolvableDefinition):
    """A resource, possibly bound to a representation."""

    def __init__(self, application, url, resource_type,
                 representation=None, media_type=None,
                 representation_needs_processing=True,
                 representation_definition=None):
        """
        :param application: A WADLApplication.
        :param url: The URL to this resource.
        :param resource_type: An ElementTree <resource> or <resource_type> tag.
        :param representation: A string representation.
        :param media_type: The media type of the representation.
        :param representation_needs_processing: Set to False if the
            'representation' parameter should be used as
            is. Otherwise, it will be transformed from a string into
            an appropriate Python data structure, depending on its
            media type.
        :param representation_definition: A RepresentationDefinition
            object describing the structure of this
            representation. Used in cases when the representation
            isn't the result of sending a standard GET to the
            resource.
        """
        super(Resource, self).__init__(application)
        self._url = url
        if isinstance(resource_type, _string_types):
            # We were passed the URL to a resource type. Look up the
            # type object itself
            self.tag = self.application.get_resource_type(resource_type).tag
        else:
            # We were passed an XML tag that describes a resource or
            # resource type.
            self.tag = resource_type

        self.representation = None
        if representation is not None:
            if media_type == 'application/json':
                if representation_needs_processing:
                    self.representation = json.loads(
                        _make_unicode(representation))
                else:
                    self.representation = representation
            else:
                raise UnsupportedMediaTypeError(
                    "This resource doesn't define a representation for "
                    "media type %s" % media_type)
        self.media_type = media_type
        if representation is not None:
            if representation_definition is not None:
                self.representation_definition = representation_definition
            else:
                self.representation_definition = (
                    self.get_representation_definition(self.media_type))

    @property
    def url(self):
        """Return the URL to this resource."""
        return self._url

    @property
    def type_url(self):
        """Return the URL to the type definition for this resource, if any."""
        if self.tag is None:
            return None
        url = self.tag.attrib.get('type')
        if url is not None:
            # This resource is defined in the WADL file.
            return url
        type_id = self.tag.attrib.get('id')
        if type_id is not None:
            # This resource was obtained by following a link.
            base = URI(self.application.markup_url).ensureSlash()
            return str(base) + '#' + type_id

        # This resource does not have any associated resource type.
        return None

    @property
    def id(self):
        """Return the ID of this resource."""
        return self.tag.attrib['id']

    def bind(self, representation, media_type='application/json',
             representation_needs_processing=True,
             representation_definition=None):
        """Bind the resource to a representation of that resource.

        :param representation: A string representation
        :param media_type: The media type of the representation.
        :param representation_needs_processing: Set to False if the
            'representation' parameter should be used as
            is.
        :param representation_definition: A RepresentationDefinition
            object describing the structure of this
            representation. Used in cases when the representation
            isn't the result of sending a standard GET to the
            resource.
        :return: A Resource bound to a particular representation.
        """
        return Resource(self.application, self.url, self.tag,
                        representation, media_type,
                        representation_needs_processing,
                        representation_definition)

    def get_representation_definition(self, media_type):
        """Get a description of one of this resource's representations."""
        default_get_response = self.get_method('GET').response
        for representation in default_get_response:
            representation_tag = representation.resolve_definition().tag
            if representation_tag.attrib.get('mediaType') == media_type:
                return representation
        raise UnsupportedMediaTypeError("No definition for representation "
                                        "with media type %s." % media_type)

    def get_method(self, http_method=None, media_type=None, query_params=None,
                   representation_params=None):
        """Look up one of this resource's methods by HTTP method.

        :param http_method: The HTTP method used to invoke the desired
                            method. Case-insensitive and optional.

        :param media_type: The media type of the representation
                           accepted by the method. Optional.

        :param query_params: The names and values of any fixed query
                             parameters used to distinguish between
                             two methods that use the same HTTP
                             method. Optional.

        :param representation_params: The names and values of any
                             fixed representation parameters used to
                             distinguish between two methods that use
                             the same HTTP method and have the same
                             media type. Optional.

        :return: A MethodDefinition, or None if there's no definition
                  that fits the given constraints.
        """
        for method_tag in self._method_tag_iter():
            name = method_tag.attrib.get('name', '').lower()
            if http_method is None or name == http_method.lower():
                method = Method(self, method_tag)
                if method.is_described_by(media_type, query_params,
                                          representation_params):
                    return method
        return None

    def parameters(self, media_type=None):
        """A list of this resource's parameters.

        :param media_type: Media type of the representation definition
            whose parameters are being named. Must be present unless
            this resource is bound to a representation.

        :raise NoBoundRepresentationError: If this resource is not
            bound to a representation and media_type was not provided.
        """
        return self._find_representation_definition(
            media_type).params(self)

    def parameter_names(self, media_type=None):
        """A list naming this resource's parameters.

        :param media_type: Media type of the representation definition
            whose parameters are being named. Must be present unless
            this resource is bound to a representation.

        :raise NoBoundRepresentationError: If this resource is not
            bound to a representation and media_type was not provided.
        """
        return self._find_representation_definition(
            media_type).parameter_names(self)

    @property
    def method_iter(self):
        """An iterator over the methods defined on this resource."""
        for method_tag in self._method_tag_iter():
            yield Method(self, method_tag)

    def get_parameter(self, param_name, media_type=None):
        """Find a parameter within a representation definition.

        :param param_name: Name of the parameter to find.

        :param media_type: Media type of the representation definition
            whose parameters are being named. Must be present unless
            this resource is bound to a representation.

        :raise NoBoundRepresentationError: If this resource is not
            bound to a representation and media_type was not provided.
        """
        definition = self._find_representation_definition(media_type)
        representation_tag = definition.tag
        for param_tag in representation_tag.findall(wadl_xpath('param')):
            if param_tag.attrib.get('name') == param_name:
                return Parameter(self, param_tag)
        return None

    def get_parameter_value(self, parameter):
        """Find the value of a parameter, given the Parameter object.

        :raise ValueError: If the parameter value can't be converted into
        its defined type.
        """

        if self.representation is None:
            raise NoBoundRepresentationError(
                "Resource is not bound to any representation.")
        if self.media_type == 'application/json':
            # XXX leonardr 2008-05-28 A real JSONPath implementation
            # should go here. It should execute tag.attrib['path']
            # against the JSON representation.
            #
            # Right now the implementation assumes the JSON
            # representation is a hash and treats tag.attrib['name'] as a
            # key into the hash.
            if parameter.style != 'plain':
                raise NotImplementedError(
                    "Don't know how to find value for a parameter of "
                    "type %s." % parameter.style)
            value = self.representation[parameter.name]
            if value is not None:
                namespace_url, data_type = self._dereference_namespace(
                    parameter.tag, parameter.type)
                if (namespace_url == XML_SCHEMA_NS_URI
                    and data_type in ['dateTime', 'date']):
                    try:
                        # Parse it as an ISO 8601 date and time.
                        value = iso_strptime(value)
                    except ValueError:
                        # Parse it as an ISO 8601 date.
                        try:
                            value = datetime.datetime(
                                *(time.strptime(value, "%Y-%m-%d")[0:6]))
                        except ValueError:
                            # Raise an unadorned ValueError so the client
                            # can treat the value as a string if they
                            # want.
                            raise ValueError(value)
            return value

        raise NotImplementedError("Path traversal not implemented for "
                                  "a representation of media type %s."
                                  % self.media_type)


    def _dereference_namespace(self, tag, value):
        """Splits a value into namespace URI and value.

        :param tag: A tag to use as context when mapping namespace
        names to URIs.
        """
        if value is not None and ':' in value:
            namespace, value = value.split(':', 1)
        else:
            namespace = ''
        ns_map = tag.get(NS_MAP)
        namespace_url = ns_map.get(namespace, None)
        return namespace_url, value

    def _definition_factory(self, id):
        """Given an ID, find a ResourceType for that ID."""
        return self.application.resource_types.get(id)

    def _get_definition_url(self):
        """Return the URL that shows where a resource is 'really' defined.

        If a resource's capabilities are defined by reference, the
        <resource> tag's 'type' attribute will contain the URL to the
        <resource_type> that defines them.
        """
        return self.tag.attrib.get('type')

    def _find_representation_definition(self, media_type=None):
        """Get the most appropriate representation definition.

        If media_type is provided, the most appropriate definition is
        the definition of the representation of that media type.

        If this resource is bound to a representation, the most
        appropriate definition is the definition of that
        representation. Otherwise, the most appropriate definition is
        the definition of the representation served in response to a
        standard GET.

        :param media_type: Media type of the definition to find. Must
            be present unless the resource is bound to a
            representation.

        :raise NoBoundRepresentationError: If this resource is not
            bound to a representation and media_type was not provided.

        :return: A RepresentationDefinition
        """
        if self.representation is not None:
            # We know that when this object was created, a
            # representation definition was either looked up, or
            # directly passed in along with the representation.
            definition = self.representation_definition.resolve_definition()
        elif media_type is not None:
            definition = self.get_representation_definition(media_type)
        else:
            raise NoBoundRepresentationError(
                "Resource is not bound to any representation, and no media "
                "media type was specified.")
        return definition.resolve_definition()


    def _method_tag_iter(self):
        """Iterate over this resource's <method> tags."""
        definition = self.resolve_definition().tag
        for method_tag in definition.findall(wadl_xpath('method')):
            yield method_tag


class Method(WADLBase):
    """A wrapper around an XML <method> tag.
    """
    def __init__(self, resource, method_tag):
        """Initialize with a <method> tag.

        :param method_tag: An ElementTree <method> tag.
        """
        self.resource = resource
        self.application = self.resource.application
        self.tag = method_tag

    @property
    def request(self):
        """Return the definition of a request that invokes the WADL method."""
        return RequestDefinition(self, self.tag.find(wadl_xpath('request')))

    @property
    def response(self):
        """Return the definition of the response to the WADL method."""
        return ResponseDefinition(self.resource,
                                  self.tag.find(wadl_xpath('response')))

    @property
    def id(self):
        """The XML ID of the WADL method definition."""
        return self.tag.attrib.get('id')

    @property
    def name(self):
        """The name of the WADL method definition.

        This is also the name of the HTTP method (GET, POST, etc.)
        that should be used to invoke the WADL method.
        """
        return self.tag.attrib.get('name').lower()

    def build_request_url(self, param_values=None, **kw_param_values):
        """Return the request URL to use to invoke this method."""
        return self.request.build_url(param_values, **kw_param_values)

    def build_representation(self, media_type=None,
                             param_values=None, **kw_param_values):
        """Build a representation to be sent when invoking this method.

        :return: A 2-tuple of (media_type, representation).
        """
        return self.request.representation(
            media_type, param_values, **kw_param_values)

    def is_described_by(self, media_type=None, query_values=None,
                        representation_values=None):
        """Returns true if this method fits the given constraints.

        :param media_type: The method must accept this media type as a
                           representation.

        :param query_values: These key-value pairs must be acceptable
                           as values for this method's query
                           parameters. This need not be a complete set
                           of parameters acceptable to the method.

        :param representation_values: These key-value pairs must be
                           acceptable as values for this method's
                           representation parameters. Again, this need
                           not be a complete set of parameters
                           acceptable to the method.
        """
        representation = None
        if media_type is not None:
            representation = self.request.get_representation_definition(
                media_type)
            if representation is None:
                return False

        if query_values is not None and len(query_values) > 0:
            request = self.request
            if request is None:
                # This method takes no special request
                # parameters, so it can't match.
                return False
            try:
                request.validate_param_values(
                    request.query_params, query_values, False)
            except ValueError:
                return False

        # At this point we know the media type and query values match.
        if (representation_values is None
            or len(representation_values) == 0):
            return True

        if representation is not None:
            return representation.is_described_by(
                representation_values)
        for representation in self.request.representations:
            try:
                representation.validate_param_values(
                    representation.params(self.resource),
                    representation_values, False)
                return True
            except ValueError:
                pass
        return False


class RequestDefinition(WADLBase, HasParametersMixin):
    """A wrapper around the description of the request invoking a method."""
    def __init__(self, method, request_tag):
        """Initialize with a <request> tag.

        :param resource: The resource to which this request can be sent.
        :param request_tag: An ElementTree <request> tag.
        """
        self.method = method
        self.resource = self.method.resource
        self.application = self.resource.application
        self.tag = request_tag

    @property
    def query_params(self):
        """Return the query parameters for this method."""
        return self.params(['query'])

    @property
    def representations(self):
        for definition in self.tag.findall(wadl_xpath('representation')):
            yield RepresentationDefinition(
                self.application, self.resource, definition)

    def get_representation_definition(self, media_type=None):
        """Return the appropriate representation definition."""
        for representation in self.representations:
            if media_type is None or representation.media_type == media_type:
                return representation
        return None

    def representation(self, media_type=None, param_values=None,
                       **kw_param_values):
        """Build a representation to be sent along with this request.

        :return: A 2-tuple of (media_type, representation).
        """
        definition = self.get_representation_definition(media_type)
        if definition is None:
            raise TypeError("Cannot build representation of media type %s"
                            % media_type)
        return definition.bind(param_values, **kw_param_values)

    def build_url(self, param_values=None, **kw_param_values):
        """Return the request URL to use to invoke this method."""
        validated_values = self.validate_param_values(
            self.query_params, param_values, **kw_param_values)
        url = self.resource.url
        if len(validated_values) > 0:
            if '?' in url:
                append = '&'
            else:
                append = '?'
            url += append + urlencode(sorted(validated_values.items()))
        return url


class ResponseDefinition(HasParametersMixin):
    """A wrapper around the description of a response to a method."""

    # XXX leonardr 2008-05-29 it would be nice to have
    # ResponseDefinitions for POST operations and nonstandard GET
    # operations say what representations and/or status codes you get
    # back. Getting this to work with Launchpad requires work on the
    # Launchpad side.
    def __init__(self, resource, response_tag, headers=None):
        """Initialize with a <response> tag.

        :param response_tag: An ElementTree <response> tag.
        """
        self.application = resource.application
        self.resource = resource
        self.tag = response_tag
        self.headers = headers

    def __iter__(self):
        """Get an iterator over the representation definitions.

        These are the representations returned in response to an
        invocation of this method.
        """
        path = wadl_xpath('representation')
        for representation_tag in self.tag.findall(path):
            yield RepresentationDefinition(
                self.resource.application, self.resource, representation_tag)

    def bind(self, headers):
        """Bind the response to a set of HTTP headers.

        A WADL response can have associated header parameters, but no
        other kind.
        """
        return ResponseDefinition(self.resource, self.tag, headers)

    def get_parameter(self, param_name):
        """Find a header parameter within the response."""
        for param_tag in self.tag.findall(wadl_xpath('param')):
            if (param_tag.attrib.get('name') == param_name
                and param_tag.attrib.get('style') == 'header'):
                return Parameter(self, param_tag)
        return None

    def get_parameter_value(self, parameter):
        """Find the value of a parameter, given the Parameter object."""
        if self.headers is None:
            raise NoBoundRepresentationError(
                "Response object is not bound to any headers.")
        if parameter.style != 'header':
            raise NotImplementedError(
                "Don't know how to find value for a parameter of "
                "type %s." % parameter.style)
        return self.headers.get(parameter.name)

    def get_representation_definition(self, media_type):
        """Get one of the possible representations of the response."""
        if self.tag is None:
            return None
        for representation in self:
            if representation.media_type == media_type:
                return representation
        return None


class RepresentationDefinition(WADLResolvableDefinition, HasParametersMixin):
    """A definition of the structure of a representation."""

    def __init__(self, application, resource, representation_tag):
        super(RepresentationDefinition, self).__init__(application)
        self.resource = resource
        self.tag = representation_tag

    def params(self, resource):
        return super(RepresentationDefinition, self).params(
            ['query', 'plain'], resource)

    def parameter_names(self, resource):
        """Return the names of all parameters."""
        return [param.name for param in self.params(resource)]

    @property
    def media_type(self):
        """The media type of the representation described here."""
        return self.resolve_definition().tag.attrib['mediaType']

    def _make_boundary(self, all_parts):
        """Make a random boundary that does not appear in `all_parts`."""
        _width = len(repr(sys.maxsize - 1))
        _fmt = '%%0%dd' % _width
        token = random.randrange(sys.maxsize)
        boundary = ('=' * 15) + (_fmt % token) + '=='
        if all_parts is None:
            return boundary
        b = boundary
        counter = 0
        while True:
            pattern = ('^--' + re.escape(b) + '(--)?$').encode('ascii')
            if not re.search(pattern, all_parts, flags=re.MULTILINE):
                break
            b = boundary + '.' + str(counter)
            counter += 1
        return b

    def _write_headers(self, buf, headers):
        """Write MIME headers to a file object."""
        for key, value in headers:
            buf.write(key.encode('UTF-8'))
            buf.write(b': ')
            buf.write(value.encode('UTF-8'))
            buf.write(b'\r\n')
        buf.write(b'\r\n')

    def _write_boundary(self, buf, boundary, closing=False):
        """Write a multipart boundary to a file object."""
        buf.write(b'--')
        buf.write(boundary.encode('UTF-8'))
        if closing:
            buf.write(b'--')
        buf.write(b'\r\n')

    def _generate_multipart_form(self, parts):
        """Generate a multipart/form-data message.

        This is very loosely based on the email module in the Python standard
        library.  However, that module doesn't really support directly embedding
        binary data in a form: various versions of Python have mangled line
        separators in different ways, and none of them get it quite right.
        Since we only need a tiny subset of MIME here, it's easier to implement
        it ourselves.

        :return: a tuple of two elements: the Content-Type of the message, and
            the entire encoded message as a byte string.
        """
        # Generate the subparts first so that we can calculate a safe boundary.
        encoded_parts = []
        for is_binary, name, value in parts:
            buf = io.BytesIO()
            if is_binary:
                ctype = 'application/octet-stream'
                # RFC 7578 says that the filename parameter isn't mandatory
                # in our case, but without it cgi.FieldStorage tries to
                # decode as text on Python 3.
                cdisp = 'form-data; name="%s"; filename="%s"' % (
                    quote(name), quote(name))
            else:
                ctype = 'text/plain; charset="utf-8"'
                cdisp = 'form-data; name="%s"' % quote(name)
            self._write_headers(buf, [
                ('MIME-Version', '1.0'),
                ('Content-Type', ctype),
                ('Content-Disposition', cdisp),
                ])
            if is_binary:
                if not isinstance(value, bytes):
                    raise TypeError('bytes payload expected: %s' % type(value))
                buf.write(value)
            else:
                if not isinstance(value, _string_types):
                    raise TypeError(
                        'string payload expected: %s' % type(value))
                lines = re.split(r'\r\n|\r|\n', value)
                for line in lines[:-1]:
                    buf.write(line.encode('UTF-8'))
                    buf.write(b'\r\n')
                buf.write(lines[-1].encode('UTF-8'))
            encoded_parts.append(buf.getvalue())

        # Create a suitable boundary.
        boundary = self._make_boundary(b'\r\n'.join(encoded_parts))

        # Now we can write the multipart headers, followed by all the parts.
        buf = io.BytesIO()
        ctype = 'multipart/form-data; boundary="%s"' % quote(boundary)
        self._write_headers(buf, [
            ('MIME-Version', '1.0'),
            ('Content-Type', ctype),
            ])
        for encoded_part in encoded_parts:
            self._write_boundary(buf, boundary)
            buf.write(encoded_part)
            buf.write(b'\r\n')
        self._write_boundary(buf, boundary, closing=True)

        return ctype, buf.getvalue()

    def bind(self, param_values, **kw_param_values):
        """Bind the definition to parameter values, creating a document.

        :return: A 2-tuple (media_type, document).
        """
        definition = self.resolve_definition()
        params = definition.params(self.resource)
        validated_values = self.validate_param_values(
            params, param_values, **kw_param_values)
        media_type = self.media_type
        if media_type == 'application/x-www-form-urlencoded':
            doc = urlencode(sorted(validated_values.items()))
        elif media_type == 'multipart/form-data':
            parts = []
            missing = object()
            for param in params:
                value = validated_values.get(param.name, missing)
                if value is not missing:
                    parts.append((param.type == 'binary', param.name, value))
            media_type, doc = self._generate_multipart_form(parts)
        elif media_type == 'application/json':
            doc = json.dumps(validated_values)
        else:
            raise ValueError("Unsupported media type: '%s'" % media_type)
        return media_type, doc

    def _definition_factory(self, id):
        """Turn a representation ID into a RepresentationDefinition."""
        return self.application.representation_definitions.get(id)

    def _get_definition_url(self):
        """Find the URL containing the representation's 'real' definition.

        If a representation's structure is defined by reference, the
        <representation> tag's 'href' attribute will contain the URL
        to the <representation> that defines the structure.
        """
        return self.tag.attrib.get('href')


class Parameter(WADLBase):
    """One of the parameters of a representation definition."""

    def __init__(self, value_container, tag):
        """Initialize with respect to a value container.

        :param value_container: Usually the resource whose representation
            has this parameter. If the resource is bound to a representation,
            you'll be able to find the value of this parameter in the
            representation. This may also be a server response whose headers
            define a value for this parameter.
        :tag: The ElementTree <param> tag for this parameter.
        """
        self.application = value_container.application
        self.value_container = value_container
        self.tag = tag

    @property
    def name(self):
        """The name of this parameter."""
        return self.tag.attrib.get('name')

    @property
    def style(self):
        """The style of this parameter."""
        return self.tag.attrib.get('style')

    @property
    def type(self):
        """The XSD type of this parameter."""
        return self.tag.attrib.get('type')

    @property
    def fixed_value(self):
        """The value to which this parameter is fixed, if any.

        A fixed parameter must be present in invocations of a WADL
        method, and it must have a particular value. This is commonly
        used to designate one parameter as containing the name of the
        server-side operation to be invoked.
        """
        return self.tag.attrib.get('fixed')

    @property
    def is_required(self):
        """Whether or not a value for this parameter is required."""
        return (self.tag.attrib.get('required', 'false').lower()
                in ['1', 'true'])

    def get_value(self):
        """The value of this parameter in the bound representation/headers.

        :raise NoBoundRepresentationError: If this parameter's value
               container is not bound to a representation or a set of
               headers.
        """
        return self.value_container.get_parameter_value(self)

    @property
    def options(self):
        """Return the set of acceptable values for this parameter."""
        return [Option(self, option_tag)
                for option_tag  in self.tag.findall(wadl_xpath('option'))]

    @property
    def link(self):
        """Get the link to another resource.

        The link may be examined and, if its type is of a known WADL
        description, it may be followed.

        :return: A Link object, or None.
        """
        link_tag = self.tag.find(wadl_xpath('link'))
        if link_tag is None:
            return None
        return Link(self, link_tag)

    @property
    def linked_resource(self):
        """Follow a link from this parameter to a new resource.

        This only works for parameters whose WADL definition includes a
        <link> tag that points to a known WADL description.

        :return: A Resource object for the resource at the other end
        of the link.
        """
        link = self.link
        if link is None:
            raise ValueError("This parameter isn't a link to anything.")
        return link.follow

class Option(WADLBase):
    """One of a set of possible values for a parameter."""

    def __init__(self, parameter, option_tag):
        """Initialize the option.

        :param parameter: A Parameter.
        :param link_tag: An ElementTree <option> tag.
        """
        self.parameter = parameter
        self.tag = option_tag

    @property
    def value(self):
        return self.tag.attrib.get('value')


class Link(WADLResolvableDefinition):
    """A link from one resource to another.

    Calling resolve_definition() on a Link will give you a Resource for the
    type of resource linked to. An alias for this is 'follow'.
    """

    def __init__(self, parameter, link_tag):
        """Initialize the link.

        :param parameter: A Parameter.
        :param link_tag: An ElementTree <link> tag.
        """
        super(Link, self).__init__(parameter.application)
        self.parameter = parameter
        self.tag = link_tag

    @property
    def follow(self):
        """Follow the link to another Resource."""
        if not self.can_follow:
            raise WADLError("Cannot follow a link when the target has no "
                            "WADL description. Try using a general HTTP "
                            "client instead.")
        return self.resolve_definition()

    @property
    def can_follow(self):
        """Can this link be followed within wadllib?

        wadllib can follow a link if it points to a resource that has
        a WADL definition.
        """
        try:
            definition_url = self._get_definition_url()
        except WADLError:
            return False
        return True

    def _definition_factory(self, id):
        """Turn a resource type ID into a ResourceType."""
        return Resource(
            self.application, self.parameter.get_value(),
            self.application.resource_types.get(id).tag)

    def _get_definition_url(self):
        """Find the URL containing the definition ."""
        type = self.tag.attrib.get('resource_type')
        if type is None:
            raise WADLError("Parameter is a link, but not to a resource "
                            "with a known WADL description.")
        return type


class ResourceType(WADLBase):
    """A wrapper around an XML <resource_type> tag."""

    def __init__(self, resource_type_tag):
        """Initialize with a <resource_type> tag.

        :param resource_type_tag: An ElementTree <resource_type> tag.
        """
        self.tag = resource_type_tag


class Application(WADLBase):
    """A WADL document made programmatically accessible."""

    def __init__(self, markup_url, markup):
        """Parse WADL and find the most important parts of the document.

        :param markup_url: The URL from which this document was obtained.
        :param markup: The WADL markup itself, or an open filehandle to it.
        """
        self.markup_url = markup_url
        if hasattr(markup, 'read'):
            self.doc = self._from_stream(markup)
        else:
            self.doc = self._from_string(markup)
        self.resources = self.doc.find(wadl_xpath('resources'))
        self.resource_base = self.resources.attrib.get('base')
        self.representation_definitions = {}
        self.resource_types = {}
        for representation in self.doc.findall(wadl_xpath('representation')):
            id = representation.attrib.get('id')
            if id is not None:
                definition = RepresentationDefinition(
                    self, None, representation)
                self.representation_definitions[id] = definition
        for resource_type in self.doc.findall(wadl_xpath('resource_type')):
            id = resource_type.attrib['id']
            self.resource_types[id] = ResourceType(resource_type)

    def _from_stream(self, stream):
        """Turns markup into a document.

        Just a wrapper around ElementTree which keeps track of namespaces.
        """
        events = "start", "start-ns", "end-ns"
        root = None
        ns_map = []

        for event, elem in ET.iterparse(stream, events):
            if event == "start-ns":
                ns_map.append(elem)
            elif event == "end-ns":
                ns_map.pop()
            elif event == "start":
                if root is None:
                    root = elem
                elem.set(NS_MAP, dict(ns_map))
        return ET.ElementTree(root)

    def _from_string(self, markup):
        """Turns markup into a document."""
        if not isinstance(markup, bytes):
            markup = markup.encode("UTF-8")
        return self._from_stream(io.BytesIO(markup))

    def get_resource_type(self, resource_type_url):
        """Retrieve a resource type by the URL of its description."""
        xml_id = self.lookup_xml_id(resource_type_url)
        resource_type = self.resource_types.get(xml_id)
        if resource_type is None:
            raise KeyError('No such XML ID: "%s"' % resource_type_url)
        return resource_type

    def lookup_xml_id(self, url):
        """A helper method for locating a part of a WADL document.

        :param url: The URL (with anchor) of the desired part of the
        WADL document.
        :return: The XML ID corresponding to the anchor.
        """
        markup_uri = URI(self.markup_url).ensureNoSlash()
        markup_uri.fragment = None

        if url.startswith('http'):
            # It's an absolute URI.
            this_uri = URI(url).ensureNoSlash()
        else:
            # It's a relative URI.
            this_uri = markup_uri.resolve(url)
        possible_xml_id = this_uri.fragment
        this_uri.fragment = None

        if this_uri == markup_uri:
            # The URL pointed elsewhere within the same WADL document.
            # Return its fragment.
            return possible_xml_id

        # XXX leonardr 2008-05-28:
        # This needs to be implemented eventually for Launchpad so
        # that a script using this client can navigate from a WADL
        # representation of a non-root resource to its definition at
        # the server root.
        raise NotImplementedError("Can't look up definition in another "
                                  "url (%s)" % url)

    def get_resource_by_path(self, path):
        """Locate one of the resources described by this document.

        :param path: The path to the resource.
        """
        # XXX leonardr 2008-05-27 This method only finds top-level
        # resources. That's all we need for Launchpad because we don't
        # define nested resources yet.
        matching = [resource for resource in self.resources
                    if resource.attrib['path'] == path]
        if len(matching) < 1:
            return None
        if len(matching) > 1:
            raise WADLError("More than one resource defined with path %s"
                            % path)
        return Resource(
            self, merge(self.resource_base, path, True), matching[0])
