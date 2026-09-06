# NOTE: do not expect anything in this file to be stable for use outside this package!
# the interface here is a confusing mess because it attempts to provide a compatible
# interface to the python-apt sourceslist classes; however it didn't make it into that
# package, so it's temporarily here, and there's no longer any reason it needs to be
# interface-compatible, so creating a completely new set of classes will be better,
# so these classes should not be relied on in the future.

import apt_pkg
import logging
import os

from copy import copy

from aptsources import sourceslist
from aptsources.distro import get_distro


apt_pkg.init()


class SourceEntry(sourceslist.SourceEntry):
    """ single sources.list entry """

    @classmethod
    def create_entry(cls, **kwargs):
        return cls(cls.create_line(**kwargs))

    @classmethod
    def create_line(cls, uri,
                    disabled=None,
                    type=None,
                    dist=None,
                    suite=None,
                    pocket=None,
                    comps=None,
                    architectures=None,
                    trusted=None,
                    comment=None):
        """ Create a line from the given parts.

        The 'uri' parameter is mandatory; the rest will be filled with defaults
        if not set or if set to None.

        If 'dist' and 'suite' are both provided, 'suite' is ignored. If 'dist'
        includes a pocket and 'pocket' is provided, the 'pocket' parameter
        will replace the pocket in 'dist'.
        """
        if disabled is None:
            disabled = False
        if type is None:
            type = get_distro().binary_type
        if suite is None:
            suite = get_distro().codename
        if comps is None:
            comps = []
        if architectures is None:
            architectures = []

        if type.startswith("#"):
            # backwards compatibility; please just use disabled param
            disabled = True
            type = type.lstrip("# ")

        hashmark = "# " if disabled else ""

        options = []
        if architectures:
            options.append(f'arch={",".join(architectures)}')
        if trusted is not None:
            options.append(f'trusted={"yes" if trusted else "no"}')
        options = " ".join(options)
        if options:
            options = f' [{options}]'

        if not dist:
            dist = suite
        if pocket:
            dist = dist.partition('-')[0]
            dist = f'{dist}-{pocket}'

        comps = " ".join(comps)
        if comps:
            comps = f' {comps}'

        if comment:
            if not comment.startswith("#"):
                comment = f' #{comment}'
            elif not comment.startswith(" "):
                comment = f' {comment}'
        else:
            comment = ''

        return f'{hashmark}{type}{options} {uri} {dist}{comps}{comment}'.strip()

    def __eq__(self, other):
        """ equal operator for two sources.list entries """
        try:
            if self.invalid or other.invalid:
                return (self.invalid == other.invalid and
                        self.line == other.line)
            return (self.disabled == other.disabled and
                    self.type == other.type and
                    set(self.architectures) == set(other.architectures) and
                    self.trusted == other.trusted and
                    self.uri.rstrip('/') == other.uri.rstrip('/') and
                    self.suite == other.suite and
                    self.pocket == other.pocket and
                    set(self.comps) == set(other.comps))
        except AttributeError:
            return False

    @property
    def suite(self):
        """ Return the suite, without pocket

        This always returns the suite in lowercase.
        """
        return self.dist.partition('-')[0].lower()

    @suite.setter
    def suite(self, new_suite):
        if not new_suite:
            return
        pocket = self._pocket
        if pocket:
            self.dist = f'{new_suite}-{pocket}'
        else:
            self.dist = new_suite

    @property
    def _pocket(self):
        """ Return the pocket, or if unset return None """
        return self.dist.partition('-')[2]

    @property
    def pocket(self):
        """ Return the pocket, or if unset return 'release'

        This always returns the pocket in lowercase.
        """
        return (self._pocket or 'release').lower()

    @pocket.setter
    def pocket(self, new_pocket):
        if new_pocket:
            self.dist = f'{self.suite}-{new_pocket}'
        else:
            self.dist = self.suite

    def __copy__(self):
        """ Copy this SourceEntry """
        return SourceEntry(str(self), file=self.file)

    def _replace(self, **kwargs):
        """ Return copy of this SourceEntry with replaced field(s) """
        entry = copy(self)
        for (k, v) in kwargs.items():
            setattr(entry, k, v)
        return entry

    def __str__(self):
        """ debug helper """
        return self.str().strip()

    def str(self):
        """ return the current entry as string """
        if self.invalid:
            return self.line
        line = self.create_line(uri=self.uri, disabled=self.disabled, type=self.type,
                                suite=self.suite, pocket=self._pocket, comps=self.comps,
                                architectures=self.architectures,
                                trusted=self.trusted, comment=self.comment)
        return f'{line}\n'


class MergedSourceEntry(SourceEntry):
    """ A SourceEntry representing one or more identical SourceEntries

    The SourceEntries this represents are identical except for the components
    they contain.  This will contain all the contained entries' components.

    If all components are removed, this will still act as a normal SourceEntry
    without any components, but all corresponding real SourceEntries will be
    removed from the SourcesList.

    This may contain multiple SourceEntries that overlap components (e.g.
    two entries that both contain 'main' component), however once any
    changes are made to the set of comps, duplicates will be removed.
    """
    def __init__(self, entry, sourceslist):
        self._initialized = False
        super(MergedSourceEntry, self).__init__(str(entry), file=entry.file)
        self._initialized = True

        self._sourceslist = sourceslist
        self._entries = [entry]

    def match(self, other):
        """ Check if this is equal to other, ignoring comps """
        if not isinstance(other, SourceEntry):
            return False
        if self.invalid:
            # Never match an invalid entry; those are full-line comments
            # and whitespace and should be left as-is
            return False
        return self._replace(comps=[]) == other._replace(comps=[])

    def _append(self, entry):
        """ Append entry

        This should be called only with an entry that is equal to us,
        besides comps.  The new entry may contain comps already in
        other entries we contain, but any modification of our comps
        will remove all duplicate comps.
        """
        self._entries.append(entry)

    def get_entry(self, comps, add=False, isolate=False):
        """ Get single SourceEntry with comps

        This moves all the components into a single entry in our entries
        list, and returns that entry.

        If add is False, this will return None if we do not already
        contain all the requested comps; otherwise this adds any
        new comps.

        If isolate is False, the entry returned may contain more
        components than those requested in comps.  If isolate is True,
        this moves any excess components into a new entry, located
        immediately after the returned entry.

        If any of the components already exist in one of our entries,
        it is used to move all the components to; otherwise the first
        entry in our list is used.

        Any of our entries that has all its components moved (thus has
        no components left) will be removed from our entries list and
        removed from our sourceslist.

        If called with no comps this will return our first SourceEntry.
        If we contain no SourceEntries (because we contain no components),
        this will return None if called with no comps.
        """
        comps = set(copy(comps))

        if not set(self.comps) >= comps and not add:
            # we don't contain all requested comps
            return None

        for e in self._entries:
            if set(e.comps) & comps:
                # we want to move requested comps to e
                comps -= set(e.comps)
                # remove other comps from other entries
                self.comps = list(set(self.comps) - comps)
                # add them all to this entry
                e.comps = list(set(e.comps) | comps)
                break
        else:
            # all comps are new to us (or no comps requested),
            # add them to our first entry
            self.comps = list(set(self.comps) | comps)
            try:
                e = self._entries[0]
            except KeyError:
                # we are empty, return None
                return None

        if isolate and comps and set(e.comps) > comps:
            newe = e._replace(comps=list(set(e.comps) - comps))
            e.comps = list(comps)
            newi = self._sourceslist.list.index(e) + 1
            self._sourceslist.list.insert(newi, newe)
            self._append(newe)

        return e

    @property
    def comps(self):
        c = set()
        for e in self._entries:
            c |= set(e.comps)
        return list(c)

    @comps.setter
    def comps(self, comps):
        if not self._initialized:
            return

        comps = set(copy(comps))
        if comps == set(self.comps):
            # no change needed
            return

        for e in self._entries:
            e.comps = list(set(e.comps) & comps)
            comps -= set(e.comps)

        if comps:
            if not self._entries:
                self._entries = [copy(self)]
                self._sourceslist.list.append(self._entries[0])
            self._entries[0].comps = list(set(self._entries[0].comps) | comps)

        for e in list(self._entries):
            if not e.comps:
                self._entries.remove(e)
                self._sourceslist.list.remove(e)

    def set_enabled(self, enabled):
        for e in self._entries:
            e.set_enabled(enabled)
        super(MergedSourceEntry, self).set_enabled(enabled)

    def __setattribute__(self, name, value):
        if not (name == 'comps' or name.startswith('_')):
            for e in self._entries:
                setattr(e, name, value)
        super(MergedSourceEntry, self).__setattribute__(name, value)


class SourcesList(sourceslist.SourcesList):
    """ represents the full sources.list + sources.list.d file """

    def refresh(self):
        """ update the list of known entries """
        self._files = set()
        super(SourcesList, self).refresh()

    def filter(self, **kwargs):
        """ convenience method to get filtered list """
        l = list(self.list)
        for (key, value) in kwargs.items():
            l = [e for e in l if getattr(e, key, not value) == value]
        return l

    def __iter__(self):
        """ simple iterator to go over self.list, returns SourceEntry
            types """
        for entry in self.list:
            yield entry

    def __len__(self):
        """ calculate len of self.list """
        return len(self.list)

    def __eq__(self, other):
        """ equal operator for two sources.list entries """
        return (all([e in other for e in self]) and
                all([e in self for e in other]))

    def add(self, type, uri, dist, comps, comment="", pos=-1, file=None,
            architectures=[], disabled=False):
        """ Create a new entry and add it to our list """
        if pos >= 0 and pos < len(self.list):
            before = self.list[pos]
        else:
            before = None

        line = SourceEntry.create_line(disabled=disabled, type=type, uri=uri,
                                       dist=dist, comps=comps, comment=comment,
                                       architectures=architectures)
        new_entry = SourceEntry(line, file=file)
        collapsed = CollapsedSourcesList(self)
        return collapsed.add_entry(new_entry, before=before)

    def load(self, file):
        """ (re)load the current sources """
        try:
            with open(file, "r") as f:
                for line in f:
                    source = SourceEntry(line, file)
                    self.list.append(source)
            self._files.add(file)
        except Exception:
            logging.warning("could not open file '%s'\n" % file)

    def save(self, remove=False):
        """ save the current sources

        By default, this will NOT remove any files that we no longer
        have entries for; those files will not be modified at all.

        If 'remove' is True, any files that we initially parsed, but
        no longer have any entries for, will be removed.
        """
        files = set(e.file for e in self.list)

        for filename in files:
            with open(filename, "w") as f:
                for source in [s for s in self.list if s.file == filename]:
                    f.write(source.str())

        if remove:
            # remove any files that are now empty
            for filename in self._files - files:
                try:
                    os.remove(filename)
                except (OSError, IOError):
                    pass
            self._files = files

        # re-create empty sources.list if needed
        sourcelist = apt_pkg.config.find_file("Dir::Etc::sourcelist")
        if sourcelist not in files:
            header = (
                "## See sources.list(5) for more information, especialy\n"
                "# Remember that you can only use http, ftp or file URIs\n"
                "# CDROMs are managed through the apt-cdrom tool.\n")

            with open(sourcelist, "w") as f:
                f.write(header)


class CollapsedSourcesList(object):
    """ collapsed version of SourcesList

    This provides a 'collapsed' view of a SourcesList.
    Each entry in our list is a MergedSourceEntry, representing real
    SourceEntry(s) from our backing SourcesList.

    Any changes to our MergedSourceEntries are reflected in our
    backing SourcesList, however direct changes to SourceEntries
    in our backing SourcesList are not reflected in our list until
    after our refresh() method is called.

    If you change any part of any MergedSourceEntry besides the comps,
    you must refresh the CollapsedSourcesList to pick up those changes.

    The 'files' kwarg may be used to restrict which lines of the backing
    SourcesList are included, by providing a list of filenames. This
    can be used, for example, to get a CollapsedSourcesList of only
    SourceEntry lines from the main sources.list file.
    """
    def __init__(self, sourceslist=None, /, files=None):
        self.sourceslist = sourceslist or SourcesList()
        self._files = files
        self.list = []
        self.refresh()

    def __iter__(self):
        """ iterator for self.list

        Returns MergedSourceEntry objects
        """
        for entry in self.list:
            yield entry

    def __len__(self):
        """ calculate len of self.list """
        return len(self.list)

    def __eq__(self, other):
        """ equal operator for two sources.list entries """
        return (all([e in other for e in self]) and
                all([e in self for e in other]))

    def __contains__(self, other):
        """ check if other is contained in this list """
        return self.has_entry(other)

    def filter(self, **kwargs):
        """ convenience method to get filtered list """
        l = list(self.list)
        for (key, value) in kwargs.items():
            l = [e for e in l if getattr(e, key, not value) == value]
        return l

    def refresh(self):
        """ update only our list of MergedSourceEntries

        This updates only our list of MergedSourceEntries, our backing
        SourcesList is not updated.  This should be called anytime
        our backing SourcesList is updated directly.

        This does not refresh our backing SourcesList.
        """
        self.list = []
        for entry in self.sourceslist:
            if self._files and entry.file not in self._files:
                continue
            for mergedentry in self.list:
                if mergedentry.match(entry):
                    mergedentry._append(entry)
                    break
            else:
                self.list.append(MergedSourceEntry(entry, self.sourceslist))

    def add_entry(self, new_entry, after=None, before=None):
        """ Add a new entry to the sources.list.

        This will try to find an existing entry, or an existing entry with
        the opposite 'disabled' state, to reuse.

        If an existing entry does not exist, new_entry is inserted.
        If either 'after' or 'before' are specified, and match an existing
        SourceEntry in our list, then new_entry will be inserted before
        or after the specified SourceEntry.  If both 'after' and 'before'
        are provided, 'after' has precedence.  If neither 'after' or 'before'
        are provided, new_entry is appended to the end of the list.
        """
        # the 'inverse' is just the entry with disabled field toggled
        # this is so we can correctly maintain the requested comps
        # for both the enabled and disabled entry matches
        inverse = new_entry._replace(disabled=not new_entry.disabled)

        # the list of comps is the same for new_entry and inverse
        comps = set(new_entry.comps)

        match_entry = None
        match_inverse = None
        for c in self.list:
            if c.match(new_entry):
                match_entry = c
            if c.match(inverse):
                match_inverse = c
            if match_entry and match_inverse:
                break

        if match_entry:
            # at least one existing entry
            if match_inverse:
                # remove comps from inverse
                inverse_comps = set(match_inverse.comps) - comps
                match_inverse.comps = list(inverse_comps)
            # add comps to existing entry
            return match_entry.get_entry(comps, add=True)

        if match_inverse:
            # at least one existing inverse entry, and no matching entry;
            # replace the inverse entry and toggle its disabled state
            new_inverse = match_inverse.get_entry(comps,
                                                  add=True, isolate=True)

            # after modifying the entry, we must refresh our merged entries
            new_inverse.set_enabled(new_inverse.disabled)
            self.refresh()
            return self.get_entry(new_entry)

        # no match at all: just append/insert new_entry
        if after and after in self.sourceslist.list:
            new_index = self.sourceslist.list.index(after) + 1
            self.sourceslist.list.insert(new_index, new_entry)
        elif before and before in self.sourceslist.list:
            new_index = self.sourceslist.list.index(before)
            self.sourceslist.list.insert(new_index, new_entry)
        else:
            self.sourceslist.list.append(new_entry)
        self.list.append(MergedSourceEntry(new_entry, self.sourceslist))
        return new_entry

    def remove_entry(self, entry):
        """ Remove the specified entry form the sources.list

        This removes as much as possible of the entry.  If the entry
        matches an existing entry in our list, but our entry contains
        more components, only the specified components will be removed
        from our list's entry.  Similarly, if entry contains multiple
        components, this will remove those components from one or multiple
        entries, if needed.

        Any entries in our list that have all their components removed will
        be removed from our list.
        """
        c = self.get_merged_entry(entry)
        if c:
            c.comps = list(set(c.comps) - set(entry.comps))

    def get_entry(self, new_entry):
        """ If we already contain new_entry, find and return it

        If new_entry is already contained in our list, with at least
        all the components in new_entry, this returns our existing entry.
        The returned entry may have more components than new_entry.

        If new_entry is not contained in our list, or we do not
        have all the components in new_entry, this returns None.

        This may combine multiple existing SourceEntry lines into a
        single SourceEntry line so it contains all the requested
        components.

        This returns a SourceEntry.
        """
        c = self.get_merged_entry(new_entry)
        if c:
            return c.get_entry(new_entry.comps)
        return None

    def get_merged_entry(self, new_entry):
        """ This is similar to get_entry(), but we return the MergedSourceEntry

        This returns the MergedSourceEntry in our list that matches
        the new_entry.

        Note that this IGNORES any comps in the new_entry, so the
        returned MergedSourceEntry may have more or less comps than
        the new_entry.

        If we contain no match for the new_entry, return None.

        This method will never combine SourceEntry lines like the
        get_entry method sometimes does.

        This returns a MergedSourceEntry.
        """
        for c in self.list:
            if c.match(new_entry):
                return c
        return None

    def has_entry(self, new_entry):
        """ Check if we already contain new_entry

        If new_entry contains multiple components, they may be located
        in multiple lines; this only checks that all requested components,
        for exactly the SourceEntry that equals new_entry (besides comps),
        are included in our list.

        This will not change our list.
        """
        c = self.get_merged_entry(new_entry)
        if c:
            return set(c.comps) >= set(new_entry.comps)
        return False
