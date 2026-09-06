# Copyright (C) 2009 Canonical
#
# Authors:
#  Michael Vogt
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License as
#  published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
from __future__ import print_function

import datetime
import os

from typing import Optional, Tuple

import apt
import apt_pkg


def get_maintenance_end_date(release_date, m_months):
    # type: (datetime.datetime, int) -> Tuple[int, int]
    """
    get the (year, month) tuple when the maintenance for the distribution
    ends. Needs the data of the release and the number of months that
    its is supported as input
    """
    # calc end date
    years = m_months // 12
    months = m_months % 12
    support_end_year = (release_date.year + years +
                        (release_date.month + months) // 12)
    support_end_month = (release_date.month + months) % 12
    # special case: this happens when e.g. doing 2010-06 + 18 months
    if support_end_month == 0:
        support_end_month = 12
        support_end_year -= 1
    return (support_end_year, support_end_month)


def get_release_date_from_release_file(path):
    # type: (str) -> Optional[int]
    """
    return the release date as time_t for the given release file
    """
    if not path or not os.path.exists(path):
        return None

    with os.fdopen(apt_pkg.open_maybe_clear_signed_file(path)) as data:
        tag = apt_pkg.TagFile(data)
        section = next(tag)
        if "Date" not in section:
            return None
        date = section["Date"]
        return apt_pkg.str_to_time(date)


def get_release_filename_for_pkg(cache, pkgname, label, release):
    # type: (apt.Cache, str, str, str) -> Optional[str]
    " get the release file that provides this pkg "
    if pkgname not in cache:
        return None
    pkg = cache[pkgname]
    ver = None
    # look for the version that comes from the repos with
    # the given label and origin
    for aver in pkg._pkg.version_list:
        if aver is None or aver.file_list is None:
            continue
        for ver_file, _index in aver.file_list:
            # print verFile
            if (ver_file.origin == label and
                    ver_file.label == label and
                    ver_file.archive == release):
                ver = aver
    if not ver:
        return None
    indexfile = cache._list.find_index(ver.file_list[0][0])
    for metaindex in cache._list.list:
        for m in metaindex.index_files:
            if (indexfile and
                    indexfile.describe == m.describe and
                    indexfile.is_trusted):
                dirname = apt_pkg.config.find_dir("Dir::State::lists")
                for relfile in ['InRelease', 'Release']:
                    name = (apt_pkg.uri_to_filename(metaindex.uri) +
                            "dists_%s_%s" % (metaindex.dist, relfile))
                    if os.path.exists(dirname + name):
                        return dirname + name
    return None
