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

from datetime import datetime

from testresources import ResourcedTestCase

from launchpadlib.testing.launchpad import (
    FakeLaunchpad,
    FakeResource,
    FakeRoot,
    IntegrityError,
)
from launchpadlib.testing.resources import (
    FakeLaunchpadResource,
    get_application,
)


class FakeRootTest(ResourcedTestCase):
    def test_create_root_resource(self):
        root_resource = FakeRoot(get_application())
        self.assertTrue(isinstance(root_resource, FakeResource))


class FakeResourceTest(ResourcedTestCase):

    resources = [("launchpad", FakeLaunchpadResource())]

    def test_repr(self):
        """A custom C{__repr__} is provided for L{FakeResource}s."""
        branches = dict(total_size="test-branch")
        self.launchpad.me = dict(getBranches=lambda statuses: branches)
        branches = self.launchpad.me.getBranches([])
        obj_id = hex(id(branches))
        self.assertEqual(
            "<FakeResource branch-page-resource object at %s>" % obj_id,
            repr(branches),
        )

    def test_repr_with_name(self):
        """
        If the fake has a C{name} property it's included in the repr string to
        make it easier to figure out what it is.
        """
        self.launchpad.me = dict(name="foo")
        person = self.launchpad.me
        self.assertEqual(
            "<FakeEntry person foo at %s>" % hex(id(person)), repr(person)
        )

    def test_repr_with_id(self):
        """
        If the fake has an C{id} property it's included in the repr string to
        make it easier to figure out what it is.
        """
        bug = dict(id="1", title="Bug #1")
        self.launchpad.bugs = dict(entries=[bug])
        [bug] = list(self.launchpad.bugs)
        self.assertEqual(
            "<FakeResource bug 1 at %s>" % hex(id(bug)), repr(bug)
        )


class FakeLaunchpadTest(ResourcedTestCase):

    resources = [("launchpad", FakeLaunchpadResource())]

    def test_wb_instantiate_without_application(self):
        """
        The builtin WADL definition is used if the C{application} is not
        provided during instantiation.
        """
        credentials = object()
        launchpad = FakeLaunchpad(credentials)
        self.assertEqual(credentials, launchpad.credentials)
        self.assertEqual(get_application(), launchpad._application)

    def test_instantiate_with_everything(self):
        """
        L{FakeLaunchpad} takes the same parameters as L{Launchpad} during
        instantiation, with the addition of an C{application} parameter.  The
        optional parameters are discarded when the object is instantiated.
        """
        credentials = object()
        launchpad = FakeLaunchpad(
            credentials,
            service_root=None,
            cache=None,
            timeout=None,
            proxy_info=None,
            application=get_application(),
        )
        self.assertEqual(credentials, launchpad.credentials)

    def test_instantiate_with_credentials(self):
        """A L{FakeLaunchpad} can be instantiated with credentials."""
        credentials = object()
        launchpad = FakeLaunchpad(credentials, application=get_application())
        self.assertEqual(credentials, launchpad.credentials)

    def test_instantiate_without_credentials(self):
        """
        A L{FakeLaunchpad} instantiated without credentials has its
        C{credentials} attribute set to C{None}.
        """
        self.assertIsNone(self.launchpad.credentials)

    def test_set_undefined_property(self):
        """
        An L{IntegrityError} is raised if an attribute is set on a
        L{FakeLaunchpad} instance that isn't present in the WADL definition.
        """
        self.assertRaises(
            IntegrityError, setattr, self.launchpad, "foo", "bar"
        )

    def test_get_undefined_resource(self):
        """
        An L{AttributeError} is raised if an attribute is accessed on a
        L{FakeLaunchpad} instance that doesn't exist.
        """
        self.launchpad.me = dict(display_name="Foo")
        self.assertRaises(AttributeError, getattr, self.launchpad.me, "name")

    def test_string_property(self):
        """
        Sample data can be created by setting L{FakeLaunchpad} attributes with
        dicts that represent objects.  Plain string values can be represented
        as C{str} values.
        """
        self.launchpad.me = dict(name="foo")
        self.assertEqual("foo", self.launchpad.me.name)

    def test_unicode_property(self):
        """
        Sample data can be created by setting L{FakeLaunchpad} attributes with
        dicts that represent objects.  Plain string values can be represented
        as C{unicode} strings.
        """
        self.launchpad.me = dict(name=u"foo")
        self.assertEqual(u"foo", self.launchpad.me.name)

    def test_datetime_property(self):
        """
        Attributes that represent dates are set with C{datetime} instances.
        """
        now = datetime.utcnow()
        self.launchpad.me = dict(date_created=now)
        self.assertEqual(now, self.launchpad.me.date_created)

    def test_invalid_datetime_property(self):
        """
        Only C{datetime} values can be set on L{FakeLaunchpad} instances for
        attributes that represent dates.
        """
        self.assertRaises(
            IntegrityError,
            setattr,
            self.launchpad,
            "me",
            dict(date_created="now"),
        )

    def test_multiple_string_properties(self):
        """
        Sample data can be created by setting L{FakeLaunchpad} attributes with
        dicts that represent objects.
        """
        self.launchpad.me = dict(name="foo", display_name="Foo")
        self.assertEqual("foo", self.launchpad.me.name)
        self.assertEqual("Foo", self.launchpad.me.display_name)

    def test_invalid_property_name(self):
        """
        Sample data set on a L{FakeLaunchpad} instance is validated against
        the WADL definition.  If a key is defined on a resource that doesn't
        match a related parameter, an L{IntegrityError} is raised.
        """
        self.assertRaises(
            IntegrityError, setattr, self.launchpad, "me", dict(foo="bar")
        )

    def test_invalid_property_value(self):
        """
        The types of sample data values set on L{FakeLaunchpad} instances are
        validated against types defined in the WADL definition.
        """
        self.assertRaises(
            IntegrityError, setattr, self.launchpad, "me", dict(name=102)
        )

    def test_callable(self):
        """
        A callable set on a L{FakeLaunchpad} instance is validated against the
        WADL definition, to make sure a matching method exists.
        """
        branches = dict(total_size="test-branch")
        self.launchpad.me = dict(getBranches=lambda statuses: branches)
        self.assertNotEqual(None, self.launchpad.me.getBranches([]))

    def test_invalid_callable_name(self):
        """
        An L{IntegrityError} is raised if a method is defined on a resource
        that doesn't match a method defined in the WADL definition.
        """
        self.assertRaises(
            IntegrityError,
            setattr,
            self.launchpad,
            "me",
            dict(foo=lambda: None),
        )

    def test_callable_object_return_type(self):
        """
        The result of a fake method is a L{FakeResource}, automatically
        created from the object used to define the return object.
        """
        branches = dict(total_size="8")
        self.launchpad.me = dict(getBranches=lambda statuses: branches)
        branches = self.launchpad.me.getBranches([])
        self.assertTrue(isinstance(branches, FakeResource))
        self.assertEqual("8", branches.total_size)

    def test_invalid_callable_object_return_type(self):
        """
        An L{IntegrityError} is raised if a method returns an invalid result.
        """
        branches = dict(total_size=8)
        self.launchpad.me = dict(getBranches=lambda statuses: branches)
        self.assertRaises(IntegrityError, self.launchpad.me.getBranches, [])

    def test_collection_property(self):
        """
        Sample collections can be set on L{FakeLaunchpad} instances.  They are
        validated the same way other sample data is validated.
        """
        branch = dict(name="foo")
        self.launchpad.branches = dict(getByUniqueName=lambda name: branch)
        branch = self.launchpad.branches.getByUniqueName("foo")
        self.assertEqual("foo", branch.name)

    def test_iterate_collection(self):
        """
        Data for a sample collection set on a L{FakeLaunchpad} instance can be
        iterated over if an C{entries} key is defined.
        """
        bug = dict(id="1", title="Bug #1")
        self.launchpad.bugs = dict(entries=[bug])
        bugs = list(self.launchpad.bugs)
        self.assertEqual(1, len(bugs))
        bug = bugs[0]
        self.assertEqual("1", bug.id)
        self.assertEqual("Bug #1", bug.title)

    def test_collection_with_invalid_entries(self):
        """
        Sample data for each entry in a collection is validated when it's set
        on a L{FakeLaunchpad} instance.
        """
        bug = dict(foo="bar")
        self.assertRaises(
            IntegrityError,
            setattr,
            self.launchpad,
            "bugs",
            dict(entries=[bug]),
        )

    def test_slice_collection(self):
        """
        Data for a sample collection set on a L{FakeLaunchpad} instance can be
        sliced if an C{entries} key is defined.
        """
        bug1 = dict(id="1", title="Bug #1")
        bug2 = dict(id="2", title="Bug #2")
        bug3 = dict(id="3", title="Bug #3")
        self.launchpad.bugs = dict(entries=[bug1, bug2, bug3])
        bugs = self.launchpad.bugs[1:3]
        self.assertEqual(2, len(bugs))
        self.assertEqual("2", bugs[0].id)
        self.assertEqual("3", bugs[1].id)

    def test_slice_collection_with_negative_start(self):
        """
        A C{ValueError} is raised if a negative start value is used when
        slicing a sample collection set on a L{FakeLaunchpad} instance.
        """
        bug1 = dict(id="1", title="Bug #1")
        bug2 = dict(id="2", title="Bug #2")
        self.launchpad.bugs = dict(entries=[bug1, bug2])
        self.assertRaises(ValueError, lambda: self.launchpad.bugs[-1:])
        self.assertRaises(ValueError, lambda: self.launchpad.bugs[-1:2])

    def test_slice_collection_with_negative_stop(self):
        """
        A C{ValueError} is raised if a negative stop value is used when
        slicing a sample collection set on a L{FakeLaunchpad} instance.
        """
        bug1 = dict(id="1", title="Bug #1")
        bug2 = dict(id="2", title="Bug #2")
        self.launchpad.bugs = dict(entries=[bug1, bug2])
        self.assertRaises(ValueError, lambda: self.launchpad.bugs[:-1])
        self.assertRaises(ValueError, lambda: self.launchpad.bugs[0:-1])

    def test_subscript_operator_out_of_range(self):
        """
        An C{IndexError} is raised if an invalid index is used when retrieving
        data from a sample collection.
        """
        bug1 = dict(id="1", title="Bug #1")
        self.launchpad.bugs = dict(entries=[bug1])
        self.assertRaises(IndexError, lambda: self.launchpad.bugs[2])

    def test_replace_property(self):
        """Values already set on fake resource objects can be replaced."""
        self.launchpad.me = dict(name="foo")
        person = self.launchpad.me
        self.assertEqual("foo", person.name)
        person.name = "bar"
        self.assertEqual("bar", person.name)
        self.assertEqual("bar", self.launchpad.me.name)

    def test_replace_method(self):
        """Methods already set on fake resource objects can be replaced."""
        branch1 = dict(name="foo", bzr_identity="lp:~user/project/branch1")
        branch2 = dict(name="foo", bzr_identity="lp:~user/project/branch2")
        self.launchpad.branches = dict(getByUniqueName=lambda name: branch1)
        self.launchpad.branches.getByUniqueName = lambda name: branch2
        branch = self.launchpad.branches.getByUniqueName("foo")
        self.assertEqual("lp:~user/project/branch2", branch.bzr_identity)

    def test_replace_property_with_invalid_value(self):
        """Values set on fake resource objects are validated."""
        self.launchpad.me = dict(name="foo")
        person = self.launchpad.me
        self.assertRaises(IntegrityError, setattr, person, "name", 1)

    def test_replace_resource(self):
        """Resources already set on L{FakeLaunchpad} can be replaced."""
        self.launchpad.me = dict(name="foo")
        self.assertEqual("foo", self.launchpad.me.name)
        self.launchpad.me = dict(name="bar")
        self.assertEqual("bar", self.launchpad.me.name)

    def test_add_property(self):
        """Sample data set on a L{FakeLaunchpad} instance can be added to."""
        self.launchpad.me = dict(name="foo")
        person = self.launchpad.me
        person.display_name = "Foo"
        self.assertEqual("foo", person.name)
        self.assertEqual("Foo", person.display_name)
        self.assertEqual("foo", self.launchpad.me.name)
        self.assertEqual("Foo", self.launchpad.me.display_name)

    def test_add_property_to_empty_object(self):
        """An empty object can be used when creating sample data."""
        self.launchpad.me = dict()
        self.assertRaises(AttributeError, getattr, self.launchpad.me, "name")
        self.launchpad.me.name = "foo"
        self.assertEqual("foo", self.launchpad.me.name)

    def test_login(self):
        """
        L{FakeLaunchpad.login} ignores all parameters and returns a new
        instance using the builtin WADL definition.
        """
        launchpad = FakeLaunchpad.login("name", "token", "secret")
        self.assertTrue(isinstance(launchpad, FakeLaunchpad))

    def test_get_token_and_login(self):
        """
        L{FakeLaunchpad.get_token_and_login} ignores all parameters and
        returns a new instance using the builtin WADL definition.
        """
        launchpad = FakeLaunchpad.get_token_and_login("name")
        self.assertTrue(isinstance(launchpad, FakeLaunchpad))

    def test_login_with(self):
        """
        L{FakeLaunchpad.login_with} ignores all parameters and returns a new
        instance using the builtin WADL definition.
        """
        launchpad = FakeLaunchpad.login_with("name")
        self.assertTrue(isinstance(launchpad, FakeLaunchpad))

    def test_lp_save(self):
        """
        Sample object have an C{lp_save} method that is a no-op by default.
        """
        self.launchpad.me = dict(name="foo")
        self.assertTrue(self.launchpad.me.lp_save())

    def test_custom_lp_save(self):
        """A custom C{lp_save} method can be set on a L{FakeResource}."""
        self.launchpad.me = dict(name="foo", lp_save=lambda: "custom")
        self.assertEqual("custom", self.launchpad.me.lp_save())

    def test_set_custom_lp_save(self):
        """
        A custom C{lp_save} method can be set on a L{FakeResource} after its
        been created.
        """
        self.launchpad.me = dict(name="foo")
        self.launchpad.me.lp_save = lambda: "custom"
        self.assertEqual("custom", self.launchpad.me.lp_save())
