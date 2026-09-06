# Copyright 2008, 2011 Canonical Ltd.

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

"""Resources for use in unit tests with the C{testresources} module."""

from pkg_resources import resource_string

from testresources import TestResource

from wadllib.application import Application

from launchpadlib.testing.launchpad import FakeLaunchpad


launchpad_testing_application = None


def get_application():
    """Get or create a WADL application for testing Launchpad.

    Note that this uses the Launchpad v1.0 WADL bundled with launchpadlib for
    testing purposes.  For your own application, you might want to construct
    an L{Application} object directly, giving it your own WADL.
    """
    global launchpad_testing_application
    if launchpad_testing_application is None:
        markup_url = "https://api.launchpad.net/1.0/"
        markup = resource_string("launchpadlib.testing", "launchpad-wadl.xml")
        launchpad_testing_application = Application(markup_url, markup)
    return launchpad_testing_application


class FakeLaunchpadResource(TestResource):
    def make(self, dependency_resources):
        return FakeLaunchpad(
            application=Application(
                "https://api.example.com/testing/",
                resource_string("launchpadlib.testing", "testing-wadl.xml"),
            )
        )
