# Copyright 2009 Canonical Ltd.

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

"""Launchpad-specific URIs and convenience lookup functions.

The code in this module lets users say "staging" when they mean
"https://api.staging.launchpad.net/".
"""

__metaclass__ = type
__all__ = [
    "lookup_service_root",
    "lookup_web_root",
    "web_root_for_service_root",
]
try:
    from urllib.parse import urlparse
except ImportError:
    from urlparse import urlparse

import warnings
from lazr.uri import URI

LPNET_SERVICE_ROOT = "https://api.launchpad.net/"
QASTAGING_SERVICE_ROOT = "https://api.qastaging.launchpad.net/"
STAGING_SERVICE_ROOT = "https://api.staging.launchpad.net/"
DEV_SERVICE_ROOT = "https://api.launchpad.test/"
DOGFOOD_SERVICE_ROOT = "https://api.dogfood.paddev.net/"
TEST_DEV_SERVICE_ROOT = "http://api.launchpad.test:8085/"

LPNET_WEB_ROOT = "https://launchpad.net/"
QASTAGING_WEB_ROOT = "https://qastaging.launchpad.net/"
STAGING_WEB_ROOT = "https://staging.launchpad.net/"
DEV_WEB_ROOT = "https://launchpad.test/"
DOGFOOD_WEB_ROOT = "https://dogfood.paddev.net/"
TEST_DEV_WEB_ROOT = "http://launchpad.test:8085/"

# If you use EDGE_SERVICE_ROOT, or its alias, or the equivalent
# string, launchpadlib will issue a deprecation warning and use
# PRODUCTION_SERVICE_ROOT instead. Similarly for EDGE_WEB_ROOT.
EDGE_SERVICE_ROOT = "https://api.edge.launchpad.net/"
EDGE_WEB_ROOT = "https://edge.launchpad.net/"

service_roots = dict(
    production=LPNET_SERVICE_ROOT,
    edge=LPNET_SERVICE_ROOT,
    qastaging=QASTAGING_SERVICE_ROOT,
    staging=STAGING_SERVICE_ROOT,
    dogfood=DOGFOOD_SERVICE_ROOT,
    dev=DEV_SERVICE_ROOT,
    test_dev=TEST_DEV_SERVICE_ROOT,
)


web_roots = dict(
    production=LPNET_WEB_ROOT,
    edge=LPNET_WEB_ROOT,
    qastaging=QASTAGING_WEB_ROOT,
    staging=STAGING_WEB_ROOT,
    dogfood=DOGFOOD_WEB_ROOT,
    dev=DEV_WEB_ROOT,
    test_dev=TEST_DEV_WEB_ROOT,
)


def _dereference_alias(root, aliases):
    """Dereference what might a URL or an alias for a URL."""
    if root == "edge":
        warnings.warn(
            (
                "Launchpad edge server no longer exists. "
                "Using 'production' instead."
            ),
            DeprecationWarning,
        )
    if root in aliases:
        return aliases[root]

    # It's not an alias. Is it a valid URL?
    (scheme, netloc, path, parameters, query, fragment) = urlparse(root)
    if scheme != "" and netloc != "":
        return root

    # It's not an alias or a valid URL.
    raise ValueError(
        "%s is not a valid URL or an alias for any Launchpad " "server" % root
    )


def lookup_service_root(service_root):
    """Dereference an alias to a service root.

    A recognized server alias such as "staging" gets turned into the
    appropriate URI. A URI gets returned as is. Any other string raises a
    ValueError.
    """
    if service_root == EDGE_SERVICE_ROOT:
        # This will trigger a deprecation warning and use production instead.
        service_root = "edge"
    return _dereference_alias(service_root, service_roots)


def lookup_web_root(web_root):
    """Dereference an alias to a website root.

    A recognized server alias such as "staging" gets turned into the
    appropriate URI. A URI gets returned as is. Any other string raises a
    ValueError.
    """
    if web_root == EDGE_WEB_ROOT:
        # This will trigger a deprecation warning and use production instead.
        web_root = "edge"
    return _dereference_alias(web_root, web_roots)


def web_root_for_service_root(service_root):
    """Turn a service root URL into a web root URL.

    This is done heuristically, not with a lookup.
    """
    service_root = lookup_service_root(service_root)
    web_root_uri = URI(service_root)
    web_root_uri.path = ""
    web_root_uri.host = web_root_uri.host.replace("api.", "", 1)
    web_root = str(web_root_uri.ensureSlash())
    return web_root
