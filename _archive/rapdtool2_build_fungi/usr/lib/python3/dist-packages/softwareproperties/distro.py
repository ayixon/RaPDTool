# dialog_apt_key.py.in - edit the apt keys
#
#  Copyright (c) 2006-2007 Canonical
#
#  Author: Michael Vogt <mvo@debian.org>
#          Sebastian Heinlein <glatzor@ubuntu.com>
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

import aptsources.distro
from gettext import gettext as _

def get_popcon_description(distro):
    if isinstance(distro, aptsources.distro.UbuntuDistribution):
        return(_("<i>To improve the user experience of Ubuntu please "
                 "take part in the popularity contest. If you do so the "
                 "list of installed software and how often it was used will "
                 "be collected and sent anonymously to the Ubuntu project "
                 "on a weekly basis.\n\n"
                 "The results are used to improve the support for popular "
                 "applications and to rank applications in the search "
                 "results.</i>"))
    elif isinstance(distro, aptsources.distro.DebianDistribution):
        return(_("<i>To improve the user experiece of Debian please take "
                 "part in the popularity contest. If you do so the list of "
                 "installed software and how often it was used will be "
                 "collected and sent anonymously to the Debian project.\n\n"
                 "The results are used to optimise the layout of the "
                 "installation CDs."))
    else:
        return(_("Submit the list of installed software and how often it is "
                 "is used to the distribution project."))

