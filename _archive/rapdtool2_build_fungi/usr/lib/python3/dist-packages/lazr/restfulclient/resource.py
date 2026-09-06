# Copyright 2008 Canonical Ltd.

# This file is part of lazr.restfulclient.
#
# lazr.restfulclient is free software: you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# lazr.restfulclient is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with lazr.restfulclient.  If not, see
# <http://www.gnu.org/licenses/>.

"""Common support for web service resources."""

__metaclass__ = type
__all__ = [
    'Collection',
    'CollectionWithKeyBasedLookup',
    'Entry',
    'NamedOperation',
    'Resource',
    'ServiceRoot',
    ]


from email.message import Message
from io import BytesIO
from json import dumps, loads

try:
    # Python 3.
    from urllib.parse import urljoin, urlparse, parse_qs, unquote, urlencode
except ImportError:
    from urlparse import urljoin, urlparse, parse_qs
    from urllib import unquote, urlencode

import sys
if sys.version_info[0] >= 3:
    text_type = str
    binary_type = bytes
else:
    text_type = unicode
    binary_type = str

from lazr.uri import URI
from wadllib.application import Resource as WadlResource

from lazr.restfulclient import __version__
from lazr.restfulclient._browser import Browser, RestfulHttp
from lazr.restfulclient._json import DatetimeJSONEncoder
from lazr.restfulclient.errors import HTTPError

missing = object()


class HeaderDictionary:
    """A dictionary that bridges httplib2's and wadllib's expectations.

    httplib2 expects all header dictionary access to give lowercase
    header names. wadllib expects to access the header exactly as it's
    specified in the WADL file, which means the official HTTP header name.

    This class transforms keys to lowercase before doing a lookup on
    the underlying dictionary. That way wadllib can pass in the
    official header name and httplib2 will get the lowercased name.
    """
    def __init__(self, wrapped_dictionary):
        self.wrapped_dictionary = wrapped_dictionary

    def get(self, key, default=None):
        """Retrieve a value, converting the key to lowercase."""
        return self.wrapped_dictionary.get(key.lower())

    def __getitem__(self, key):
        """Retrieve a value, converting the key to lowercase."""
        value = self.get(key, missing)
        if value is missing:
            raise KeyError(key)
        return value


class RestfulBase:
    """Base class for classes that know about lazr.restful services."""

    JSON_MEDIA_TYPE = 'application/json'

    def _transform_resources_to_links(self, dictionary):
        new_dictionary = {}
        for key, value in dictionary.items():
            if isinstance(value, Resource):
                value = value.self_link
            new_dictionary[self._get_external_param_name(key)] = value
        return new_dictionary

    def _get_external_param_name(self, param_name):
        """Turn a lazr.restful name into something to be sent over HTTP.

        For resources this may involve sticking '_link' or
        '_collection_link' on the end of the parameter name. For
        arguments to named operations, the parameter name is returned
        as is.
        """
        return param_name


class Resource(RestfulBase):
    """Base class for lazr.restful HTTP resources."""

    def __init__(self, root, wadl_resource):
        """Initialize with respect to a wadllib Resource object."""
        if root is None:
            # This _is_ the root.
            root = self
        # These values need to be put directly into __dict__ to avoid
        # calling __setattr__, which would cause an infinite recursion.
        self.__dict__['_root'] = root
        self.__dict__['_wadl_resource'] = wadl_resource

    FIND_COLLECTIONS = object()
    FIND_ENTRIES = object()
    FIND_ATTRIBUTES = object()

    @property
    def lp_collections(self):
        """Name the collections this resource links to."""
        return self._get_parameter_names(self.FIND_COLLECTIONS)

    @property
    def lp_entries(self):
        """Name the entries this resource links to."""
        return self._get_parameter_names(self.FIND_ENTRIES)

    @property
    def lp_attributes(self):
        """Name this resource's scalar attributes."""
        return self._get_parameter_names(self.FIND_ATTRIBUTES)

    @property
    def lp_operations(self):
        """Name all of this resource's custom operations."""
        # This library distinguishes between named operations by the
        # value they give for ws.op, not by their WADL names or IDs.
        names = []
        for method in self._wadl_resource.method_iter:
            name = method.name.lower()
            if name == 'get':
                params = method.request.params(['query', 'plain'])
            elif name == 'post':
                for media_type in ['application/x-www-form-urlencoded',
                                   'multipart/form-data']:
                    definition = method.request.get_representation_definition(
                        media_type)
                    if definition is not None:
                        definition = definition.resolve_definition()
                        break
                params = definition.params(self._wadl_resource)
            for param in params:
                if param.name == 'ws.op':
                    names.append(param.fixed_value)
                    break
        return names

    @property
    def __members__(self):
        """A hook into dir() that returns web service-derived members."""
        return self._get_parameter_names(
            self.FIND_COLLECTIONS, self.FIND_ENTRIES, self.FIND_ATTRIBUTES)

    __methods__ = lp_operations

    def _get_parameter_names(self, *kinds):
        """Retrieve some subset of the resource's parameters."""
        names = []
        for parameter in self._wadl_resource.parameters(
            self.JSON_MEDIA_TYPE):
            name = parameter.name
            link = parameter.link
            if (name != 'self_link' and link is not None
                and link.can_follow):
                # This is a link to a resource with a WADL
                # description.  Since this is a lazr.restful web
                # service, we know it's either an entry or a
                # collection, and that its name ends with '_link' or
                # '_collection_link', respectively.
                #
                # self_link is a special case. 'obj.self' will always
                # work, but it's not useful. 'obj.self_link' is
                # useful, so we advertise the scalar value instead.
                if name.endswith('_collection_link'):
                    # It's a link to a collection.
                    if self.FIND_COLLECTIONS in kinds:
                        names.append(name[:-16])
                else:
                    # It's a link to an entry.
                    if self.FIND_ENTRIES in kinds:
                        names.append(name[:-5])
            else:
                # There are three possibilities. This is not a link at
                # all, it's a link to a resource not described by
                # WADL, or it's the 'self_link'. Either way,
                # lazr.restfulclient should treat this parameter as a
                # scalar attribute.
                if self.FIND_ATTRIBUTES in kinds:
                    names.append(name)
        return names

    def lp_has_parameter(self, param_name):
        """Does this resource have a parameter with the given name?"""
        return self._get_external_param_name(param_name) is not None

    def lp_get_parameter(self, param_name):
        """Get the value of one of the resource's parameters.

        :return: A scalar value if the parameter is not a link. A new
                 Resource object, whose resource is bound to a
                 representation, if the parameter is a link.
        """
        self._ensure_representation()
        for suffix in ['_link', '_collection_link']:
            param = self._wadl_resource.get_parameter(
                param_name + suffix)
            if param is not None:
                try:
                    param.get_value()
                except KeyError:
                    # The parameter could have been present, but isn't.
                    # Try the next parameter.
                    continue
                if param.get_value() is None:
                    # This parameter is a link to another object, but
                    # there's no other object. Return None rather than
                    # chasing down the nonexistent other object.
                    return None
                linked_resource = param.linked_resource
                return self._create_bound_resource(
                    self._root, linked_resource, param_name=param.name)
        param = self._wadl_resource.get_parameter(param_name)
        if param is None:
            raise KeyError("No such parameter: %s" % param_name)
        return param.get_value()

    def lp_get_named_operation(self, operation_name):
        """Get a custom operation with the given name.

        :return: A NamedOperation instance that can be called with
                 appropriate arguments to invoke the operation.
        """
        params = {'ws.op': operation_name}
        method = self._wadl_resource.get_method('get', query_params=params)
        if method is None:
            method = self._wadl_resource.get_method(
                'post', representation_params=params)
        if method is None:
            raise KeyError("No operation with name: %s" % operation_name)
        return NamedOperation(self._root, self, method)

    @classmethod
    def _create_bound_resource(
        cls, root, resource, representation=None,
        representation_media_type='application/json',
        representation_needs_processing=True, representation_definition=None,
        param_name=None):
        """Create a lazr.restful Resource subclass from a wadllib Resource.

        :param resource: The wadllib Resource to wrap.
        :param representation: A previously fetched representation of
            this resource, to be reused. If not provided, this method
            will act just like the Resource constructor.
        :param representation_media_type: The media type of any previously
            fetched representation.
        :param representation_needs_processing: Set to False if the
            'representation' parameter should be used as
            is.
        :param representation_definition: A wadllib
            RepresentationDefinition object describing the structure
            of this representation. Used in cases when the representation
            isn't the result of sending a standard GET to the resource.
        :param param_name: The name of the link that was followed to get
            to this resource.
        :return: An instance of the appropriate lazr.restful Resource
            subclass.
        """
        # We happen to know that all lazr.restful resource types are
        # defined in a single document. Turn the resource's type_url
        # into an anchor into that document: this is its resource
        # type. Then look up a client-side class that corresponds to
        # the resource type.
        type_url = resource.type_url
        resource_type = urlparse(type_url)[-1]
        default = Entry

        if (type_url.endswith('-page')
            or (param_name is not None
                and param_name.endswith('_collection_link'))):
            default = Collection
        r_class = root.RESOURCE_TYPE_CLASSES.get(resource_type, default)
        if representation is not None:
            # We've been given a representation. Bind the resource
            # immediately.
            resource = resource.bind(
                representation, representation_media_type,
                representation_needs_processing,
                representation_definition=representation_definition)
        else:
            # We'll fetch a representation and bind the resource when
            # necessary.
            pass
        return r_class(root, resource)

    def lp_refresh(self, new_url=None, etag=None):
        """Update this resource's representation."""
        if new_url is not None:
            self._wadl_resource._url = new_url
        headers = {}
        if etag is not None:
            headers['If-None-Match'] = etag
        representation = self._root._browser.get(
            self._wadl_resource, headers=headers)
        if representation == self._root._browser.NOT_MODIFIED:
            # The entry wasn't modified. No need to do anything.
            return
        # __setattr__ assumes we're setting an attribute of the resource,
        # so we manipulate __dict__ directly.
        self.__dict__['_wadl_resource'] = self._wadl_resource.bind(
            representation, self.JSON_MEDIA_TYPE)

    def __getattr__(self, attr):
        """Try to retrive a named operation or parameter of the given name."""
        try:
            return self.lp_get_named_operation(attr)
        except KeyError:
            pass
        try:
            return self.lp_get_parameter(attr)
        except KeyError:
            raise AttributeError("%s object has no attribute '%s'"
                % (self, attr))

    def lp_values_for(self, param_name):
        """Find the set of possible values for a parameter."""
        parameter = self._wadl_resource.get_parameter(
            param_name, self.JSON_MEDIA_TYPE)
        options = parameter.options
        if len(options) > 0:
            return [option.value for option in options]
        return None

    def _get_external_param_name(self, param_name):
        """What's this parameter's name in the underlying representation?"""
        for suffix in ['_link', '_collection_link', '']:
            name = param_name + suffix
            if self._wadl_resource.get_parameter(name):
                return name
        return None

    def _ensure_representation(self):
        """Make sure this resource has a representation fetched."""
        if self._wadl_resource.representation is None:
            # Get a representation of the linked resource.
            representation = self._root._browser.get(self._wadl_resource)
            if isinstance(representation, binary_type):
                representation = representation.decode('utf-8')
            representation = loads(representation)

            # In rare cases, the resource type served by the
            # server conflicts with the type the client thought
            # this resource had. When this happens, the server
            # value takes precedence.
            #
            # XXX This should probably be moved into a hook method
            # defined by Entry, since it's not relevant to other
            # resource types.
            if isinstance(representation, dict):
                type_link = representation['resource_type_link']
                if (type_link is not None
                    and type_link != self._wadl_resource.type_url):
                    resource_type = self._root._wadl.get_resource_type(
                        type_link)
                    self._wadl_resource.tag = resource_type.tag
            self.__dict__['_wadl_resource'] = self._wadl_resource.bind(
                representation, self.JSON_MEDIA_TYPE,
                representation_needs_processing=False)

    def __ne__(self, other):
        """Inequality operator."""
        return not self == other


class ScalarValue(Resource):
    """A resource representing a single scalar value."""

    @property
    def value(self):
        """Return the scalar value."""
        self._ensure_representation()
        return self._wadl_resource.representation


class HostedFile(Resource):
    """A resource representing a file managed by a lazr.restful service."""

    def open(self, mode='r', content_type=None, filename=None):
        """Open the file on the server for read or write access."""
        if mode in ('r', 'w'):
            return HostedFileBuffer(self, mode, content_type, filename)
        else:
            raise ValueError("Invalid mode. Supported modes are: r, w")

    def delete(self):
        """Delete the file from the server."""
        self._root._browser.delete(self._wadl_resource.url)

    def _get_parameter_names(self, *kinds):
        """HostedFile objects define no web service parameters."""
        return []

    def __eq__(self, other):
        """Equality comparison.

        Two hosted files are the same if they have the same URL.

        There is no need to check the contents because the only way to
        retrieve or modify the hosted file contents is to open a
        filehandle, which goes direct to the server.
        """
        return (other is not None and
                self._wadl_resource.url == other._wadl_resource.url)


class ServiceRoot(Resource):
    """Entry point to the service. Subclass this for a service-specific client.

    :ivar credentials: The credentials instance used to access Launchpad.
    """

    # Custom subclasses of Resource to use when
    # instantiating resources of a certain WADL type.
    RESOURCE_TYPE_CLASSES = {'HostedFile': HostedFile,
                             'ScalarValue': ScalarValue}

    def __init__(self, authorizer, service_root, cache=None,
                 timeout=None, proxy_info=None, version=None,
                 base_client_name='', max_retries=Browser.MAX_RETRIES):
        """Root access to a lazr.restful API.

        :param credentials: The credentials used to access the service.
        :param service_root: The URL to the root of the web service.
        :type service_root: string
        """
        if version is not None:
            if service_root[-1] != '/':
                service_root += '/'
            service_root += str(version)
            if service_root[-1] != '/':
                service_root += '/'
        self._root_uri = URI(service_root)

        # Set up data necessary to calculate the User-Agent header.
        self._base_client_name = base_client_name

        # Get the WADL definition.
        self.credentials = authorizer
        self._browser = Browser(
            self, authorizer, cache, timeout, proxy_info, self._user_agent,
            max_retries)
        self._wadl = self._browser.get_wadl_application(self._root_uri)

        # Get the root resource.
        root_resource = self._wadl.get_resource_by_path('')
        bound_root = root_resource.bind(
            self._browser.get(root_resource), 'application/json')
        super(ServiceRoot, self).__init__(None, bound_root)

    @property
    def _user_agent(self):
        """The value for the User-Agent header.

        This will be something like:
        launchpadlib 1.6.1, lazr.restfulclient 1.0.0; application=apport

        That is, a string describing lazr.restfulclient and an
        optional custom client built on top, and parameters containing
        any authorization-specific information that identifies the
        user agent (such as the application name).
        """
        base_portion = "lazr.restfulclient %s" % __version__
        if self._base_client_name != '':
            base_portion = self._base_client_name + ' (' + base_portion + ')'

        message = Message()
        message['User-Agent'] = base_portion
        if self.credentials is not None:
            user_agent_params = self.credentials.user_agent_params
            for key in sorted(user_agent_params):
                value = user_agent_params[key]
                message.set_param(key, value, 'User-Agent')
        return message['User-Agent']

    def httpFactory(self, authorizer, cache, timeout, proxy_info):
        return RestfulHttp(authorizer, cache, timeout, proxy_info)

    def load(self, url):
        """Load a resource given its URL."""
        parsed = urlparse(url)
        if parsed.scheme == '':
            # This is a relative URL. Make it absolute by joining
            # it with the service root resource.
            if url[:1] == '/':
                url = url[1:]
            url = str(self._root_uri.append(url))
        document = self._browser.get(url)
        if isinstance(document, binary_type):
            document = document.decode('utf-8')
        try:
            representation = loads(document)
        except ValueError:
            raise ValueError("%s doesn't serve a JSON document." % url)
        type_link = representation.get("resource_type_link")
        if type_link is None:
            raise ValueError("Couldn't determine the resource type of %s."
                             % url)
        resource_type = self._root._wadl.get_resource_type(type_link)
        wadl_resource = WadlResource(self._root._wadl, url, resource_type.tag)
        return self._create_bound_resource(
            self._root, wadl_resource, representation, 'application/json',
            representation_needs_processing=False)


class NamedOperation(RestfulBase):
    """A class for a named operation to be invoked with GET or POST."""

    def __init__(self, root, resource, wadl_method):
        """Initialize with respect to a WADL Method object"""
        self.root = root
        self.resource = resource
        self.wadl_method = wadl_method

    def __call__(self, *args, **kwargs):
        """Invoke the method and process the result."""
        if len(args) > 0:
            raise TypeError('Method must be called with keyword args.')
        http_method = self.wadl_method.name
        args = self._transform_resources_to_links(kwargs)
        request = self.wadl_method.request

        if http_method in ('get', 'head', 'delete'):
            params = request.query_params
        else:
            definition = request.get_representation_definition(
                'multipart/form-data')
            if definition is None:
                definition = request.get_representation_definition(
                    'application/x-www-form-urlencoded')
            assert definition is not None, (
                "A POST named operation must define a multipart or "
                "form-urlencoded request representation."
                )
            params = definition.params(self.resource._wadl_resource)
        send_as_is_params = set([param.name for param in params
                                 if param.type == 'binary'
                                 or len(param.options) > 0])
        for key, value in args.items():
            # Certain parameter values should not be JSON-encoded:
            # binary parameters (because they can't be JSON-encoded)
            # and option values (because JSON-encoding them will screw
            # up wadllib's parameter validation). The option value thing
            # is a little hacky, but it's the best solution for now.
            if key not in send_as_is_params:
                args[key] = dumps(value, cls=DatetimeJSONEncoder)
        if http_method in ('get', 'head', 'delete'):
            url = self.wadl_method.build_request_url(**args)
            in_representation = ''
            extra_headers = {}
        else:
            url = self.wadl_method.build_request_url()
            (media_type,
             in_representation) = self.wadl_method.build_representation(
                **args)
            extra_headers = {'Content-type': media_type}
        # Pass uppercase method names to httplib2, as that is what it works
        # with. If you pass a lowercase method name to httplib then it doesn't
        # consider it to be a GET, PUT, etc., and so will do things like not
        # cache. Wadl Methods return their method lower cased, which is how it
        # is compared in this method, but httplib2 expects the opposite, hence
        # the .upper() call.
        response, content = self.root._browser._request(
            url, in_representation, http_method.upper(),
            extra_headers=extra_headers)

        if response.status == 201:
            return self._handle_201_response(url, response, content)
        else:
            if http_method == 'post':
                # The method call probably modified this resource in
                # an unknown way. If it moved to a new location, reload it or
                # else just refresh its representation.
                if response.status == 301:
                    url = response['location']
                    response, content = self.root._browser._request(url)
                else:
                    self.resource.lp_refresh()
            return self._handle_200_response(url, response, content)

    def _handle_201_response(self, url, response, content):
        """Handle the creation of a new resource by fetching it."""
        wadl_response = self.wadl_method.response.bind(
            HeaderDictionary(response))
        wadl_parameter = wadl_response.get_parameter('Location')
        wadl_resource = wadl_parameter.linked_resource
        # Fetch a representation of the new resource.
        response, content = self.root._browser._request(
            wadl_resource.url)
        # Return an instance of the appropriate lazr.restful
        # Resource subclass.
        return Resource._create_bound_resource(
            self.root, wadl_resource, content, response['content-type'])

    def _handle_200_response(self, url, response, content):
        """Process the return value of an operation."""
        content_type = response['content-type']
        # Process the returned content, assuming we know how.
        response_definition = self.wadl_method.response
        representation_definition = (
            response_definition.get_representation_definition(
                content_type))

        if representation_definition is None:
            # The operation returned a document with nothing
            # special about it.
            if content_type == self.JSON_MEDIA_TYPE:
                if isinstance(content, binary_type):
                    content = content.decode('utf-8')
                return loads(content)
            # We don't know how to process the content.
            return content

        # The operation returned a representation of some
        # resource. Instantiate a Resource object for it.
        if isinstance(content, binary_type):
            content = content.decode('utf-8')
        
        document = loads(content)
        if document is None:
            # The operation returned a null value.
            return document
        if "self_link" in document and "resource_type_link" in document:
            # The operation returned an entry. Use the self_link and
            # resource_type_link of the entry representation to build
            # a Resource object of the appropriate type. That way this
            # object will support all of the right named operations.
            url = document["self_link"]
            resource_type = self.root._wadl.get_resource_type(
                document["resource_type_link"])
            wadl_resource = WadlResource(self.root._wadl, url,
                                         resource_type.tag)
        else:
            # The operation returned a collection. It's probably an ad
            # hoc collection that doesn't correspond to any resource
            # type.  Instantiate it as a resource backed by the
            # representation type defined in the return value, instead
            # of a resource type tag.
            representation_definition = (
                representation_definition.resolve_definition())
            wadl_resource = WadlResource(
                self.root._wadl, url, representation_definition.tag)

        return Resource._create_bound_resource(
            self.root, wadl_resource, document, content_type,
            representation_needs_processing=False,
            representation_definition=representation_definition)

    def _get_external_param_name(self, param_name):
        """Named operation parameter names are sent as is."""
        return param_name


class Entry(Resource):
    """A class for an entry-type resource that can be updated with PATCH."""

    def __init__(self, root, wadl_resource):
        super(Entry, self).__init__(root, wadl_resource)
        # Initialize this here in a semi-magical way so as to stop a
        # particular infinite loop that would follow.  Setting
        # self._dirty_attributes would call __setattr__(), which would
        # turn around immediately and get self._dirty_attributes.  If
        # this latter was not in the instance dictionary, that would
        # end up calling __getattr__(), which would again reference
        # self._dirty_attributes.  This is where the infloop would
        # occur.  Poking this directly into self.__dict__ means that
        # the check for self._dirty_attributes won't call __getattr__(),
        # breaking the cycle.
        self.__dict__['_dirty_attributes'] = {}
        super(Entry, self).__init__(root, wadl_resource)

    def __repr__(self):
        """Return the WADL resource type and the URL to the resource."""
        return '<%s at %s>' % (
            URI(self.resource_type_link).fragment, self.self_link)

    def lp_delete(self):
        """Delete the resource."""
        return self._root._browser.delete(URI(self.self_link))

    def __str__(self):
        """Return the URL to the resource."""
        return self.self_link

    def __getattr__(self, name):
        """Try to retrive a parameter of the given name."""
        if name != '_dirty_attributes':
            if name in self._dirty_attributes:
                return self._dirty_attributes[name]
        return super(Entry, self).__getattr__(name)

    def __setattr__(self, name, value):
        """Set the parameter of the given name."""
        if not self.lp_has_parameter(name):
            raise AttributeError("'%s' object has no attribute '%s'" %
                                 (self.__class__.__name__, name))
        self._dirty_attributes[name] = value

    def __eq__(self, other):
        """Equality operator.

        Two entries are the same if their self_link and http_etag
        attributes are the same, and if their dirty attribute dicts
        contain the same values.
        """
        return (
            other is not None and
            self.self_link == other.self_link and
            self.http_etag == other.http_etag and
            self._dirty_attributes == other._dirty_attributes)

    def lp_refresh(self, new_url=None):
        """Update this resource's representation."""
        etag = getattr(self, 'http_etag', None)
        super(Entry, self).lp_refresh(new_url, etag)
        self._dirty_attributes.clear()

    def lp_save(self):
        """Save changes to the entry."""
        representation = self._transform_resources_to_links(
            self._dirty_attributes)

        # If the entry contains an ETag, set the If-Match header
        # to that value.
        headers = {}
        etag = getattr(self, 'http_etag', None)
        if etag is not None:
            headers['If-Match'] = etag

        # PATCH the new representation to the 'self' link.  It's possible that
        # this will cause the object to be permanently moved.  Catch that
        # exception and refresh our representation.
        response, content = self._root._browser.patch(
            URI(self.self_link), representation, headers)
        if response.status == 301:
            self.lp_refresh(response['location'])
        self._dirty_attributes.clear()

        content_type = response['content-type']
        if response.status == 209 and content_type == self.JSON_MEDIA_TYPE:
            # The server sent back a new representation of the object.
            # Use it in preference to the existing representation.
            if isinstance(content, binary_type):
                content = content.decode('utf-8')
            new_representation = loads(content)
            self._wadl_resource.representation = new_representation
            self._wadl_resource.media_type = content_type


class Collection(Resource):
    """A collection-type resource that supports pagination."""

    def __init__(self, root, wadl_resource):
        """Create a collection object."""
        super(Collection, self).__init__(root, wadl_resource)

    def __len__(self):
        """The number of items in the collection.

        :return: length of the collection
        :rtype: int
        """
        total_size = self.total_size
        if isinstance(total_size, int):
            # The size was a number present in the collection
            # representation.
            return total_size
        elif isinstance(total_size, ScalarValue):
            # The size was linked to from the collection representation,
            # not directly present.
            return total_size.value
        else:
            raise TypeError('collection size is not available')

    def __iter__(self):
        """Iterate over the items in the collection.

        :return: iterator
        :rtype: sequence of `Entry`
        """
        self._ensure_representation()
        current_page = self._wadl_resource.representation
        while True:
            for resource in self._convert_dicts_to_entries(
                current_page.get('entries', {})):
                yield resource
            next_link = current_page.get('next_collection_link')
            if next_link is None:
                break
            next_get = self._root._browser.get(URI(next_link))
            if isinstance(next_get, binary_type):
                next_get = next_get.decode('utf-8')
            current_page = loads(next_get)

    def __getitem__(self, key):
        """Look up a slice, or a subordinate resource by index.

        To discourage situations where a lazr.restful client fetches
        all of an enormous list, all collection slices must have a
        definitive end point. For performance reasons, all collection
        slices must be indexed from the start of the list rather than
        the end.
        """
        if isinstance(key, slice):
            return self._get_slice(key)
        else:
            # Look up a single item by its position in the list.
            found_slice = self._get_slice(slice(key, key + 1))
            if len(found_slice) != 1:
                raise IndexError("list index out of range")
            return found_slice[0]

    def _get_slice(self, slice):
        """Retrieve a slice of a collection."""
        start = slice.start or 0
        stop = slice.stop

        if start < 0:
            raise ValueError("Collection slices must have a nonnegative "
                             "start point.")
        if stop < 0:
            raise ValueError("Collection slices must have a definite, "
                             "nonnegative end point.")

        existing_representation = self._wadl_resource.representation
        if (existing_representation is not None
            and start < len(existing_representation['entries'])):
            # An optimization: the first page of entries has already
            # been loaded. This can happen if this collection is the
            # return value of a named operation, or if the client did
            # something like check the length of the collection.
            #
            # Either way, we've already made an HTTP request and
            # gotten some entries back. The client has requested a
            # slice that includes some of the entries we already have.
            # In the best case, we can fulfil the slice immediately,
            # without making another HTTP request.
            #
            # Even if we can't fulfil the entire slice, we can get one
            # or more objects from the first page and then have fewer
            # objects to retrieve from the server later. This saves us
            # time and bandwidth, and it might let us save a whole
            # HTTP request.
            entry_page = existing_representation['entries']

            first_page_size = len(entry_page)
            entry_dicts = entry_page[start:stop]
            page_url = existing_representation.get('next_collection_link')
        else:
            # No part of this collection has been loaded yet, or the
            # slice starts beyond the part that has been loaded. We'll
            # use our secret knowledge of lazr.restful to set a value for
            # the ws.start variable. That way we start reading entries
            # from the first one we want.
            first_page_size = None
            entry_dicts = []
            page_url = self._with_url_query_variable_set(
                self._wadl_resource.url, 'ws.start', start)

        desired_size = stop - start
        more_needed = desired_size - len(entry_dicts)

        # Iterate over pages until we have the correct number of entries.
        while more_needed > 0 and page_url is not None:
            page_get = self._root._browser.get(page_url)
            if isinstance(page_get, binary_type):
                page_get = page_get.decode('utf-8')
            representation = loads(page_get)
            current_page_entries = representation['entries']
            entry_dicts += current_page_entries[:more_needed]
            more_needed = desired_size - len(entry_dicts)

            page_url = representation.get('next_collection_link')
            if page_url is None:
                # We've gotten the entire collection; there are no
                # more entries.
                break
            if first_page_size is None:
                first_page_size = len(current_page_entries)
            if more_needed > 0 and more_needed < first_page_size:
                # An optimization: it's likely that we need less than
                # a full page of entries, because the number we need
                # is less than the size of the first page we got.
                # Instead of requesting a full-sized page, we'll
                # request only the number of entries we think we'll
                # need. If we're wrong, there's no problem; we'll just
                # keep looping.
                page_url = self._with_url_query_variable_set(
                    page_url, 'ws.size', more_needed)

        if slice.step is not None:
            entry_dicts = entry_dicts[::slice.step]

        # Convert entry_dicts into a list of Entry objects.
        return [resource for resource
                in self._convert_dicts_to_entries(entry_dicts)]

    def _convert_dicts_to_entries(self, entries):
        """Convert dictionaries describing entries to Entry objects.

        The dictionaries come from the 'entries' field of the JSON
        dictionary you get when you GET a page of a collection. Each
        dictionary is the same as you'd get if you sent a GET request
        to the corresponding entry resource. So each of these
        dictionaries can be treated as a preprocessed representation
        of an entry resource, and turned into an Entry instance.

        :yield: A sequence of Entry instances.
        """
        for entry_dict in entries:
            resource_url = entry_dict['self_link']
            resource_type_link = entry_dict['resource_type_link']
            wadl_application = self._wadl_resource.application
            resource_type = wadl_application.get_resource_type(
                resource_type_link)
            resource = WadlResource(
                self._wadl_resource.application, resource_url,
                resource_type.tag)
            yield Resource._create_bound_resource(
                self._root, resource, entry_dict, self.JSON_MEDIA_TYPE,
                False)

    def _with_url_query_variable_set(self, url, variable, new_value):
        """A helper method to set a query variable in a URL."""
        uri = URI(url)
        if uri.query is None:
            params = {}
        else:
            params = parse_qs(uri.query)
        params[variable] = str(new_value)
        uri.query = urlencode(params, True)
        return str(uri)


class CollectionWithKeyBasedLookup(Collection):
    """A collection-type resource that supports key-based lookup.

    This collection can be sliced, but any single index passed into
    __getitem__ will be treated as a custom lookup key.
    """

    def __getitem__(self, key):
        """Look up a slice, or a subordinate resource by unique ID."""
        if isinstance(key, slice):
            return super(CollectionWithKeyBasedLookup, self).__getitem__(key)

        try:
            url = self._get_url_from_id(key)
        except NotImplementedError:
            raise TypeError("unsubscriptable object")
        if url is None:
            raise KeyError(key)

        shim_resource = self(key)
        try:
            shim_resource._ensure_representation()
        except HTTPError as e:
            if e.response.status == 404:
                raise KeyError(key)
            else:
                raise
        return shim_resource

    def __call__(self, key):
        """Retrieve a member from this collection without looking it up."""

        try:
            url = self._get_url_from_id(key)
        except NotImplementedError:
            raise TypeError("unsubscriptable object")
        if url is None:
            raise ValueError(key)

        if self.collection_of is not None:
            # We know what kind of resource is at the other end of the
            # URL. There's no need to actually fetch that URL until
            # the user demands it. If the user is invoking a named
            # operation on this object rather than fetching its data,
            # this will save us one round trip.
            representation = None
            resource_type_link = urljoin(
                self._root._wadl.markup_url, '#' + self.collection_of)
        else:
            # We don't know what kind of resource this is. Either the
            # subclass wasn't programmed with this knowledge, or
            # there's simply no way to tell without going to the
            # server, because the collection contains more than one
            # kind of resource. The only way to know for sure is to
            # retrieve a representation of the resource and see how
            # the resource describes itself.
            try:
                url_get = self._root._browser.get(url)
                if isinstance(url_get, binary_type):
                    url_get = url_get.decode('utf-8')                
                representation = loads(url_get)
            except HTTPError as error:
                # There's no resource corresponding to the given ID.
                if error.response.status == 404:
                    raise KeyError(key)
                raise
            # We know that every lazr.restful resource has a
            # 'resource_type_link' in its representation.
            resource_type_link = representation['resource_type_link']

        resource = WadlResource(self._root._wadl, url, resource_type_link)
        return self._create_bound_resource(
            self._root, resource, representation=representation,
            representation_needs_processing=False)

    # If provided, this should be a string designating the ID of a
    # resource_type from a specific service's WADL file.
    collection_of = None

    def _get_url_from_id(self, key):
        """Transform the unique ID of an object into its URL."""
        raise NotImplementedError()


class HostedFileBuffer(BytesIO):
    """The contents of a file hosted by a lazr.restful service."""
    def __init__(self, hosted_file, mode, content_type=None, filename=None):
        self.url = hosted_file._wadl_resource.url
        if mode == 'r':
            if content_type is not None:
                raise ValueError("Files opened for read access can't "
                                 "specify content_type.")
            if filename is not None:
                raise ValueError("Files opened for read access can't "
                                 "specify filename.")
            response, value = hosted_file._root._browser.get(
                self.url, return_response=True)
            content_type = response['content-type']
            last_modified = response.get('last-modified')

            # The Content-Location header contains the URL of the file
            # hosted by the web service. We happen to know that the
            # final component of the URL is the name of the uploaded
            # file.
            content_location = response['content-location']
            path = urlparse(content_location)[2]
            filename = unquote(path.split("/")[-1])
        elif mode == 'w':
            value = ''
            if content_type is None:
                raise ValueError("Files opened for write access must "
                                 "specify content_type.")
            if filename is None:
                raise ValueError("Files opened for write access must "
                                 "specify filename.")
            last_modified = None
        else:
            raise ValueError("Invalid mode. Supported modes are: r, w")

        self.hosted_file = hosted_file
        self.mode = mode
        self.content_type = content_type
        self.filename = filename
        self.last_modified = last_modified
        BytesIO.__init__(self, value)

    def close(self):
        if self.mode == 'w':
            disposition = 'attachment; filename="%s"' % self.filename
            self.hosted_file._root._browser.put(
                self.url, self.getvalue(),
                self.content_type, {'Content-Disposition': disposition})
        BytesIO.close(self)

    def write(self, b):
        BytesIO.write(self, b)
