# Copyright (c) Eric Hugoson.
# See LICENSE for details.

"""Gathers sequence relevant basic sequence data: length, contig
lengths, GC-content, N50, L50, N90, L90."""

from __future__ import division, print_function

import logging
import re

from Bio import SeqIO
from Bio.SeqUtils import GC


class parseSeqStats():
    def __init__(self, seq, base_name, seq_type, logger=None):
        """Initialize generators for headers as well as sequence"""
        self.logger = logger
        try:
            self.logger.log(logging.INFO, "Starting sequence stats gathering")
        except AttributeError:
            pass
        if seq_type in ('fna', 'faa'):
            self.seq_type = "fasta"
        elif re.match("(gb.?.?)|genbank", seq_type):
            self.seq_type = "genbank"
        else:
            self.seq_type = seq_type
        try:
            self.logger.log(logging.INFO, "Sequence type given as: " +
                            self.seq_type)
        except AttributeError:
            pass
        self.seq_headers = [seqi.id for seqi in SeqIO.parse(seq, self.seq_type)]
        self.seq_fasta = [seqi.seq for seqi in SeqIO.parse(seq, self.seq_type)]
        self.base_name = base_name
        self.sequence = seq

    def get_stats(self, total_length, all_lengths):
        """Finds assembly stats if applicable"""
        length = []
        n50, n90 = "", ""
        for contig in sorted(all_lengths, reverse=True):
            length.append(contig)
            if sum(length) >= total_length * 0.9:
                n90 = contig
                l90 = len(length)
                if n50:
                    break
            if sum(length) >= total_length / 2:
                if n50:
                    continue
                n50 = contig
                l50 = len(length)
                if n90:
                    break
        return n50, l50, n90, l90

    def get_length(self):
        """Returns complete sequence length, all individual contig
        lengths, and overall GC content"""
        all_lengths, total_fasta = [], []
        try:
            self.logger.log(logging.INFO, "Gathering sequence length")
        except AttributeError:
            pass
        for fasta in self.seq_fasta:
            all_lengths.append(len(fasta))
            total_fasta.append(str(fasta))
        if self.seq_type == "faa":
            gc_content = 0.0
        else:
            try:
                self.logger.log(logging.INFO, "Calculating GC-content of given sequence")
            except AttributeError:
                pass
            # implement memory-efficient method here
            gc_content = round(GC(''.join(str(total_fasta))), 2)
        seq_length = sum(all_lengths)
        return seq_length, all_lengths, gc_content

    def get_cds(self, proteome=None):
        if proteome:
            cds = [cd.seq for cd in SeqIO.parse(proteome, "fasta")]
        elif self.seq_type == "faa":
            cds = self.seq_fasta
        else:
            cds = None
        return cds
