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

## Before releasing

- [ ] Build from `Singularity.def` and confirm it matches the sandbox build. Only the
      sandbox path has been exercised so far.
- [ ] Restore a git remote, tag `RaPDTool-v2.3.2`, push.
- [ ] Upload the image to figshare and refresh the conda recipe pin.
- [ ] Decide whether the benchmark kit gains a genus-detection axis (option "B" —
      scored separately, never merged into the species axis).
