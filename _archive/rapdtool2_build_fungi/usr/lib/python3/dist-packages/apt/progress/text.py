# Copyright (c) 2009 Julian Andres Klode <jak@debian.org>
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
"""Progress reporting for text interfaces."""
from __future__ import print_function

import io
import os
import signal
import sys

import types
from typing import Callable, Optional, Union


import apt_pkg
from apt.progress import base


__all__ = ['AcquireProgress', 'CdromProgress', 'OpProgress']


def _(msg):
    # type: (str) -> str
    """Translate the message, also try apt if translation is missing."""
    res = apt_pkg.gettext(msg)
    if res == msg:
        res = apt_pkg.gettext(msg, "apt")
    return res


class TextProgress(object):
    """Internal Base class for text progress classes."""

    def __init__(self, outfile=None):
        # type: (Optional[io.TextIOBase]) -> None
        self._file = outfile or sys.stdout
        self._width = 0

    def _write(self, msg, newline=True, maximize=False):
        # type: (str, bool, bool) -> None
        """Write the message on the terminal, fill remaining space."""
        self._file.write("\r")
        self._file.write(msg)

        # Fill remaining stuff with whitespace
        if self._width > len(msg):
            self._file.write((self._width - len(msg)) * ' ')
        elif maximize:  # Needed for OpProgress.
            self._width = max(self._width, len(msg))
        if newline:
            self._file.write("\n")
        else:
            #self._file.write("\r")
            self._file.flush()


class OpProgress(base.OpProgress, TextProgress):
    """Operation progress reporting.

    This closely resembles OpTextProgress in libapt-pkg.
    """

    def __init__(self, outfile=None):
        # type: (Optional[io.TextIOBase]) -> None
        TextProgress.__init__(self, outfile)
        base.OpProgress.__init__(self)
        self.old_op = ""

    def update(self, percent=None):
        # type: (Optional[float]) -> None
        """Called periodically to update the user interface."""
        base.OpProgress.update(self, percent)
        if self.major_change and self.old_op:
            self._write(self.old_op)
        self._write("%s... %i%%\r" % (self.op, self.percent), False, True)
        self.old_op = self.op

    def done(self):
        # type: () -> None
        """Called once an operation has been completed."""
        base.OpProgress.done(self)
        if self.old_op:
            self._write(_("%c%s... Done") % ('\r', self.old_op), True, True)
        self.old_op = ""


class AcquireProgress(base.AcquireProgress, TextProgress):
    """AcquireProgress for the text interface."""

    def __init__(self, outfile=None):
        # type: (Optional[io.TextIOBase]) -> None
        TextProgress.__init__(self, outfile)
        base.AcquireProgress.__init__(self)
        self._signal = None  # type: Union[Callable[[signal.Signals, types.FrameType], None], int, signal.Handlers, None] # noqa
        self._width = 80
        self._id = 1

    def start(self):
        # type: () -> None
        """Start an Acquire progress.

        In this case, the function sets up a signal handler for SIGWINCH, i.e.
        window resize signals. And it also sets id to 1.
        """
        base.AcquireProgress.start(self)
        self._signal = signal.signal(signal.SIGWINCH, self._winch)
        # Get the window size.
        self._winch()
        self._id = 1

    def _winch(self, *dummy):
        # type: (object) -> None
        """Signal handler for window resize signals."""
        if hasattr(self._file, "fileno") and os.isatty(self._file.fileno()):
            import fcntl
            import termios
            import struct
            buf = fcntl.ioctl(self._file, termios.TIOCGWINSZ, 8 * b' ')  # noqa
            dummy, col, dummy, dummy = struct.unpack('hhhh', buf)
            self._width = col - 1  # 1 for the cursor

    def ims_hit(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Called when an item is update (e.g. not modified on the server)."""
        base.AcquireProgress.ims_hit(self, item)
        line = _('Hit ') + item.description
        if item.owner.filesize:
            line += ' [%sB]' % apt_pkg.size_to_str(item.owner.filesize)
        self._write(line)

    def fail(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Called when an item is failed."""
        base.AcquireProgress.fail(self, item)
        if item.owner.status == item.owner.STAT_DONE:
            self._write(_("Ign ") + item.description)
        else:
            self._write(_("Err ") + item.description)
            self._write("  %s" % item.owner.error_text)

    def fetch(self, item):
        # type: (apt_pkg.AcquireItemDesc) -> None
        """Called when some of the item's data is fetched."""
        base.AcquireProgress.fetch(self, item)
        # It's complete already (e.g. Hit)
        if item.owner.complete:
            return
        item.owner.id = self._id
        self._id += 1
        line = _("Get:") + "%s %s" % (item.owner.id, item.description)
        if item.owner.filesize:
            line += (" [%sB]" % apt_pkg.size_to_str(item.owner.filesize))

        self._write(line)

    def pulse(self, owner):
        # type: (apt_pkg.Acquire) -> bool
        """Periodically invoked while the Acquire process is underway.

        Return False if the user asked to cancel the whole Acquire process."""
        base.AcquireProgress.pulse(self, owner)
        # only show progress on a tty to not clutter log files etc
        if (hasattr(self._file, "fileno") and
                not os.isatty(self._file.fileno())):
            return True

        # calculate progress
        percent = (((self.current_bytes + self.current_items) * 100.0) /
                        float(self.total_bytes + self.total_items))

        shown = False
        tval = '%i%%' % percent
        end = ""
        if self.current_cps:
            eta = int(float(self.total_bytes - self.current_bytes) /
                        self.current_cps)
            end = " %sB/s %s" % (apt_pkg.size_to_str(self.current_cps),
                                 apt_pkg.time_to_str(eta))

        for worker in owner.workers:
            val = ''
            if not worker.current_item:
                if worker.status:
                    val = ' [%s]' % worker.status
                    if len(tval) + len(val) + len(end) >= self._width:
                        break
                    tval += val
                    shown = True
                continue
            shown = True

            if worker.current_item.owner.id:
                val += " [%i %s" % (worker.current_item.owner.id,
                                    worker.current_item.shortdesc)
            else:
                val += ' [%s' % worker.current_item.description
            if worker.current_item.owner.active_subprocess:
                val += ' %s' % worker.current_item.owner.active_subprocess

            val += ' %sB' % apt_pkg.size_to_str(worker.current_size)

            # Add the total size and percent
            if worker.total_size and not worker.current_item.owner.complete:
                val += "/%sB %i%%" % (
                    apt_pkg.size_to_str(worker.total_size),
                    worker.current_size * 100.0 / worker.total_size)

            val += ']'

            if len(tval) + len(val) + len(end) >= self._width:
                # Display as many items as screen width
                break
            else:
                tval += val

        if not shown:
            tval += _(" [Working]")

        if self.current_cps:
            tval += (self._width - len(end) - len(tval)) * ' ' + end

        self._write(tval, False)
        return True

    def media_change(self, medium, drive):
        # type: (str, str) -> bool
        """Prompt the user to change the inserted removable media."""
        base.AcquireProgress.media_change(self, medium, drive)
        self._write(_("Media change: please insert the disc labeled\n"
                      " '%s'\n"
                      "in the drive '%s' and press enter\n") % (medium, drive))
        return input() not in ('c', 'C')

    def stop(self):
        # type: () -> None
        """Invoked when the Acquire process stops running."""
        base.AcquireProgress.stop(self)
        # Trick for getting a translation from apt
        self._write((_("Fetched %sB in %s (%sB/s)\n") % (
                    apt_pkg.size_to_str(self.fetched_bytes),
                    apt_pkg.time_to_str(self.elapsed_time),
                    apt_pkg.size_to_str(self.current_cps))).rstrip("\n"))

        # Delete the signal again.
        import signal
        signal.signal(signal.SIGWINCH, self._signal)


class CdromProgress(base.CdromProgress, TextProgress):
    """Text CD-ROM progress."""

    def ask_cdrom_name(self):
        # type: () -> Optional[str]
        """Ask the user to provide a name for the disc."""
        base.CdromProgress.ask_cdrom_name(self)
        self._write(_("Please provide a name for this medium, such as "
                      "'Debian 2.1r1 Disk 1'"), False)
        try:
            return str(input(":"))
        except KeyboardInterrupt:
            return None

    def update(self, text, current):
        # type: (str, int) -> None
        """Set the current progress."""
        base.CdromProgress.update(self, text, current)
        if text:
            self._write(text, False)

    def change_cdrom(self):
        # type: () -> bool
        """Ask the user to change the CD-ROM."""
        base.CdromProgress.change_cdrom(self)
        self._write(_("Please insert an installation medium and press enter"),
                    False)
        try:
            return bool(input() == '')
        except KeyboardInterrupt:
            return False
