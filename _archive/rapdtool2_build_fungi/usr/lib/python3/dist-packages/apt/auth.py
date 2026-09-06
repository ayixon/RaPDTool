#!/usr/bin/python3
# -*- coding: utf-8 -*-
# auth - authentication key management
#
#  Copyright (c) 2004 Canonical
#  Copyright (c) 2012 Sebastian Heinlein
#
#  Author: Michael Vogt <mvo@debian.org>
#          Sebastian Heinlein <devel@glatzor.de>
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
"""Handle GnuPG keys used to trust signed repositories."""

from __future__ import print_function

import errno
import os
import os.path
import shutil
import subprocess
import sys
import tempfile

import apt_pkg
from apt_pkg import gettext as _

from typing import List, Optional, Tuple


class AptKeyError(Exception):
    pass


class AptKeyIDTooShortError(AptKeyError):
    """Internal class do not rely on it."""


class TrustedKey(object):

    """Represents a trusted key."""

    def __init__(self, name, keyid, date):
        # type: (str, str, str) -> None
        self.raw_name = name
        # Allow to translated some known keys
        self.name = _(name)
        self.keyid = keyid
        self.date = date

    def __str__(self):
        # type: () -> str
        return "%s\n%s %s" % (self.name, self.keyid, self.date)


def _call_apt_key_script(*args, **kwargs):
    # type: (str, Optional[str]) -> str
    """Run the apt-key script with the given arguments."""
    conf = None
    cmd = [apt_pkg.config.find_file("Dir::Bin::Apt-Key", "/usr/bin/apt-key")]
    cmd.extend(args)
    env = os.environ.copy()
    env["LANG"] = "C"
    env["APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE"] = "1"
    try:
        if apt_pkg.config.find_dir("Dir") != "/":
            # If the key is to be installed into a chroot we have to export the
            # configuration from the chroot to the apt-key script by using
            # a temporary APT_CONFIG file. The apt-key script uses apt-config
            # shell internally
            conf = tempfile.NamedTemporaryFile(
                prefix="apt-key", suffix=".conf")
            conf.write(apt_pkg.config.dump().encode("UTF-8"))
            conf.flush()
            env["APT_CONFIG"] = conf.name
        proc = subprocess.Popen(cmd, env=env, universal_newlines=True,
                                stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE)

        stdin = kwargs.get("stdin", None)

        output, stderr = proc.communicate(stdin)  # type: str, str

        if proc.returncode:
            raise AptKeyError(
                "The apt-key script failed with return code %s:\n"
                "%s\n"
                "stdout: %s\n"
                "stderr: %s" % (
                    proc.returncode, " ".join(cmd), output, stderr))
        elif stderr:
            sys.stderr.write(stderr)    # Forward stderr

        return output.strip()
    finally:
        if conf is not None:
            conf.close()


def add_key_from_file(filename):
    # type: (str) -> None
    """Import a GnuPG key file to trust repositores signed by it.

    Keyword arguments:
    filename -- the absolute path to the public GnuPG key file
    """
    if not os.path.abspath(filename):
        raise AptKeyError("An absolute path is required: %s" % filename)
    if not os.access(filename, os.R_OK):
        raise AptKeyError("Key file cannot be accessed: %s" % filename)
    _call_apt_key_script("add", filename)


def add_key_from_keyserver(keyid, keyserver):
    # type: (str, str) -> None
    """Import a GnuPG key file to trust repositores signed by it.

    Keyword arguments:
    keyid -- the long keyid (fingerprint) of the key, e.g.
             A1BD8E9D78F7FE5C3E65D8AF8B48AD6246925553
    keyserver -- the URL or hostname of the key server
    """
    tmp_keyring_dir = tempfile.mkdtemp()
    try:
        _add_key_from_keyserver(keyid, keyserver, tmp_keyring_dir)
    except Exception:
        raise
    finally:
        # We are racing with gpg when removing sockets, so ignore
        # failure to delete non-existing files.
        def onerror(func, path, exc_info):
            # type: (object, str, Tuple[type, Exception, object]) -> None
            if (isinstance(exc_info[1], OSError) and
                exc_info[1].errno == errno.ENOENT):
                return
            raise

        shutil.rmtree(tmp_keyring_dir, onerror=onerror)


def _add_key_from_keyserver(keyid, keyserver, tmp_keyring_dir):
    # type: (str, str, str) -> None
    if len(keyid.replace(" ", "").replace("0x", "")) < (160 / 4):
        raise AptKeyIDTooShortError(
            "Only fingerprints (v4, 160bit) are supported")
    # create a temp keyring dir
    tmp_secret_keyring = os.path.join(tmp_keyring_dir, "secring.gpg")
    tmp_keyring = os.path.join(tmp_keyring_dir, "pubring.gpg")
    # default options for gpg
    gpg_default_options = [
        "gpg",
        "--no-default-keyring", "--no-options",
        "--homedir", tmp_keyring_dir,
    ]
    # download the key to a temp keyring first
    res = subprocess.call(gpg_default_options + [
        "--secret-keyring", tmp_secret_keyring,
        "--keyring", tmp_keyring,
        "--keyserver", keyserver,
        "--recv", keyid,
    ])
    if res != 0:
        raise AptKeyError("recv from '%s' failed for '%s'" % (
            keyserver, keyid))
    # FIXME:
    # - with gnupg 1.4.18 the downloaded key is actually checked(!),
    #   i.e. gnupg will not import anything that the server sends
    #   into the keyring, so the below checks are now redundant *if*
    #   gnupg 1.4.18 is used

    # now export again using the long key id (to ensure that there is
    # really only this one key in our keyring) and not someone MITM us
    tmp_export_keyring = os.path.join(tmp_keyring_dir, "export-keyring.gpg")
    res = subprocess.call(gpg_default_options + [
        "--keyring", tmp_keyring,
        "--output", tmp_export_keyring,
        "--export", keyid,
    ])
    if res != 0:
        raise AptKeyError("export of '%s' failed", keyid)
    # now verify the fingerprint, this is probably redundant as we
    # exported by the fingerprint in the previous command but its
    # still good paranoia
    output = subprocess.Popen(
        gpg_default_options + [
            "--keyring", tmp_export_keyring,
            "--fingerprint",
            "--batch",
            "--fixed-list-mode",
            "--with-colons",
        ],
        stdout=subprocess.PIPE,
        universal_newlines=True).communicate()[0]
    got_fingerprint = None
    for line in output.splitlines():
        if line.startswith("fpr:"):
            got_fingerprint = line.split(":")[9]
            # stop after the first to ensure no subkey trickery
            break
    # strip the leading "0x" is there is one and uppercase (as this is
    # what gnupg is using)
    signing_key_fingerprint = keyid.replace("0x", "").upper()
    if got_fingerprint != signing_key_fingerprint:
        # make the error match what gnupg >= 1.4.18 will output when
        # it checks the key itself before importing it
        raise AptKeyError(
            "recv from '%s' failed for '%s'" % (
                keyserver, signing_key_fingerprint))
    # finally add it
    add_key_from_file(tmp_export_keyring)


def add_key(content):
    # type: (str) -> None
    """Import a GnuPG key to trust repositores signed by it.

    Keyword arguments:
    content -- the content of the GnuPG public key
    """
    _call_apt_key_script("adv", "--quiet", "--batch",
                         "--import", "-", stdin=content)


def remove_key(fingerprint):
    # type: (str) -> None
    """Remove a GnuPG key to no longer trust repositores signed by it.

    Keyword arguments:
    fingerprint -- the fingerprint identifying the key
    """
    _call_apt_key_script("rm", fingerprint)


def export_key(fingerprint):
    # type: (str) -> str
    """Return the GnuPG key in text format.

    Keyword arguments:
    fingerprint -- the fingerprint identifying the key
    """
    return _call_apt_key_script("export", fingerprint)


def update():
    # type: () -> str
    """Update the local keyring with the archive keyring and remove from
    the local keyring the archive keys which are no longer valid. The
    archive keyring is shipped in the archive-keyring package of your
    distribution, e.g. the debian-archive-keyring package in Debian.
    """
    return _call_apt_key_script("update")


def net_update():
    # type: () -> str
    """Work similar to the update command above, but get the archive
    keyring from an URI instead and validate it against a master key.
    This requires an installed wget(1) and an APT build configured to
    have a server to fetch from and a master keyring to validate. APT
    in Debian does not support this command and relies on update
    instead, but Ubuntu's APT does.
    """
    return _call_apt_key_script("net-update")


def list_keys():
    # type: () -> List[TrustedKey]
    """Returns a list of TrustedKey instances for each key which is
    used to trust repositories.
    """
    # The output of `apt-key list` is difficult to parse since the
    # --with-colons parameter isn't user
    output = _call_apt_key_script("adv", "--with-colons", "--batch",
                                  "--fixed-list-mode", "--list-keys")
    res = []
    for line in output.split("\n"):
        fields = line.split(":")
        if fields[0] == "pub":
            keyid = fields[4]
        if fields[0] == "uid":
            uid = fields[9]
            creation_date = fields[5]
            key = TrustedKey(uid, keyid, creation_date)
            res.append(key)
    return res


if __name__ == "__main__":
    # Add some known keys we would like to see translated so that they get
    # picked up by gettext
    lambda: _("Ubuntu Archive Automatic Signing Key <ftpmaster@ubuntu.com>")
    lambda: _("Ubuntu CD Image Automatic Signing Key <cdimage@ubuntu.com>")

    apt_pkg.init()
    for trusted_key in list_keys():
        print(trusted_key)
