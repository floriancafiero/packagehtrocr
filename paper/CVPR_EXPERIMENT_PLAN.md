# CVPR 2027 experiment plan

## Working research question

**Can generative visual recognizers follow an explicit transcription policy, or
do learned linguistic/editorial priors dominate what they output?**

The central experiment changes the requested transcription policy while keeping
the **same source image, same model weights, same decoding regime, and same
evaluation material**.

The paper therefore separates two quantities that ordinary CER/WER conflate:

1. **visual recognition ability**;
2. **compliance with the requested transcription convention**.

## Core intervention: policy swap

For each promptable VLM, evaluate the same images under three pre-registered
conditions.

### Neutral

Minimal instruction: transcribe the line and return only the transcription.

### Matched policy

Instruction matches the benchmark target convention.

- CMMHWR26: CATMuS-style convention.
- GT4HistOCR: diplomatic convention.

### Conflicting policy

Instruction deliberately requests the opposite editorial behavior.

- CMMHWR26: diplomatic preservation.
- GT4HistOCR: CATMuS-style normalization/allograph policy.

Prompts are frozen under `benchmark/prompts/` before model inference.

## Main hypotheses

### H1 — transcription is instruction-conditioned

For a non-trivial fraction of source lines, changing only the transcription
policy changes the VLM output.

Primary observable:
- exact output-change rate;
- normalized grapheme distance between prompt-conditioned outputs.

### H2 — matched policy improves target compliance

Relative to the neutral and conflicting prompts, a policy matching the benchmark
target reduces target CER/WER and policy-specific errors.

Primary observable:
- paired B-A CER/WER difference;
- fraction of lines improved/worsened/unchanged;
- document-level bootstrap interval.

### H3 — standard CER conflates perception and policy mismatch

Some apparent recognition errors are coherent output-policy choices rather than
simple visual misreadings.

Evidence:
- source-aware annotation of changed/error spans;
- policy-sensitive character/abbreviation/segmentation subsets;
- examples where prompt changes alter editorial representation while visual
  content remains stable.

### H4 — specialization changes controllability

A historical-text specialist and a general-purpose VLM may respond differently
to the same policy intervention.

Candidate comparison:
- MEDUSA-4B;
- Qwen3-VL-4B-Instruct;
- MEDUSA-9B matched-policy reference run.

Possible outcomes are both informative:
- specialization improves compliance;
- or fine-tuning hard-codes a convention and makes policy switching harder.

### H5 — policy effects generalize across visual domains

The same qualitative phenomenon should be tested in:
- historical handwriting (CMMHWR26);
- historical print (GT4HistOCR).

The desired target convention is intentionally different between the two
benchmarks.

## Benchmark A — CMMHWR26

### Data

Use the public post-competition test set with official transcriptions.

Canonical table:
- document_id;
- page_id;
- line_id;
- system;
- reference;
- prediction;
- task/language if recoverable;
- source image and line geometry.

### Systems

Fixed baseline:
- Kraken / CATMuS 1.6.

Promptable:
- MEDUSA-4B;
- Qwen3-VL-4B-Instruct.

Scale/control:
- MEDUSA-9B under matched CATMuS policy initially.

### Conditions

For MEDUSA-4B and Qwen-4B:
- neutral;
- CATMuS matched;
- diplomatic conflicting.

The benchmark-specific manifest is:
`benchmark/cmmhwr/SYSTEMS_POLICY.csv`.

## Benchmark B — GT4HistOCR historical print

### Why

GT4HistOCR gives a genuine domain shift:
- historical print instead of handwriting;
- German/Latin material;
- diplomatic transcriptions preserving historical forms;
- multiple books/documents for clustered inference.

The corpus is heavily imbalanced by subcorpus, so use the frozen balanced subset
builder rather than uniform line sampling.

### Subset

Default pilot:
- up to 500 lines per upstream subcorpus;
- at most 75 lines per book;
- seed 2027.

The final sample size can increase after inference-cost measurement, but the
selection rule must be frozen before inspecting model effects.

### Systems and conditions

Promptable:
- MEDUSA-4B: neutral / diplomatic matched / CATMuS conflicting;
- Qwen3-VL-4B: neutral / diplomatic matched / CATMuS conflicting;
- MEDUSA-9B diplomatic matched initially.

A conventional OCR baseline can be added if it is not trained on the evaluation
lines. Do not use a GT4HistOCR-trained model as an out-of-domain baseline and
then claim generalization.

The benchmark-specific manifest is:
`benchmark/gt4histocr/SYSTEMS_POLICY.csv`.

## Primary quantitative analyses

### 1. Ordinary benchmark accuracy

For every run:
- CER/WER;
- micro aggregation;
- document-level macro aggregation;
- document-level heterogeneity.

This establishes comparability with conventional OCR/HTR evaluation.

### 2. Within-model policy swap

Use `policy_swap_summary()`.

For every same-model policy pair:
- output-change rate;
- mean/median normalized output distance;
- fraction of source lines moving toward the benchmark target;
- fraction moving away;
- mean line-level target delta;
- document-level macro target delta with bootstrap interval.

The most important comparisons are:
- neutral -> matched;
- conflicting -> matched.

### 3. Cross-model comparison

Under the **same matched target policy**:
- conventional/specialized/general VLM accuracy;
- paired document-level differences;
- error profiles.

This separates policy compliance from model-family performance.

### 4. Policy-sensitive subsets

Predefine benchmark-specific subsets where convention matters.

CMMHWR candidates:
- u/v and i/j conventions;
- allographic forms;
- abbreviations;
- segmentation changes.

GT4HistOCR candidates:
- historical/allographic Unicode characters;
- abbreviation markers where reliably encoded;
- historical spelling/word-boundary cases.

Do not create subsets after inspecting which model benefits.

## Source-aware annotation study

This is an explanatory validation layer, not the novelty claim by itself.

### Pilot

Target:
- 300–500 error or prompt-changed spans;
- stratified by model and benchmark strata;
- two independent annotators;
- model identity hidden;
- image + target convention + reference + output visible.

### Labels

Mechanical/source-aware categories:
- visual_misrecognition;
- content_omission;
- hallucinated_addition;
- repetition;
- orthographic_normalization;
- linguistic_correction;
- abbreviation_change;
- segmentation_policy_change;
- unsupported_completion;
- ambiguous/other.

A policy-intervention label applies only when behavior exceeds or conflicts with
the **declared target convention**.

### Reliability

Report:
- raw agreement;
- Cohen's kappa for the primary category;
- ambiguity rate;
- adjudication protocol.

If pilot agreement is weak, revise/merge categories before full annotation.

## Statistical unit and inference

Never treat thousands of lines from the same document as independent evidence.

Primary comparison:
- paired differences on the same recognition lines;
- resample complete documents/manuscripts/books;
- report effect + interval.

Micro CER/WER remain useful descriptive leaderboard quantities, but are not the
primary inferential estimand.

## Pre-registration-like safeguards

Before running the full experiment:

1. freeze the benchmark subset IDs;
2. freeze prompt text;
3. freeze exact model revisions;
4. freeze decoding settings;
5. freeze primary comparisons;
6. freeze policy-sensitive subset definitions;
7. record checksums for prediction files.

Do not tune prompt wording after seeing which condition improves the target
score.

## Figures planned

1. **Policy-swap design**: same image + same weights -> three transcription
   policies.
2. **Prompt controllability**: output-change rate and output distance by model.
3. **Target movement**: matched-vs-neutral/conflicting delta CER/WER with
   document bootstrap intervals.
4. **Policy-sensitive subset performance**.
5. **Source-grounded behavior profile** from human annotation.
6. **Handwriting vs print comparison**.

## Success criterion for CVPR

Proceed as a CVPR main-track submission if the policy intervention reveals a
substantive, reproducible phenomenon such as:

- matched instructions materially improve target compliance;
- conflicting instructions induce coherent editorial changes without equivalent
  visual-recognition changes;
- specialist and general VLMs differ strongly in controllability;
- CER/WER differences can be decomposed into policy mismatch vs visual error;
- effects repeat across handwriting and print.

The strongest result need not be that matched prompts always help. Finding that
a fine-tuned VLM **cannot** override its learned transcription convention despite
explicit instructions would also be scientifically meaningful.

## Redirect criterion

Prefer ICDAR if:
- policy effects are weak;
- interesting behavior is confined to one historical HTR benchmark;
- the main value becomes the evaluation toolkit/error-analysis framework.

Retain the R Journal paper as a later software publication regardless of the
CVPR empirical outcome.

## Timeline

### 18–30 September
- finish benchmark plumbing;
- freeze CMMHWR and GT4 subset IDs;
- freeze prompts/system manifests;
- run CMMHWR Kraken + first 4B policy swaps;
- validate output/table pipeline.

### 1–15 October
- run full 4B experiment on both benchmarks;
- pilot 300–500 source-aware annotations;
- inspect whether H1–H4 are empirically supported;
- decide whether 9B/additional models are needed.

### 16–31 October
- full annotation if pilot is reliable;
- policy-sensitive subset analyses;
- all figures and ablations;
- paper draft.

### 1–9 November
- reviewer-style stress test;
- address strongest alternative explanations;
- finalize related work and limitations.

### 10 November
- CVPR registration.

### 16 November
- CVPR submission.
