<div align="center">
  <h1>$\huge \textcolor{red}{\textsf{R}}\textsf{a}\textcolor{red}{\textsf{P}}\textcolor{red}{\textsf{D}}\textcolor{red}{\textsf{T}}\textsf{ool}$</h1>
  <h1>${{\color{red}Ra}pid\ {\color{red}P}rofiling\ and\ {\color{red}D}econvolution\ {\color{red}Tool}}$</h1>
</div>

![RaPDTool pipeline](docs/RaPDTool_pipeline_newedit.png)

<div align="center">

📖 <strong><a href="docs/RaPDTool_Manual_v2.3.0_EN.pdf">Reference Manual (v2.3.0, PDF)</a></strong>

</div>

RaPDTool offers a simple, easy-to-use workflow for microbial-community profiling,
contig binning and "genomic-distance" exploration by chaining several
bioinformatic tools into a single pipeline:

1. **Taxonomic profile** from a metagenome assembly (or genomic assembly) with **FOCUS**.
2. **Binning** of a metagenome into individual genomes/bins with **Metabat2**, refined
   into a non-redundant set with **Binning_refiner**.
3. **Completeness / redundancy** and basic MAG statistics with **miComplete**.
4. **"Taxonomic neighborhood"** of each bin against a curated type-material **Mash** database.
5. **Interactive visualization** with **Krona**, plus per-species FASTA output.

---

## What's new

- **Screen mode (v2.3.0)** – `-m screen` runs FOCUS + `mash screen` to report which
  reference genomes are present in a metagenome **without binning** (fast "what's there"),
  accepting either a FASTA assembly or **raw FASTQ reads**. `-i` takes a single file:
  concatenate paired or multi-lane FASTQ (`cat R1.fastq R2.fastq > all.fastq`) first.
- **One-line conda install** – `conda create -n rapdtool -c conda-forge -c kjestradag rapdtool`
  sets everything up; the tested image and databases are fetched and cached automatically on first use.
- **Robust error handling** – if any tool fails, the pipeline stops immediately with a
  clear message instead of producing partial/garbage output.
- **External databases** – the mash reference via `-d`/`$RTMASHDB` and the FOCUS k-mer
  database via `--focus-db`/`$RTFOCUSDB` (neither is bundled in the image, keeping it slim).
- **Three run modes** – `full` (default: binning + per-bin classification), `profile`
  (single-genome assembly: FOCUS + whole-assembly Mash), and `screen` (FOCUS +
  `mash screen` containment to report what's present in a metagenome, no binning;
  accepts FASTA or raw FASTQ reads).
- **Parallelism** – `-t/--threads` is passed to FOCUS, Metabat2, miComplete and Mash.
- **Any FASTA extension** accepted (`.fasta`, `.fa`, `.fna`, `.fas`, …, optionally `.gz`)
  with a quick format check.
- **Metabat coverage** – pass a depth/coverage file with `-a`.
- **Per-species bins** – `rapdtool_split_bins.py` writes one FASTA per identified species
  (runs automatically in full mode; disable with `--no-split-bins`).
- Migrated from `os.system` string calls to `subprocess` with argument lists (no shell
  quoting/injection issues); general clean-up and bug fixes.

---

## Install

RaPDTool installs from conda and runs a **prebuilt, tested Apptainer image** — no
bioinformatics tools are installed on your machine. Install it into a dedicated
environment:

```bash
conda create -n rapdtool -c conda-forge -c kjestradag rapdtool
conda activate rapdtool
```

This pulls in [Apptainer](https://apptainer.org/) (from conda-forge) and the `rapdtool`
launcher. On the
**first run**, the image (~0.5 GB) and the reference databases are downloaded and cached
under `~/.cache/rapdtool` (override with `$RAPDTOOL_CACHE`). Each run checks figshare and
re-downloads an asset when a newer version is published (skip with
`$RAPDTOOL_NO_UPDATE_CHECK=1`; force with `rapdtool update`). Pre-fetch everything with:

```bash
rapdtool setup      # optional: download image + databases ahead of time
rapdtool --where    # show where the image and databases are cached
```

Requirements: Linux with conda. That's it — Apptainer and the databases are handled
for you.

<details>
<summary>Advanced: build the image yourself</summary>

The recipe (`Singularity.def`) rebuilds the whole image from scratch — it downloads and
installs all tools; nothing but the recipe and the `bin/` scripts is needed. Run it from
the cloned repository root (so the `%files` paths resolve):

```bash
git clone https://github.com/BioTools-Dev/RaPDTool.git
cd RaPDTool
apptainer build --fakeroot rapdtool.sif Singularity.def
export RAPDTOOL_SIF=$PWD/rapdtool.sif
```

Requirements: `apptainer` with working `--fakeroot` (or root), an internet connection, and
~5–6 GB of free disk during the build (final image ~0.5 GB). The build takes several
minutes and self-checks its essential components, so it fails loudly rather than producing
a broken image.

> **Note on reproducibility.** The **distributed image** (figshare, fetched automatically)
> is the frozen, version-controlled artifact intended for reproducible analyses. The recipe
> above instead rebuilds from *currently available* package versions, so it is not
> bit-identical to the distributed image. The recipe is verified to build and run correctly
> as of the latest commit, and already carries the fixes needed for current dependency
> versions — for example, patching miComplete for Biopython ≥1.80 (`Bio.SeqUtils.GC` →
> `gc_fraction`), pinning `setuptools<81` so `focus_app` keeps `pkg_resources`, and using
> Miniforge to avoid the Anaconda channel Terms-of-Service prompt. The pipeline pins its
> core tools, but their transitive dependencies and the base installers are not fully
> frozen: full pinning is itself fragile (older builds can become unsolvable over time, and
> "latest" installers / base images move), and packages published to PyPI may occasionally
> be withdrawn. As upstream libraries evolve, a fresh build may therefore need a small
> additional fix. If you build from the recipe, **compare your results against the
> distributed image** before relying on them, and please open an issue if a build breaks so
> the recipe can be updated.

</details>

<details>
<summary>Advanced: use your own databases</summary>

```bash
# Point at your own databases instead of the auto-downloaded ones
export RTMASHDB=/path/to/mash_db.msh       # NCBI type material or GTDB r202
export RTFOCUSDB=/path/to/focus            # a directory containing db/k6
```

The image and databases are hosted on figshare and fetched automatically:
[image](https://doi.org/10.6084/m9.figshare.21375609) ·
[mash DB](https://doi.org/10.6084/m9.figshare.21379491) ·
[FOCUS DB](https://doi.org/10.6084/m9.figshare.21395619).
To use a different mash database, set `$RTMASHDB` to any `.msh` (e.g. GTDB r202).
</details>

---

## Usage

The `rapdtool` command forwards its arguments to the pipeline (the databases are provided
automatically):

```
rapdtool -i INPUT [-o OUTPUT] [-m {full,profile,screen}] [-t THREADS] [-a COVERAGE]
         [--screen-max-dist D] [--screen-genus-max-dist D] [--no-split-bins] [--force] [-c COMMENT]

  -i, --input      input FASTA assembly (.fasta/.fa/.fna/.fas, optionally .gz)   [required]
                   (screen mode also accepts FASTQ reads: .fastq/.fq[.gz];
                    one file only — cat paired/multi-lane FASTQ together first)
  -o, --output     output directory (default: ./rapdtool_results)
  -m, --mode       full (default): binning + per-bin taxonomic classification (MAGs);
                   profile: single-genome assembly (FOCUS + whole-assembly Mash);
                   screen: FOCUS + mash-screen containment — which reference genomes
                   are present in a metagenome (FASTA or raw FASTQ reads), no binning
  -t, --threads    threads for FOCUS/Metabat/miComplete/Mash (default: all cores)
  -a, --coverage   depth/coverage file passed to Metabat2 (-a)
      --screen-max-dist  max Mash distance for a SPECIES call in screen mode
                         (default: 0.043, where 95.2 % ANI falls)
      --screen-genus-max-dist  max Mash distance for a GENUS call in screen mode
                         (default: 0.13; the same band full mode uses)
                         (--screen-identity/--screen-genus-identity remain as
                          deprecated aliases: distance = 1 - identity)
      --no-split-bins   disable per-species FASTA output
      --force      overwrite existing results for the same input
  -c, --comment    comment recorded in the log

  -d, --database   mash .msh to use instead of the cached one   (optional override)
      --focus-db   FOCUS db directory (containing db/k6) to use  (optional override)
```

### Examples

```bash
# Full pipeline (metagenome assembly)
rapdtool -i assembly.fasta -o results

# Screen: which reference genomes are present in a metagenome (no binning)
rapdtool -i assembly.fasta -m screen -o screen_out

# Screen from raw reads. -i takes ONE file, so concatenate the runs first
# (paired R1/R2, or several lanes) and pass the single result:
cat reads_R1.fastq reads_R2.fastq > reads_all.fastq
rapdtool -i reads_all.fastq -m screen -o screen_reads
# gzipped reads concatenate the same way — cat R1.fastq.gz R2.fastq.gz > all.fastq.gz

# Profile a single-genome assembly (FOCUS + whole-assembly Mash classification)
rapdtool -i genome.fna -m profile -o prof_out

# Full pipeline with 16 threads and a precomputed coverage file
rapdtool -i assembly.fa -t 16 -a depth.txt
```

---

## Output

Results are written under the `-o` directory (default `rapdtool_results`):

- `profilesfmbm/` – FOCUS profiling results
- `allresultsfmbm/` – ten closest Mash hits per bin
- `workfmbm/` – intermediate binning / distance data
- `species_bins/` – one FASTA per identified species (full mode)
- `rapdtool_confidence.tbl` / `.txt` – merged high-confidence Species/Genus report
- `rapdtool_krona.html` – interactive Krona visualization
- `log/logfmbm.txt` – full execution log

For each bin, RaPDTool reports the ten closest neighbors from the Mash comparison,
simplifying interpretation and providing a basis for finer OGRI/ANI analysis.

### Reading the Genus table

Genus and species are reported in **separate tables**, because they answer different
questions. A row in the species table is a genome close enough to a reference to be
named (Mash distance ≤ 0.043, where 95 % ANI actually falls). A row in the genus table is
one that is *not*: it sits at 0.043–0.13, close enough to place in a genus and no closer.

The `ANI-est` column is **not** `1 − d`. That conversion, which Mash itself uses, overstates
identity by 12 d points; the reported value applies the measured correction
**ANI = 1 − 1.12 d**, so `d = 0.043` reads as 95.2 % and not 95.7 %. The `Mash-distance`
column is printed beside it, untranslated.
Reading the genus table as a weaker species list is the one way to misuse it.

A genus already named in the species table is **not** repeated here, and only the nearest
reference per genus is kept — without that, widening the band fills the table with the
same genus at increasing distance.

**Read the genus table against the rest of it.** A genus there is worth trusting when it
stands on its own, and worth doubting when a genus known to be genomically
near-inseparable from it is already reported. The clearest case is *Escherichia* and
*Shigella*: *Shigella* is nested inside *E. coli* rather than forming a distinct lineage,
and in this reference set the two sit **0.023 apart — closer than the species threshold
itself**. Any sample containing *E. coli* therefore tends to raise a *Shigella* genus
call that reflects shared ancestry, not a second organism. Measured across the benchmark
communities, a spurious *Shigella* appears in every dataset containing *E. coli* and in
none of the dataset that does not.

The same caution applies wherever a genus boundary is narrower than the genomic distance
between its members — recently split genera (*Clostridium* sensu lato, *Bacillus* with
its *Priestia* and *Peribacillus* segregates, *Mycobacterium* and *Mycolicibacterium*)
and the closely related Enterobacteriaceae (*Klebsiella*, *Raoultella*, *Enterobacter*)
are the usual suspects. The check itself needs no literature: a genus whose nearest
relative is already named in the species table deserves scrutiny, one with no such
neighbour usually does not. Across the twenty benchmark genomes only two had *any*
out-of-genus neighbour within 0.15 in this database, so the situation is uncommon and
identifiable rather than pervasive.

Conversely, the genus table is where a genuinely present organism surfaces when the
evidence will not support a species call — one absent from the database, or a real
community member whose coverage is too low to clear the species threshold. At 3 M reads
the benchmark's *Corallococcus* is reported at genus rank while it is missed entirely at
species rank: backing off a rank rather than falling silent is the intended behaviour.

---

## Repository layout

```
bin/            pipeline scripts (rapdtool.py, rapdtool_split_bins.py, rapdtool_results.pl)
scripts/        rapdtool — host launcher (downloads/caches the image + databases, runs it)
conda-recipe/   conda package recipe (meta.yaml, build.sh)
docs/           figures and the reference manual (PDF)
Singularity.def container build recipe
CHANGELOG.md    version history
```

See [CHANGELOG.md](CHANGELOG.md) for the full list of changes.

---

## Dependencies

FOCUS · Metabat2 (2.15) · Binning_refiner (1.4.3) · miComplete (1.1.1) · Mash (2.3) ·
KronaTools · entrez-direct (used only when reporting Mash hits; requires internet).

## References

- Sánchez-Reyes A, Fernández-López MG. Sketched reference databases for genome-based taxonomy and comparative genomics.
  Braz J Biol. 2022;84:e256673. https://doi.org/10.1590/1519-6984.256673.
- Ondov BD *et al.* *Mash: fast genome and metagenome distance estimation using MinHash.*
  Genome Biol. 2016;17(1):132.
- Silva GGZ *et al.* *FOCUS: an alignment-free model to identify organisms in
  metagenomes using non-negative least squares.* PeerJ. 2014;2:e425.
- Song WZ, Thomas T. *Binning_refiner.* Bioinformatics. 2017;33(12):1873-1875.
- Kang DD *et al.* *MetaBAT 2.* PeerJ. 2019;7:e7359.

## Maintainer

RaPDTool was co-developed by **Dr. Ayixon Sánchez-Reyes** and **Dr. Karel Estrada** and is maintained by **Dr. Estrada**.  
**Dr. Karel Estrada** ([@kjestradag](https://github.com/kjestradag) , karel.estrada@ibt.unam.mx) Unidad de Secuenciación Masiva y Bioinformática. UNAM.  
**Dr. Ayixon Sánchez-Reyes** (ayixon@gmail.com , ayixon.sanchez@ibt.unam.mx) Researchers for Mexico Program (CONACYT), Institute of Biotechnology, UNAM.  
Issues and pull requests are welcome on the [GitHub repository](https://github.com/BioTools-Dev/RaPDTool).

## Acknowledgments

We thank Ing. Roberto Peredo for his help in developing this tool.  
Funded in part by project CF 2019 265222 (FORDECYT-PRONACES CONACYT-México).
