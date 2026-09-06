# Copyright (c) Eric Hugoson.
# See LICENSE for details.

"""Returns the relative distances between all identified hmms within
genome"""

from __future__ import division, print_function

import logging
import re
from collections import defaultdict
from itertools import chain


class linkageAnalysis():
    def __init__(self, seq_object, base_name, seq_type, proteome, seqstats,
                 hmm_matches, cutoff=0.8, logger=None):
        self.base_name = base_name
        self.seq_object = seq_object
        self.seq_type = seq_type
        _, self.seq_length, all_lengths, _, _ = seqstats
        self.proteome = proteome
        self.hmm_matches = hmm_matches
        self.hmm_locations = defaultdict(list)
        self.locs = defaultdict(list)
        self.logger = logger
        self.is_valid = True
        # checks if there are more than one contig
        # heuristically determines if it is one chromosome and plasmids
        if len(all_lengths) > 1 and cutoff:
            chromosome = 0
            for length in all_lengths:
                if (length / sum(all_lengths)) > cutoff:
                    chromosome = length
            if not chromosome:
                try:
                    self.logger.log(logging.WARNING, "%s contains multiple "\
                                    "contigs cannot be used to calculate "\
                                    "weights. Skipping." % self.base_name)
                except AttributeError:
                    pass
                self.is_valid = False
            self.seq_length = chromosome
        if seq_type == "faa":
            try:
                self.logger.log(logging.ERROR, "Sequence given for linkage "\
                                "analysis is proteome, must be nucleotide fasta "\
                                "or genbank file")
            except AttributeError:
                pass
            raise TypeError('Sequences for linkage analysis needs to be fna or' \
                            'gbk')
        with open(self.proteome) as prot_file:
            self.p_headers = set(header for header in prot_file
                                 if re.search("^>", header))

    def get_locations(self):
        """Get locations or start and stop for each matched produced by
        the completeness check, including duplicates. Also hooks in downstream
        functions that eventually calculate the relative linkage of all markers"""
        # prodigal writes ID=X_XX... in proteome, also START # STOP of sequence
        # the ID can be found in .tblout, therefore if match ID => get location
        # Force same format out of .gbk
        #
        #print(self.hmm_matches)
        #
        ## for each matching gene get weight from self.p_headers and put into
        ## new dict in format dict[hmm] = [[START, STOP], [START, STOP], [...]]
        try:
            self.logger.log(logging.INFO, "Mapping locations of found markers")
        except AttributeError:
            pass
        for hmm, genes in self.hmm_matches.items():
            for gene in genes:
                for loc in self.p_headers:
                    if re.search(re.escape(gene[0])+r"\s", loc):
                        # convert to int and append to dict[hmm]
                        self.hmm_locations[hmm].append(list(map(int,
                                                       loc.split('#')[1:3])))
            #print(self.hmm_locations[hmm])
        return self.hmm_locations

    def check_overlap(self, marker_locs, query_locs, reverse=False):
        """Tries to resolve an overlap in locations. Returns true if
        starting query loc precedes the match start"""
        forws = marker_locs[0] >= query_locs[0]
        revs = marker_locs[1] <= query_locs[1]
        forw_rev = marker_locs[0] <= query_locs[1]
        rev_forw = marker_locs[1] >= query_locs[0]
        # query end after marker start
        if forw_rev and forws and not reverse:
            return True
        # query start before marker end
        if rev_forw and revs and reverse:
            return True
        # within
        if not forws and not revs:
            return True
        return False

    def find_neighbour_distance(self):
        """For each location of each matched marker the location of start and stop
        are compared to all other locations, lowest value is stored"""
        # for each hmm compare loc(s) to all other locs to find lowest negative
        # value, these are closest neighbours up- and downstream
        if not self.hmm_locations:
            self.get_locations()
        try:
            self.logger.log(logging.INFO, "Finding distances between identified "\
                            "markers")
        except AttributeError:
            pass
        for hmm, locs in self.hmm_locations.items():
            min_floc = []
            min_rloc = []
            for loc in locs:
                # nested list comprehension
                # reads locs and compares end of current read to start of all
                # if negative -> adds sequence length to simulate circularity
                forward_l = [[int(each[0] - loc[1] + 1) if int(each[0] - loc[1] > 0)
                              else 1 if self.check_overlap(loc, each)
                              else int(each[0] - loc[1] + self.seq_length + 1) for
                              each in forw]
                             for key, forw in self.hmm_locations.items() if not
                             key == hmm]
                # flatten list
                forward_l_flat = list(chain.from_iterable(forward_l))
                min_floc.append(min(forward_l_flat))
                reverse_l = [[int(loc[0] - each[1] + 1) if int(loc[0] - each[1] > 0)
                              else 1 if self.check_overlap(loc, each, reverse=True)
                              else int(loc[0] - each[1] + self.seq_length + 1) for
                              each in rev]
                             for key, rev in self.hmm_locations.items() if not
                             key == hmm]
                reverse_l_flat = list(chain.from_iterable(reverse_l))
                min_rloc.append(min(reverse_l_flat))
            self.locs[hmm].append(min(min_floc))
            self.locs[hmm].append(min(min_rloc))
        return self.locs

    def calculate_linkage_scores(self):
        """From dict of with smallest distance locations up- and downstream
        the average is calculated, totaled and a relative value is calculated"""
        if not self.locs:
            self.find_neighbour_distance()
        try:
            self.logger.log(logging.INFO, "Calculating relative distances "\
                            "between found markers")
        except AttributeError:
            pass
        linkage_absvals = {hmm: (loc[0] + loc[1]) / 2 for (hmm, loc) in
                           self.locs.items()}
        total_distance = sum([linkVal for hmm, linkVal in
                              linkage_absvals.items()])
        linkage_rel_vals = {hmm: [(linkVal / total_distance)]
                            for hmm, linkVal in linkage_absvals.items()}
        return linkage_rel_vals
