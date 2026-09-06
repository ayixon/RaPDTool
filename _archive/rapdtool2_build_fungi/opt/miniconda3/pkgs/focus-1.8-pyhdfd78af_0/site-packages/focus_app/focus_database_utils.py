# !/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import logging
import os
import random

from pathlib import Path

from focus_app.focus import (count_kmers,
                             is_wanted_file)
from focus_app import version

WORK_DIRECTORY = str(Path(__file__).parents[0])
LOGGER_FORMAT = '[%(asctime)s - %(levelname)s] %(message)s'


def get_k_mer_count(genomes, kmer_size, threads, kmer_order):
    """Get k-mer count per genome.

    Args:
        genomes (str): Path to file with genomes and their metadata.
        kmer_size (int): K-mer size.
        threads (int): Number of threads used on the k-mer counting.
        kmer_order (list): K-mers to be counted.

    Returns:
        List: List with counts and genomes metadata.

    """
    results = []
    with open(genomes) as f:
        for row in f:
            row = row.strip().split("\t")
            metadata = row[:-1]
            query_file = row[-1]

            if not Path(query_file).exists():
                continue

            k_count = count_kmers(query_file, kmer_size, threads, kmer_order)
            row = metadata + [str(x) for x in k_count]
            results.append("\t".join(row) + "\n")

    return results


def parse_args():
    """Parse args entered by the user.

    Returns:
        argparse.Namespace: Parsed arguments.

    """
    parser = argparse.ArgumentParser(description="FOCUS Database Utils",
                                     epilog="example > focus_database_utils -m GENOMES_TABULAR_FILE")
    parser.add_argument('-v', '--version', action='version', version='FOCUS {}'.format(version))
    parser.add_argument("-g", "--genomes", help="Path to directory with FAST(A/Q) files", required=True)
    parser.add_argument("-t", "--threads", help="Number Threads used in the k-mer counting (Default: 4)", default="4")
    parser.add_argument('-l', '--log', help='Path to log file (Default: STDOUT).', required=False)

    return parser.parse_args()


def main():
    logger = logging.getLogger(__name__)
    args = parse_args()

    if args.log:
        logging.basicConfig(format=LOGGER_FORMAT, level=logging.INFO, filename=args.log)
    else:
        logging.basicConfig(format=LOGGER_FORMAT, level=logging.INFO)

    genomes = args.genomes
    threads = args.threads

    logger.info("FOCUS Database Utils")
    logger.info("Working on {}".format(genomes))

    dbs = "{}/db/".format(WORK_DIRECTORY)
    for db_file in os.listdir(dbs):
        kmer_size = int(db_file[1:])
        db_file = "{}/{}".format(dbs, db_file)

        # get k-mer order from db file
        with open(db_file) as f:
            kmer_order = f.readline().strip().split()[8:]

        k_mer_counts = get_k_mer_count(genomes, kmer_size, threads, kmer_order)

        logger.info("{} genomes will be added to the {} database".format(len(k_mer_counts), db_file))

        with open(db_file, "a") as output:
            for new_row in k_mer_counts:
                output.write(new_row)

    logger.info("Done :)")


if __name__ == "__main__":
    main()
