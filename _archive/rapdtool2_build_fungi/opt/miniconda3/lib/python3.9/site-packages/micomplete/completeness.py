# Copyright (c) Eric Hugoson.
# See LICENSE for details.

"""
Module investigates the completeness of a given genome with respect to a given
set of HMM makers, in so far as it runs HMMer and parses the output.


"""

from __future__ import division, print_function

import logging
import os
import re
import subprocess
import sys
from collections import defaultdict


class calcCompleteness():
    def __init__(self, fasta, base_name, hmms, evalue=1e-10, bias=0.1,
                 best_domain=0.1, weights=None, hlist=False, linkage=False,
                 logger=None, lenient=False):
        self.base_name = base_name
        self.evalue = "-E %s" % (str(evalue))
        self.tblout = "%s.tblout" % (self.base_name)
        self.hmms = hmms
        self.fasta = fasta
        self.linkage = linkage
        self.weights = weights
        self.logger = logger
        self.lenient = lenient
        try:
            self.logger.log(logging.INFO, "Starting completeness for " + fasta)
        except AttributeError:
            pass
        self.hmm_names = set({})
        self.bias = bias
        self.best_domain = best_domain
        with open(self.hmms) as hmmfile:
            for line in hmmfile:
                if re.search('^NAME', line):
                    name = line.split(' ')
                    self.hmm_names.add(name[2].strip())

    def hmm_search(self):
        """
        Runs hmmsearch using the supplied .hmm file, and specified evalue.
        Produces an output table from hmmsearch, function returns its name.
        """
        try:
            self.logger.log(logging.INFO, "Starting hmmsearch")
        except AttributeError:
            pass
        hmmsearch = ["hmmsearch", self.evalue, "--tblout", self.tblout,
                     self.hmms, self.fasta]
        if sys.version_info > (3, 4):
            comp_proc = subprocess.run(hmmsearch, stdout=subprocess.DEVNULL)
            errcode = comp_proc.returncode
        else:
            errcode = subprocess.call(hmmsearch, stdout=open(os.devnull, 'wb'),
                                      stderr=subprocess.STDOUT)
        if errcode > 0:
            try:
                self.logger.log(logging.WARNING, "Error thrown by HMMER, is %s"
                                "empty?" % self.fasta)
            except AttributeError:
                print("Warning:", end=' ', file=sys.stderr)
                print("Error thrown by HMMER, is %s empty?" % self.fasta,
                      file=sys.stderr)
        return self.tblout, errcode

    def get_completeness(self, multi_hit=1/2):
        """
        Reads the out table of hmmer to find which hmms are present, and
        which are duplicated. Duplicates are only considered duplicates if
        the evalue of the secondary hit is within the squareroot of the best
        hit.

        Returns: Dict of all hmms found with evalues for best and possible
        deulicates, list of hmms with duplicates, and names of all hmms
        which were searched for.
        """
        _, errcode = self.hmm_search()
        if errcode > 0:
            return 0, 0, 0
        self.hmm_matches = defaultdict(list)
        self.seen_hmms = set()
        # gather gene name and evalue in dict by key[hmm]
        try:
            self.logger.log(logging.INFO, "Parsing identified HMMs and "
                            "corresponding evalues")
        except AttributeError:
            pass
        for hmm in self.hmm_names:
            with open(self.tblout) as hmm_table:
                for found_hmm in hmm_table:
                    if re.match("#$", found_hmm):
                        break
                    if re.search("^" + hmm + "$", found_hmm.split()[2]):
                        found_hmm = found_hmm.split()
                        # gathers name, evalue, score, bias
                        self.hmm_matches[hmm].append([found_hmm[0], found_hmm[4],
                                                      found_hmm[5], found_hmm[6],
                                                      found_hmm[7]])
                        self.seen_hmms.add(hmm)
        self.filled_hmms = defaultdict(list)
        # section can be expanded to check for unique gene matches
        for hmm, gene_matches in self.hmm_matches.items():
            # sort by lowest eval to fill lowest first
            for gene in sorted(gene_matches, key=lambda ev: float(ev[1])):
                if not self.lenient:
                    # skip if sequence match found to be dubious
                    if suspicion_check(gene, self.bias, self.best_domain):
                        try:
                            self.logger.log(logging.INFO, "%s failed suspiscion check"
                                            % gene)
                        except AttributeError:
                            pass
                        continue
                #if hmm not in self.filled_hmms:
                self.filled_hmms[hmm].append(gene)
                #elif float(gene[1]) < pow(float(self.filled_hmms[hmm][0][1]), multi_hit):
                #    self.filled_hmms[hmm].append(gene)
        try:
            self.logger.log(logging.INFO, "Assigning duplicates")
        except AttributeError:
            pass
        self.dup_hmms = [hmm for hmm, genes in self.filled_hmms.items()
                         if len(genes) > 1]
        #if self.hlist and not self.linkage:
        #    self.print_hmm_lists()
        return self.filled_hmms, self.dup_hmms, self.hmm_names

    def quantify_completeness(self):
        """
        Function returns the number of found markers, duplicated markers, and
        total number of markers.
        """
        filled_hmms, _, hmm_names = self.get_completeness()
        try:
            self.logger.log(logging.INFO, "Summarising completeness stats")
        except AttributeError:
            pass
        try:
            num_foundhmms = len(filled_hmms)
            num_hmms = len(hmm_names)
        except TypeError:
            num_foundhmms = 0
            num_totalhmms = 0
            num_hmms = 0
            return num_foundhmms, num_totalhmms, num_hmms
        all_duphmms = [len(genes) for hmm, genes in self.filled_hmms.items()]
        num_totalhmms = sum(all_duphmms)
        return num_foundhmms, num_totalhmms, num_hmms

    def print_hmm_lists(self, directory='.'):
        """Prints the contents of found, duplicate and and not found markers"""
        try:
            self.logger.log(logging.INFO, "Writing files of found, duplicate, and missing markers")
        except AttributeError:
            pass
        if directory:
            try:
                os.mkdir(directory)
            except FileExistsError:
                pass
        hlist_name = directory + "/%s_hmms.list" % (self.base_name)
        with open(hlist_name, 'w+') as seen_list:
            for each_hmm in self.seen_hmms:
                seen_list.write("%s\n" % each_hmm)
        dup_list_name = directory + "/%s_hmms_duplicate.list" % (self.base_name)
        with open(dup_list_name, 'w+') as dup_list:
            for each_dup in self.dup_hmms:
                dup_list.write("%s\n" % each_dup)
        missing_list_name = directory + "/%s_hmms_missing.list" % (self.base_name)
        with open(missing_list_name, 'w+') as missing_list:
            for hmm in self.hmm_names:
                if hmm not in self.seen_hmms:
                    missing_list.write("%s\n" % hmm)
        return hlist_name

    def attribute_weights(self):
        """Using the markers found and duplicates from get_completeness(), and
        provided weights, adds up weight of present and duplicate markers"""
        try:
            self.logger.log(logging.INFO, "Attributing weights to markers")
        except AttributeError:
            pass
        weighted_complete = 0
        weighted_redun = 0
        with open(self.weights, 'r') as weights:
            try:
                all_weights = [(weight_set[0], float(weight_set[1]))
                               for weight_set in
                               (weight.split('\t') for weight in weights)
                                if not weight_set[0] == "Standard deviation:"]
            except ValueError:
                try:
                    self.logger.log(logging.ERROR, "Weights file appears to be "
                                                   "invalid. Please ensure the "
                                                   "correct file has been "
                                                   "provided.")
                except AttributeError:
                    pass
                raise RuntimeError("Weights file appears to be invalid. Please "
                                   "ensure the correct file has been provided.")
        if not len(all_weights) == len(self.hmm_names):
            try:
                self.logger.log(logging.ERROR, "Number of weights do not match "
                                               "number of markers. Ensure that "
                                               "you have selected the correct "
                                               "weights/markers file")
            except AttributeError:
                pass
            raise RuntimeError("Mismatched weights and markers. Ensure that "
                               "the correct files have been given.")
        for hmm in self.seen_hmms:
            found = False
            for each_weight in all_weights:
                if hmm == each_weight[0]:
                    weighted_complete += float(each_weight[1])
                    found = True
                    break
            if not found:
                try:
                    self.logger.log(logging.WARNING, "Marker %s not found "
                                    "in weights file." % hmm)
                    print("Warning:", end=' ', file=sys.stderr)
                    print("Marker %s could not be found in weights file."
                          % hmm, file=sys.stderr)
                except AttributeError:
                    print("Warning:", end=' ', file=sys.stderr)
                    print("Marker %s could not be found in weights file."
                          % hmm, file=sys.stderr)
        for hmm in self.dup_hmms:
            with open(self.weights, 'r') as weights:
                for each_weight in weights:
                    if re.match(hmm + "\t", each_weight):
                        weighted_redun += float(each_weight.split()[1])
        weighted_redun = round(((weighted_redun + weighted_complete) /
                                weighted_complete), 4)
        if weighted_complete:
            weighted_complete = round(weighted_complete, 4)
            if not weighted_complete:
                weighted_complete = 0.0001
        return weighted_complete, weighted_redun


def suspicion_check(gene_match, bias, bestdomain):
    """Check if bias is in the same order of magnitude as the match
    and if the evalue for the best domain is high. Both indicating
    a dubious result."""
    if float(gene_match[2]) * bias <= float(gene_match[3]) or \
            float(gene_match[4]) - float(gene_match[1]) > bestdomain:
        return True
    return False
