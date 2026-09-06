# v2.3.2 — the release the manuscript cites

**Status: released.** 2.3.2 supersedes 2.3.1 as the published version. It was held back
for a while — the reasoning is kept below, because it was reversed for a reason worth
recording — and then folded in once two things changed: the manuscript had not been
submitted, and the Mash boundaries were recalibrated against a measurement, which made
this the version the benchmark should run on.

Its predecessor 2.3.1 remains tagged (`RaPDTool-v2.3.1`, Zenodo 10.5281/zenodo.21640025)
and is not withdrawn; it is simply no longer the version the paper describes.

## What changed

**Recalibrated Mash boundaries.** The species and genus cutoffs were inherited
conventions; they are now the boundaries measured over every pair of the prokaryotic type
material — 30,209 genomes, 4.56 × 10⁸ pairs — at the sketch size this tool ships. Species
moves from `d < 0.05` to **`d ≤ 0.043`**, where 95 % ANI actually falls; genus from
`0.05–0.08` to **`0.043 < d ≤ 0.13`**, the wide edge of a precision plateau that holds
~96 % under both NCBI and GTDB.

**No more biased identity.** `1 − d`, the conversion Mash itself uses, overstates ANI by
12 d points. Cutoffs are now declared as distance (`--screen-max-dist`,
`--screen-genus-max-dist`, with the identity flags kept as deprecated aliases) and the
report prints `ANI-est = 1 − 1.12 d` beside the untranslated distance.

**Screen mode reports genus**, using the same boundaries full mode applies. Before this,
`full` and `profile` tiered a bin by Mash distance while `screen` had a single cutoff and
no genus tier, so the same organism got a genus call from one mode and silence from the
other. Its genus table keeps one row per genus and drops a genus already named at species
rank. See `CHANGELOG.md`.

The genus table prints **before** the species table, mirroring full mode. That order is
load-bearing: a consumer scoping the species block as everything between
`Reference genomes detected` and the FOCUS heading — as the benchmark kit's
`mash_detection.py` does — still sees species rows only, which is why species-level
results are unchanged by this release.

## Why it was held back, and why that was reversed

The original judgement, recorded here because the reasoning still holds for its own
premises: the change was good engineering but did not make the manuscript more
publishable. No headline number moved, it added a disclosure (a spurious *Shigella*
genus call wherever *E. coli* is present), and it broke a version story that had just
been settled — Methods stated that the benchmark ran v2.3.0 and that v2.3.1 "differs only
in input-file handling and report formatting", which does not cover a change to what
screen reports.

Two things then changed the calculus:

1. **The manuscript had not been submitted.** Folding a new version in costs far less
   before review than during it, and the earlier decision had assumed otherwise.
2. **The Mash boundaries were recalibrated.** Species moved from `d < 0.05` to
   `d ≤ 0.043` and genus from `0.05–0.08` to `0.043–0.13`, measured over all 4.56 × 10⁸
   pairs of the type material. That is a substantive improvement to what the tool
   reports, and it belongs in the version the paper describes.

Re-running the benchmark on 2.3.2 also removed the awkward Methods clause: the benchmark
and the released version are now the same, so there is no mismatch left to declare.

## What it gains, for the release notes

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
| `bin/`, `scripts/`, `Singularity.def`, `conda-recipe/` | the change itself, version 2.3.2 |
| `SIF/rapdtool_apptainer_new/rapdtool3_build/` | sandbox with the new code, label `Version: 2.3.2` |
| `SIF/rapdtool_apptainer_new/rapdtool_v2.3.2.sif` | image built from that sandbox |
| `local/v232_validation/` | the screen re-runs, the genus-axis scorer and the measurement scripts (git-ignored) |

The recalibrated benchmark lives in the kit, `local/rapdtool_benchmark_git`, which is a
separate repository with its own DOI. The reference databases are read in place and are
not copied here.

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

## Release checklist

- [x] Recalibrate the boundaries and re-run the benchmark on all six datasets; species
      results unchanged, `verify_kit.sh` at 20/20.
- [x] Update the kit (results, Figure 5, §4b) and the manuscript (§2.4, §3.5, Methods
      options, Figure 5 and its caption).
- [ ] Build from `Singularity.def` and confirm it works. Every image so far was repacked
      from the sandbox; the from-recipe path has not been exercised since 2.3.1, and the
      README tells readers they can use it.
- [ ] Push `main` and the `RaPDTool-v2.3.2` tag. The conda recipe pins `git_rev:
      RaPDTool-v2.3.2`, so a build fails until the tag is on the remote.
- [ ] Cut the GitHub release; let Zenodo archive it and take the new DOI.
- [ ] Replace the version and DOI in the manuscript — abstract, Data availability and
      Methods §2.3. The clause "benchmark runs used v2.3.0, which differs only in
      input-file handling and report formatting" can go: the benchmark now runs on the
      released version.
- [ ] `conda build` and upload, once the tag is pushed.
- [x] Upload the image and the mash database to figshare. The database must be
      `type_30209genomes.msh`: the previous one carried four sketches built from
      `*_cds_from_genomic` and `*_rna_from_genomic` files rather than genomes, and the
      rRNA sketch matched unrelated samples at moderate distance. Keep one file per
      article — the launcher takes the first the API returns.
