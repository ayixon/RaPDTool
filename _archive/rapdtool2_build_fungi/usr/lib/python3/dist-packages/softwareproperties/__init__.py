#  __init__.py - defines globals
#
#  Copyright (c) 2007 Canonical Ltd.
#
#  Author: Sebastian Heinlein <glatzor@ubuntu.com>
#          Michael Vogt <mvo@debian.org>
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
#  USA

# Level of the update automation
(UPDATE_MANUAL, 
 UPDATE_NOTIFY, 
 UPDATE_DOWNLOAD, 
 UPDATE_INST_SEC) = list(range(4))

# Provide more readable synonyms for apt configuration options
CONF_MAP = {
    "autoupdate"   : "APT::Periodic::Update-Package-Lists",
    "autodownload" : "APT::Periodic::Download-Upgradeable-Packages",
    "autoclean"    : "APT::Periodic::AutocleanInterval",
    "unattended"   : "APT::Periodic::Unattended-Upgrade",
    "max_size"     : "APT::Archives::MaxSize",
    "max_age"      : "APT::Archives::MaxAge"
}


