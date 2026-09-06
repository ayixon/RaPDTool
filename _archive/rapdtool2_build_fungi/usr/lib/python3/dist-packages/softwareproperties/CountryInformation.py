# country.py - provides country based information
#
#  Copyright (c) 2006 FSF Europe
#
#  Author:
#       Sebastian Heinlein <glatzor@ubuntu.com>
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

import os
import gettext
from xml.etree.ElementTree import ElementTree

class CountryInformation(object):
  def __init__(self):
    # get a list of country codes and real names
    self.countries = {}
    fname = "/usr/share/xml/iso-codes/iso_3166.xml"
    if os.path.exists(fname):
      et = ElementTree(file=fname)
      it = et.iter('iso_3166_entry')
      for elm in it:
        if "common_name" in elm.attrib:
          descr = elm.attrib["common_name"]
        else:
          descr = elm.attrib["name"]
        if "alpha_2_code" in elm.attrib:
          code = elm.attrib["alpha_2_code"]
        else:
          code = elm.attrib["alpha_3_code"]
        self.countries[code] = gettext.dgettext('iso_3166',descr)
    self.country = None
    self.code = None
    locale = os.getenv("LANG", default="en.UK")
    a = locale.find("_")
    z = locale.find(".")
    if z == -1:
        z = len(locale)
    self.code = locale[a+1:z]
    self.country = self.get_country_name(self.code)

  def get_country_name(self, code):
    if code in self.countries:
        name = self.countries[code]
        return name
    else:
        return code
