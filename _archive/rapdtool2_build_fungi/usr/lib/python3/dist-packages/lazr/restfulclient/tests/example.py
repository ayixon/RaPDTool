# Copyright 2009 Canonical Ltd.  All rights reserved.
#
# This file is part of lazr.restfulclient
#
# lazr.restfulclient is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# lazr.restfulclient is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with lazr.restfulclient.  If not, see <http://www.gnu.org/licenses/>.
"Test client for the lazr.restful example web service."

__metaclass__ = type
__all__ = [
    'CookbookWebServiceClient',
    ]


try:
    # Python 3.
    from urllib.parse import quote
except ImportError:
    from urllib import quote

from lazr.restfulclient.resource import (
    CollectionWithKeyBasedLookup, ServiceRoot)


class CookbookSet(CollectionWithKeyBasedLookup):
    """A custom subclass capable of cookbook lookup by cookbook name."""

    def _get_url_from_id(self, id):
        """Transform a cookbook name into the URL to a cookbook resource."""
        return (str(self._root._root_uri.ensureSlash())
                + 'cookbooks/' + quote(str(id)))

    collection_of = "cookbook"


class RecipeSet(CollectionWithKeyBasedLookup):
    """A custom subclass capable of recipe lookup by recipe ID."""

    def _get_url_from_id(self, id):
        """Transform a recipe ID into the URL to a recipe resource."""
        return str(self._root._root_uri.ensureSlash()) + 'recipes/' + str(id)

    collection_of = "recipe"


class CookbookWebServiceClient(ServiceRoot):

    RESOURCE_TYPE_CLASSES = dict(ServiceRoot.RESOURCE_TYPE_CLASSES)
    RESOURCE_TYPE_CLASSES['recipes'] = RecipeSet
    RESOURCE_TYPE_CLASSES['cookbooks'] = CookbookSet

    DEFAULT_SERVICE_ROOT = "http://cookbooks.dev/"
    DEFAULT_VERSION = "1.0"

    def __init__(self, service_root=DEFAULT_SERVICE_ROOT,
                 version=DEFAULT_VERSION, cache=None):
        super(CookbookWebServiceClient, self).__init__(
            None, service_root, cache=cache, version=version)
