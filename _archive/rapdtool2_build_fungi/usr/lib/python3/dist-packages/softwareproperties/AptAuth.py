# dialog_apt_key.py.in - edit the apt keys
#  
#  Copyright (c) 2004 Canonical
#  
#  Author: Michael Vogt <mvo@debian.org>
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

from __future__ import print_function

import atexit
import datetime
import gettext
import os
import shutil
import subprocess
import tempfile

from subprocess import PIPE

# gettext convenient
_ = gettext.gettext
def dummy(e): return e
N_ = dummy

# some known keys
N_("Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.com>")
N_("Ubuntu CD Image Automatic Signing Key <cdimage@ubuntu.com>")
N_("Ubuntu Archive Automatic Signing Key (2012) <ftpmaster@ubuntu.com>")
N_("Ubuntu CD Image Automatic Signing Key (2012) <cdimage@ubuntu.com>")
N_("Ubuntu Extras Archive Automatic Signing Key <ftpmaster@ubuntu.com>")

class AptAuth:
    def __init__(self, rootdir="/"):
        self.rootdir = rootdir
        self.tmpdir = tempfile.mkdtemp()
        self.aptconf = os.path.join(self.tmpdir, 'apt.conf')
        with open(self.aptconf, 'w') as f:
            f.write('DIR "%s";\n' % self.rootdir)
        os.environ['APT_CONFIG'] = self.aptconf
        atexit.register(self._cleanup_tmpdir)

    def _cleanup_tmpdir(self):
        shutil.rmtree(self.tmpdir)

    def list(self):
        cmd = ["/usr/bin/apt-key", "--quiet", "adv", "--with-colons", "--batch", "--fixed-list-mode", "--list-keys"]
        res = []
        p = subprocess.run(cmd, stdout=PIPE, stderr=PIPE, universal_newlines=True).stdout
        name = ''
        for line in p:
            fields = line.split(":")
            if fields[0] in ["pub", "uid"]:
                name = fields[9]
            if fields[0] == "pub":
                key = fields[4]
                expiry = datetime.date.fromtimestamp(int(fields[5])).isoformat()
            if not name:
                continue
            res.append("%s %s\n%s" % (key, expiry, _(name)))
            name = ''
        return res

    def add(self, filename):
        cmd = ["/usr/bin/apt-key", "--quiet", "--fakeroot", "add", filename]
        return subprocess.run(cmd, stderr=PIPE).returncode == 0

    def update(self):
        cmd = ["/usr/bin/apt-key", "--quiet", "--fakeroot", "update"]
        return subprocess.run(cmd, stderr=PIPE).returncode == 0

    def rm(self, key):
        cmd = ["/usr/bin/apt-key", "--quiet", "--fakeroot", "rm", key]
        return subprocess.run(cmd, stderr=PIPE).returncode == 0
