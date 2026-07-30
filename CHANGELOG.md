# Changelog

All notable changes to RaPDTool are documented here.

## [2.3.2] — 2026-07-30

### Changed
- **Screen mode now reports genus, with the cutoffs full mode already used.** `full` and
  `profile` tier a bin by its Mash distance to the nearest reference — below 0.05 into
  *Species with high confidence*, 0.05–0.08 into *Genus with high confidence* — while
  `screen` applied a single `--screen-identity` cutoff (0.95) and had no genus tier at
  all. The same organism therefore got a genus call from one mode and silence from the
  other: on a genome 94.5 % identical to its nearest reference, `profile` reported
  *Hymenobacter baengnokdamensis* and `screen` reported nothing at all. Screen now
  applies both tiers, so the rank follows the evidence rather than the mode that
  produced it.

  The new `--screen-genus-identity` (default 0.92, the identity equivalent of Mash
  distance 0.08) sets the lower edge; `--screen-identity` (0.95) still sets the species
  edge and is unchanged. Genus hits are written to `mashscreen_genus_hits.txt` and
  reported in a *Genus detected (mash screen…)* table.

  **The genus table is printed before the species table**, mirroring full mode's order.
  A consumer that scopes the species block as everything between
  `Reference genomes detected` and the FOCUS heading — as the benchmark kit's
  `mash_detection.py` does — therefore still sees species rows only, and species-level
  counts are unchanged by this release.

## [2.3.1] — 2026-07-28

### Fixed
- **Documented input extensions now actually work.** FOCUS selects its inputs by file
  suffix and reads only `.fna`/`.fasta`/`.fastq`, so inputs this tool documents as valid
  — `.fa`, `.fas`, `.ffn`, `.frn`, `.fq`, and anything `.gz` — were silently ignored by
  the profiling step. The working copy is now decompressed if needed and renamed to a
  suffix FOCUS accepts. Output directories keep the name of the file the user supplied.
- **Long names no longer wrap in `rapdtool_confidence.tbl`.** Table columns are sized to
  their widest value instead of sharing a fixed width budget, so a long species name or
  taxID stays on one line; only the scaffold list, reproduced in full in
  `rapdtool_confidence.txt`, is narrowed to what is left.

### Changed
- **FOCUS reporting cutoff lowered from 1 % to 0.5 % relative abundance.** Set from the
  threshold sweep of the RaPDTool benchmark: across mock communities at 3, 10 and 30 M
  reads, 0.5 % recovers every species present (recall 1.0) against 0.80–0.95 at 1 %,
  with F1 higher at 0.5 % at every depth tested. Affects only which rows are listed in
  `rapdtool_confidence.tbl|txt`; the complete FOCUS profile under `profilesfmbm/` is
  unfiltered as before, and Mash-based detection is unaffected.
- The report merger uses `Text::SimpleTable` directly rather than
  `Text::SimpleTable::AutoWidth`, dropping the Moo and Type::Tiny dependencies from the
  image.

### Documentation
- Screen mode: `-i` takes a single file, so paired or multi-lane FASTQ must be
  concatenated first (`cat R1.fastq R2.fastq > all.fastq`). Documented in the README,
  the usage block and the launcher help.

## [2.3.0] — 2026-07-10

### Added
- **Screen mode** (`-m screen`) — FOCUS + `mash screen` (containment) to identify the
  reference genomes present in a metagenome **without binning**. Reports each detected
  genome (species/taxID via esearch) with its identity and shared-hashes, for hits at or
  above `--screen-identity` (default 0.95). Full and profile modes are unchanged.
- **FASTQ input in screen mode** — screen accepts raw sequencing reads
  (`.fastq`/`.fq`, optionally `.gz`) in addition to FASTA assemblies. Full and profile
  still require a FASTA assembly.
- **Auto-refresh of cached assets** — the launcher records the figshare file version of
  each cached asset (image, mash DB, FOCUS DB) and re-downloads it automatically when a
  newer version is published, so updating figshare is enough (no filename/version change
  needed). Skip the per-run check with `$RAPDTOOL_NO_UPDATE_CHECK=1`; force a refresh with
  `rapdtool update`.

### Changed
- Output directory flag renamed from `-r/--root` to `-o/--output` (more conventional
  in bioinformatics CLIs).

## [2.2.0] — 2026-07-07

Major robustness, usability and packaging overhaul.

### Added
- **Conda distribution** — `conda install -c kjestradag rapdtool` installs a small
  launcher (plus Apptainer) that downloads and caches the prebuilt image and the
  reference databases on first use; no bioinformatics tools are installed on the host.
- **Two run modes** via `-m/--mode {full,profile}`. `profile` runs FOCUS + Krona for
  single-genome assemblies (where binning does not apply) and, when a mash database is
  supplied, also classifies the **whole assembly as a single bin** (Mash classification
  table without binning/completeness columns).
- **Per-species FASTA output** — new `rapdtool_split_bins.py` writes one FASTA per
  identified species (`<Species>__<bin>.fna`). Runs automatically in full mode
  (disable with `--no-split-bins`); also usable standalone.
- **External FOCUS database** via `--focus-db` / `$RTFOCUSDB` (k-mer `db/k6`, no longer
  bundled in the image).
- **Parallelism** — `-t/--threads` (default: all cores) passed to FOCUS, Metabat2,
  miComplete and Mash.
- **Metabat coverage** — `-a/--coverage` to pass a depth/coverage file to Metabat2.
- **`--force`** to overwrite existing results for the same input.
- Convenience host launcher `rapdtool.sh` (auto-discovers the SIF and auto-binds the
  input/database/output directories) with helper `apptainer_bind.sh`.
- Documented, reproducible `Singularity.def`; `CHANGELOG.md`.

### Changed
- **External mash database** via `-d/--database` / `$RTMASHDB` — removed the hard-coded
  database path.
- Migrated from `os.system` string calls to `subprocess` with argument lists (no shell
  quoting/injection issues).
- Accepts **any FASTA extension** (`.fasta/.fa/.fna/.fas/…`, optionally `.gz`) with a
  quick format check.
- Rewrote the orchestrator around a `Pipeline` class; grouped path state; replaced
  `os.system('cp/mv/rm/mkdir')` with `shutil`/`os.makedirs`.
- Container entrypoint now forwards all arguments (`exec rapdtool.py "$@"`).
- Hardened `rapdtool_results.pl` so it no longer aborts when mash/miComplete inputs are
  absent (profile mode).
- **Slimmed the image ~70%** (1.60 GB → 0.48 GB): removed the conda package cache, the
  Miniconda installer, C headers/manpages, static libraries, package test suites,
  HMMER easel sources, docs/locales, pip and unused stdlib, and tkinter/tcl-tk
  (matplotlib forced headless via `MPLBACKEND=Agg`). The mash and FOCUS databases are
  no longer bundled.

### Fixed
- Pipeline now **aborts on any tool failure** with a clear message and log, instead of
  continuing and producing partial/garbage output.
- Fixed undefined `message` reference in error paths.
- `apptainer_bind.sh` no longer crashes under `set -u` when `$RTMASHDB`/`$RTFOCUSDB` are
  unset.
- `rapdtool.sh` now discovers versioned `rapdtool*.sif` instead of failing on a missing
  `rapdtool.sif`.

## [2.1.0] — earlier

- FOCUS / Metabat2 / Binning_refiner / miComplete / Mash pipeline with report merge and
  Krona visualization, distributed as an Apptainer image.
