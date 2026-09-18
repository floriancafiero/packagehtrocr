# R Journal paper outline

## Working title

**Statistical Evaluation of OCR and Handwritten Text Recognition in R**

Package name in the title/subtitle should remain provisional until the API and CRAN name are stable.

## Core claim

The paper must not claim novelty for CER/WER themselves.

The contribution is an R-native framework that treats OCR/HTR evaluation as a
statistical analysis problem:

1. explicit Unicode and normalization policy;
2. transparent edit alignment;
3. micro vs macro aggregation over hierarchical documents;
4. genuinely paired system comparisons;
5. cluster-bootstrap uncertainty at the document/manuscript level;
6. sensitivity of conclusions to evaluation policy;
7. error decomposition and confusion diagnostics;
8. reproducible outputs and plots.

## 1. Introduction

### Problem

OCR/HTR papers often compress recognition quality into one CER/WER number.

That number can obscure:

- different definitions of "character";
- normalization choices;
- uneven document lengths;
- dependence among lines from the same page/document;
- heterogeneity across manuscripts/languages/scripts;
- uncertainty in differences between systems.

### Software gap

Existing tools already calculate CER/WER and alignments. The paper should compare
explicitly with:

- base R / string-distance tools;
- Python recognition-evaluation tooling such as jiwer;
- OCR-D / dinglehopper / QuiVer;
- other OCR evaluation software identified in the literature.

The argument is not that these tools are deficient generally, but that ocrinfer
offers a coherent R workflow for statistical comparison, sensitivity analysis,
and downstream research reporting.

## 2. Evaluation model and package design

### Canonical input

Long-format table with:

- reference;
- prediction;
- system;
- line identifier;
- page/document/manuscript identifier;
- optional corpus metadata.

### Evaluation policy

Explain:

- NFC/NFKC/NFD/NFKD/none;
- grapheme vs codepoint;
- word tokenization;
- case;
- whitespace;
- punctuation.

Show that policy is retained with evaluation results.

## 3. Alignment and elementary metrics

Introduce:

- `align_text()`;
- `edit_counts()`;
- `cer()`;
- `wer()`.

Keep mathematical exposition short. Emphasize reproducibility and Unicode semantics.

### Controlled Unicode example

Use the public CATMuS text fixture.

Show a canonically equivalent reference/prediction pair that can differ under raw
codepoint evaluation but becomes identical under NFC + grapheme evaluation.

This is a methodological demonstration, not a model benchmark.

## 4. Hierarchical aggregation

Explain:

### Micro

Pool errors and reference units before division.

### Macro

Compute an error rate for each document/manuscript, then average those rates.

Demonstrate that long documents dominate micro estimates but not macro estimates.

Use a controlled toy example first, then report both quantities for the real public benchmark.

## 5. Paired comparison and uncertainty

Introduce `compare_systems()`.

Requirements:

- same paired IDs;
- identical ground-truth text;
- same evaluation policy.

Bootstrap complete higher-level units, not lines.

Report:

- system A estimate;
- system B estimate;
- B - A;
- percentile interval;
- number of resampling units.

The first paper should avoid turning this into a general bootstrap-methodology paper.
The contribution is a safe, explicit implementation for OCR/HTR evaluation.

## 6. Sensitivity analysis

Introduce `normalization_sensitivity()`.

Main research question:

> Does the substantive comparison between systems depend on an otherwise hidden evaluation policy?

Candidate policies:

- raw codepoints;
- NFC + graphemes;
- case-insensitive;
- punctuation-insensitive;
- collapsed whitespace.

The strongest empirical result would be a public case where the magnitude or ranking
of system performance materially changes under plausible policies. Do not claim such a
reversal unless it is actually observed.

## 7. Error diagnosis

Introduce:

- `error_profile()`;
- `confusion_table()`;
- `plot_error_profile()`.

Demonstrate stratification by a relevant metadata variable such as script type,
language, century, or document.

Distinguish diagnosis from causal explanation.

## 8. Public case studies

### A. Controlled CATMuS fixture

Purpose:

- Unicode semantics;
- normalization sensitivity;
- regression tests.

Never describe the controlled transformations as HTR systems.

### B. Real public HTR comparison

Target:

- CATMuS/CMMHWR-compatible public material;
- at least two openly reproducible recognition systems;
- frozen line-level predictions committed or archived separately;
- metadata sufficient for manuscript-level clustering.

Needed before paper submission.

### C. Historical printed OCR

Use a clearly licensed public benchmark, potentially from the OCR-D ecosystem.

Purpose:

- demonstrate applicability beyond handwriting;
- page/document-level analysis;
- show that the package is OCR/HTR infrastructure rather than a medieval-specific tool.

## 9. Comparison with existing software

Create a factual capability table.

Candidate dimensions:

- CER/WER;
- alignment;
- Unicode/grapheme policy;
- preprocessing policy;
- page/document aggregation;
- micro/macro distinction;
- paired comparison;
- uncertainty intervals;
- cluster bootstrap;
- metadata-stratified diagnostics;
- tidy R outputs;
- plots.

Every claim in the final paper must be verified against current versions of competing tools.

## 10. Discussion

Discuss:

- evaluation policy as part of reproducibility;
- unit-of-analysis choices;
- when macro vs micro answers different questions;
- why an interval on a paired difference is more informative than two leaderboard numbers;
- limits of the current package.

Do not oversell bootstrap intervals as solving benchmark representativeness.

## 11. Future work

Candidates, deliberately outside initial scope:

- PAGE XML / ALTO readers;
- layout evaluation;
- confidence calibration;
- additional bootstrap methods;
- multiple-system simultaneous comparisons;
- benchmark registry;
- richer tokenization for languages without whitespace word boundaries.

## Figures anticipated

1. Diagram: recognition outputs → policy → alignment → aggregation → comparison/diagnosis.
2. Unicode example: raw codepoints vs NFC/graphemes.
3. Micro vs macro estimates on heterogeneous documents.
4. Paired B - A differences with bootstrap intervals.
5. Error-type profile by system.
6. Sensitivity of performance to evaluation policy.

## Tables anticipated

1. Comparison with existing evaluation tools.
2. Public benchmark metadata and licensing.
3. Main system estimates under micro/macro aggregation.
4. Sensitivity-analysis results.

## Reproducibility target

The article reproduction should consume **frozen predictions**, not rerun large OCR/HTR models.

The core R analysis should therefore be fast enough for R Journal reproducibility checks.
