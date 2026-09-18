# CVPR 2027 experiment plan

## Goal

Determine whether conventional edit-distance leaderboards adequately characterize
the quality and fidelity of modern OCR/HTR systems, especially generative VLMs.

The experiments are designed to be falsifiable. If the proposed phenomena are
weak or absent, the paper should be redirected to ICDAR/R Journal rather than
overclaimed.

## Hypotheses

### H1 — Error-profile divergence

Systems with comparable CER/WER can exhibit substantially different proportions
of substitutions, deletions, insertions, repetitions, normalization/correction,
and unsupported-generation errors.

**Evidence required:** effect sizes with uncertainty and consistent patterns on
more than one subset/model pair.

### H2 — Generative-fidelity trade-off

Generative VLMs may reduce local recognition errors while introducing more
language-prior transformations (normalization, correction, completion, or
unsupported addition) than specialized recognizers.

**Evidence required:** human-validated source-aware annotations.

### H3 — Aggregation sensitivity

Micro and document-level macro evaluation may produce materially different
estimates and possibly different system ordering when benchmark documents vary
in length/difficulty.

**Evidence required:** report both estimands and quantify document-level
heterogeneity. Ranking reversal is interesting but not required.

### H4 — Evaluation-policy sensitivity

Plausible text policies (Unicode normalization, grapheme/codepoint unit,
punctuation, whitespace, case) can change effect magnitude and, in some cases,
system ordering.

**Evidence required:** policies pre-specified before inspecting model ranking.

### H5 — Small leaderboard gains may be fragile

For systems evaluated on the same material, some small CER/WER differences may
have document-level paired intervals that include zero or show strong
heterogeneity.

**Evidence required:** paired resampling at a defensible cluster level.

This is not claimed as a novel statistical theorem; it is a benchmark-quality
diagnostic.

## Benchmark A — CMMHWR26

### Why

Public post-competition test ground truth, historical handwriting, multiple
languages/tasks, and direct relevance to classical/specialized HTR vs generative
VLMs.

### Systems

Minimum:
- Kraken / CATMuS baseline;
- MEDUSA-4B;
- MEDUSA-9B.

Strong extension:
- one Qwen-family VLM used in the same line-recognition setting;
- one additional specialized recognizer if outputs are reproducible.

### Data table

One row per line × system:

- task;
- language;
- document_id;
- page_id;
- line_id;
- system;
- reference;
- prediction.

### First validation

Before novel analysis, reproduce official aggregate CER/WER closely enough to
validate line extraction, Unicode policy, and model inference.

## Benchmark B — GT4HistOCR historical print

Use **GT4HistOCR** as the primary second domain.

Why:
- 313,173 printed line-image/transcription pairs;
- German Fraktur and Early Modern Latin;
- 15th–19th century material;
- diplomatic-style transcriptions preserving historical character forms;
- upstream Zenodo README states CC BY-SA 4.0 (the publication describes CC BY 4.0); treat the archive as CC BY-SA unless clarified;
- print rather than handwriting, giving a genuine visual-domain shift from
  CMMHWR26;
- not listed among the MEDUSA 0.1 training datasets.

Use a pre-specified held-out subset spanning printing periods/scripts rather than
the full corpus if inference cost is high.

Candidate systems:
- Tesseract or an OCR-D/Calamari historical-print recognizer;
- MEDUSA-4B/9B as out-of-domain visual transcription models;
- the same additional general VLM used on CMMHWR26.

This benchmark is especially useful for source-fidelity categories because
Fraktur, historical spellings, and diplomatic character forms create cases where
language-prior normalization can be distinguished from literal recognition.

Optional third-domain validation:
- IAM or another modern handwriting dataset if time permits.

The second benchmark must test whether findings generalize beyond medieval
handwriting, not simply add more historical pages.

## Fidelity annotation study

### Sampling

Create a stratified sample from *errors*, not from all correct lines.

Target initial pilot:
- 300–500 errorful line outputs;
- balanced across model families and languages/tasks;
- include matched cases where systems have similar CER but different outputs.

If taxonomy proves stable, expand to 1,000+ errorful outputs.

### Annotators

At least two independent annotators for the source-aware categories.

Each item should display:
- line image;
- reference transcription;
- system output;
- aligned differences.

Annotators should not see model identity during labeling.

### Labels

Mechanical labels:
- substitution;
- deletion;
- insertion;
- repetition.

Source-aware labels:
- visual misrecognition;
- orthographic normalization;
- linguistic correction;
- abbreviation representation change;
- unsupported completion;
- hallucinated addition;
- content omission;
- ambiguous / cannot determine.

Allow multi-label where a span genuinely combines phenomena.

### Reliability

Report:
- raw agreement;
- a chance-corrected coefficient suitable for the label structure;
- adjudication protocol.

Do not collapse ambiguous cases silently.

## Automatic error decomposition

The package already provides:
- alignments;
- CER/WER;
- edit counts;
- confusion tables;
- error profiles;
- micro/macro aggregation;
- paired cluster bootstrap;
- policy sensitivity.

Next software work should prioritize:
1. span-level error extraction;
2. repeated-span detection;
3. export format for annotation;
4. import of adjudicated fidelity labels;
5. fidelity-profile summaries.

Avoid building unrelated package functionality before the experiment is running.

## Statistical analyses

### Standard leaderboard reproduction

Per system:
- official metric/policy;
- micro CER/WER;
- document-level macro CER/WER.

### Paired model differences

For each system pair:
- B - A effect;
- document/manuscript cluster bootstrap interval;
- paired scatter/forest plot.

### Heterogeneity

Stratify by:
- language/task;
- document/manuscript;
- second benchmark strata.

Only use script/century if metadata are reliable.

### Fidelity profile

Per system/model family:
- frequency of each source-aware error category;
- normalized per reference character/word and per errorful line;
- paired comparisons when the same line is recognized by all systems.

### Sensitivity grid

Pre-register a compact set:

1. competition-compatible;
2. NFC + grapheme;
3. raw codepoint;
4. punctuation-insensitive;
5. collapsed whitespace;
6. optional case-insensitive only where case is meaningful.

Do not optimize policy to favor a system.

## Figures

1. **Framework diagram**: image → recognizer → alignment → statistical profile →
   fidelity profile.
2. **Same CER, different errors**: matched qualitative examples.
3. **Micro vs macro / paired forest plot**.
4. **Error composition by model family**.
5. **Human-validated generative fidelity errors**.
6. **Policy sensitivity heatmap / rank stability plot**.

## Critical ablations

- grapheme vs codepoint;
- with/without punctuation;
- micro vs macro;
- line bootstrap vs document bootstrap (diagnostic only; document is primary);
- purely automatic taxonomy vs human source-aware labels.

## Success criteria for CVPR

Proceed as CVPR main-track paper if, by late October, we have:

- at least two model families including generative VLMs;
- a validated fidelity annotation taxonomy;
- one strong main benchmark plus a second domain;
- at least one substantive result conventional CER/WER obscures;
- public/reproducible analysis code;
- clean benchmark inference pipeline.

## Redirection criteria

Prefer ICDAR if:
- the important phenomena appear only on historical HTR;
- source-aware taxonomy is valuable but data scale remains modest;
- the main novelty is document-analysis-specific.

Prefer R Journal if:
- empirical novelty is weak but the evaluation software/workflow is robust,
  general, and mature.

## Timeline

### 18–30 September
- freeze related-work matrix;
- obtain CMMHWR26 ground truth;
- generate baseline + MEDUSA frozen predictions;
- reproduce official metrics;
- implement span export / annotation tooling.

### 1–15 October
- pilot fidelity taxonomy on 300–500 outputs;
- revise categories based on disagreements;
- identify second benchmark;
- run second-domain systems.

### 16–31 October
- full annotation sample;
- final statistical analyses;
- figures/tables;
- write method + experiments.

### 1–9 November
- complete draft;
- internal reviewer-style pass;
- strengthen comparisons/ablations.

### 10 November
- CVPR paper registration deadline.

### 11–15 November
- final experiments and writing.

### 16 November
- CVPR submission deadline AOE.
