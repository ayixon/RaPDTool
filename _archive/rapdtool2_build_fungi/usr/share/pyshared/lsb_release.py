#!/usr/bin/python

# LSB release detection module for Debian
# (C) 2005-10 Chris Lawrence <lawrencc@debian.org>
# (C) 2018 Didier Raboud <odyx@debian.org>

#    This package is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; version 2 dated June, 1991.

#    This package is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this package; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
#    02110-1301 USA

# Python3-compatible print() function
from __future__ import print_function

import sys
import subprocess
import os
import re
import warnings
import csv

def get_distro_info(origin='Debian'):
    try:
        FileNotFoundException = FileNotFoundError
    except NameError:
        # There is no FileNotFoundError in python2
        FileNotFoundException = IOError

    try:
        csvfile = open('/usr/share/distro-info/%s.csv' % origin.lower())
    except FileNotFoundException:
        # Unknown distro, fallback to Debian
        csvfile = open('/usr/share/distro-info/debian.csv')

    reader = csv.DictReader(csvfile)
    global RELEASE_CODENAME_LOOKUP, RELEASES_ORDER, TESTING_CODENAME
    RELEASE_CODENAME_LOOKUP = { r['version']: r['series'] for r in reader if r['version']}
    RELEASES_ORDER = list(RELEASE_CODENAME_LOOKUP.items())
    RELEASES_ORDER.sort(key=lambda n: float(n[0]))
    RELEASES_ORDER = list(list(zip(*RELEASES_ORDER))[1])

    if origin.lower() == 'debian':
        TESTING_CODENAME = 'unknown.new.testing'
        RELEASES_ORDER.extend(['stable', 'proposed-updates', 'testing', 'testing-proposed-updates', 'unstable', 'sid'])

    csvfile.close()

# Populate default distro info
get_distro_info()

def lookup_codename(release, unknown=None):
    m = re.match(r'(\d+)\.(\d+)(r(\d+))?', release)
    if not m:
        return unknown

    if int(m.group(1)) < 7:
        shortrelease = '%s.%s' % m.group(1,2)
    else:
        shortrelease = '%s' % m.group(1)
    return RELEASE_CODENAME_LOOKUP.get(shortrelease, unknown)

# LSB compliance packages... may grow eventually
PACKAGES = 'lsb-core lsb-cxx lsb-graphics lsb-desktop lsb-languages lsb-multimedia lsb-printing lsb-security'

modnamere = re.compile(r'lsb-(?P<module>[a-z0-9]+)-(?P<arch>[^ ]+)(?: \(= (?P<version>[0-9.]+)\))?')

def valid_lsb_versions(version, module):
    # If a module is ever released that only appears in >= version, deal
    # with that here
    if version == '3.0':
        return ['2.0', '3.0']
    elif version == '3.1':
        if module in ('desktop', 'qt4'):
            return ['3.1']
        elif module == 'cxx':
            return ['3.0', '3.1']
        else:
            return ['2.0', '3.0', '3.1']
    elif version == '3.2':
        if module == 'desktop':
            return ['3.1', '3.2']
        elif module == 'qt4':
            return ['3.1']
        elif module in ('printing', 'languages', 'multimedia'):
            return ['3.2']
        elif module == 'cxx':
            return ['3.0', '3.1', '3.2']
        else:
            return ['2.0', '3.0', '3.1', '3.2']
    elif version == '4.0':
        if module == 'desktop':
            return ['3.1', '3.2', '4.0']
        elif module == 'qt4':
            return ['3.1']
        elif module in ('printing', 'languages', 'multimedia'):
            return ['3.2', '4.0']
        elif module == 'security':
            return ['4.0']
        elif module == 'cxx':
            return ['3.0', '3.1', '3.2', '4.0']
        else:
            return ['2.0', '3.0', '3.1', '3.2', '4.0']
    elif version == '4.1':
        if module == 'desktop':
            return ['3.1', '3.2', '4.0', '4.1']
        elif module == 'qt4':
            return ['3.1']
        elif module in ('printing', 'languages', 'multimedia'):
            return ['3.2', '4.0', '4.1']
        elif module == 'security':
            return ['4.0', '4.1']
        elif module == 'cxx':
            return ['3.0', '3.1', '3.2', '4.0', '4.1']
        else:
            return ['2.0', '3.0', '3.1', '3.2', '4.0', '4.1']


    return [version]

try:
    set # introduced in 2.4
except NameError:
    import sets
    set = sets.Set

# This is Debian-specific at present
def check_modules_installed():
    # Find which LSB modules are installed on this system
    C_env = os.environ.copy(); C_env['LC_ALL'] = 'C'
    output = subprocess.Popen(['dpkg-query','-f',"${Version} ${Provides}\n",'-W'] + PACKAGES.split(),
                              env=C_env,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              close_fds=True).communicate()[0].decode('utf-8')

    if not output:
        return []

    modules = set()
    for line in output.split(os.linesep):
        if not line:
           break
        version, provides = line.split(' ', 1)
        # Debian package versions can be 3.2-$REV, 3.2+$REV or 3.2~$REV.
        version = re.split('[-+~]', version, 1)[0]
        for pkg in provides.split(','):
            mob = modnamere.search(pkg)
            if not mob:
                continue

            mgroups = mob.groupdict()
            # If no versioned provides...
            if mgroups.get('version'):
                module = '%(module)s-%(version)s-%(arch)s' % mgroups
                modules.add(module)
            else:
                module = mgroups['module']
                for v in valid_lsb_versions(version, module):
                    mgroups['version'] = v
                    module = '%(module)s-%(version)s-%(arch)s' % mgroups
                    modules.add(module)

    modules = list(modules)
    modules.sort()
    return modules

longnames = {'v' : 'version', 'o': 'origin', 'a': 'suite',
             'c' : 'component', 'l': 'label'}

def parse_policy_line(data):
    retval = {}
    bits = data.split(',')
    for bit in bits:
        kv = bit.split('=', 1)
        if len(kv) > 1:
            k, v = kv[:2]
            if k in longnames:
                retval[longnames[k]] = v
    return retval

def release_index(x):
    suite = x[1].get('suite')
    if suite:
        if suite in RELEASES_ORDER:
            return int(len(RELEASES_ORDER) - RELEASES_ORDER.index(suite))
        else:
            try:
                return float(suite)
            except ValueError:
                return 0
    return 0

def compare_release(x, y):
    warnings.warn('compare_release(x,y) is deprecated; please use the release_index(x) as key for sort() instead.', DeprecationWarning, stacklevel=2)
    suite_x_i = release_index(x)
    suite_y_i = release_index(y)
    
    try:
        return suite_x_i - suite_y_i
    except TypeError:
        return (suite_x_i > suite_y_i) - (suite_x_i < suite_y_i)

def parse_apt_policy():
    data = []
    
    C_env = os.environ.copy(); C_env['LC_ALL'] = 'C.UTF-8'
    policy = subprocess.Popen(['apt-cache','policy'],
                              env=C_env,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE,
                              close_fds=True).communicate()[0].decode('utf-8')
    for line in policy.split('\n'):
        line = line.strip()
        m = re.match(r'(-?\d+)', line)
        if m:
            priority = int(m.group(1))
        if line.startswith('release'):
            bits = line.split(' ', 1)
            if len(bits) > 1:
                data.append( (priority, parse_policy_line(bits[1])) )

    return data

def guess_release_from_apt(origin='Debian', component='main',
                           ignoresuites=('experimental'),
                           label='Debian',
                           alternate_olabels={'Debian Ports': ('ftp.ports.debian.org', 'ftp.debian-ports.org')}):
    releases = parse_apt_policy()

    if not releases:
        return None

    # We only care about the specified origin, component, and label
    releases = [x for x in releases if (
        x[1].get('origin', '') == origin and
        x[1].get('suite', '') not in ignoresuites and
        x[1].get('component', '') == component and
        x[1].get('label', '') == label) or (
        x[1].get('origin', '') in alternate_olabels and
        x[1].get('label', '') in alternate_olabels.get(x[1].get('origin', '')))]

    # Check again to make sure we didn't wipe out all of the releases
    if not releases:
        return None
    
    releases.sort(key=lambda tuple: tuple[0],reverse=True)

    # We've sorted the list by descending priority, so the first entry should
    # be the "main" release in use on the system

    max_priority = releases[0][0]
    releases = [x for x in releases if x[0] == max_priority]
    releases.sort(key=release_index)

    return releases[0][1]

def guess_debian_release():
    distinfo = {}

    distinfo['ID'] = 'Debian'
    # Use /etc/dpkg/origins/default to fetch the distribution name
    etc_dpkg_origins_default = os.environ.get('LSB_ETC_DPKG_ORIGINS_DEFAULT','/etc/dpkg/origins/default')
    if os.path.exists(etc_dpkg_origins_default):
        try:
            with open(etc_dpkg_origins_default) as dpkg_origins_file:
                for line in dpkg_origins_file:
                    try:
                        (header, content) = line.split(': ', 1)
                        header = header.lower()
                        content = content.strip()
                        if header == 'vendor':
                            distinfo['ID'] = content
                    except ValueError:
                        pass
        except IOError as msg:
            print('Unable to open ' + etc_dpkg_origins_default + ':', str(msg), file=sys.stderr)

    # Populate RELEASES_ORDER for the correct distro
    get_distro_info(distinfo['ID'])

    kern = os.uname()[0]
    if kern in ('Linux', 'Hurd', 'NetBSD'):
        distinfo['OS'] = 'GNU/'+kern
    elif kern == 'FreeBSD':
        distinfo['OS'] = 'GNU/k'+kern
    elif kern in ('GNU/Linux', 'GNU/kFreeBSD'):
        distinfo['OS'] = kern
    else:
        distinfo['OS'] = 'GNU'

    distinfo['DESCRIPTION'] = '%(ID)s %(OS)s' % distinfo

    etc_debian_version = os.environ.get('LSB_ETC_DEBIAN_VERSION','/etc/debian_version')
    if os.path.exists(etc_debian_version):
        try:
            with open(etc_debian_version) as debian_version:
                release = debian_version.read().strip()
        except IOError as msg:
            print('Unable to open ' + etc_debian_version + ':', str(msg), file=sys.stderr)
            release = 'unknown'
            
        if not release[0:1].isalpha():
            # /etc/debian_version should be numeric
            codename = lookup_codename(release, 'n/a')
            distinfo.update({ 'RELEASE' : release, 'CODENAME' : codename })
        elif release.endswith('/sid'):
            if release.rstrip('/sid').lower() != 'testing':
                global TESTING_CODENAME
                TESTING_CODENAME = release.rstrip('/sid')
            distinfo['RELEASE'] = 'testing/unstable'
        else:
            distinfo['RELEASE'] = release

    # Only use apt information if we did not get the proper information
    # from /etc/debian_version or if we don't have a codename
    # (which will happen if /etc/debian_version does not contain a
    # number but some text like 'testing/unstable' or 'lenny/sid')
    #
    # This is slightly faster and less error prone in case the user
    # has an entry in his /etc/apt/sources.list but has not actually
    # upgraded the system.
    if not distinfo.get('CODENAME'):
      rinfo = guess_release_from_apt()
      if rinfo:
        release = rinfo.get('version')

        # Special case Debian-Ports as their Release file has 'version': '1.0'
        if release == '1.0' and rinfo.get('origin') == 'Debian Ports' and rinfo.get('label') in ('ftp.ports.debian.org', 'ftp.debian-ports.org'):
            release = None
            rinfo.update({'suite': 'unstable'})

        if release:
            codename = lookup_codename(release, 'n/a')
        else:
            release = rinfo.get('suite', 'unstable')
            if release == 'testing':
                # Would be nice if I didn't have to hardcode this.
                codename = TESTING_CODENAME
            else:
                codename = 'sid'
        distinfo.update({ 'RELEASE' : release, 'CODENAME' : codename })

    if distinfo.get('RELEASE'):
        distinfo['DESCRIPTION'] += ' %(RELEASE)s' % distinfo
    if distinfo.get('CODENAME'):
        distinfo['DESCRIPTION'] += ' (%(CODENAME)s)' % distinfo

    return distinfo

# Whatever is guessed above can be overridden in /usr/lib/os-release by derivatives
def get_os_release():
    distinfo = {}
    os_release = os.environ.get('LSB_OS_RELEASE', '/usr/lib/os-release')
    if os.path.exists(os_release):
        try:
            with open(os_release) as os_release_file:
                for line in os_release_file:
                    line = line.strip()
                    if not line:
                        continue
                    # Skip invalid lines
                    if not '=' in line:
                        continue
                    var, arg = line.split('=', 1)
                    if arg.startswith('"') and arg.endswith('"'):
                        arg = arg[1:-1]
                    if arg: # Ignore empty arguments
                        # Concert os-release to lsb-release-style
                        if var == 'VERSION_ID':
                            # It'll ignore point-releases
                            distinfo['RELEASE'] = arg.strip()
                        elif var == 'VERSION_CODENAME':
                            distinfo['CODENAME'] = arg.strip()
                        elif var == 'ID':
                            # ID=debian
                            distinfo['ID'] = arg.strip().title()
                        elif var == 'PRETTY_NAME':
                            distinfo['DESCRIPTION'] = arg.strip()
        except IOError as msg:
            print('Unable to open ' + os_release + ':', str(msg), file=sys.stderr)

    return distinfo

def get_distro_information():
    lsbinfo = get_os_release()
    # OS is only used inside guess_debian_release anyway
    for key in ('ID', 'RELEASE', 'CODENAME', 'DESCRIPTION',):
        if key not in lsbinfo:
            distinfo = guess_debian_release()
            distinfo.update(lsbinfo)
            return distinfo
    else:
        return lsbinfo

def test():
    print(get_distro_information())
    print(check_modules_installed())

if __name__ == '__main__':
    test()
