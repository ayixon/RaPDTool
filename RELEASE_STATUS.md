# v2.3.2 — held, not released

**Status: complete and validated, deliberately unpublished.** Nothing here has been
pushed to GitHub, added to the benchmark kit, or cited in the manuscript. The git
remotes were removed from this working copy so a push cannot happen by accident.

**Release when:** the v2.3.1 publication process is finished. Until then v2.3.1
(`BioTools-Dev/RaPDTool`, tag `RaPDTool-v2.3.1`, Zenodo 10.5281/zenodo.21640025) is the
current release and this tree must not reach it.

## What changed

Screen mode now reports genus, using the cutoffs full mode already applied. Before this,
`full` and `profile` tiered a bin by Mash distance — below 0.05 into *Species with high
confidence*, 0.05–0.08 into *Genus with high confidence* — while `screen` had a single
`--screen-identity` cutoff (0.95) and no genus tier. The same organism therefore got a
genus call from one mode and silence from the other. See `CHANGELOG.md`.

The genus table prints **before** the species table, mirroring full mode. That order is
load-bearing: a consumer scoping the species block as everything between
`Reference genomes detected` and the FOCUS heading — as the benchmark kit's
`mash_detection.py` does — still sees species rows only.

## Why it was held back

It is good engineering, but it does not make the manuscript more publishable:

- **No headline number moves.** Species detection is identical across all six benchmark
  datasets (19/20/20/20/5/8, matching the published run). OPAL metrics come from the
  FOCUS profile, which is untouched.
- **It adds a disclosure.** A spurious *Shigella* genus call appears in every dataset
  containing *E. coli*, and in none of the one that does not.
- **It breaks a version story that was just settled.** Methods states the benchmark ran
  v2.3.0 and that v2.3.1 "differs only in input-file handling and report formatting".
  That sentence does not cover 2.3.2, which changes what screen reports.

## What it gains, for the release notes when it does ship

- **Out of domain:** screen resolves 3/3 genus-tier genomes of the mirror experiment
  (*Hymenobacter*, *Nostoc*, *Exiguobacterium*) at precision 1.0, where before it
  reported none — the same answer full mode gave.
- **Low coverage:** at 3 M reads the mock's *Corallococcus*, missed entirely at species
  rank, is reported at genus rank. Graceful degradation now covers two regimes, absent
  organism and insufficient depth, not one.
- **Cost:** the *Shigella* call above. *Escherichia* and *Shigella* sit 0.023 apart in
  this reference set, closer than the species threshold itself. Only 2 of the 20
  benchmark genomes have any out-of-genus neighbour within 0.15, so the effect is
  uncommon and identifiable. `README.md`, "Reading the Genus table", documents how to
  check for it.

## What is here

| Path | |
|---|---|
| `bin/`, `scripts/`, `Singularity.def`, `conda-recipe/` | the change itself, version bumped to 2.3.2 |
| `SIF/rapdtool_apptainer_new/rapdtool3_build/` | sandbox with the new code, label `Version: 2.3.2` |
| `SIF/rapdtool_apptainer_new/rapdtool_v2.3.2.sif` | image built from that sandbox (492 MB) |
| `validation/results_screen_2.3.2/` | screen re-run on all six benchmark datasets |
| `validation/genus_detection.py` | scores the genus tier as its own axis |
| `validation/run232_screen.sh` | the re-run batch |
| `validation/nearest_other_genus.sh` | nearest out-of-genus neighbour per mock genome |

Reference data (mash DB, FOCUS DB) and the benchmark inputs are **not** copied; they are
read in place. A full copy of the stable tree was not possible anyway — 74 GB against
41 GB free — and not useful: only 18 MB of it is the repository.

## Audit, 2026-07-30

Everything in this tree was re-checked after the fact. Two defects were found and fixed;
both were introduced by this release and neither is present in v2.3.1.

**Fixed — the launcher could silently run the wrong image.** The cached image is named
after `$RAPDTOOL_VERSION`, but the download source is a fixed figshare article that
serves whatever is current there. With the version bumped to 2.3.2 and no 2.3.2 image
published, a run without `$RAPDTOOL_SIF` would have fetched the **2.3.1** image, stored
it as `rapdtool_2.3.2.sif`, reported "rapdtool 2.3.2" and executed 2.3.1 — no genus
tier, no warning. Every test here set `$RAPDTOOL_SIF` explicitly, so this was never hit
in practice. `check_sif_version()` now compares the image's own `Version:` label against
the launcher and refuses on mismatch. Worth keeping for the real release: the same trap
exists whenever a version is bumped before the image is uploaded.

**Fixed — the new intermediate file was left behind.** The post-merge cleanup removed
`mashscreen_hits.txt` but not `mashscreen_genus_hits.txt`, so every screen run littered
its output directory with a stray file. The species intermediate was cleaned and the
genus one was not, which is exactly the asymmetry an audit is for.

**Verified, no action needed:**

- Species results are unchanged. The species lists — not merely the counts — are
  identical between v2.3.1 and v2.3.2 across all six datasets, compared by checksum:
  19/20/20/20/5/8.
- The *Corallococcus* result holds. It is in the gold standard (species taxid 2316724),
  appears **nowhere** in the v2.3.1 table, and in v2.3.2 is placed at genus rank with
  *Corallococcus praedator* — the exact gold species — as its closest hit at 0.9434.
- No regression in `profile` mode: byte-identical genus rows before and after the Perl
  change.
- The image contains the final code (`md5` of `rapdtool.py` and `rapdtool_results.pl`
  matches repo → sandbox → SIF).
- Inverted cutoffs (`--screen-genus-identity` above `--screen-identity`) warn and
  produce no genus band, rather than failing.
- Both hit files are written on every run even when empty, so a stale file from an
  earlier run cannot resurrect a genus table.
- No `2.3.1` string remains in the code, launcher, recipe or definition file.
- `validation/` is git-ignored and absent from the commit.

**Known and accepted:** in the genus table the `taxID` column carries the taxid of the
closest *species*, not of the genus. That is what full mode has always done and changing
one without the other would be worse; the `.txt` output names the columns explicitly
(`Genus  Closest-species  taxID  …`).

## Before releasing

- [ ] Build from `Singularity.def` and confirm it matches the sandbox build. Only the
      sandbox path has been exercised so far.
- [ ] Restore a git remote, tag `RaPDTool-v2.3.2`, push.
- [ ] Upload the image to figshare and refresh the conda recipe pin.
- [ ] Decide whether the benchmark kit gains a genus-detection axis (option "B" —
      scored separately, never merged into the species axis).
