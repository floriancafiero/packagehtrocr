# Visual transcription fidelity annotation guidelines

## Purpose

These annotations characterize *why* a recognition output differs from a
reference transcription. They are designed for comparing specialized OCR/HTR
systems with generative VLMs.

The annotation question is deliberately source-aware:

> **Given the image, the reference transcription, and the system output, what
> best explains this difference as a transcription error?**

Do not judge whether the prediction is linguistically elegant, semantically
plausible, or useful downstream. Judge whether it is faithful to the visible
source under the stated transcription convention.

## Blinding

Annotators must not see model identity.

Each item contains:
- an image or image identifier supplied by the benchmark workflow;
- full reference text;
- full predicted text;
- the aligned error span;
- local context;
- a mechanical edit type;
- an anonymous annotation ID.

Model identity is kept in a separate key.

## Primary labels

### `visual_misrecognition`

Use when the model appears to have read visible characters/words incorrectly and
there is no stronger reason to interpret the change as normalization,
correction, abbreviation handling, or completion.

Example pattern:
- visible/reference: `raison`
- output: `maison`

The precise example must be verified against the image.

### `content_omission`

Use when source content that is visibly present is absent from the prediction.

This label concerns omission of actual source content, not merely a tokenization
difference.

### `hallucinated_addition`

Use when the prediction adds content for which there is no plausible support in
the visible source.

The added content may be linguistically plausible. Plausibility does not make it
faithful.

### `repetition`

Use when the system repeats characters, words, or a span beyond what appears in
the source.

Automatic repetition detection is only a candidate flag; the image decides the
label.

### `orthographic_normalization`

Use when the source/reference contains a visible historical, non-standard, or
variant spelling and the prediction replaces it with a normalized spelling.

This is not necessarily a bad output for every downstream task. It is an
intervention relative to diplomatic visual transcription.

### `linguistic_correction`

Use when the prediction changes a visibly attested form toward a more probable,
grammatically correct, or lexically expected form.

The key distinction from visual misrecognition is that the output looks like a
language-model correction of what is actually present.

### `abbreviation_change`

Use when the prediction expands, contracts, or changes the representation of a
visible abbreviation relative to the reference transcription convention.

Do not mark a difference as erroneous merely because another transcription
convention would also be reasonable. Follow the benchmark's stated convention.

### `unsupported_completion`

Use when the image is damaged, occluded, cropped, faint, or otherwise
insufficient to support the predicted content confidently, but the model
supplies a plausible completion.

This differs from `hallucinated_addition`:
- **unsupported completion**: there is a visually expected/partially visible
  textual slot, but the exact generated content is not supported;
- **hallucinated addition**: the model adds content for which there is no source
  slot/evidence.

### `other`

Use for a genuine source-aware error that does not fit the current taxonomy.
Explain briefly in `notes`.

### `ambiguous`

Use when the image or transcription convention does not permit a reliable
decision.

Ambiguity is a valid outcome and should not be forced into another class.

## Decision order

For each error span:

1. **Can the source evidence be read reliably?**
   - No → consider `unsupported_completion` or `ambiguous`.
   - Yes → continue.
2. **Is visible source content missing?**
   - Yes → `content_omission`.
3. **Is unsupported content added?**
   - Yes → `hallucinated_addition` or `repetition`.
4. **Does the prediction preserve the underlying visual content but alter its
   linguistic representation?**
   - historical/variant spelling → `orthographic_normalization`;
   - probable correction → `linguistic_correction`;
   - abbreviation convention → `abbreviation_change`.
5. Otherwise → `visual_misrecognition`.
6. If none is defensible → `other` or `ambiguous`.

## Secondary label

Use `secondary_label` only when two mechanisms genuinely coexist.

Example: an unsupported completion that also modernizes spelling could receive:
- primary: `unsupported_completion`;
- secondary: `orthographic_normalization`.

The primary label should identify the mechanism most directly relevant to visual
fidelity.

## Confidence

Recommended scale:

- **3 — high:** image evidence clearly supports the label;
- **2 — medium:** label is most plausible but some ambiguity remains;
- **1 — low:** difficult case; likely candidate for adjudication.

## Annotation pilot

Initial target:
- 300–500 error spans;
- at least two independent annotators;
- balanced across model families and major language/task strata;
- model identity hidden;
- disagreements adjudicated only after independent annotation.

Report raw agreement and Cohen's kappa for the primary label. If the taxonomy is
too fine to achieve stable agreement, merge or revise categories *before* the
full annotation round rather than after inspecting desired model effects.

## Important safeguards

- Do not infer the intended word from linguistic context when the image is
  unreadable.
- Do not reward a model for silently correcting the source.
- Do not penalize a model for following the official transcription convention.
- Do not use model identity as evidence.
- Do not optimize the taxonomy after seeing which categories favor a particular
  model family.
