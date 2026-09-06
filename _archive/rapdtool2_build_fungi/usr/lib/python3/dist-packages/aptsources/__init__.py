from __future__ import print_function

import apt_pkg


# init the package system, but do not re-initialize config
if "APT" not in apt_pkg.config:
    apt_pkg.init_config()
apt_pkg.init_system()
