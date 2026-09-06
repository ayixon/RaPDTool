# apt/progress/base.py - Base classes for progress reporting.
#
# Copyright (C) 2009 Julian Andres Klode <jak@debian.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
# USA
# pylint: disable-msg = R0201
"""Base classes for progress reporting.

Custom progress classes should inherit from these classes. They can also be
used as dummy progress classes which simply do nothing.
"""
from __future__ import print_function

import errno
import fcntl
import io
import os
import re
import select
import sys

from typing import Optional, Union

import apt_pkg

__all__ = ['AcquireProgress', 'CdromProgress', 'InstallProgress', 'OpProgress']


class AcquireProgress(object):
    """Monitor object for downloads controlled by the Acquire class.

    This is an mostly abstract class. You should subclass it and implement the
    methods to get something useful.
    """

    current_bytes = current_cps = fetched_bytes = last_bytes = total_bytes \
                  = 0.0
    current_items = elapsed_time = total_items = 0

    def done(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Invoked when an item is successfully and completely fetched."""

    def fail(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Invoked when an item could not be fetched."""

    def fetch(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Invoked when some of the item's data is fetched."""

    def ims_hit(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Invoked when an item is confirmed to be up-to-date.

        Invoked when an item is confirmed to be up-to-date. For instance,
        when an HTTP download is informed that the file on the server was
        not modified.
        """

    def media_change(self, media, drive):
        # type: (str, str) -> bool
        """Prompt the user to change the inserted removable media.

        The parameter 'media' decribes the name of the media type that
        should be changed, whereas the parameter 'drive' should be the
        identifying name of the drive whose media should be changed.

        This method should not return until the user has confirmed to the user
        interface that the media change is complete. It must return True if
        the user confirms the media change, or False to cancel it.
        """
        return False

    def pulse(self, owner):
        # type: (apt_pkg.Acquire) -> bool
        """Periodically invoked while the Acquire process is underway.

        This method gets invoked while the Acquire progress given by the
        parameter 'owner' is underway. It should display information about
        the current state.

        This function returns a boolean value indicating whether the
        acquisition should be continued (True) or cancelled (False).
        """
        return True

    def start(self):
        # type: () -> None
        """Invoked when the Acquire process starts running."""
        # Reset all our values.
        self.current_bytes = 0.0
        self.current_cps = 0.0
        self.current_items = 0
        self.elapsed_time = 0
        self.fetched_bytes = 0.0
        self.last_bytes = 0.0
        self.total_bytes = 0.0
        self.total_items = 0

    def stop(self):
        # type: () -> None
        """Invoked when the Acquire process stops running."""


class CdromProgress(object):
    """Base class for reporting the progress of adding a cdrom.

    Can be used with apt_pkg.Cdrom to produce an utility like apt-cdrom. The
    attribute 'total_steps' defines the total number of steps and can be used
    in update() to display the current progress.
    """

    total_steps = 0

    def ask_cdrom_name(self):
        # type: () -> Optional[str]
        """Ask for the name of the cdrom.

        If a name has been provided, return it. Otherwise, return None to
        cancel the operation.
        """

    def change_cdrom(self):
        # type: () -> bool
        """Ask for the CD-ROM to be changed.

        Return True once the cdrom has been changed or False to cancel the
        operation.
        """

    def update(self, text, current):
        # type: (str, int) -> None
        """Periodically invoked to update the interface.

        The string 'text' defines the text which should be displayed. The
        integer 'current' defines the number of completed steps.
        """


class InstallProgress(object):
    """Class to report the progress of installing packages."""

    child_pid, percent, select_timeout, status = 0, 0.0, 0.1, ""

    def __init__(self):
        # type: () -> None
        (self.statusfd, self.writefd) = os.pipe()
        # These will leak fds, but fixing this safely requires API changes.
        self.write_stream = os.fdopen(self.writefd, "w")  # type: io.TextIOBase
        self.status_stream = os.fdopen(self.statusfd, "r")  # type: io.TextIOBase # noqa
        fcntl.fcntl(self.statusfd, fcntl.F_SETFL, os.O_NONBLOCK)

    def start_update(self):
        # type: () -> None
        """(Abstract) Start update."""

    def finish_update(self):
        # type: () -> None
        """(Abstract) Called when update has finished."""

    def __enter__(self):
        # type: () -> InstallProgress
        return self

    def __exit__(self, type, value, traceback):
        # type: (object, object, object) -> None
        self.write_stream.close()
        self.status_stream.close()

    def error(self, pkg, errormsg):
        # type: (str, str) -> None
        """(Abstract) Called when a error is detected during the install."""

    def conffile(self, current, new):
        # type: (str, str) -> None
        """(Abstract) Called when a conffile question from dpkg is detected."""

    def status_change(self, pkg, percent, status):
        # type: (str, float, str) -> None
        """(Abstract) Called when the APT status changed."""

    def dpkg_status_change(self, pkg, status):
        # type: (str, str) -> None
        """(Abstract) Called when the dpkg status changed."""

    def processing(self, pkg, stage):
        # type: (str, str) -> None
        """(Abstract) Sent just before a processing stage starts.

        The parameter 'stage' is one of "upgrade", "install"
        (both sent before unpacking), "configure", "trigproc", "remove",
        "purge". This method is used for dpkg only.
        """

    def run(self, obj):
        # type: (Union[apt_pkg.PackageManager, Union[bytes, str]]) -> int
        """Install using the object 'obj'.

        This functions runs install actions. The parameter 'obj' may either
        be a PackageManager object in which case its do_install() method is
        called or the path to a deb file.

        If the object is a PackageManager, the functions returns the result
        of calling its do_install() method. Otherwise, the function returns
        the exit status of dpkg. In both cases, 0 means that there were no
        problems.
        """
        pid = self.fork()
        if pid == 0:
            try:
                # PEP-446 implemented in Python 3.4 made all descriptors
                # CLOEXEC, but we need to be able to pass writefd to dpkg
                # when we spawn it
                os.set_inheritable(self.writefd, True)
            except AttributeError:  # if we don't have os.set_inheritable()
                pass
            # pm.do_install might raise a exception,
            # when this happens, we need to catch
            # it, otherwise os._exit() is not run
            # and the execution continues in the
            # parent code leading to very confusing bugs
            try:
                os._exit(obj.do_install(self.write_stream.fileno()))  # type: ignore # noqa
            except AttributeError:
                os._exit(os.spawnlp(os.P_WAIT, "dpkg", "dpkg", "--status-fd",
                                    str(self.write_stream.fileno()), "-i",
                                    obj))  # type: ignore # noqa
            except Exception as e:
                sys.stderr.write("%s\n" % e)
                os._exit(apt_pkg.PackageManager.RESULT_FAILED)

        self.child_pid = pid
        res = self.wait_child()
        return os.WEXITSTATUS(res)

    def fork(self):
        # type: () -> int
        """Fork."""
        return os.fork()

    def update_interface(self):
        # type: () -> None
        """Update the interface."""
        try:
            line = self.status_stream.readline()
        except IOError as err:
            # resource temporarly unavailable is ignored
            if err.errno != errno.EAGAIN and err.errno != errno.EWOULDBLOCK:
                print(err.strerror)
            return

        pkgname = status = status_str = percent = base = ""

        if line.startswith('pm'):
            try:
                (status, pkgname, percent, status_str) = line.split(":", 3)
            except ValueError:
                # silently ignore lines that can't be parsed
                return
        elif line.startswith('status'):
            try:
                (base, pkgname, status, status_str) = line.split(":", 3)
            except ValueError:
                (base, pkgname, status) = line.split(":", 2)
        elif line.startswith('processing'):
            (status, status_str, pkgname) = line.split(":", 2)
            self.processing(pkgname.strip(), status_str.strip())

        # Always strip the status message
        pkgname = pkgname.strip()
        status_str = status_str.strip()
        status = status.strip()

        if status == 'pmerror' or status == 'error':
            self.error(pkgname, status_str)
        elif status == 'conffile-prompt' or status == 'pmconffile':
            match = re.match("\\s*\'(.*)\'\\s*\'(.*)\'.*", status_str)
            if match:
                self.conffile(match.group(1), match.group(2))
        elif status == "pmstatus":
            # FIXME: Float comparison
            if float(percent) != self.percent or status_str != self.status:
                self.status_change(pkgname, float(percent), status_str.strip())
                self.percent = float(percent)
                self.status = status_str.strip()
        elif base == "status":
            self.dpkg_status_change(pkgname, status)

    def wait_child(self):
        # type: () -> int
        """Wait for child progress to exit.

        This method is responsible for calling update_interface() from time to
        time. It exits once the child has exited. The return values is the
        full status returned from os.waitpid() (not only the return code).
        """
        (pid, res) = (0, 0)
        while True:
            try:
                select.select([self.status_stream], [], [],
                              self.select_timeout)
            except select.error as error:
                (errno_, _errstr) = error.args
                if errno_ != errno.EINTR:
                    raise

            self.update_interface()
            try:
                (pid, res) = os.waitpid(self.child_pid, os.WNOHANG)
                if pid == self.child_pid:
                    break
            except OSError as err:
                if err.errno == errno.ECHILD:
                    break
                if err.errno != errno.EINTR:
                    raise

        return res


class OpProgress(object):
    """Monitor objects for operations.

    Display the progress of operations such as opening the cache."""

    major_change, op, percent, subop = False, "", 0.0, ""

    def update(self, percent=None):
        # type: (Optional[float]) -> None
        """Called periodically to update the user interface.

        You may use the optional argument 'percent' to set the attribute
        'percent' in this call.
        """
        if percent is not None:
            self.percent = percent

    def done(self):
        # type: () -> None
        """Called once an operation has been completed."""
