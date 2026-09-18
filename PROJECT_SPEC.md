# ocrinfer — project specification

## Target contribution

**Working paper title:** *Statistical Evaluation of OCR and Handwritten Text Recognition in R*

**Working package name:** `ocrinfer` (provisional).

The intended R Journal contribution is not another implementation of CER/WER. It is:

> an R-native framework for uncertainty quantification, paired system comparison,
> hierarchical aggregation, normalization sensitivity analysis, and error diagnosis
> in OCR/HTR evaluation.

## Canonical data model

A long table should support:

- dataset/corpus;
- document or manuscript ID;
- page ID;
- line ID;
- system/model;
- reference;
- prediction;
- optional metadata such as language, script and century.

A minimal analysis requires only reference and prediction.

## Evaluation policy

Every analysis should make explicit:

- Unicode normalization: NFC/NFKC/NFD/NFKD/none;
- evaluation unit: grapheme/codepoint/word;
- case policy;
- whitespace policy;
- punctuation policy.

## Statistical core

### Micro error rate

Pool edit counts before division:

`sum(errors) / sum(reference units)`

### Macro error rate

Calculate an error rate per higher-level unit and average:

`mean(document CER)`

### Paired system comparison

For systems evaluated on the same material:

1. calculate metrics per document/manuscript;
2. calculate paired differences;
3. resample complete higher-level units;
4. report the difference and bootstrap interval.

## Public benchmark plan

1. **CATMuS Medieval** — primary open HTR example.
2. **Historical printed OCR** — preferably an explicitly licensed OCR-D/QuiVer subset.
3. **Controlled Unicode examples** — synthetic examples distributed with the package.

Predictions should be generated once and frozen so paper reproduction does not need
to rerun large OCR/HTR models.

## Release roadmap

### 0.0.1 — metric kernel
- normalization;
- grapheme/codepoint/word tokenization;
- alignment;
- edit counts;
- CER/WER;
- row-level evaluation;
- tests and toy data.

### 0.1.0 — aggregation
- micro/macro summaries;
- line/page/document/manuscript grouping;
- evaluation-policy metadata;
- first public benchmark subset.

### 0.2.0 — comparison and inference
- paired system comparison;
- document-level bootstrap;
- confidence intervals;
- normalization sensitivity.

### 0.3.0 — diagnostics and presentation
- confusion tables;
- error profiles;
- comparison/error plots.

## Deliberately postponed

- OCR execution;
- image processing;
- PAGE/ALTO readers;
- layout metrics;
- confidence calibration;
- model downloading;
- Python dependencies.
