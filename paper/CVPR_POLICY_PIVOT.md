# CVPR pivot: transcription policy compliance

## New working title

**Reading or Rewriting? Benchmarking Transcription Policy Compliance in Vision-Language Models**

Alternative:

**Transcription Is a Task Specification: Evaluating Policy Compliance in Generative OCR and HTR**

## Why the previous formulation is no longer enough

Several recent papers now occupy large parts of the original idea:

- Levchenko (2025) already shows historical-character loss and
  "over-historicization" in VLM OCR.
- Vesalainen et al. (2026) already show that Qwen can improve CER/WER while
  silently regularizing/normalizing historical orthography compared with TrOCR.
- OCR-EDR (September 2026) already performs source-grounded image-conditioned
  diagnosis and localization of OCR errors, including completeness/content/
  structure errors and rendering-equivalent outputs.
- HIPE-OCRepair already studies over-correction, micro/macro aggregation and
  confidence intervals in LLM-assisted OCR post-correction.

Therefore, **source-grounded error diagnosis alone is not a sufficient CVPR
novelty claim**.

## The stronger question

OCR/HTR ground truth is not just "what is visible in the image." It is:

> image + transcription policy.

A historical line can legitimately have different targets under different
editorial policies:

- diplomatic: preserve historical spelling/allographs/abbreviations;
- normalized: regularize selected forms;
- benchmark-specific: e.g. CATMuS conventions.

Traditional recognizers usually have one fixed output convention learned during
training.

Generative VLMs add a new variable: **the transcription policy can be expressed
in the prompt**.

This creates a new evaluation question:

> Can a VLM change its transcription behavior when the target transcription
> policy changes, while remaining grounded in the same visual source?

## Core experiment: policy swap

For the same image and same VLM, run three prompt conditions.

### P0 — neutral

"Transcribe the text in this line image. Output only the transcription."

### P1 — CATMuS-style

Use the public MEDUSA/CMMHWR target instruction:

- keep abbreviations as written;
- modernize word segmentation;
- use u/i rather than v/j under the target convention;
- do not record allographic variants;
- output only the transcription.

### P2 — diplomatic

- preserve historical spelling;
- preserve visually meaningful allographs/character forms available in Unicode;
- preserve abbreviations;
- preserve source word segmentation unless the benchmark states otherwise;
- do not silently correct or modernize;
- mark nothing that is not visually supported;
- output only the transcription.

## Two complementary datasets

### CMMHWR26

Target policy: CATMuS-like benchmark convention.

Compare:
- neutral prompt;
- matched CATMuS prompt;
- deliberately mismatched diplomatic prompt.

Expected diagnostic:
- Does explicit matched policy reduce convention-specific errors?
- Does a diplomatic prompt preserve visual forms that are *wrong under the
  benchmark target*?

### GT4HistOCR

Target policy: diplomatic transcriptions preserving historical forms as much as
possible in Unicode.

Compare:
- neutral prompt;
- matched diplomatic prompt;
- deliberately mismatched CATMuS/normalized prompt.

Expected diagnostic:
- Does the generic/normalized instruction increase historical-form loss?
- Can explicit diplomatic instructions recover those forms?
- Are specialist and general-purpose VLMs equally controllable?

## Model families

Minimum:

1. Kraken / conventional recognizer — fixed-output baseline, not promptable.
2. MEDUSA-4B.
3. MEDUSA-9B.
4. General-purpose Qwen VLM (4B preferred for tractability).

A crucial comparison is not only model A vs B, but:

> model A under prompt P0 vs the **same model A** under P1/P2.

This controls for architecture and weights.

## Main hypotheses

### H1 — VLM transcription is instruction-conditioned

The same model/image produces measurably different outputs under different
transcription policies.

### H2 — matched policy improves target compliance

A prompt matching the dataset's target convention reduces policy-specific
errors relative to a neutral or conflicting prompt.

### H3 — CER conflates perception and policy mismatch

Some CER differences arise because a model follows a different but coherent
transcription policy rather than because it visually misreads the source.

### H4 — specialization changes controllability

Fine-tuned historical VLMs and general-purpose VLMs differ in how strongly they
respond to policy prompts. Fine-tuning may improve target accuracy but also make
the learned policy harder to override.

### H5 — policy effects generalize across handwriting and print

The phenomenon appears both on CMMHWR26 handwriting and GT4HistOCR print, even
though their desired transcription conventions differ.

## What is genuinely new if supported

The claim is no longer:

> We have a better OCR error taxonomy.

It becomes:

> We show that for generative visual recognizers, **transcription policy is an
> experimental variable**. Standard OCR evaluation conflates visual recognition
> ability with policy compliance. We introduce a paired policy-swap protocol
> that measures both on the same images and model weights.

This is analogous in spirit to recent work treating transcription policy as a
latent variable in ASR, but instantiated and studied for visual transcription
where the source image provides independent grounding evidence.

## Evaluation

### Ordinary accuracy

- CER/WER;
- micro and document-level macro;
- paired document-level intervals.

### Policy-sensitive subsets

Identify spans where the target convention matters:

- historical/allographic characters;
- abbreviations;
- word-boundary decisions;
- orthographic variants;
- convention-specific character mappings.

Report performance separately on these subsets.

### Prompt effect

For each model/image pair:

- whether output changes at all;
- edit distance between outputs under two policies;
- whether the change moves toward the matched target;
- change in policy-sensitive error rate;
- change in ordinary CER/WER.

### Source-grounded annotation

Human annotators inspect image + reference + anonymous output and label error
spans as:

- visual misrecognition;
- omission;
- unsupported addition/repetition/completion;
- orthographic/allographic normalization beyond target policy;
- linguistic correction beyond target policy;
- abbreviation-policy mismatch;
- segmentation-policy mismatch;
- ambiguous/other.

Do not infer internal model causality from these labels. They describe observable
output behavior relative to image and declared policy.

## A result worth CVPR

The strongest possible result would look like:

> On the same images and weights, changing only the transcription instruction
> shifts a substantial fraction of errors between visual misrecognition and
> policy-driven rewriting. Global CER hides this change, and specialist vs
> general VLMs differ systematically in controllability.

A weaker but still useful result:

> VLMs largely ignore policy prompts, revealing that transcription convention is
> encoded primarily by fine-tuning priors rather than instruction following.

Either outcome is scientifically informative.

## Failure criterion

If prompt policy has little measurable effect and the remaining finding reduces
to "VLMs normalize more than classical OCR," the CVPR novelty is insufficient;
redirect the work to ICDAR with the software/statistical framework.
