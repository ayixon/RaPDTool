#!/usr/bin/env python3
"""RaPDTool - Rapid Profiling and Deconvolution Tool for metagenomes.

Pipeline: FOCUS (taxonomic profile) -> Metabat2 (binning) -> Binning_refiner
-> miComplete (completeness) -> Mash (genomic-distance classification) ->
report merge -> Krona -> per-species bin split.

Modes:
  full     complete pipeline (default)
  profile  only FOCUS profiling + Krona (for genomic assemblies where binning
           does not make sense)
"""

import argparse
import gzip
import os
import shutil
import subprocess
import sys
import time

VERSION = '2.3.2'

# accepted input extensions (optionally followed by .gz)
FASTA_EXTS = ('.fasta', '.fa', '.fna', '.fas', '.ffn', '.frn')
FASTQ_EXTS = ('.fastq', '.fq')          # raw reads, accepted in screen mode only
INPUT_EXTS = FASTA_EXTS + FASTQ_EXTS

# FOCUS selects its inputs by file suffix and reads only these three, so the
# working copy is renamed to one of them (and decompressed if needed) before
# FOCUS is invoked. Without this, an input this tool documents as valid -- .fa,
# .fas, .fq, or anything .gz -- is silently ignored by FOCUS.
FOCUS_EXTS = ('.fna', '.fasta', '.fastq')


def eprint(*args):
    print(*args, file=sys.stderr)


class Pipeline:
    def __init__(self, opts):
        self.opts = opts
        self.mode = opts.mode
        self.threads = str(opts.threads)
        self.comment = '' if opts.comment is None else '\nComment: ' + opts.comment
        self.launched_from = os.getcwd()
        self.database = None
        self.focus_db = None
        self.root = ''
        self.paths = {}
        self.log_file = ''
        # file-dependent attributes, set in set_file_paths()
        self.filename = ''
        self.bluntname = ''
        self.input_file = ''

    # ------------------------------------------------------------------ utils
    def log(self, message):
        if self.log_file:
            with open(self.log_file, 'a') as fh:
                fh.write(str(message) + '\n')

    def fail(self, step, detail):
        msg = 'ERROR in step "%s": %s' % (step, detail)
        self.log(msg)
        eprint('\n' + msg)
        if self.log_file:
            eprint('Pipeline aborted. See log: ' + self.log_file)
        sys.exit(1)

    def run(self, step, argv, stdout_path=None, cwd=None, stdin_data=None,
            allow_fail=False):
        """Run a command as an argv list (no shell). Aborts on failure unless
        allow_fail is set. If stdout_path is given, stdout is redirected there,
        otherwise it is captured."""
        argv = [str(a) for a in argv]
        shown = '$ ' + ' '.join(argv)
        if stdout_path:
            shown += ' > ' + stdout_path
        self.log(shown)
        outf = open(stdout_path, 'w') if stdout_path else None
        try:
            res = subprocess.run(
                argv, cwd=cwd, input=stdin_data,
                stdout=outf if outf else subprocess.PIPE,
                stderr=subprocess.PIPE, text=True)
        except FileNotFoundError:
            if outf:
                outf.close()
            self.fail(step, "executable not found: '%s'" % argv[0])
        finally:
            if outf:
                outf.close()
        stderr = (res.stderr or '').strip()
        if res.returncode != 0:
            if allow_fail:
                self.log('[%s] warning: exit %d %s' % (step, res.returncode, stderr))
                return res
            self.fail(step, 'exited with code %d\n%s' % (res.returncode, stderr))
        if stderr:
            self.log('[%s] stderr: %s' % (step, stderr[:2000]))
        return res

    @staticmethod
    def open_maybe_gz(path):
        if path.endswith('.gz'):
            return gzip.open(path, 'rt')
        return open(path, 'r')

    @classmethod
    def blunt_name(cls, filename):
        """Strip a known FASTA/FASTQ extension (and optional .gz); '.' -> '_'."""
        name = filename
        if name.lower().endswith('.gz'):
            name = name[:-3]
        low = name.lower()
        for ext in INPUT_EXTS:
            if low.endswith(ext):
                name = name[:-len(ext)]
                break
        else:
            rmp = name.rfind('.')
            if rmp >= 0:
                name = name[:rmp]
        return name.replace('.', '_')

    @classmethod
    def focus_name(cls, filename, fastq=False):
        """Name the working copy so FOCUS accepts it: strip .gz, replace a known
        extension with .fasta (or .fastq for reads), leave .fna/.fasta/.fastq as
        they are. Only the copy is renamed -- every output path keeps the name
        the user gave."""
        name = filename
        if name.lower().endswith('.gz'):
            name = name[:-3]
        low = name.lower()
        if low.endswith(FOCUS_EXTS):
            return name
        for ext in INPUT_EXTS:
            if low.endswith(ext):
                name = name[:-len(ext)]
                break
        return name + ('.fastq' if fastq else '.fasta')

    def _first_char(self, path):
        try:
            with self.open_maybe_gz(path) as fh:
                for line in fh:
                    s = line.strip()
                    if s:
                        return s[0]
        except (OSError, gzip.BadGzipFile):
            return None
        return None

    def is_fasta(self, path):
        return self._first_char(path) == '>'

    def is_fastq(self, path):
        return self._first_char(path) == '@'

    # ------------------------------------------------------------------ setup
    def set_root(self, root_option):
        if root_option is None:
            root = os.path.join(self.launched_from, 'rapdtool_results')
        else:
            root = os.path.abspath(root_option)
        os.makedirs(root, exist_ok=True)
        self.root = root + '/'
        return 'Using root path ' + self.root

    def set_paths(self):
        r = self.root
        p = self.paths
        p['log'] = r + 'log/'
        p['input'] = r + 'inputfmbm/'
        p['profiles'] = r + 'profilesfmbm/'
        p['processed'] = r + 'processedfmbm/'
        p['allresults'] = r + 'allresultsfmbm/'
        work = r + 'workfmbm/'
        p['work'] = work
        p['logfocus'] = work + 'logfocus/'
        p['binmetabat'] = work + 'binmetabat/'
        p['logmetabat'] = work + 'logmetabat/'
        p['inbinningref'] = work + 'inbinningref/'
        p['outbinningref'] = work + 'outbinningref/'
        p['logbinningref'] = work + 'logbinningref/'
        p['inmicomplete'] = work + 'inmicomplete/'
        p['outmicomplete'] = work + 'outmicomplete/'
        p['outmash'] = work + 'outmash/'
        p['micompleteres'] = r + 'miCompleteRes/'

        if self.mode == 'full':
            needed = list(p.keys())
        else:
            needed = ['log', 'input', 'profiles', 'processed', 'logfocus', 'work']

        self.log_file = p['log'] + 'logfmbm.txt'
        for key in needed:
            os.makedirs(p[key], exist_ok=True)
        return 'All paths were verified'

    def pick_database(self):
        """Resolve the mash database from -d/--database (defaults to $RTMASHDB).
        Required in full mode. In profile mode it is optional: if given, mash is
        run on the whole assembly as a single bin; if absent, mash is skipped."""
        db = self.opts.database
        if not db:
            if self.mode == 'profile':
                return 'profile mode: no mash database given, mash classification skipped'
            self.fail('database',
                      'no database given. Pass -d/--database <file.msh> or export '
                      'RTMASHDB=/path/to/database.msh')
        db = os.path.abspath(db)
        if not os.path.isfile(db):
            self.fail('database', 'database not found: ' + db)
        self.database = db
        return 'Using database: ' + db

    def pick_focus_db(self):
        """Resolve the FOCUS k-mer database directory from --focus-db (defaults
        to $RTFOCUSDB). FOCUS runs in both modes, so it is always required.
        The directory must contain 'db/k6' (kmer size 6, FOCUS default)."""
        d = self.opts.focus_db
        if not d:
            self.fail('focus-db',
                      'no FOCUS database given. Pass --focus-db <dir> or export '
                      'RTFOCUSDB=/path/to/focus (a directory containing db/k6)')
        d = os.path.abspath(d)
        kdb = os.path.join(d, 'db', 'k6')
        if not os.path.isfile(kdb):
            self.fail('focus-db', 'FOCUS k-mer database not found: ' + kdb)
        self.focus_db = d
        return 'Using FOCUS database dir: ' + d

    def pick_fasta(self):
        opt = self.opts.input
        if not os.path.isfile(opt):
            self.fail('input', 'input file not found: ' + opt)
        fastq = False
        if self.mode == 'screen':
            fastq = self.is_fastq(opt)
            if not (self.is_fasta(opt) or fastq):
                self.fail('input', 'not a FASTA/FASTQ file (must start with ">" or "@"): ' + opt)
        elif not self.is_fasta(opt):
            self.fail('input', 'not a FASTA assembly (must start with ">"). Raw reads '
                      '(FASTQ) are supported only in screen mode (-m screen): ' + opt)
        filename = os.path.basename(opt)
        target = self.paths['input'] + self.focus_name(filename, fastq)
        if opt.lower().endswith('.gz'):
            with self.open_maybe_gz(opt) as src, open(target, 'w') as dst:
                shutil.copyfileobj(src, dst)
        elif os.path.abspath(opt) != os.path.abspath(target):
            shutil.copy(opt, target)
        bluntname = self.blunt_name(filename)

        collide = [self.paths['profiles'] + bluntname + '/',
                   self.paths['allresults'] + bluntname + '/']
        if self.mode == 'full':
            collide += [self.paths['binmetabat'] + bluntname + '/',
                        self.paths['inbinningref'] + bluntname + '/',
                        self.paths['outbinningref'] + bluntname + '_Binning_refiner_outputs/',
                        self.paths['outmash'] + bluntname + '/']
        existing = [c for c in collide if os.path.exists(c)]
        if existing and not self.opts.force:
            self.fail('input', 'results for "%s" already exist (%s). Use --force to '
                      'overwrite or a different -r output dir.' % (bluntname, existing[0]))

        info = os.stat(target)
        self.filename = filename
        self.bluntname = bluntname
        self.input_file = target
        return ('Input file: %s, size: %d, tstamp: %s' %
                (target, info.st_size,
                 time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(info.st_mtime))))

    def set_file_paths(self):
        b = self.bluntname
        p = self.paths
        self.focus_out = p['profiles'] + b + '/'
        self.focus_log = p['logfocus'] + self.filename + '.txt'
        self.result_path = p['allresults'] + b + '/'
        self.mash_out = p['outmash'] + b + '/'
        if self.mode == 'full':
            self.metabat_bin = p['binmetabat'] + b + '/'
            self.metabat_log = p['logmetabat'] + self.filename + '.txt'
            self.binref_in = p['inbinningref'] + b + '/'
            self.binref_in_one = self.binref_in + 'one/'
            self.binref_in_two = self.binref_in + 'two/'
            self.binref_out = p['outbinningref'] + b + '_Binning_refiner_outputs/'
            self.binref_sandl = self.binref_out + b + '_sources_and_length.txt'
            self.binref_contigs = self.binref_out + b + '_contigs.txt'
            self.binref_sankey_csv = self.binref_out + b + '_sankey.csv'
            self.binref_sankey_htm = self.binref_out + b + '_sankey.html'
            self.binref_refbins = self.binref_out + b + '_refined_bins/'
            self.binref_log = p['logbinningref'] + self.filename + '.txt'
            self.micomplete_in = p['inmicomplete'] + b + '.tab'
            self.micomplete_out = p['outmicomplete'] + 'miCompleteOut_' + b + '.tab'

        dirs = [self.focus_out, self.result_path]
        if self.mode == 'full':
            dirs += [self.metabat_bin, self.binref_in, self.binref_in_one,
                     self.binref_in_two, self.mash_out]
        for d in dirs:
            if os.path.exists(d):
                shutil.rmtree(d)
            os.makedirs(d)
        return 'Filenames and paths were initialized'

    # ------------------------------------------------------------------ steps
    def step_focus(self, index, total):
        print('Running FOCUS.. [%d/%d]' % (index, total))
        self.log('FOCUS command')
        self.run('focus',
                 ['focus', '-q', self.paths['input'], '-o', self.focus_out,
                  '-l', self.focus_log, '-t', self.threads, '-b', self.focus_db])
        levels = self.focus_out + 'output_All_levels.csv'
        if not os.path.isfile(levels):
            self.fail('focus', 'expected output not created: ' + levels)
        self.log('focus - profile created (%s)' % levels)

    def step_metabat(self, index, total):
        print('Running Metabat.. [%d/%d]' % (index, total))
        self.log('METABAT command')
        argv = ['metabat2', '-t', self.threads, '-m', '1500',
                '-i', self.input_file, '-o', self.metabat_bin + 'metabat']
        if self.opts.coverage:
            cov = os.path.abspath(self.opts.coverage)
            if not os.path.isfile(cov):
                self.fail('metabat', 'coverage/depth file not found: ' + cov)
            argv += ['-a', cov]
        self.run('metabat2', argv, stdout_path=self.metabat_log)
        bins = os.listdir(self.metabat_bin)
        if not bins:
            self.fail('metabat2', 'no bins were produced (check assembly / coverage)')
        for sub in (self.binref_in_one, self.binref_in_two):
            for name in bins:
                shutil.copy(self.metabat_bin + name, sub + name)
        self.log('metabat - %d bin(s) created' % len(bins))

    def step_binning_refiner(self, index, total):
        print('Running Binning_refiner.. [%d/%d]' % (index, total))
        self.log('Binning_refiner command')
        self.run('Binning_refiner',
                 ['Binning_refiner', '-i', self.binref_in, '-p', self.bluntname, '-plot'],
                 stdout_path=self.binref_log, cwd=self.paths['outbinningref'])
        if not os.path.isdir(self.binref_refbins):
            self.fail('Binning_refiner', 'refined bins dir not created: ' + self.binref_refbins)
        # normalize refined bin extensions to .fna
        refined = []
        for name in os.listdir(self.binref_refbins):
            if name.endswith('.fna'):
                refined.append(name)
                continue
            dot = name.rfind('.')
            newname = (name[:dot] if dot >= 0 else name) + '.fna'
            shutil.move(self.binref_refbins + name, self.binref_refbins + newname)
            refined.append(newname)
        self.refined_bins = os.listdir(self.binref_refbins)
        self.log('Binning_refiner - %d refined bin(s)' % len(self.refined_bins))

    def step_micomplete(self, index, total):
        print('Running miComplete.. [%d/%d]' % (index, total))
        self.log('miComplete command')
        fna = sorted(self.binref_refbins + n for n in self.refined_bins if n.endswith('.fna'))
        self.run('miCompletelist', ['miCompletelist.sh'],
                 stdin_data='\n'.join(fna) + '\n', stdout_path=self.micomplete_in)
        self.run('miComplete',
                 ['miComplete', self.micomplete_in, '--hmms', 'Bact105',
                  '--threads', self.threads],
                 stdout_path=self.micomplete_out, allow_fail=True)
        if os.path.isfile(self.micomplete_out):
            shutil.copy(self.micomplete_out, self.paths['micompleteres'])
            self.log('miComplete - %s' % self.micomplete_out)

    def step_mash(self, index, total):
        print('Running Mash.. [%d/%d]' % (index, total))
        self.log('MASH - start cycling')
        for name in self.refined_bins:
            self.run('mash',
                     ['mash', 'dist', self.binref_refbins + name, self.database,
                      '-p', self.threads],
                     stdout_path=self.mash_out + name + '.txt', allow_fail=True)
        reports = os.listdir(self.mash_out)
        self.log('mash - %d taxonomic match report(s)' % len(reports))
        self._extract_min_dist(reports)

    def step_mash_profile(self, index, total):
        """Profile mode: classify the whole assembly as a single 'bin'.
        The report parser expects a '.fna' query name, so mash is run on a .fna
        symlink to the input; the link is removed afterwards so no per-scaffold
        (binning) info leaks into the merged table."""
        print('Running Mash.. [%d/%d]' % (index, total))
        self.log('MASH (whole assembly as a single bin)')
        os.makedirs(self.mash_out, exist_ok=True)
        query = self.paths['work'] + self.bluntname + '.fna'
        if os.path.lexists(query):
            os.remove(query)
        os.symlink(self.input_file, query)
        self.run('mash', ['mash', 'dist', query, self.database, '-p', self.threads],
                 stdout_path=self.mash_out + self.bluntname + '.fna.txt', allow_fail=True)
        os.remove(query)
        reports = os.listdir(self.mash_out)
        self.log('mash - %d taxonomic match report(s)' % len(reports))
        self._extract_min_dist(reports)

    def step_mash_screen(self, index, total):
        """Screen mode: identify reference genomes contained in the whole assembly
        with 'mash screen' (containment) -- no binning.

        Hits are tiered exactly as full/profile mode tiers its Mash distances, so the
        same evidence yields the same rank whichever mode produced it: identity
        >= --screen-identity (0.95, i.e. distance < 0.05) is reported as a species and
        >= --screen-genus-identity (0.92, distance 0.05-0.08) as a genus. Before 2.3.2
        screen applied the species cutoff alone and stayed silent across the genus
        band, so an organism full mode placed to genus was not reported at all.

        Written to mashscreen_hits.txt (species) and mashscreen_genus_hits.txt (genus)
        for the report merger."""
        print('Running Mash screen.. [%d/%d]' % (index, total))
        self.log('MASH screen (reference-genome containment)')
        os.makedirs(self.mash_out, exist_ok=True)
        raw = self.mash_out + self.bluntname + '.screen.tab'
        self.run('mash-screen',
                 ['mash', 'screen', '-w', '-p', self.threads, self.database, self.input_file],
                 stdout_path=raw, allow_fail=True)
        cutoff = self.opts.screen_identity
        gcutoff = self.opts.screen_genus_identity
        if gcutoff > cutoff:
            self.log('WARNING: --screen-genus-identity (%.2f) is above --screen-identity '
                     '(%.2f), so no genus band exists' % (gcutoff, cutoff))
        hits, ghits = [], []
        if os.path.isfile(raw):
            for line in open(raw):
                f = line.rstrip('\n').split('\t')
                if len(f) < 5:
                    continue
                try:
                    ident = float(f[0])
                except ValueError:
                    continue
                row = (ident, f[1], f[4])            # identity, shared-hashes, ref name
                if ident >= cutoff:
                    hits.append(row)
                elif ident >= gcutoff:
                    ghits.append(row)
            hits.sort(reverse=True)
            ghits.sort(reverse=True)
        for name, rows in (('mashscreen_hits.txt', hits),
                           ('mashscreen_genus_hits.txt', ghits)):
            with open(self.root + name, 'w') as fh:
                for ident, shared, ref in rows:
                    fh.write('%.4f\t%s\t%s\n' % (ident, shared, ref))
        self.log('mash screen - %d genome(s) >= %.2f identity (species tier), '
                 '%d in %.2f-%.2f (genus tier)'
                 % (len(hits), cutoff, len(ghits), gcutoff, cutoff))

    def _extract_min_dist(self, reports, want=10):
        for mtm in reports:
            rows = []
            rown = 0
            for line in open(self.mash_out + mtm):
                rown += 1
                items = line.rstrip().split('\t')
                if len(items) != 5:
                    continue
                dist = float(items[2])
                items.append(str(rown))
                items.append(dist)
                idx = len(rows)
                while idx - 1 >= 0 and dist < rows[idx - 1][6]:
                    idx -= 1
                if idx == len(rows):
                    if len(rows) == want:
                        continue
                    rows.append(items)
                    continue
                rows.insert(idx, items)
                if len(rows) > want:
                    rows.pop()
            with open(self.result_path + mtm + '.out', 'w') as out:
                for row in rows:
                    out.write('\t'.join(row[:6]) + '\n')
                out.write(self.comment + '\n')
        self.log('Extracted best %d distances for %d file(s)' % (want, len(reports)))

    def link_results(self):
        for src in (self.binref_sandl, self.binref_contigs, self.binref_sankey_csv,
                    self.binref_sankey_htm):
            if os.path.isfile(src):
                shutil.copy(src, self.result_path + os.path.basename(src))
        self.log('Binning_refiner outputs linked to results dir')

    def merge_and_krona(self, index, total):
        print('Copying and merging results.. [%d/%d]' % (index, total))
        self.log('Copying and merging results..')
        merge_argv = ['rapdtool_results.pl']
        if self.mode == 'profile':          # no binning -> drop completeness/bin columns
            merge_argv.append('-p')
        self.run('rapdtool_results', merge_argv, cwd=self.root)
        print('Generating Krona visualization.. [%d/%d]' % (index + 1, total))
        self.log('Generating Krona visualization..')
        self.run('krona', ['ktImportText', 'forkrona.txt', '-o', 'rapdtool_krona.html'],
                 cwd=self.root, allow_fail=True)
        for junk in ('profilesfmbm.txt', 'forkrona.txt', 'mashscreen_hits.txt'):
            jp = self.root + junk
            if os.path.isfile(jp):
                os.remove(jp)

    def step_split_bins(self, index, total):
        print('Splitting bins by species.. [%d/%d]' % (index, total))
        self.log('rapdtool_split_bins command')
        self.run('rapdtool_split_bins',
                 ['rapdtool_split_bins.py', '--root', self.root],
                 cwd=self.root, allow_fail=True)

    def cleanup(self):
        self.log('Removing tmp directories..')
        log_dir = self.paths['log']
        # miComplete leaves artifacts in the launch directory
        for name in os.listdir(self.launched_from):
            if name.endswith('.tblout') or name.endswith('_prodigal.faa'):
                try:
                    os.remove(os.path.join(self.launched_from, name))
                except OSError:
                    pass
        for src in (os.path.join(self.launched_from, 'miComplete.log'),
                    self.root + 'assemblyID_annot.txt'):
            if os.path.isfile(src):
                shutil.move(src, log_dir + os.path.basename(src))
        for key in ('input', 'processed', 'micompleteres'):
            d = self.paths.get(key, '')
            if d and os.path.isdir(d):
                shutil.rmtree(d)

    # ------------------------------------------------------------------- main
    def run_pipeline(self):
        root_msg = self.set_root(self.opts.output)
        paths_msg = self.set_paths()   # sets self.log_file, so log from here on
        self.log('\n* Starting execution ' + time.strftime('%Y-%m-%d %H:%M:%S') +
                 ' (mode: %s)' % self.mode + self.comment)
        self.log(root_msg)
        self.log(paths_msg)
        self.log(self.pick_database())
        self.log(self.pick_focus_db())
        self.log(self.pick_fasta())
        self.log(self.set_file_paths())

        if self.mode == 'profile':
            run_mash = self.database is not None
            total = 4 if run_mash else 3
            step = 1
            self.step_focus(step, total); step += 1
            if run_mash:
                self.step_mash_profile(step, total); step += 1
            shutil.move(self.input_file, self.paths['processed'] + self.filename)
            self.merge_and_krona(step, total)
            self.cleanup()
        elif self.mode == 'screen':
            total = 4
            self.step_focus(1, total)
            self.step_mash_screen(2, total)
            shutil.move(self.input_file, self.paths['processed'] + self.filename)
            self.merge_and_krona(3, total)
            self.cleanup()
        else:
            total = 8 if self.opts.split_bins else 7
            self.step_focus(1, total)
            self.step_metabat(2, total)
            self.step_binning_refiner(3, total)
            self.step_micomplete(4, total)
            self.step_mash(5, total)
            self.link_results()
            shutil.move(self.input_file, self.paths['processed'] + self.filename)
            self.merge_and_krona(6, total)
            if self.opts.split_bins:
                self.step_split_bins(8, total)
            self.cleanup()

        self.log('Done - results are in ' + self.root)
        print('Done - your results are in ' + self.root)


def pick_options(argv=None):
    parser = argparse.ArgumentParser(
        prog='rapdtool.py',
        description='RaPDTool v%s - Focus/Metabat/Binning_refiner/miComplete/Mash '
                    'metagenome pipeline' % VERSION)
    parser.add_argument('-i', '--input', required=True,
                        help='input FASTA assembly (.fasta/.fa/.fna/.fas/.ffn/.frn, optionally '
                             '.gz); FASTQ reads (.fastq/.fq[.gz]) are also accepted in screen '
                             'mode. Compressed or non-canonical extensions are normalised '
                             'internally, so any of these works')
    parser.add_argument('-d', '--database', default=os.environ.get('RTMASHDB'),
                        help='mash database (.msh). Default: $RTMASHDB. Not needed in profile mode.')
    parser.add_argument('--focus-db', dest='focus_db', default=os.environ.get('RTFOCUSDB'),
                        help='FOCUS database directory (must contain db/k6). Default: $RTFOCUSDB')
    parser.add_argument('-o', '--output', help='output directory (default: ./rapdtool_results)')
    parser.add_argument('-c', '--comment', help='comment recorded in the log')
    parser.add_argument('-m', '--mode', choices=('full', 'profile', 'screen'), default='full',
                        help='full pipeline, profile (single genome), or screen '
                             '(FOCUS + mash-screen containment, no binning) (default: full)')
    parser.add_argument('--screen-identity', dest='screen_identity', type=float, default=0.95,
                        help='min mash-screen identity to report a genome as a SPECIES in '
                             'screen mode (default: 0.95, i.e. Mash distance < 0.05)')
    parser.add_argument('--screen-genus-identity', dest='screen_genus_identity',
                        type=float, default=0.92,
                        help='min mash-screen identity to report a genome as a GENUS in '
                             'screen mode, below --screen-identity (default: 0.92, i.e. '
                             'Mash distance 0.05-0.08 -- the same band full mode uses)')
    parser.add_argument('-t', '--threads', type=int, default=(os.cpu_count() or 4),
                        help='threads for FOCUS/Metabat/miComplete/Mash (default: all cores)')
    parser.add_argument('-a', '--coverage', help='depth/coverage file passed to Metabat2 (-a)')
    parser.add_argument('--split-bins', dest='split_bins', action='store_true', default=True,
                        help='write one FASTA per identified species (default: on in full mode)')
    parser.add_argument('--no-split-bins', dest='split_bins', action='store_false',
                        help='disable per-species bin splitting')
    parser.add_argument('--force', action='store_true',
                        help='overwrite existing results for the same input')
    parser.add_argument('-v', '--version', action='version', version='RaPDTool ' + VERSION)
    return parser.parse_args(argv)


def main():
    opts = pick_options()
    Pipeline(opts).run_pipeline()


if __name__ == '__main__':
    main()
