# ocrinfer — project specification

## Primary research target

**CVPR 2027** — working research title:

**Beyond Edit Distance: Evaluating Visual Transcription Fidelity in the VLM Era**

The R package is the evaluation engine and reproducibility artifact for the paper.
A later R Journal package paper remains a secondary objective after the research
framework and empirical findings mature.

## Research contribution

The CVPR project asks whether conventional OCR/HTR leaderboards adequately
characterize visual transcription quality when specialized recognizers and
generative VLMs have different inductive biases.

The intended contribution combines:

- explicit Unicode/evaluation policy;
- micro vs document-level macro estimands;
- paired higher-level uncertainty;
- mechanical error decomposition;
- source-aware transcription-fidelity categories;
- model-family comparison;
- robustness/sensitivity of leaderboard conclusions.

The headline novelty is NOT CER/WER, paired inference, or error taxonomies alone.
See `paper/CVPR_POSITIONING.md` for the literature boundaries.

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

1. verify the same paired IDs and reference text;
2. calculate metrics per document/manuscript;
3. calculate paired differences;
4. resample complete higher-level units;
5. report effect and bootstrap interval.

This is a benchmark-quality protocol rather than a claim of new statistical
theory.

## Main empirical plan

### Benchmark A — CMMHWR26

Use the public post-competition test set with official transcriptions.

Initial systems:
- Kraken / CATMuS baseline;
- MEDUSA-4B;
- MEDUSA-9B;
- ideally one additional general VLM.

### Benchmark B — second domain

Add a modern/printed or modern-handwriting setting to test whether findings
generalize beyond historical manuscripts.

### Controlled fixture

The bundled CATMuS examples remain useful for regression tests and Unicode
sensitivity demonstrations, but are not recognition-system benchmark results.

## Source-aware fidelity study

Mechanical edit types are insufficient for the CVPR paper.

The annotation study should distinguish at least:

- visual misrecognition;
- content omission;
- insertion/hallucinated addition;
- repetition;
- orthographic normalization;
- linguistic correction;
- abbreviation representation change;
- unsupported completion;
- ambiguous/cannot determine.

Annotations should be image-conditioned, blinded to system identity, and
double-coded on a stratified sample.

## Package roadmap

### Implemented

- normalization;
- grapheme/codepoint/word tokenization;
- alignment;
- edit counts;
- CER/WER;
- row-level evaluation;
- metadata preservation;
- micro/macro summaries;
- paired document-level bootstrap;
- normalization sensitivity;
- confusion tables;
- error profiles;
- publication-oriented plots;
- unit tests and CI.

Current GitHub Actions check: **R CMD check --as-cran — Status: OK**.

### CVPR-critical next functions

- span-level error extraction;
- repeated-span detection;
- export of candidate errors for annotation;
- import of adjudicated fidelity labels;
- fidelity-profile summaries and plots;
- rank/policy stability summaries.

## Deliberately postponed

Not needed for the CVPR core:

- OCR execution inside the R package;
- image processing;
- PAGE/ALTO readers;
- layout metrics;
- model downloading;
- generic confidence calibration.

## Submission decision rule

Proceed with CVPR if the experiments reveal a substantive phenomenon that CER/WER
alone obscures and it generalizes beyond one narrow benchmark.

Redirect to ICDAR if the strongest contribution remains document-analysis/HTR
specific.

Retain R Journal as a later software publication if the package is strong but the
empirical novelty is insufficient for a broad vision venue.
