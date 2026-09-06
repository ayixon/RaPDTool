# package.py - apt package abstraction
#
#  Copyright (c) 2005-2009 Canonical
#
#  Author: Michael Vogt <michael.vogt@ubuntu.com>
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
"""Functionality related to packages."""
from __future__ import print_function

import logging
import os
import sys
import re
import socket
import subprocess
import threading

from http.client import BadStatusLine
from urllib.error import HTTPError
from urllib.request import urlopen

from typing import (Any, Iterable, Iterator, List, Optional, Set,
                    Tuple, Union, no_type_check, Mapping,
                    Sequence)

import apt_pkg
import apt.progress.text

from apt.progress.base import (
    AcquireProgress,
    InstallProgress,
)

from apt_pkg import gettext as _

__all__ = ('BaseDependency', 'Dependency', 'Origin', 'Package', 'Record',
           'Version', 'VersionList')


def _file_is_same(path, size, hashes):
    # type: (str, int, apt_pkg.HashStringList) -> bool
    """Return ``True`` if the file is the same."""
    if os.path.exists(path) and os.path.getsize(path) == size:
        with open(path) as fobj:
            return apt_pkg.Hashes(fobj).hashes == hashes
    return False


class FetchError(Exception):
    """Raised when a file could not be fetched."""


class UntrustedError(FetchError):
    """Raised when a file did not have a trusted hash."""


class BaseDependency(object):
    """A single dependency."""

    class __dstr(str):
        """Compare helper for compatibility with old third-party code.

        Old third-party code might still compare the relation with the
        previously used relations (<<,<=,==,!=,>=,>>,) instead of the curently
        used ones (<,<=,=,!=,>=,>,). This compare helper lets < match to <<,
        > match to >> and = match to ==.
        """

        def __eq__(self, other):
            # type: (object) -> bool
            if str.__eq__(self, other):
                return True
            elif str.__eq__(self, '<'):
                return str.__eq__('<<', other)
            elif str.__eq__(self, '>'):
                return str.__eq__('>>', other)
            elif str.__eq__(self, '='):
                return str.__eq__('==', other)
            else:
                return False

        def __ne__(self, other):
            # type: (object) -> bool
            return not self.__eq__(other)

    def __init__(self, version, dep):
        # type: (Version, apt_pkg.Dependency) -> None
        self._version = version  # apt.package.Version
        self._dep = dep  # apt_pkg.Dependency

    def __str__(self):
        # type: () -> str
        return '%s: %s' % (self.rawtype, self.rawstr)

    def __repr__(self):
        # type: () -> str
        return ('<BaseDependency: name:%r relation:%r version:%r rawtype:%r>'
                % (self.name, self.relation, self.version, self.rawtype))

    @property
    def name(self):
        # type: () -> str
        """The name of the target package."""
        return self._dep.target_pkg.name

    @property
    def relation(self):
        # type: () -> str
        """The relation (<, <=, =, !=, >=, >, '') in mathematical notation.

        The empty string will be returned in case of an unversioned dependency.
        """
        return self.__dstr(self._dep.comp_type)

    @property
    def relation_deb(self):
        # type: () -> str
        """The relation (<<, <=, =, !=, >=, >>, '') in Debian notation.

        The empty string will be returned in case of an unversioned dependency.
        For more details see the Debian Policy Manual on the syntax of
        relationship fields:
        https://www.debian.org/doc/debian-policy/ch-relationships.html#s-depsyntax  # noqa

        .. versionadded:: 1.0.0
        """
        return self._dep.comp_type_deb

    @property
    def version(self):
        # type: () -> str
        """The target version or an empty string.

        Note that the version is only an empty string in case of an unversioned
        dependency. In this case the relation is also an empty string.
        """
        return self._dep.target_ver

    @property
    def target_versions(self):
        # type: () -> List[Version]
        """A list of all Version objects which satisfy this dependency.

        .. versionadded:: 1.0.0
        """
        tvers = []
        _tvers = self._dep.all_targets()  # type: List[apt_pkg.Version]
        for _tver in _tvers:  # type: apt_pkg.Version
            _pkg = _tver.parent_pkg  # type: apt_pkg.Package
            cache = self._version.package._pcache  # apt.cache.Cache
            pkg = cache._rawpkg_to_pkg(_pkg)  # apt.package.Package
            tver = Version(pkg, _tver)  # apt.package.Version
            tvers.append(tver)
        return tvers

    @property
    def installed_target_versions(self):
        # type: () -> List[Version]
        """A list of all installed Version objects which satisfy this dep.

        .. versionadded:: 1.0.0
        """
        return [tver for tver in self.target_versions if tver.is_installed]

    @property
    def rawstr(self):
        # type: () -> str
        """String represenation of the dependency.

        Returns the string representation of the dependency as it would be
        written in the debian/control file.  The string representation does not
        include the type of the dependency.

        Example for an unversioned dependency:
          python3

        Example for a versioned dependency:
          python3 >= 3.2

        .. versionadded:: 1.0.0
        """
        if self.version:
            return '%s %s %s' % (self.name, self.relation_deb, self.version)
        else:
            return self.name

    @property
    def rawtype(self):
        # type: () -> str
        """Type of the dependency.

        This should be one of 'Breaks', 'Conflicts', 'Depends', 'Enhances',
        'PreDepends', 'Recommends', 'Replaces', 'Suggests'.

        Additional types might be added in the future.
        """
        return self._dep.dep_type_untranslated

    @property
    def pre_depend(self):
        # type: () -> bool
        """Whether this is a PreDepends."""
        return self._dep.dep_type_untranslated == 'PreDepends'


class Dependency(List[BaseDependency]):
    """Represent an Or-group of dependencies.

    Attributes defined here:
        or_dependencies - The possible choices
        rawstr - String represenation of the Or-group of dependencies
        rawtype - The type of the dependencies in the Or-group
        target_version - A list of Versions which satisfy this Or-group of deps
    """

    def __init__(self, version, base_deps, rawtype):
        # type: (Version, List[BaseDependency], str) -> None
        super(Dependency, self).__init__(base_deps)
        self._version = version  # apt.package.Version
        self._rawtype = rawtype

    def __str__(self):
        # type: () -> str
        return '%s: %s' % (self.rawtype, self.rawstr)

    def __repr__(self):
        # type: () -> str
        return '<Dependency: [%s]>' % (', '.join(repr(bd) for bd in self))

    @property
    def or_dependencies(self):
        # type: () -> Dependency
        return self

    @property
    def rawstr(self):
        # type: () -> str
        """String represenation of the Or-group of dependencies.

        Returns the string representation of the Or-group of dependencies as it
        would be written in the debian/control file.  The string representation
        does not include the type of the Or-group of dependencies.

        Example:
          python2 >= 2.7 | python3

        .. versionadded:: 1.0.0
        """
        return ' | '.join(bd.rawstr for bd in self)

    @property
    def rawtype(self):
        # type: () -> str
        """Type of the Or-group of dependency.

        This should be one of 'Breaks', 'Conflicts', 'Depends', 'Enhances',
        'PreDepends', 'Recommends', 'Replaces', 'Suggests'.

        Additional types might be added in the future.

        .. versionadded:: 1.0.0
        """
        return self._rawtype

    @property
    def target_versions(self):
        # type: () -> List[Version]
        """A list of all Version objects which satisfy this Or-group of deps.

        .. versionadded:: 1.0.0
        """
        tvers = []  # type: List[Version]
        for bd in self:  # apt.package.Dependency
            for tver in bd.target_versions:  # apt.package.Version
                if tver not in tvers:
                    tvers.append(tver)
        return tvers

    @property
    def installed_target_versions(self):
        # type: () -> List[Version]
        """A list of all installed Version objects which satisfy this dep.

        .. versionadded:: 1.0.0
        """
        return [tver for tver in self.target_versions if tver.is_installed]


class Origin(object):
    """The origin of a version.

    Attributes defined here:
        archive   - The archive (eg. unstable)
        component - The component (eg. main)
        label     - The Label, as set in the Release file
        origin    - The Origin, as set in the Release file
        codename  - The Codename, as set in the Release file
        site      - The hostname of the site.
        trusted   - Boolean value whether this is trustworthy.
    """

    def __init__(self, pkg, packagefile):
        # type: (Package, apt_pkg.PackageFile) -> None
        self.archive = packagefile.archive
        self.component = packagefile.component
        self.label = packagefile.label
        self.origin = packagefile.origin
        self.codename = packagefile.codename
        self.site = packagefile.site
        self.not_automatic = packagefile.not_automatic
        # check the trust
        indexfile = pkg._pcache._list.find_index(packagefile)
        if indexfile and indexfile.is_trusted:
            self.trusted = True
        else:
            self.trusted = False

    def __repr__(self):
        # type: () -> str
        return ("<Origin component:%r archive:%r origin:%r label:%r "
                "site:%r isTrusted:%r>") % (self.component, self.archive,
                                            self.origin, self.label,
                                            self.site, self.trusted)


class Record(Mapping[Any, Any]):
    """Record in a Packages file

    Represent a record as stored in a Packages file. You can use this like
    a dictionary mapping the field names of the record to their values::

        >>> record = Record("Package: python-apt\\nVersion: 0.8.0\\n\\n")
        >>> record["Package"]
        'python-apt'
        >>> record["Version"]
        '0.8.0'

    For example, to get the tasks of a package from a cache, you could do::

        package.candidate.record["Tasks"].split()

    Of course, you can also use the :attr:`Version.tasks` property.

    """

    def __init__(self, record_str):
        # type: (str) -> None
        self._rec = apt_pkg.TagSection(record_str)

    def __hash__(self):
        # type: () -> int
        return hash(self._rec)

    def __str__(self):
        # type: () -> str
        return str(self._rec)

    def __getitem__(self, key):
        # type: (str) -> str
        return self._rec[key]

    def __contains__(self, key):
        # type: (object) -> bool
        return key in self._rec

    def __iter__(self):
        # type: () -> Iterator[str]
        return iter(self._rec.keys())

    def iteritems(self):
        # type: () -> Iterable[Tuple[object, str]]
        """An iterator over the (key, value) items of the record."""
        for key in self._rec.keys():
            yield key, self._rec[key]

    def get(self, key, default=None):
        # type: (str, object) -> object
        """Return record[key] if key in record, else *default*.

        The parameter *default* must be either a string or None.
        """
        return self._rec.get(key, default)

    def has_key(self, key):
        # type: (str) -> bool
        """deprecated form of ``key in x``."""
        return key in self._rec

    def __len__(self):
        # type: () -> int
        return len(self._rec)


class Version(object):
    """Representation of a package version.

    The Version class contains all information related to a
    specific package version.

    .. versionadded:: 0.7.9
    """

    def __init__(self, package, cand):
        # type: (Package, apt_pkg.Version) -> None
        self.package = package
        self._cand = cand
        self.package._pcache._weakversions.add(self)

    def _cmp(self, other):
        # type: (Any) -> Union[int, Any]
        """Compares against another apt.Version object or a version string.

        This method behaves like Python 2's cmp builtin and returns an integer
        according to the outcome.  The return value is negative in case of
        self < other, zero if self == other and positive if self > other.

        The comparison includes the package name and architecture if other is
        an apt.Version object.  If other isn't an apt.Version object it'll be
        assumed that other is a version string (without package name/arch).

        .. versionchanged:: 1.0.0
        """
        # Assume that other is an apt.Version object.
        try:
            self_name = self.package.fullname
            other_name = other.package.fullname
            if self_name < other_name:
                return -1
            elif self_name > other_name:
                return 1
            return apt_pkg.version_compare(self._cand.ver_str, other.version)
        except AttributeError:
            # Assume that other is a string that only contains the version.
            try:
                return apt_pkg.version_compare(self._cand.ver_str, other)
            except TypeError:
                return NotImplemented

    def __eq__(self, other):
        # type: (object) -> bool
        return self._cmp(other) == 0

    def __ge__(self, other):
        # type: (Version) -> bool
        return self._cmp(other) >= 0

    def __gt__(self, other):
        # type: (Version) -> bool
        return self._cmp(other) > 0

    def __le__(self, other):
        # type: (Version) -> bool
        return self._cmp(other) <= 0

    def __lt__(self, other):
        # type: (Version) -> bool
        return self._cmp(other) < 0

    def __ne__(self, other):
        # type: (object) -> Union[bool, Any]
        try:
            return self._cmp(other) != 0
        except TypeError:
            return NotImplemented

    def __hash__(self):
        # type: () -> int
        return self._cand.hash

    def __str__(self):
        # type: () -> str
        return '%s=%s' % (self.package.name, self.version)

    def __repr__(self):
        # type: () -> str
        return '<Version: package:%r version:%r>' % (self.package.name,
                                                     self.version)

    @property
    def _records(self):
        # type: () -> apt_pkg.PackageRecords
        """Internal helper that moves the Records to the right position."""
        # If changing lookup, change fetch_binary() as well
        if not self.package._pcache._records.lookup(self._cand.file_list[0]):
            raise LookupError("Could not lookup record")

        return self.package._pcache._records

    @property
    def _translated_records(self):
        # type: () -> Optional[apt_pkg.PackageRecords]
        """Internal helper to get the translated description."""
        desc_iter = self._cand.translated_description
        if self.package._pcache._records.lookup(desc_iter.file_list.pop(0)):
            return self.package._pcache._records
        return None

    @property
    def installed_size(self):
        # type: () -> int
        """Return the size of the package when installed."""
        return self._cand.installed_size

    @property
    def homepage(self):
        # type: () -> str
        """Return the homepage for the package."""
        return self._records.homepage

    @property
    def size(self):
        # type: () -> int
        """Return the size of the package."""
        return self._cand.size

    @property
    def architecture(self):
        # type: () -> str
        """Return the architecture of the package version."""
        return self._cand.arch

    @property
    def downloadable(self):
        # type: () -> bool
        """Return whether the version of the package is downloadable."""
        return bool(self._cand.downloadable)

    @property
    def is_installed(self):
        # type: () -> bool
        """Return wether this version of the package is currently installed.

        .. versionadded:: 1.0.0
        """
        inst_ver = self.package.installed
        return (inst_ver is not None and inst_ver._cand.id == self._cand.id)

    @property
    def version(self):
        # type: () -> str
        """Return the version as a string."""
        return self._cand.ver_str

    @property
    def summary(self):
        # type: () -> Optional[str]
        """Return the short description (one line summary)."""
        records = self._translated_records
        return records.short_desc if records is not None else None

    @property
    def raw_description(self):
        # type: () -> str
        """return the long description (raw)."""
        return self._records.long_desc

    @property
    def section(self):
        # type: () -> str
        """Return the section of the package."""
        return self._cand.section

    @property
    def description(self):
        # type: () -> str
        """Return the formatted long description.

        Return the formatted long description according to the Debian policy
        (Chapter 5.6.13).
        See http://www.debian.org/doc/debian-policy/ch-controlfields.html
        for more information.
        """
        desc = ''
        records = self._translated_records
        dsc = records.long_desc if records is not None else None

        if not dsc:
            return _("Missing description for '%s'."
                     "Please report.") % (self.package.name)

        try:
            if not isinstance(dsc, str):
                # Only convert where needed (i.e. Python 2.X)
                dsc = dsc.decode("utf-8")
        except UnicodeDecodeError as err:
            return _("Invalid unicode in description for '%s' (%s). "
                     "Please report.") % (self.package.name, err)

        lines = iter(dsc.split("\n"))
        # Skip the first line, since its a duplication of the summary
        next(lines)
        for raw_line in lines:
            if raw_line.strip() == ".":
                # The line is just line break
                if not desc.endswith("\n"):
                    desc += "\n\n"
                continue
            if raw_line.startswith("  "):
                # The line should be displayed verbatim without word wrapping
                if not desc.endswith("\n"):
                    line = "\n%s\n" % raw_line[2:]
                else:
                    line = "%s\n" % raw_line[2:]
            elif raw_line.startswith(" "):
                # The line is part of a paragraph.
                if desc.endswith("\n") or desc == "":
                    # Skip the leading white space
                    line = raw_line[1:]
                else:
                    line = raw_line
            else:
                line = raw_line
            # Add current line to the description
            desc += line
        return desc

    @property
    def source_name(self):
        # type: () -> str
        """Return the name of the source package."""
        try:
            return self._records.source_pkg or self.package.shortname
        except IndexError:
            return self.package.shortname

    @property
    def source_version(self):
        # type: () -> str
        """Return the version of the source package."""
        try:
            return self._records.source_ver or self._cand.ver_str
        except IndexError:
            return self._cand.ver_str

    @property
    def priority(self):
        # type: () -> str
        """Return the priority of the package, as string."""
        return self._cand.priority_str

    @property
    def policy_priority(self):
        # type: () -> int
        """Return the internal policy priority as a number.
           See apt_preferences(5) for more information about what it means.
        """
        return self.package._pcache._depcache.policy.get_priority(self._cand)

    @property
    def record(self):
        # type: () -> Record
        """Return a Record() object for this version.

        Return a Record() object for this version which provides access
        to the raw attributes of the candidate version
        """
        return Record(self._records.record)

    def get_dependencies(self, *types):
        # type: (str) -> List[Dependency]
        """Return a list of Dependency objects for the given types.

        Multiple types can be specified. Possible types are:
        'Breaks', 'Conflicts', 'Depends', 'Enhances', 'PreDepends',
        'Recommends', 'Replaces', 'Suggests'

        Additional types might be added in the future.
        """
        depends_list = []
        depends = self._cand.depends_list
        for type_ in types:
            try:
                for dep_ver_list in depends[type_]:
                    base_deps = []
                    for dep_or in dep_ver_list:
                        base_deps.append(BaseDependency(self, dep_or))
                    depends_list.append(Dependency(self, base_deps, type_))
            except KeyError:
                pass
        return depends_list

    @property
    def provides(self):
        # type: () -> List[str]
        """ Return a list of names that this version provides."""
        return [p[0] for p in self._cand.provides_list]

    @property
    def enhances(self):
        # type: () -> List[Dependency]
        """Return the list of enhances for the package version."""
        return self.get_dependencies("Enhances")

    @property
    def dependencies(self):
        # type: () -> List[Dependency]
        """Return the dependencies of the package version."""
        return self.get_dependencies("PreDepends", "Depends")

    @property
    def recommends(self):
        # type: () -> List[Dependency]
        """Return the recommends of the package version."""
        return self.get_dependencies("Recommends")

    @property
    def suggests(self):
        # type: () -> List[Dependency]
        """Return the suggests of the package version."""
        return self.get_dependencies("Suggests")

    @property
    def origins(self):
        # type: () -> List[Origin]
        """Return a list of origins for the package version."""
        origins = []
        for (packagefile, _unused) in self._cand.file_list:
            origins.append(Origin(self.package, packagefile))
        return origins

    @property
    def filename(self):
        # type: () -> str
        """Return the path to the file inside the archive.

        .. versionadded:: 0.7.10
        """
        return self._records.filename

    @property
    def md5(self):
        # type: () -> str
        """Return the md5sum of the binary.

        .. versionadded:: 0.7.10
        """
        return self._records.md5_hash

    @property
    def sha1(self):
        # type: () -> str
        """Return the sha1sum of the binary.

        .. versionadded:: 0.7.10
        """
        return self._records.sha1_hash

    @property
    def sha256(self):
        # type: () -> str
        """Return the sha256sum of the binary.

        .. versionadded:: 0.7.10
        """
        return self._records.sha256_hash

    @property
    def tasks(self):
        # type: () -> Set[str]
        """Get the tasks of the package.

        A set of the names of the tasks this package belongs to.

        .. versionadded:: 0.8.0
        """
        return set(self.record["Task"].split())

    def _uris(self):
        # type: () -> Iterator[str]
        """Return an iterator over all available urls.

        .. versionadded:: 0.7.10
        """
        for (packagefile, _unused) in self._cand.file_list:
            indexfile = self.package._pcache._list.find_index(packagefile)
            if indexfile:
                yield indexfile.archive_uri(self._records.filename)

    @property
    def uris(self):
        # type: () -> List[str]
        """Return a list of all available uris for the binary.

        .. versionadded:: 0.7.10
        """
        return list(self._uris())

    @property
    def uri(self):
        # type: () -> Optional[str]
        """Return a single URI for the binary.

        .. versionadded:: 0.7.10
        """
        try:
            return next(iter(self._uris()))
        except StopIteration:
            return None

    def fetch_binary(self, destdir='', progress=None,
                     allow_unauthenticated=None):
        # type: (str, Optional[AcquireProgress], Optional[bool]) -> str
        """Fetch the binary version of the package.

        The parameter *destdir* specifies the directory where the package will
        be fetched to.

        The parameter *progress* may refer to an apt_pkg.AcquireProgress()
        object. If not specified or None, apt.progress.text.AcquireProgress()
        is used.

        The keyword-only parameter *allow_unauthenticated* specifies whether
        to allow unauthenticated downloads. If not specified, it defaults to
        the configuration option `APT::Get::AllowUnauthenticated`.

        .. versionadded:: 0.7.10
        """
        if allow_unauthenticated is None:
            allow_unauthenticated = apt_pkg.config.find_b("APT::Get::"
                                        "AllowUnauthenticated", False)
        base = os.path.basename(self._records.filename)
        destfile = os.path.join(destdir, base)
        if _file_is_same(destfile, self.size, self._records.hashes):
            logging.debug('Ignoring already existing file: %s' % destfile)
            return os.path.abspath(destfile)

        # Verify that the index is actually trusted
        pfile, offset = self._cand.file_list[0]
        index = self.package._pcache._list.find_index(pfile)

        if not (allow_unauthenticated or (index and index.is_trusted)):
            raise UntrustedError("Could not fetch %s %s source package: "
                                 "Source %r is not trusted" %
                                 (self.package.name, self.version,
                                  getattr(index, "describe", "<unkown>")))
        if not self.uri:
            raise ValueError("No URI for this binary.")
        hashes = self._records.hashes
        if not (allow_unauthenticated or hashes.usable):
            raise UntrustedError("The item %r could not be fetched: "
                                     "No trusted hash found." %
                                     destfile)
        acq = apt_pkg.Acquire(progress or apt.progress.text.AcquireProgress())
        acqfile = apt_pkg.AcquireFile(acq, self.uri, hashes,
                                      self.size, base, destfile=destfile)
        acq.run()

        if acqfile.status != acqfile.STAT_DONE:
            raise FetchError("The item %r could not be fetched: %s" %
                             (acqfile.destfile, acqfile.error_text))

        return os.path.abspath(destfile)

    def fetch_source(self, destdir="", progress=None, unpack=True,
                     allow_unauthenticated=None):
        # type: (str, Optional[AcquireProgress], bool, Optional[bool]) -> str
        """Get the source code of a package.

        The parameter *destdir* specifies the directory where the source will
        be fetched to.

        The parameter *progress* may refer to an apt_pkg.AcquireProgress()
        object. If not specified or None, apt.progress.text.AcquireProgress()
        is used.

        The parameter *unpack* describes whether the source should be unpacked
        (``True``) or not (``False``). By default, it is unpacked.

        If *unpack* is ``True``, the path to the extracted directory is
        returned. Otherwise, the path to the .dsc file is returned.

        The keyword-only parameter *allow_unauthenticated* specifies whether
        to allow unauthenticated downloads. If not specified, it defaults to
        the configuration option `APT::Get::AllowUnauthenticated`.
        """
        if allow_unauthenticated is None:
            allow_unauthenticated = apt_pkg.config.find_b("APT::Get::"
                                        "AllowUnauthenticated", False)

        src = apt_pkg.SourceRecords()
        acq = apt_pkg.Acquire(progress or apt.progress.text.AcquireProgress())

        dsc = None
        record = self._records
        source_name = record.source_pkg or self.package.shortname
        source_version = record.source_ver or self._cand.ver_str
        source_lookup = src.lookup(source_name)

        while source_lookup and source_version != src.version:
            source_lookup = src.lookup(source_name)
        if not source_lookup:
            raise ValueError("No source for %r" % self)
        files = list()

        if not (allow_unauthenticated or src.index.is_trusted):
            raise UntrustedError("Could not fetch %s %s source package: "
                                 "Source %r is not trusted" %
                                 (self.package.name, self.version,
                                  src.index.describe))
        for fil in src.files:
            base = os.path.basename(fil.path)
            destfile = os.path.join(destdir, base)
            if fil.type == 'dsc':
                dsc = destfile
            if _file_is_same(destfile, fil.size, fil.hashes):
                logging.debug('Ignoring already existing file: %s' % destfile)
                continue

            if not (allow_unauthenticated or fil.hashes.usable):
                raise UntrustedError("The item %r could not be fetched: "
                                         "No trusted hash found." %
                                         destfile)
            files.append(apt_pkg.AcquireFile(acq,
                            src.index.archive_uri(fil.path),
                            fil.hashes, fil.size, base, destfile=destfile))
        acq.run()

        if dsc is None:
            raise ValueError("No source for %r" % self)

        for item in acq.items:
            if item.status != item.STAT_DONE:
                raise FetchError("The item %r could not be fetched: %s" %
                                 (item.destfile, item.error_text))

        if unpack:
            outdir = src.package + '-' + apt_pkg.upstream_version(src.version)
            outdir = os.path.join(destdir, outdir)
            subprocess.check_call(["dpkg-source", "-x", dsc, outdir])
            return os.path.abspath(outdir)
        else:
            return os.path.abspath(dsc)


class VersionList(Sequence[Version]):
    """Provide a mapping & sequence interface to all versions of a package.

    This class can be used like a dictionary, where version strings are the
    keys. It can also be used as a sequence, where integers are the keys.

    You can also convert this to a dictionary or a list, using the usual way
    of dict(version_list) or list(version_list). This is useful if you need
    to access the version objects multiple times, because they do not have to
    be recreated this way.

    Examples ('package.versions' being a version list):
        '0.7.92' in package.versions # Check whether 0.7.92 is a valid version.
        package.versions[0] # Return first version or raise IndexError
        package.versions[0:2] # Return a new VersionList for objects 0-2
        package.versions['0.7.92'] # Return version 0.7.92 or raise KeyError
        package.versions.keys() # All keys, as strings.
        max(package.versions)
    """

    def __init__(self, package, slice_=None):
        # type: (Package, Optional[slice]) -> None
        self._package = package  # apt.package.Package()
        self._versions = package._pkg.version_list  # [apt_pkg.Version(), ...]
        if slice_:
            self._versions = self._versions[slice_]

    def __getitem__(self, item):
        # type: (Union[int, slice, str]) -> Any
        # FIXME: Should not be returning Any, should have overloads; but
        # pyflakes complains
        if isinstance(item, slice):
            return self.__class__(self._package, item)
        try:
            # Sequence interface, item is an integer
            return Version(self._package, self._versions[item])  # type: ignore
        except TypeError:
            # Dictionary interface item is a string.
            for ver in self._versions:
                if ver.ver_str == item:
                    return Version(self._package, ver)
        raise KeyError("Version: %r not found." % (item))

    def __str__(self):
        # type: () -> str
        return '[%s]' % (', '.join(str(ver) for ver in self))

    def __repr__(self):
        # type: () -> str
        return '<VersionList: %r>' % self.keys()

    def __iter__(self):
        # type: () -> Iterator[Version]
        """Return an iterator over all value objects."""
        return (Version(self._package, ver) for ver in self._versions)

    def __contains__(self, item):
        # type: (object) -> bool
        if isinstance(item, Version):  # Sequence interface
            item = item.version
        # Dictionary interface.
        for ver in self._versions:
            if ver.ver_str == item:
                return True
        return False

    def __eq__(self, other):
        # type: (Any) -> bool
        return list(self) == list(other)

    def __len__(self):
        # type: () -> int
        return len(self._versions)

    # Mapping interface

    def keys(self):
        # type: () -> List[str]
        """Return a list of all versions, as strings."""
        return [ver.ver_str for ver in self._versions]

    def get(self, key, default=None):
        # type: (str, Optional[Version]) -> Optional[Version]
        """Return the key or the default."""
        try:
            return self[key]  # type: ignore  # FIXME: should be deterined automatically # noqa
        except LookupError:
            return default


class Package(object):
    """Representation of a package in a cache.

    This class provides methods and properties for working with a package. It
    lets you mark the package for installation, check if it is installed, and
    much more.
    """

    def __init__(self, pcache, pkgiter):
        # type: (apt.Cache, apt_pkg.Package) -> None
        """ Init the Package object """
        self._pkg = pkgiter
        self._pcache = pcache           # python cache in cache.py
        self._changelog = ""            # Cached changelog

    def __str__(self):
        # type: () -> str
        return self.name

    def __repr__(self):
        # type: () -> str
        return '<Package: name:%r architecture=%r id:%r>' % (
            self._pkg.name, self._pkg.architecture, self._pkg.id)

    def __lt__(self, other):
        # type: (Package) -> bool
        return self.name < other.name

    @property
    def candidate(self):
        # type: () -> Optional[Version]
        """Return the candidate version of the package.

        This property is writeable to allow you to set the candidate version
        of the package. Just assign a Version() object, and it will be set as
        the candidate version.
        """
        cand = self._pcache._depcache.get_candidate_ver(self._pkg)
        if cand is not None:
            return Version(self, cand)
        return None

    @candidate.setter
    def candidate(self, version):
        # type: (Version) -> None
        """Set the candidate version of the package."""
        self._pcache.cache_pre_change()
        self._pcache._depcache.set_candidate_ver(self._pkg, version._cand)
        self._pcache.cache_post_change()

    @property
    def installed(self):
        # type: () -> Optional[Version]
        """Return the currently installed version of the package.

        .. versionadded:: 0.7.9
        """
        if self._pkg.current_ver is not None:
            return Version(self, self._pkg.current_ver)
        return None

    @property
    def name(self):
        # type: () -> str
        """Return the name of the package, possibly including architecture.

        If the package is not part of the system's preferred architecture,
        return the same as :attr:`fullname`, otherwise return the same
        as :attr:`shortname`

        .. versionchanged:: 0.7.100.3

        As part of multi-arch, this field now may include architecture
        information.
        """
        return self._pkg.get_fullname(True)

    @property
    def fullname(self):
        # type: () -> str
        """Return the name of the package, including architecture.

        Note that as for :meth:`architecture`, this returns the
        native architecture for Architecture: all packages.

        .. versionadded:: 0.7.100.3"""
        return self._pkg.get_fullname(False)

    @property
    def shortname(self):
        # type: () -> str
        """Return the name of the package, without architecture.

        .. versionadded:: 0.7.100.3"""
        return self._pkg.name

    @property
    def id(self):
        # type: () -> int
        """Return a uniq ID for the package.

        This can be used eg. to store additional information about the pkg."""
        return self._pkg.id

    @property
    def essential(self):
        # type: () -> bool
        """Return True if the package is an essential part of the system."""
        return self._pkg.essential

    def architecture(self):
        # type: () -> str
        """Return the Architecture of the package.

        Note that for Architecture: all packages, this returns the
        native architecture, as they are internally treated like native
        packages. To get the concrete architecture, look at the
        :attr:`Version.architecture` attribute.

        .. versionchanged:: 0.7.100.3
            This is now the package's architecture in the multi-arch sense,
            previously it was the architecture of the candidate version
            and deprecated.
        """
        return self._pkg.architecture

    # depcache states

    @property
    def marked_install(self):
        # type: () -> bool
        """Return ``True`` if the package is marked for install."""
        return self._pcache._depcache.marked_install(self._pkg)

    @property
    def marked_upgrade(self):
        # type: () -> bool
        """Return ``True`` if the package is marked for upgrade."""
        return self._pcache._depcache.marked_upgrade(self._pkg)

    @property
    def marked_delete(self):
        # type: () -> bool
        """Return ``True`` if the package is marked for delete."""
        return self._pcache._depcache.marked_delete(self._pkg)

    @property
    def marked_keep(self):
        # type: () -> bool
        """Return ``True`` if the package is marked for keep."""
        return self._pcache._depcache.marked_keep(self._pkg)

    @property
    def marked_downgrade(self):
        # type: () -> bool
        """ Package is marked for downgrade """
        return self._pcache._depcache.marked_downgrade(self._pkg)

    @property
    def marked_reinstall(self):
        # type: () -> bool
        """Return ``True`` if the package is marked for reinstall."""
        return self._pcache._depcache.marked_reinstall(self._pkg)

    @property
    def is_installed(self):
        # type: () -> bool
        """Return ``True`` if the package is installed."""
        return (self._pkg.current_ver is not None)

    @property
    def is_upgradable(self):
        # type: () -> bool
        """Return ``True`` if the package is upgradable."""
        return (self.is_installed and
                self._pcache._depcache.is_upgradable(self._pkg))

    @property
    def is_auto_removable(self):
        # type: () -> bool
        """Return ``True`` if the package is no longer required.

        If the package has been installed automatically as a dependency of
        another package, and if no packages depend on it anymore, the package
        is no longer required.
        """
        return ((self.is_installed or self.marked_install) and
                self._pcache._depcache.is_garbage(self._pkg))

    @property
    def is_auto_installed(self):
        # type: () -> bool
        """Return whether the package is marked as automatically installed."""
        return self._pcache._depcache.is_auto_installed(self._pkg)
    # sizes

    @property
    def installed_files(self):
        # type: () -> List[str]
        """Return a list of files installed by the package.

        Return a list of unicode names of the files which have
        been installed by this package
        """
        for name in self.name, self.fullname:
            path = "/var/lib/dpkg/info/%s.list" % name
            try:
                with open(path, "rb") as file_list:
                    return file_list.read().decode("utf-8").split(u"\n")
            except EnvironmentError:
                continue

        return []

    def get_changelog(self, uri=None, cancel_lock=None):
        # type: (Optional[str], Optional[threading.Event]) -> str
        """
        Download the changelog of the package and return it as unicode
        string.

        The parameter *uri* refers to the uri of the changelog file. It may
        contain multiple named variables which will be substitued. These
        variables are (src_section, prefix, src_pkg, src_ver). An example is
        the Ubuntu changelog::

            "http://changelogs.ubuntu.com/changelogs/pool" \\
                "/%(src_section)s/%(prefix)s/%(src_pkg)s" \\
                "/%(src_pkg)s_%(src_ver)s/changelog"

        The parameter *cancel_lock* refers to an instance of threading.Event,
        which if set, prevents the download.
        """
        # Return a cached changelog if available
        if self._changelog != u"":
            return self._changelog

        if not self.candidate:
            return _("The list of changes is not available")

        if uri is None:
            if self.candidate.origins[0].origin == "Debian":
                uri = "http://packages.debian.org/changelogs/pool" \
                      "/%(src_section)s/%(prefix)s/%(src_pkg)s" \
                      "/%(src_pkg)s_%(src_ver)s/changelog"
            elif self.candidate.origins[0].origin == "Ubuntu":
                uri = "http://changelogs.ubuntu.com/changelogs/pool" \
                      "/%(src_section)s/%(prefix)s/%(src_pkg)s" \
                      "/%(src_pkg)s_%(src_ver)s/changelog"
            else:
                res = _("The list of changes is not available")
                if isinstance(res, str):
                    return res
                else:
                    return res.decode("utf-8")

        # get the src package name
        src_pkg = self.candidate.source_name

        # assume "main" section
        src_section = "main"
        # use the section of the candidate as a starting point
        section = self.candidate.section

        # get the source version
        src_ver = self.candidate.source_version

        try:
            # try to get the source version of the pkg, this differs
            # for some (e.g. libnspr4 on ubuntu)
            # this feature only works if the correct deb-src are in the
            # sources.list otherwise we fall back to the binary version number
            src_records = apt_pkg.SourceRecords()
        except SystemError:
            pass
        else:
            while src_records.lookup(src_pkg):
                if not src_records.version:
                    continue
                if self.candidate.source_version == src_records.version:
                    # Direct match, use it and do not do more lookups.
                    src_ver = src_records.version
                    section = src_records.section
                    break
                if apt_pkg.version_compare(src_records.version, src_ver) > 0:
                    # The version is higher, it seems to match.
                    src_ver = src_records.version
                    section = src_records.section

        section_split = section.split("/", 1)
        if len(section_split) > 1:
            src_section = section_split[0]
        del section_split

        # lib is handled special
        prefix = src_pkg[0]
        if src_pkg.startswith("lib"):
            prefix = "lib" + src_pkg[3]

        # stip epoch
        src_ver_split = src_ver.split(":", 1)
        if len(src_ver_split) > 1:
            src_ver = "".join(src_ver_split[1:])
        del src_ver_split

        uri = uri % {"src_section": src_section,
                     "prefix": prefix,
                     "src_pkg": src_pkg,
                     "src_ver": src_ver}

        timeout = socket.getdefaulttimeout()

        # FIXME: when python2.4 vanishes from the archive,
        #        merge this into a single try..finally block (pep 341)
        try:
            try:
                # Set a timeout for the changelog download
                socket.setdefaulttimeout(2)

                # Check if the download was canceled
                if cancel_lock and cancel_lock.is_set():
                    return u""
                # FIXME: python3.2: Should be closed manually
                changelog_file = urlopen(uri)
                # do only get the lines that are new
                changelog = u""
                regexp = "^%s \\((.*)\\)(.*)$" % (re.escape(src_pkg))
                while True:
                    # Check if the download was canceled
                    if cancel_lock and cancel_lock.is_set():
                        return u""
                    # Read changelog line by line
                    line_raw = changelog_file.readline()
                    if not line_raw:
                        break
                    # The changelog is encoded in utf-8, but since there isn't
                    # any http header, urllib2 seems to treat it as ascii
                    line = line_raw.decode("utf-8")

                    #print line.encode('utf-8')
                    match = re.match(regexp, line)
                    if match:
                        # strip epoch from installed version
                        # and from changelog too
                        installed = getattr(self.installed, 'version', None)
                        if installed and ":" in installed:
                            installed = installed.split(":", 1)[1]
                        changelog_ver = match.group(1)
                        if changelog_ver and ":" in changelog_ver:
                            changelog_ver = changelog_ver.split(":", 1)[1]

                        if (installed and apt_pkg.version_compare(
                                changelog_ver, installed) <= 0):
                            break
                    # EOF (shouldn't really happen)
                    changelog += line

                # Print an error if we failed to extract a changelog
                if len(changelog) == 0:
                    changelog = _("The list of changes is not available")
                    if not isinstance(changelog, str):
                        changelog = changelog.decode("utf-8")
                self._changelog = changelog

            except HTTPError:
                if self.candidate.origins[0].origin == "Ubuntu":
                    res = _("The list of changes is not available yet.\n\n"
                            "Please use "
                            "http://launchpad.net/ubuntu/+source/%s/"
                            "%s/+changelog\n"
                            "until the changes become available or try again "
                            "later.") % (src_pkg, src_ver)
                else:
                    res = _("The list of changes is not available")
                if isinstance(res, str):
                    return res
                else:
                    return res.decode("utf-8")
            except (IOError, BadStatusLine):
                res = _("Failed to download the list of changes. \nPlease "
                        "check your Internet connection.")
                if isinstance(res, str):
                    return res
                else:
                    return res.decode("utf-8")
        finally:
            socket.setdefaulttimeout(timeout)
        return self._changelog

    @property
    def versions(self):
        # type: () -> VersionList
        """Return a VersionList() object for all available versions.

        .. versionadded:: 0.7.9
        """
        return VersionList(self)

    @property
    def is_inst_broken(self):
        # type: () -> bool
        """Return True if the to-be-installed package is broken."""
        return self._pcache._depcache.is_inst_broken(self._pkg)

    @property
    def is_now_broken(self):
        # type: () -> bool
        """Return True if the installed package is broken."""
        return self._pcache._depcache.is_now_broken(self._pkg)

    @property
    def has_config_files(self):
        # type: () -> bool
        """Checks whether the package is is the config-files state."""
        return self. _pkg.current_state == apt_pkg.CURSTATE_CONFIG_FILES

    # depcache actions

    def mark_keep(self):
        # type: () -> None
        """Mark a package for keep."""
        self._pcache.cache_pre_change()
        self._pcache._depcache.mark_keep(self._pkg)
        self._pcache.cache_post_change()

    def mark_delete(self, auto_fix=True, purge=False):
        # type: (bool, bool) -> None
        """Mark a package for deletion.

        If *auto_fix* is ``True``, the resolver will be run, trying to fix
        broken packages.  This is the default.

        If *purge* is ``True``, remove the configuration files of the package
        as well.  The default is to keep the configuration.
        """
        self._pcache.cache_pre_change()
        self._pcache._depcache.mark_delete(self._pkg, purge)
        # try to fix broken stuffsta
        if auto_fix and self._pcache._depcache.broken_count > 0:
            fix = apt_pkg.ProblemResolver(self._pcache._depcache)
            fix.clear(self._pkg)
            fix.protect(self._pkg)
            fix.remove(self._pkg)
            fix.resolve()
        self._pcache.cache_post_change()

    def mark_install(self, auto_fix=True, auto_inst=True, from_user=True):
        # type: (bool, bool, bool) -> None
        """Mark a package for install.

        If *autoFix* is ``True``, the resolver will be run, trying to fix
        broken packages.  This is the default.

        If *autoInst* is ``True``, the dependencies of the packages will be
        installed automatically.  This is the default.

        If *fromUser* is ``True``, this package will not be marked as
        automatically installed. This is the default. Set it to False if you
        want to be able to automatically remove the package at a later stage
        when no other package depends on it.
        """
        self._pcache.cache_pre_change()
        self._pcache._depcache.mark_install(self._pkg, auto_inst, from_user)
        # try to fix broken stuff
        if auto_fix and self._pcache._depcache.broken_count > 0:
            fixer = apt_pkg.ProblemResolver(self._pcache._depcache)
            fixer.clear(self._pkg)
            fixer.protect(self._pkg)
            fixer.resolve(True)
        self._pcache.cache_post_change()

    def mark_upgrade(self, from_user=True):
        # type: (bool) -> None
        """Mark a package for upgrade."""
        if self.is_upgradable:
            auto = self.is_auto_installed
            self.mark_install(from_user=from_user)
            self.mark_auto(auto)
        else:
            # FIXME: we may want to throw a exception here
            sys.stderr.write(("MarkUpgrade() called on a non-upgradeable pkg: "
                              "'%s'\n") % self._pkg.name)

    def mark_auto(self, auto=True):
        # type: (bool) -> None
        """Mark a package as automatically installed.

        Call this function to mark a package as automatically installed. If the
        optional parameter *auto* is set to ``False``, the package will not be
        marked as automatically installed anymore. The default is ``True``.
        """
        self._pcache._depcache.mark_auto(self._pkg, auto)

    def commit(self, fprogress, iprogress):
        # type: (AcquireProgress, InstallProgress) -> None
        """Commit the changes.

        The parameter *fprogress* refers to a apt_pkg.AcquireProgress() object,
        like apt.progress.text.AcquireProgress().

        The parameter *iprogress* refers to an InstallProgress() object, as
        found in apt.progress.base.
        """
        self._pcache._depcache.commit(fprogress, iprogress)


@no_type_check
def _test():
    """Self-test."""
    print("Self-test for the Package modul")
    import random
    apt_pkg.init()
    progress = apt.progress.text.OpProgress()
    cache = apt.Cache(progress)
    pkg = cache["apt-utils"]
    print("Name: %s " % pkg.name)
    print("ID: %s " % pkg.id)
    print("Priority (Candidate): %s " % pkg.candidate.priority)
    print("Priority (Installed): %s " % pkg.installed.priority)
    print("Installed: %s " % pkg.installed.version)
    print("Candidate: %s " % pkg.candidate.version)
    print("CandidateDownloadable: %s" % pkg.candidate.downloadable)
    print("CandidateOrigins: %s" % pkg.candidate.origins)
    print("SourcePkg: %s " % pkg.candidate.source_name)
    print("Section: %s " % pkg.section)
    print("Summary: %s" % pkg.candidate.summary)
    print("Description (formatted) :\n%s" % pkg.candidate.description)
    print("Description (unformatted):\n%s" % pkg.candidate.raw_description)
    print("InstalledSize: %s " % pkg.candidate.installed_size)
    print("PackageSize: %s " % pkg.candidate.size)
    print("Dependencies: %s" % pkg.installed.dependencies)
    print("Recommends: %s" % pkg.installed.recommends)
    for dep in pkg.candidate.dependencies:
        print(",".join("%s (%s) (%s) (%s)" % (o.name, o.version, o.relation,
                       o.pre_depend) for o in dep.or_dependencies))
    print("arch: %s" % pkg.candidate.architecture)
    print("homepage: %s" % pkg.candidate.homepage)
    print("rec: ", pkg.candidate.record)

    print(cache["2vcard"].get_changelog())
    for i in True, False:
        print("Running install on random upgradable pkgs with AutoFix: ", i)
        for pkg in cache:
            if pkg.is_upgradable:
                if random.randint(0, 1) == 1:
                    pkg.mark_install(i)
        print("Broken: %s " % cache._depcache.broken_count)
        print("InstCount: %s " % cache._depcache.inst_count)

    print()
    # get a new cache
    for i in True, False:
        print("Randomly remove some packages with AutoFix: %s" % i)
        cache = apt.Cache(progress)
        for name in cache.keys():
            if random.randint(0, 1) == 1:
                try:
                    cache[name].mark_delete(i)
                except SystemError:
                    print("Error trying to remove: %s " % name)
        print("Broken: %s " % cache._depcache.broken_count)
        print("DelCount: %s " % cache._depcache.del_count)


# self-test
if __name__ == "__main__":
    _test()
