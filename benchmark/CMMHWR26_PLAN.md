# Real public benchmark plan: CMMHWR26

## Purpose

This benchmark will provide the main *real-system* case study for the R Journal
paper. It is separate from the controlled CATMuS normalization fixture.

The recognition models are not rerun during article reproduction. Inference is
performed once, line-level predictions are frozen, and the R analysis consumes
those frozen predictions.

## Ground truth

Use the post-competition CMMHWR26 release **with transcriptions**:

- Zenodo record: https://zenodo.org/records/19884972
- file: `cmmhwr_test_with_transcriptions.tar.xz`

This is preferable to evaluating on CATMuS Medieval itself because some candidate
recognizers were trained on CATMuS material.

## Recognition systems

Initial target comparison:

1. **kraken-CATMuS 1.6** — competition baseline;
2. **MEDUSA-4B 0.1** — public competition model;
3. **MEDUSA-9B 0.1** — public larger model.

Public model cards:

- https://huggingface.co/ENC-PSL/Medusa0.1Line-4B
- https://huggingface.co/ENC-PSL/Medusa0.1Line-9B

Competition results/method descriptions:

- https://cmmhwr26.inria.fr/results/

The first frozen benchmark should reproduce the published aggregate metrics
closely enough to validate the extraction and scoring pipeline before using the
new statistical analyses.

## Frozen output schema

One row per recognition line and system:

| column | meaning |
|---|---|
| `task` | CMMHWR task |
| `language` | language / evaluation stratum |
| `document_id` | manuscript/document identifier |
| `page_id` | page identifier |
| `line_id` | competition line identifier |
| `system` | recognizer/model |
| `reference` | official transcription |
| `prediction` | frozen model output |

Optional metadata can be added if it is unambiguously recoverable from the
released corpus.

## Validation stage

Before producing new results:

1. run each model on the same released line images;
2. verify one-to-one line ID alignment;
3. evaluate using the competition-compatible text policy;
4. reproduce published CER/WER aggregates for the baseline and MEDUSA models;
5. document any remaining discrepancy before proceeding.

The package should not silently choose a policy merely because it reproduces a
leaderboard. The competition-compatible policy must be explicitly recorded.

## R Journal analyses

### 1. Micro vs macro aggregation

Report at least:

- pooled/micro CER and WER;
- macro document/manuscript CER and WER;
- official competition aggregation where it differs from either.

This demonstrates that "the error rate" is not a unique estimand.

### 2. Paired uncertainty

For each pair of systems:

- require identical line IDs and reference strings;
- calculate B - A differences;
- resample complete manuscripts/documents;
- report percentile bootstrap intervals;
- show `plot_comparison()`.

### 3. Heterogeneity

Stratify where justified by released metadata:

- task;
- language;
- manuscript/document;
- possibly script or century if available and reliable.

The goal is descriptive diagnosis, not causal interpretation.

### 4. Error profiles

Use:

- `error_profile()`;
- `confusion_table()`;
- `plot_error_profile()`.

Identify common substitution/deletion/insertion patterns and whether they differ
across recognizers or language strata.

### 5. Evaluation-policy sensitivity

Use `normalization_sensitivity()` to compare a small pre-registered set of
plausible policies, for example:

- competition-compatible policy;
- raw codepoints;
- NFC + graphemes;
- punctuation-insensitive;
- whitespace-collapsed.

Do not search over policies to manufacture a ranking reversal. The analysis
should show robustness or sensitivity transparently.

## Reproducibility artifacts

The R Journal repository/archive should contain:

- the extraction script for official reference text;
- exact model/version identifiers;
- frozen predictions;
- checksums;
- a compact CSV/Parquet analysis table;
- R script/vignette generating all benchmark tables and figures.

Large source images and model weights remain at their authoritative public
locations rather than being copied into the R package.

## Separation from the package

This directory is research/reproducibility material and is excluded from the
source package build. The CRAN package itself should remain lightweight.
