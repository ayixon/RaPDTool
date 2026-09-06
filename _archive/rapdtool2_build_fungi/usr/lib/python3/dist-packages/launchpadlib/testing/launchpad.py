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

"""Testing API allows fake data to be used in unit tests.

Testing launchpadlib code is tricky, because it depends so heavily on a
remote, unique webservice: Launchpad.  This module helps you write tests for
your launchpadlib application that can be run locally and quickly.

Say you were writing some code that needed to call out to Launchpad and get
the branches owned by the logged-in person, and then do something to them. For
example, something like this::

  def collect_unique_names(lp):
      names = []
      for branch in lp.me.getBranches():
          names.append(branch.unique_name)
      return names

To test it, you would first prepare a L{FakeLaunchpad} object, and give it
some sample data of your own devising::

  lp = FakeLaunchpad()
  my_branches = [dict(unique_name='~foo/bar/baz')]
  lp.me = dict(getBranches: lambda status: my_branches)

Then, in the test, call your own code and assert that it behaves correctly
given the data.

  names = collect_unique_names(lp)
  self.assertEqual(['~foo/bar/baz'], names)

And that's it.

The L{FakeLaunchpad} code uses a WADL file to type-check any objects created
or returned.  This means you can be sure that you won't accidentally store
sample data with misspelled attribute names.

The WADL file that we use by default is for version 1.0 of the Launchpad API.
If you want to work against a more recent version of the API, download the
WADL yourself (see <https://help.launchpad.net/API/Hacking>) and construct
your C{FakeLaunchpad} like this::

  from wadllib.application import Application
  lp = FakeLaunchpad(
      Application('https://api.launchpad.net/devel/',
                  '/path/to/wadl.xml'))

Where 'https://api.launchpad.net/devel/' is the URL for the WADL file, found
also in the WADL file itelf.
"""

from datetime import datetime

try:
    from collections.abc import Callable
except ImportError:
    from collections import Callable
import sys

if sys.version_info[0] >= 3:
    basestring = str

JSON_MEDIA_TYPE = "application/json"


class IntegrityError(Exception):
    """Raised when bad sample data is used with a L{FakeLaunchpad} instance."""


class FakeLaunchpad(object):
    """A fake Launchpad API class for unit tests that depend on L{Launchpad}.

    @param application: A C{wadllib.application.Application} instance for a
        Launchpad WADL definition file.
    """

    def __init__(
        self,
        credentials=None,
        service_root=None,
        cache=None,
        timeout=None,
        proxy_info=None,
        application=None,
    ):
        if application is None:
            from launchpadlib.testing.resources import get_application

            application = get_application()
        root_resource = FakeRoot(application)
        self.__dict__.update(
            {
                "credentials": credentials,
                "_application": application,
                "_service_root": root_resource,
            }
        )

    def __setattr__(self, name, values):
        """Set sample data.

        @param name: The name of the attribute.
        @param values: A dict representing an object matching a resource
            defined in Launchpad's WADL definition.
        """
        service_root = self._service_root
        setattr(service_root, name, values)

    def __getattr__(self, name):
        """Get sample data.

        @param name: The name of the attribute.
        """
        return getattr(self._service_root, name)

    @classmethod
    def login(
        cls,
        consumer_name,
        token_string,
        access_secret,
        service_root=None,
        cache=None,
        timeout=None,
        proxy_info=None,
    ):
        """Convenience for setting up access credentials."""
        from launchpadlib.testing.resources import get_application

        return cls(object(), application=get_application())

    @classmethod
    def get_token_and_login(
        cls,
        consumer_name,
        service_root=None,
        cache=None,
        timeout=None,
        proxy_info=None,
    ):
        """Get credentials from Launchpad and log into the service root."""
        from launchpadlib.testing.resources import get_application

        return cls(object(), application=get_application())

    @classmethod
    def login_with(
        cls,
        consumer_name,
        service_root=None,
        launchpadlib_dir=None,
        timeout=None,
        proxy_info=None,
    ):
        """Log in to Launchpad with possibly cached credentials."""
        from launchpadlib.testing.resources import get_application

        return cls(object(), application=get_application())


def find_by_attribute(element, name, value):
    """Find children of element where attribute name is equal to value."""
    return [child for child in element if child.get(name) == value]


def strip_suffix(string, suffix):
    if string.endswith(suffix):
        return string[: -len(suffix)]
    return string


class FakeResource(object):
    """
    Represents valid sample data on L{FakeLaunchpad} instances.

    @ivar _children: A dictionary of child resources, each of type
        C{FakeResource}.
    @ivar _values: A dictionary of values associated with this resource. e.g.
        "display_name" or "date_created".  The values of this dictionary will
        never be C{FakeResource}s.

    Note that if C{_children} has a key, then C{_values} will not, and vice
    versa. That is, they are distinct dicts.
    """

    special_methods = ["lp_save"]

    def __init__(self, application, resource_type, values=None):
        """Construct a FakeResource.

        @param application: A C{waddlib.application.Application} instance.
        @param resource_type: A C{wadllib.application.ResourceType} instance
            for this resource.
        @param values: Optionally, a dict representing attribute key/value
            pairs for this resource.
        """
        if values is None:
            values = {}
        self.__dict__.update(
            {
                "_application": application,
                "_resource_type": resource_type,
                "_children": {},
                "_values": values,
            }
        )

    def __setattr__(self, name, value):
        """Set sample data.

        C{value} can be a dict representing an object matching a resource
        defined in the WADL definition.  Alternatively, C{value} could be a
        resource itself.  Either way, it is checked for type correctness
        against the WADL definition.
        """
        if isinstance(value, dict):
            self._children[name] = self._create_child_resource(name, value)
        else:
            values = {}
            values.update(self._values)
            values[name] = value
            # Confirm that the new 'values' dict is a partial type match for
            # this resource.
            self._check_resource_type(self._resource_type, values)
            self.__dict__["_values"] = values

    def __getattr__(self, name, _marker=object()):
        """Get sample data.

        @param name: The name of the attribute.
        """
        result = self._children.get(name, _marker)
        if result is _marker:
            result = self._values.get(name, _marker)
            if isinstance(result, Callable):
                return self._wrap_method(name, result)
        if name in self.special_methods:
            return lambda: True
        if result is _marker:
            raise AttributeError("%r has no attribute '%s'" % (self, name))
        return result

    def _wrap_method(self, name, method):
        """Wrapper around methods validates results when it's run.

        @param name: The name of the method.
        @param method: The callable to run when the method is called.
        """

        def wrapper(*args, **kwargs):
            return self._run_method(name, method, *args, **kwargs)

        return wrapper

    def _create_child_resource(self, name, values):
        """
        Ensure that C{values} is a valid object for the C{name} attribute and
        return a resource object to represent it as API data.

        @param name: The name of the attribute to check the C{values} object
            against.
        @param values: A dict with key/value pairs representing attributes and
            methods of an object matching the C{name} resource's definition.
        @return: A L{FakeEntry} for an ordinary resource or a
            L{FakeCollection} for a resource that represents a collection.
        @raises IntegrityError: Raised if C{name} isn't a valid attribute for
            this resource or if C{values} isn't a valid object for the C{name}
            attribute.
        """
        root_resource = self._application.get_resource_by_path("")
        is_link = False
        param = root_resource.get_parameter(
            name + "_collection_link", JSON_MEDIA_TYPE
        )
        if param is None:
            is_link = True
            param = root_resource.get_parameter(
                name + "_link", JSON_MEDIA_TYPE
            )
        if param is None:
            raise IntegrityError("%s isn't a valid property." % (name,))
        resource_type = self._get_resource_type(param)
        if is_link:
            self._check_resource_type(resource_type, values)
            return FakeEntry(self._application, resource_type, values)
        else:
            name, child_resource_type = self._check_collection_type(
                resource_type, values
            )
            return FakeCollection(
                self._application,
                resource_type,
                values,
                name,
                child_resource_type,
            )

    def _get_resource_type(self, param):
        """Get the resource type for C{param}.

        @param param: An object representing a C{_link} or C{_collection_link}
            parameter.
        @return: The resource type for the parameter, or None if one isn't
            available.
        """
        [link] = list(param.tag)
        name = link.get("resource_type")
        return self._application.get_resource_type(name)

    def _check_resource_type(self, resource_type, partial_object):
        """
        Ensure that attributes and methods defined for C{partial_object} match
        attributes and methods defined for C{resource_type}.

        @param resource_type: The resource type to check the attributes and
            methods against.
        @param partial_object: A dict with key/value pairs representing
            attributes and methods.
        """
        for name, value in partial_object.items():
            if isinstance(value, Callable):
                # Performs an integrity check.
                self._get_method(resource_type, name)
            else:
                self._check_attribute(resource_type, name, value)

    def _check_collection_type(self, resource_type, partial_object):
        """
        Ensure that attributes and methods defined for C{partial_object} match
        attributes and methods defined for C{resource_type}.  Collection
        entries are treated specially.

        @param resource_type: The resource type to check the attributes and
            methods against.
        @param partial_object: A dict with key/value pairs representing
            attributes and methods.
        @return: (name, resource_type), where 'name' is the name of the child
            resource type and 'resource_type' is the corresponding resource
            type.
        """
        name = None
        child_resource_type = None
        for name, value in partial_object.items():
            if name == "entries":
                name, child_resource_type = self._check_entries(
                    resource_type, value
                )
            elif isinstance(value, Callable):
                # Performs an integrity check.
                self._get_method(resource_type, name)
            else:
                self._check_attribute(resource_type, name, value)
        return name, child_resource_type

    def _find_representation_id(self, resource_type, name):
        """Find the WADL XML id for the representation of C{resource_type}.

        Looks in the WADL for the first representiation associated with the
        method for a resource type.

        :return: An XML id (a string).
        """
        get_method = self._get_method(resource_type, name)
        for response in get_method:
            for representation in response:
                representation_url = representation.get("href")
                if representation_url is not None:
                    return self._application.lookup_xml_id(representation_url)

    def _check_attribute(self, resource_type, name, value):
        """
        Ensure that C{value} is a valid C{name} attribute on C{resource_type}.

        Does this by finding the representation for the default, canonical GET
        method (as opposed to the many "named" GET methods that exist.)

        @param resource_type: The resource type to check the attribute
            against.
        @param name: The name of the attribute.
        @param value: The value to check.
        """
        xml_id = self._find_representation_id(resource_type, "get")
        self._check_attribute_representation(xml_id, name, value)

    def _check_attribute_representation(self, xml_id, name, value):
        """
        Ensure that C{value} is a valid value for C{name} with the
        representation definition matching C{xml_id}.

        @param xml_id: The XML ID for the representation to check the
            attribute against.
        @param name: The name of the attribute.
        @param value: The value to check.
        @raises IntegrityError: Raised if C{name} is not a valid attribute
            name or if C{value}'s type is not valid for the attribute.
        """
        representation = self._application.representation_definitions[xml_id]
        parameters = {child.get("name"): child for child in representation.tag}
        if name not in parameters:
            raise IntegrityError("%s not found" % name)
        parameter = parameters[name]
        data_type = parameter.get("type")
        if data_type is None:
            if not isinstance(value, basestring):
                raise IntegrityError(
                    "%s is not a str or unicode for %s" % (value, name)
                )
        elif data_type == "xsd:dateTime":
            if not isinstance(value, datetime):
                raise IntegrityError(
                    "%s is not a datetime for %s" % (value, name)
                )

    def _get_method(self, resource_type, name):
        """Get the C{name} method on C{resource_type}.

        @param resource_type: The method's resource type.
        @param name: The name of the method.
        @raises IntegrityError: Raised if a method called C{name} is not
            available on C{resource_type}.
        @return: The XML element for the method from the WADL.
        """
        if name in self.special_methods:
            return
        resource_name = resource_type.tag.get("id")
        xml_id = "%s-%s" % (resource_name, name)
        try:
            [get_method] = find_by_attribute(resource_type.tag, "id", xml_id)
        except ValueError:
            raise IntegrityError(
                "%s is not a method of %s" % (name, resource_name)
            )
        return get_method

    def _run_method(self, name, method, *args, **kwargs):
        """Run a method and convert its result into a L{FakeResource}.

        If the result represents an object it is validated against the WADL
        definition before being returned.

        @param name: The name of the method.
        @param method: A callable.
        @param args: Arguments to pass to the callable.
        @param kwargs: Keyword arguments to pass to the callable.
        @return: A L{FakeResource} representing the result if it's an object.
        @raises IntegrityError: Raised if the return value from the method
            isn't valid.
        """
        result = method(*args, **kwargs)
        if name in self.special_methods:
            return result
        else:
            return self._create_resource(self._resource_type, name, result)

    def _create_resource(self, resource_type, name, result):
        """Create a new L{FakeResource} for C{resource_type} method call result.

        @param resource_type: The resource type of the method.
        @param name: The name of the method on C{resource_type}.
        @param result: The result of calling the method.
        @raises IntegrityError: Raised if C{result} is an invalid return value
            for the method.
        @return: A L{FakeResource} for C{result}.
        """
        resource_name = resource_type.tag.get("id")
        if resource_name == name:
            name = "get"
        xml_id = self._find_representation_id(resource_type, name)
        xml_id = strip_suffix(xml_id, "-full")
        if xml_id not in self._application.resource_types:
            xml_id += "-resource"
        result_resource_type = self._application.resource_types[xml_id]
        self._check_resource_type(result_resource_type, result)
        # XXX: Should this wrap in collection?
        return FakeResource(self._application, result_resource_type, result)

    def _get_child_resource_type(self, resource_type):
        """Get the name and resource type for the entries in a collection.

        @param resource_type: The resource type for a collection.
        @return: (name, resource_type), where 'name' is the name of the child
            resource type and 'resource_type' is the corresponding resource
            type.
        """
        xml_id = self._find_representation_id(resource_type, "get")
        representation_definition = (
            self._application.representation_definitions[xml_id]
        )

        [entry_links] = find_by_attribute(
            representation_definition.tag, "name", "entry_links"
        )
        [resource_type] = list(entry_links)
        resource_type_url = resource_type.get("resource_type")
        resource_type_name = resource_type_url.split("#")[1]
        return (
            resource_type_name,
            self._application.get_resource_type(resource_type_url),
        )

    def _check_entries(self, resource_type, entries):
        """Ensure that C{entries} are valid for a C{resource_type} collection.

        @param resource_type: The resource type of the collection the entries
            are in.
        @param entries: A list of dicts representing objects in the
            collection.
        @return: (name, resource_type), where 'name' is the name of the child
            resource type and 'resource_type' is the corresponding resource
            type.
        """
        name, child_resource_type = self._get_child_resource_type(
            resource_type
        )
        for entry in entries:
            self._check_resource_type(child_resource_type, entry)
        return name, child_resource_type

    def __repr__(self):
        """
        The resource type, identifier if available, and memory address are
        used to generate a representation of this fake resource.
        """
        name = self._resource_type.tag.get("id")
        key = "object"
        key = self._values.get("id", key)
        key = self._values.get("name", key)
        return "<%s %s %s at %s>" % (
            self.__class__.__name__,
            name,
            key,
            hex(id(self)),
        )


class FakeRoot(FakeResource):
    """Fake root object for an application."""

    def __init__(self, application):
        """Create a L{FakeResource} for the service root of C{application}.

        @param application: A C{wadllib.application.Application} instance.
        """
        resource_type = application.get_resource_type(
            application.markup_url + "#service-root"
        )
        super(FakeRoot, self).__init__(application, resource_type)


class FakeEntry(FakeResource):
    """A fake resource for an entry."""


class FakeCollection(FakeResource):
    """A fake resource for a collection."""

    def __init__(
        self,
        application,
        resource_type,
        values=None,
        name=None,
        child_resource_type=None,
    ):
        super(FakeCollection, self).__init__(
            application, resource_type, values
        )
        self.__dict__.update(
            {"_name": name, "_child_resource_type": child_resource_type}
        )

    def __iter__(self):
        """Iterate items if this resource has an C{entries} attribute."""
        entries = self._values.get("entries", ())
        for entry in entries:
            yield self._create_resource(
                self._child_resource_type, self._name, entry
            )

    def __getitem__(self, key):
        """Look up a slice, or a subordinate resource by index.

        @param key: An individual object key or a C{slice}.
        @raises IndexError: Raised if an invalid key is provided.
        @return: A L{FakeResource} instance for the entry matching C{key}.
        """
        entries = list(self)
        if isinstance(key, slice):
            start = key.start or 0
            stop = key.stop
            if start < 0:
                raise ValueError(
                    "Collection slices must have a nonnegative " "start point."
                )
            if stop < 0:
                raise ValueError(
                    "Collection slices must have a definite, "
                    "nonnegative end point."
                )
            return entries.__getitem__(key)
        elif isinstance(key, int):
            return entries.__getitem__(key)
        else:
            raise IndexError("Do not support index lookups yet.")
