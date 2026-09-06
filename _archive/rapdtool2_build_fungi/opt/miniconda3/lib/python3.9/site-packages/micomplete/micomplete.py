#!/usr/bin/env python

"""
Copyright and License

Copyright 2017 Eric Hugoson and Lionel Guy

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with
this program.  If not, see http://www.gnu.org/licenses/.
"""

from __future__ import division, print_function

import argparse
import logging
import logging.handlers
import multiprocessing as mp
import os
import re
import shutil
import subprocess
import sys
from collections import OrderedDict, defaultdict
from contextlib import contextmanager
from distutils import spawn

import Bio
from Bio import SeqIO
import matplotlib.pyplot as plt
import numpy as np

try:
    from statistics import median
except ImportError:
    from numpy import median
try:
    from micomplete import __version__
except ImportError:
    __version__ = "1.1.1"
try:
    from micomplete import parseSeqStats
    from micomplete import linkageAnalysis
    from micomplete import calcCompleteness
except ImportError:
    from parseseqs import parseSeqStats
    from linkageanalysis import linkageAnalysis
    from completeness import calcCompleteness

# ordered dict for <3.6 compatibility
HEADERS = OrderedDict()
HEADERS["Name"] = None
HEADERS["Length"] = None
HEADERS["GC-content"] = None
HEADERS["Present Markers"] = None
HEADERS["Completeness"] = None
HEADERS["Redundancy"] = None
HEADERS["Weighted completeness"] = None
HEADERS["Weighted redundancy"] = None
HEADERS["Contigs"] = None
HEADERS["CDS"] = None
HEADERS["N50"] = None
HEADERS["L50"] = None
HEADERS["N90"] = None
HEADERS["L90"] = None

BUILTIN_MARKERS = {"Bact105": ["share/Bact105.hmm", "share/Bact105.weights"],
                   "Arch131": ["share/Arch131.hmm", "share/Arch131.weights"]
                  }

PATH = os.path.abspath(os.path.dirname(__file__))

def _worker(seqObject, seq_type, argv, q=None, name=None):
    seqObject = ''.join(seqObject)
    base_name = base_name = ''.join(os.path.basename(seqObject).split('.')[:-1])
    if not name:
        name = base_name
    log_lvl = logging.WARNING
    if argv.debug:
        log_lvl = logging.DEBUG
    elif argv.verbose:
        log_lvl = logging.INFO
    logger = _configure_logger(q, name, log_lvl)
    logger.log(logging.INFO, "Started work on %s" % name)
    logger.log(logging.INFO, "Creating proteome")
    if re.match("(gb.?.?)|genbank", seq_type):
        logger.log(logging.INFO, "gbk-file, will attempt to extract"
                   "proteome from gbk")
        proteome = extract_gbk_trans(seqObject)
        # if output file is found to be empty, extract contigs and translate
        if os.stat(proteome).st_size == 0:
            logger.log(logging.INFO, "Failed to extract proteome from"
                       "gbk, will extract contigs and create proteome"
                       "using create_proteome()")
            contigs = get_contigs_gbk(seqObject, name=name)
            proteome = create_proteome(contigs, name)
            if os.stat(proteome).st_size == 0:
                logger.log(logging.WARN, "Unable to extract either"
                           "proteins or contigs from genbank file."
                           "Check for file integrity")
    elif seq_type == "fna":
        logger.log(logging.INFO, "Nucleotide fasta, will translate"
                   "using create_proteome()")
        proteome = create_proteome(seqObject, name)
    elif seq_type == "faa":
        logger.log(logging.INFO, "Type is amino acid fasta already")
        proteome = seqObject
    logger.log(logging.INFO, "Gathering stats for sequence")
    fastats = parseSeqStats(seqObject, name, seq_type, logger=logger)
    seq_length, contigs, GCcontent = fastats.get_length()
    try:
        cds = len(fastats.get_cds(proteome))
    except TypeError:
        cds = "-"
    seqstats = (fastats, seq_length, contigs, GCcontent, cds)
    if argv.linkage:
        try:
            assert argv.hmms
        except (AssertionError, NameError):
            logger.log(logging.ERROR, "No HMMs were provided, but a linkage"
                       "calculation was requested.")
            raise NameError("A set of HMMs must be provided to calculate linkage")
        logger.log(logging.INFO, "Started completeness check")
        comp = calcCompleteness(proteome, name, argv.hmms, evalue=argv.evalue,
                                bias=argv.bias, best_domain=argv.domain_cutoff,
                                weights=argv.weights, hlist=argv.hlist,
                                linkage=argv.linkage, lenient=argv.lenient,
                                logger=logger)
        hmm_matches, _, total_hmms = comp.get_completeness()
        if argv.hlist:
            logger.log(logging.INFO, "Writing found/missing/duplicated marker"
                       "lists")
            comp.print_hmm_lists(directory=argv.hlist)
        try:
            frac_hmm = len(hmm_matches) / len(total_hmms)
        except TypeError:
            frac_hmm = 0
        logger.log(logging.INFO, "Checking fraction of markers found in sequence")
        if frac_hmm < argv.cutoff:
            perc_hmm = frac_hmm * 100
            try:
                logger.log(logging.WARNING, "Only %i%% of markers were found in"
                           "%s will not be used to calculate linkage"
                           % (perc_hmm, name))
            except AttributeError:
                print("Warning:", end=' ', file=sys.stderr)
                print("%i%% of markers were found in %s, cannot be used to"
                        "calculate linkage" % (perc_hmm, name), file=sys.stderr)
            return
        logger.log(logging.INFO, "Starting linkage calculations of markers in"
                   "sequence")
        linkage = linkageAnalysis(seqObject, name, seq_type, proteome, seqstats,
                                  hmm_matches, cutoff=argv.linkage_cutoff,
                                  logger=logger)
        if not linkage.is_valid:
            return
        linkage_vals = linkage.calculate_linkage_scores()
        for hmm, match in hmm_matches.items():
            linkage_vals[hmm].append(match)
        q.put(linkage_vals)
        return linkage_vals
    _compile_results(seq_type, name, argv, proteome, seqstats, q, logger)


def _compile_results(seq_type, name, argv, proteome, seqstats, q=None,
                     logger=None):
    """
    Compile results from sequences passed to requested modules and pass
    to Queue for thread safe output. If no Queue given print directly to
    stdout.
    """
    output = []
    headers = HEADERS
    headers['Name'] = name
    headers['CDs'] = seqstats[4]
    if not seq_type == 'faa':
        logger.log(logging.INFO, "Gathering nucleotide sequence stats")
        fastats, headers['Length'], all_lengths, headers['GC-content'], _ = seqstats
        headers['Contigs'] = len(all_lengths)
    else:
        fastats, headers['Length'], headers['Contigs'], headers['GC-content'] = "-", "-", "-", "-"
    #output.extend((name, seq_length, GC))
    if argv.hmms:
        logger.log(logging.INFO, "Started completeness check")
        comp = calcCompleteness(proteome, name, argv.hmms, evalue=argv.evalue,
                                bias=argv.bias, best_domain=argv.domain_cutoff,
                                weights=argv.weights, hlist=argv.hlist,
                                linkage=argv.linkage, lenient=argv.lenient,
                                logger=logger)
        filled_hmms, redun_hmms, total_hmms = comp.quantify_completeness()
        try:
            headers['Present Markers'] = filled_hmms
        except TypeError:
            headers['Present Markers'] = 0
        output.append(headers['Present Markers'])
        try:
            headers['Completeness'] = '%0.4f' % (round(headers['Present Markers'] / total_hmms, 4))
        except ZeroDivisionError:
            headers['Completeness'] = 0
        output.append(headers['Completeness'])
        try:
            headers['Redundancy'] = '%0.4f' % (round((redun_hmms) / headers['Present Markers'], 4))
        except ZeroDivisionError:
            headers['Redundancy'] = 0
        output.append(headers['Redundancy'])
        if argv.weights:
            logger.log(logging.INFO, "Gathering weighted completeness scores")
            if headers['Present Markers'] > 0:
                headers['Weighted completeness'], headers['Weighted redundancy'] = comp.attribute_weights()
            else:
                headers['Weighted completeness'], headers['Weighted redundancy'] = 0, 0
            output.append('%0.4f' % headers['Weighted completeness'])
            output.append('%0.4f' % headers['Weighted redundancy'])
    # only calculate assembly stats if filetype is fna
    if argv.hlist:
        logger.log(logging.INFO, "Writing found/missing/duplicated marker lists")
        comp.print_hmm_lists(directory=argv.hlist)
    if not re.match("(gb.?.?)|genbank|faa", seq_type):
        logger.log(logging.INFO, "Gathering assembly stats")
        headers['N50'], headers['L50'], headers['N90'], headers['L90'] = fastats.get_stats(headers['Length'], all_lengths)
    else:
        headers['N50'], headers['L50'], headers['N90'], headers['L90'] = '-', '-', '-', '-'
    output.extend((headers['N50'], headers['L50'], headers['N90'], headers['L90']))
    if sys.version_info >= (3, 6):
        headers = {header: value for header, value in headers.items() if not value is None}
    else:
        headers = OrderedDict((header, value) for header, value in headers.items() if not value is None)
    if q:
        q.put(headers)
    else:
        print(*headers.values(), sep='\t')


def _configure_logger(q, name, level=logging.WARNING):
    qh = CustomQueueHandler(q)
    logger = logging.getLogger(name)
    logformatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    qh.setFormatter(logformatter)
    logger.addHandler(qh)
    logger.setLevel(level)
    return logger


class CustomQueueHandler(logging.handlers.QueueHandler):
    def prepare(self, record):
        """
        Override prepare method of the QueueHandler to ensure same behavior
        across python versions, respecting formatting assigned.
        """
        msg = self.format(record)
        record.message = msg
        record.msg = msg
        record.args = None
        record.exc_info = None
        record.exc_text = None
        return record


def _listener(q, out=None, weights=None, linkage=False, logger=None, 
              logfile="miComplete.log"):
    """
    Function responsible for outputting information in a thread safe manner.
    Recieves write requests from Queue and writes different targets depending
    on type. Writes results from general operation to stdout, logobjects
    to logfile and any calculated weights of each organism to unified
    tmp file.
    """
    first_result = True
    warnings = False
    logger = _configure_logger(q, "listener", "INFO")
    if logfile:
        logtarget = open(logfile, 'w')
    if linkage:
        weights_file = "micomplete_weights.temp"
        weights_tmp = open(weights_file, mode='w+')
        m = _weights_writer(logger)
        next(m)
    with _dynamic_open(out) as handle:
        # write comment headers before listening
        handle.write("## miComplete\n## v%s\n" % __version__)
        try:
            with open(weights) as weight:
                w_std = weight.readline()
                handle.write("## Weights:\t%s\n## Weights %s"
                             % (weights, w_std))
        except TypeError:
            pass
        while True:
            write_request = q.get()
            if write_request == 'done':
                break
            if isinstance(write_request, dict) and linkage:
                callback = m.send((write_request, weights_tmp))
                continue
            if isinstance(write_request, dict):
                if first_result:
                    for header in write_request.keys():
                        handle.write(str(header) + '\t')
                    handle.write('\n')
                    first_result = False
                for request in write_request.values():
                    handle.write(str(request) + '\t')
                handle.write('\n')
                continue
            if isinstance(write_request, logging.LogRecord):
                if write_request.levelname == "WARNING":
                    warnings = True
                logtarget.write(write_request.getMessage() + '\n')
                continue
            logger.log(logging.WARNING, "Unhandled queue object at _listener: "
                       + handle)
            continue
    try:
        logtarget.close()
    except AttributeError:
        pass
    try:
        m.send(("break", None))
        weights_tmp.close()
        weights_output(weights_file, outfile=out)
    except NameError:
        return
    finally:
        if warnings:
            print("\nmiComplete finished with warnings. View them in %s" % logfile,
                  file=sys.stderr)
    return weights_file


@contextmanager
def _dynamic_open(outfile='-'):
    """Dynamically opens file or stdout depending on argument.

    Usage:
        with dynamic_open(outfile) as handle:
            ##
    """
    if outfile and outfile != '-':
        handle = open(outfile, 'w')
    else:
        handle = sys.stdout
    # close and flush open file if not stdout
    try:
        yield handle
    finally:
        if handle is not sys.stdout:
            handle.close()


def _bias_check(all_bias, logger=None):
    for hmm, bias in all_bias.items():
        total_fraction_bias = sum(bias) / len(bias)
        if total_fraction_bias > 0.5:
            try:
                logger.log(logging.WARNING, "More than 50 of found marker %s had "
                           "more 10 of score bias. Consider not using this marker"
                           % hmm)
            except AttributeError:
                print("Warning:", file=sys.stderr, end=' ')
                print("More than %s%% of found markers had a higher than %s%% of" %
                      (0.5 * 100, 0.1 * 100), file=sys.stderr, end=' ')
                print("score bias in marker %s. Consider not using this marker." %
                      hmm, file=sys.stderr)


def _weights_writer(logger=None):
    """Coroutine to main _listener process for sets of hmm weights. Once all
    sets have been received and _listener has exited, runs bias check"""
    all_bias = defaultdict(list)
    while True:
        weights_set, tmpfile = yield
        if weights_set == "break":
            _bias_check(all_bias, logger=logger)
            continue
        for hmm, match in sorted(weights_set.items(), key=lambda e: e[1],
                                 reverse=True):
            {all_bias[hmm].append(1) if float(stats[3]) / float(stats[2]) > 0.1
             else all_bias[hmm].append(0) for stats in match[1]}
            weight = (str(hmm) + '\t' + str(match[0]) + '\n')
            tmpfile.write(weight)
        tmpfile.write('-\n')
        tmpfile.flush()
    return tmpfile


def weights_output(weights_file, logger=None, outfile='-'):
    """Creates boxplot all linkage values for each marker present in
    micomplete_weights.temp file"""
    # also output weights
    # weight = median / sum(medians)
    with open(weights_file, mode='r') as weights:
        hmm_weights = defaultdict(list)
        for weight in weights:
            if weight.strip() == '-':
                continue
            weight = weight.split()
            hmm_weights[weight[0]].append(float(weight[1]))
    data = []
    labels = []
    stds = []
    median_weights = {}
    #ln_median_weights = []
    # establish medians, also append axis data
    for hmm, weight in sorted(hmm_weights.items(), key=lambda kv: median(kv[1]),
                              reverse=True):
        median_weights[hmm] = median(weight)
        log_weights = [np.log10(each) for each in weight]
        #mu = np.mean(weight)
        sigma = np.std(weight)
        #xmu, _, sigma = stats.lognorm.fit(weight, floc=0)
        #mu = np.log(xmu)
        #mu = np.mean(log_weights)
        #sigma = np.std(log_weights)
        #m = np.exp(mu + sigma**2 / 2.0)
        #stds.append((np.exp(2 * mu + sigma**2) * (np.exp(sigma**2) - 1))**0.5)
        stds.append(sigma)
        data.append(log_weights)
        labels.append(hmm)
    # calculate normalized median weights
    ln_sq_stds = [float(sq_stds**2) for sq_stds in stds]
    ln_sqrt_sum_stds = sum(ln_sq_stds) ** 0.5
    #sqrt_sum_stds = np.e ** ln_sqrt_sum_stds
    weights_sum = sum(median_weights.values())
    norm_weights = []
    with _dynamic_open(outfile) as out:
        out.write("Standard deviation:\t" + str(ln_sqrt_sum_stds) + '\n')
        for hmm, median_weight in sorted(median_weights.items(),
                                         key=lambda kv: kv[1]):
            norm_weight = median_weight / weights_sum
            norm_weights.append(np.log10(norm_weight))
            out.write(hmm + "\t" + str(norm_weight) + '\n')
    # create violinplot
    plt.style.use('seaborn')
    fig = plt.figure(1, figsize=(9, 6))
    ax = fig.add_subplot(111)
    ax.set_aspect('auto')
    parts = plt.violinplot(data, vert=False, showmedians=True, widths=1.0, bw_method='scott')
    for pc in parts['bodies']:
        pc.set_alpha(1)
    medians = []
    for dataset in data:
        medians.append(np.median(dataset))
    inds = np.arange(1, len(medians) + 1)
    ax.scatter(norm_weights[::-1], inds, marker='|', color='red', s=30, zorder=3)
    ax.scatter(medians, inds, marker='|', color='orange', s=30, zorder=3)
    ax.set_yticks(np.arange(1, len(labels) + 1))
    ax.set_yticklabels(labels, fontsize=6)
    ax.xaxis.grid(True, linestyle='-', which='major', color='lightgrey',
                  alpha=0.5)
    ax.set_xlabel('Relative linkage distance (log)')
    ax.set_ylabel('Markers')
    plt.show()
    #plt.savefig("distplot.png", format="png", dpi=800)


def create_proteome(fasta, base_name=None, logger=None):
    """Create proteome from given .fna file, returns proteome filename"""
    try:
        assert shutil.which('prodigal')
    except AssertionError:
        raise RuntimeError("Unable to locate prodigal in path")
    except AttributeError:
        try:
            assert spawn.find_executable('prodigal')
        except AssertionError:
            raise RuntimeError('Unable to find prodigal in path')
    if not base_name:
        base_name = ''.join(os.path.basename(fasta).split('.')[:-1])
    prot_filename = base_name + "_prodigal.faa"
    if sys.version_info > (3, 4):
        subprocess.run(['prodigal', '-i', fasta, '-a', prot_filename],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.call(['prodigal', '-i', fasta, '-a', prot_filename],
                        stdout=open(os.devnull, 'wb'), stderr=subprocess.STDOUT)
    return prot_filename


def extract_gbk_trans(gbkfile, outfile=None, logger=None):
    """Extract translated sequences from given GeneBank file and out to given
    filename. Returns file name of translation"""
    input_handle = open(gbkfile, mode='r')
    if outfile:
        output_handle = open(outfile, mode='w+')
    else:
        base_name = base_name = ''.join(os.path.basename(gbkfile).split('.')[:-1])
        outfile = base_name + "_translations.faa"
        output_handle = open(outfile, mode='w+')
    contig_n = 0
    cds_n = 0
    # compile regex to match multi-loc hits
    loc_search = re.compile('{(.*?)}')
    for record in SeqIO.parse(input_handle, "genbank"):
        for feature in record.features:
            if feature.type == "source":
                contig_n += 1
            if feature.type == "CDS":
                cds_n += 1
                try:
                    header = ">" + feature.qualifiers['locus_tag'][0]
                except KeyError:
                    try:
                        header = ">" + feature.qualifiers['gene'][0]
                    except KeyError:
                        try:
                            header = ">" + feature.qualifiers['protein_id'][0]
                        except KeyError:
                            continue
                # some CDS do not have translations, retrieve nucleotide sequence
                # and translate
                try:
                    assert feature.qualifiers['translation'][0]
                except (AssertionError, KeyError):
                    start = str(feature.location.nofuzzy_start)
                    end = str(feature.location.nofuzzy_end)
                    if feature.strand > 0:
                        strand = '+'
                    else:
                        strand = '-'
                    ttable = int(''.join(feature.qualifiers['transl_table']))
                    # check if the locus represents valid CDS else skip
                    try:
                        fasta_trans = ('\n' + str(feature.extract(record.seq).translate(
                            table=ttable, cds=True, to_stop=True)) + '\n')
                    except Bio.Data.CodonTable.TranslationError:
                        continue
                    #conitnue # not sure why it was here. miscopied from above?
                    output_handle.write(header)
                    output_handle.write(' # ' + start + ' # ' + end + ' # ' +
                                        strand + ' # ID=' + str(contig_n) + '_'
                                        + str(cds_n) + ';')
                    output_handle.write(fasta_trans)
                    continue
                # very occasionally translated seqs have two or more locations
                # regex search to handle such cases
                output_handle.write(header)
                locs = loc_search.search(str(feature.location))
                if locs:
                    locs_list = locs.group(1).split(',')
                    for loc in locs_list:
                        loc_str = ''.join(l for l in ''.join(loc)
                                          if l not in "[]")
                        loc_str = re.sub(r'\(|\)|:', ' # ', loc_str)
                        loc_str = re.sub('>|<', '', loc_str)
                        output_handle.write(" # " + loc_str)
                else:
                    loc_str = ''.join(l for l in ''.join(str(feature.location))
                                      if l not in "[]")
                    loc_str = re.sub(r'\(|\)|\:', ' # ', loc_str)
                    loc_str = re.sub('>|<', '', loc_str)
                    output_handle.write(" # " + loc_str)
                output_handle.write('ID=' + str(contig_n) + '_' + str(cds_n)
                                    + ';')
                output_handle.write('\n' + feature.qualifiers['translation'][0]
                                    + '\n')
    input_handle.close()
    output_handle.flush()
    output_handle.close()
    return outfile


def get_contigs_gbk(gbk, name=None):
    """Extracts all sequences from gbk file, returns filename"""
    handle = open(gbk, mode='r')
    if not name:
        name = base_name = ''.join(os.path.basename(gbk).split('.')[:-1])
    out_handle = open(name, mode='w')
    for seq in SeqIO.parse(handle, "genbank"):
        out_handle.write(">" + seq.id + "\n")
        out_handle.write(str(seq.seq) + "\n")
    out_handle.close()
    return name


def main():
    if sys.version_info < (3, 4):
       raise Exception("miComplete does not support python version below 3.4")
    parser = argparse.ArgumentParser(
        description="""
            Quality control of metagenome assembled genomes. Able to gather
            relevant statistics of completeness and redundancy of genomes given 
            sets of marker genes, as well as weighted versions of these statstics
            (including defining new weights for any given set).
            """,
        epilog="""Report issues and bugs to the issue tracker at
                https://bitbucket.org/evolegiolab/micomplete or directly to 
                eric@hugoson.org""",
        prog='miComplete')

    parser.add_argument("sequence_tab", help="""Sequence(s) along with type (fna,
                        faa, gbk) provided in a tabular format""")
    parser.add_argument("--lenient", action='store_true', default=False,
                        help="""By default miComplete drops hits with too high
                        bias or too low best domain score. This argument disables
                        that behavior, permitting any hit which meet the evalue
                        requirements.""")
    parser.add_argument("--format", default=None, choices=['fna', 'faa', 'gbk'],
                        help="""This argument should be used when a single
                        sequence file is given in place of tabulated file of
                        sequences. The argument should be followed by the format
                        of the sequence.""")
    parser.add_argument("--hlist", required=False, default=None, type=str,
                        nargs='?', help="""Write list of Present, Absent and
                        Duplicated markers for each organism to file""")
    parser.add_argument("--hmms", required=False, default=False,
                        help="""Specifies a set of HMMs to be used for
                        completeness check or linkage analysis. The default sets,
                        "Bact105" and "Arch131", can be called via their 
                        respective names.""")
    parser.add_argument("--weights", required=False, default=None,
                        help="""Specify a set of weights for the HMMs specified.
                        The default sets, "Bact105" and "Arch131", can be called
                        via their respective names.""")
    parser.add_argument("--linkage", required=False, default=False,
                        action='store_true', help="""Specifies that the provided
                        sequences should be used to calculate the weights of the
                        provided HMMs""")
    parser.add_argument("--linkage-cutoff", type=float, default=0.8,
                        help="""Cutoff fraction of the entire fasta which
                        needs to be contained in a single contig in order to be 
                        included in linkage calculations. Disabling this is 
                        likely to result in some erroneous calculations.""")
    parser.add_argument("--evalue", required=False, type=float, default=4e-10,
                        help="""Specify e-value cutoff to be used for
                        completeness check. Default = 4e-10""")
    parser.add_argument("--bias", required=False, type=float, default=0.3,
                        help="""Specify bias cutoff as fraction of score as
                        defined by hmmer. Default = 0.3""")
    parser.add_argument("--domain-cutoff", type=float, default=1e-5,
                        help="""Specify largest allowed difference between full
                        sequence- and domain evalues. Default = 1e-5""")
    parser.add_argument("--cutoff", required=False, type=float, default=0.9,
                        help="""Specify cutoff percentage of markers required
                        to be present in genome for it be included in linkage 
                        calculation. Default = 0.9""")
    parser.add_argument("--threads", required=False, default=1, type=int,
                        help="""Specify number of threads to be used in
                        parallel. Default = 1""")
    parser.add_argument("--log", required=False, default="miComplete.log",
                        type=str, help="Log name. Default=miComplete.log")
    parser.add_argument("-v", "--verbose", required=False, default=False,
                        action='store_true', help="""Enable verbose logging""")
    parser.add_argument("--debug", required=False, default=False,
                        action='store_true')
    parser.add_argument("--version", default=False, action='version',
                        version='%(prog)s {version}'.format(version=__version__), 
                        help="Returns miComplete version and exits")
    parser.add_argument("-o", "--outfile", default=None, help="Outfile "
                        "can be specified. None or \"-\" will result in "
                        "printing to stdout")
    args = parser.parse_args()

    if args.hmms or args.linkage:
        try:
            assert shutil.which('hmmsearch')
        except AssertionError:
            raise RuntimeError('Unable to find hmmsearch in path')
        except AttributeError:
            try:
                assert spawn.find_executable('hmmsearch')
            except AssertionError:
                raise RuntimeError('Unable to find hmmsearch in path')
        if args.hmms in BUILTIN_MARKERS.keys():
            args.hmms = os.path.join(PATH, BUILTIN_MARKERS[args.hmms][0])
        if args.weights in BUILTIN_MARKERS.keys():
            args.weights = os.path.join(PATH, BUILTIN_MARKERS[args.weights][1])
    
    with open(args.sequence_tab) as seq_file:
        input_seqs = [seq.strip().split('\t') for seq in seq_file
                      if not re.match('#|\n', seq)]

    manager = mp.Manager()
    q = manager.Queue()
    pool = mp.Pool(processes=args.threads + 1)
    logger = _configure_logger(q, "main", "DEBUG")
    writer = pool.apply_async(_listener, (q, args.outfile),
                              {"weights": args.weights, "linkage": args.linkage,
                               "logfile": args.log})
    logger.log(logging.INFO, "miComplete has started")
    logger.log(logging.INFO, "Using %i thread(s)" % args.threads)
    jobs = []
    if args.format:
        job = pool.apply_async(_worker, (args.sequence_tab, args.format, args),
                               {"q": q})
        jobs.append(job)
    else:
        try:
            logger.log(logging.INFO, "List of given sequences:")
            for seq in input_seqs:
                logger.log(logging.INFO, seq[0])
            for i in input_seqs:
                if len(i) == 2:
                    i.append(None)
                job = pool.apply_async(_worker, (i[0], i[1], args),
                                       {"q": q, "name": i[2]})
                jobs.append(job)
        except IndexError:
            raise RuntimeError('File given appears to be incorrectly formatted. '
                               'If you are attempting to use a single sequence '
                               'file, remember to provide the --format argument.')

    # get() all processes to catch errors
    for job in jobs:
        try:
            job.get()
        except Exception as e:
            # since Queue dies with manager, set up new logger here to
            # catch exceptions
            logger = logging.getLogger("main")
            handler = logging.FileHandler(args.log)
            formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            handler.setFormatter(formatter)
            logger.addHandler(handler)
            logger.log(logging.ERROR, "Error encountered in main. Exiting.",
                       exc_info=True)
            raise e
    logger.log(logging.INFO, "Finished work on all given sequences")
    q.put("done")
    logger.log(logging.INFO, "Waiting for listener to finish and exit")
    pool.close()
    pool.join()
    logger.info("miComplete has finished")

if __name__ == "__main__":
    main()
