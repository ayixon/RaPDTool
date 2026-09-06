# Copyright 2009 Canonical Ltd.  All rights reserved.

# This file is part of wadllib.
#
# wadllib is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# wadllib is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with wadllib. If not, see <http://www.gnu.org/licenses/>.
"""
Parser for ISO 8601 time strings
================================

>>> d = iso_strptime("2008-01-07T05:30:30.345323+03:00")
>>> d
datetime.datetime(2008, 1, 7, 5, 30, 30, 345323, tzinfo=TimeZone(10800))
>>> d.timetuple()
(2008, 1, 7, 5, 30, 30, 0, 7, 0)
>>> d.utctimetuple()
(2008, 1, 7, 2, 30, 30, 0, 7, 0)
>>> iso_strptime("2008-01-07T05:30:30.345323-03:00")
datetime.datetime(2008, 1, 7, 5, 30, 30, 345323, tzinfo=TimeZone(-10800))
>>> iso_strptime("2008-01-07T05:30:30.345323")
datetime.datetime(2008, 1, 7, 5, 30, 30, 345323)
>>> iso_strptime("2008-01-07T05:30:30")
datetime.datetime(2008, 1, 7, 5, 30, 30)
>>> iso_strptime("2008-01-07T05:30:30+02:00")
datetime.datetime(2008, 1, 7, 5, 30, 30, tzinfo=TimeZone(7200))
"""


import re
import datetime

RE_TIME = re.compile(r"""^
   # pattern matching date
   (?P<year>\d{4})\-(?P<month>\d{2})\-(?P<day>\d{2})
   # separator
   T
   # pattern matching time
   (?P<hour>\d{2})\:(?P<minutes>\d{2})\:(?P<seconds>\d{2})
   # pattern matching optional microseconds
   (\.(?P<microseconds>\d{6}))?
   # pattern matching optional timezone offset
   (?P<tz_offset>[\-\+]\d{2}\:\d{2})?
   $""", re.VERBOSE)

class TimeZone(datetime.tzinfo):

    def __init__(self, tz_string):
        hours, minutes = tz_string.lstrip("-+").split(":")
        self.stdoffset = datetime.timedelta(hours=int(hours),
                                            minutes=int(minutes))
        if tz_string.startswith("-"):
            self.stdoffset *= -1

    def __repr__(self):
        return "TimeZone(%s)" % (
            self.stdoffset.days*24*60*60 + self.stdoffset.seconds)

    def utcoffset(self, dt):
        return self.stdoffset

    def dst(self, dt):
        return datetime.timedelta(0)



def iso_strptime(time_str):
    x = RE_TIME.match(time_str)
    if not x:
        raise ValueError
    d = datetime.datetime(int(x.group("year")), int(x.group("month")),
        int(x.group("day")), int(x.group("hour")), int(x.group("minutes")),
        int(x.group("seconds")))
    if x.group("microseconds"):
        d = d.replace(microsecond=int(x.group("microseconds")))
    if x.group("tz_offset"):
        d = d.replace(tzinfo=TimeZone(x.group("tz_offset")))
    return d
