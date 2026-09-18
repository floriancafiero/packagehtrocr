# Pairwise policy-preference annotation

## Question

For each item, inspect the source image and the declared target transcription
convention. You see:

- the benchmark reference;
- anonymous output **A**;
- anonymous output **B**.

Model and prompt identity are hidden.

Answer:

> Which output is the better transcription of the visible source under the
> declared target convention?

Allowed values for `preferred_output`:

- `A`
- `B`
- `tie`
- `ambiguous`

## Important distinction

Do **not** choose the output that is linguistically nicer, more modern, or more
plausible. Choose the output that best follows the source image **and** the target
transcription policy.

For example, if the target policy preserves historical spelling, silently
modernizing a visible form is a fidelity error even if the modernized output is
easier to read.

Conversely, if the target policy explicitly normalizes a convention, following
that normalization is not an error.

## Reason label

Use `reason_label` to record the main reason for the preference when possible:

- `visual_accuracy`
- `content_completeness`
- `less_hallucination`
- `less_repetition`
- `policy_compliance`
- `better_abbreviation_handling`
- `better_segmentation`
- `other`
- `ambiguous`

The preference judgment is primary; the reason label is explanatory.

## Confidence

- **3** — clear from the image and convention;
- **2** — preferred output is more likely but some uncertainty remains;
- **1** — difficult case.

Use `ambiguous` rather than forcing a decision when the source itself is not
readable enough.

## Pilot protocol

For the first pilot:

- 300 changed outputs;
- at least two independent annotators;
- A/B side randomized independently of model/prompt identity;
- balance across models and policy-condition pairs;
- do not adjudicate until independent annotation is complete.

After the pilot, compute:
- raw A/B/tie/ambiguous frequencies;
- agreement on preferred output;
- preference rate for matched vs neutral/conflicting policy after unblinding;
- preference rate separately for cases where CER improves, worsens, or stays
  effectively unchanged.

## Why this is central to the CVPR claim

CER tells us whether one text is closer to the benchmark reference.

This experiment asks a different question:

> When changing only the transcription instruction changes the output, do humans
> looking at the source image agree that the change makes the transcription more
> faithful to the requested convention?

A positive result supports the claim that transcription policy is an
experimentally controllable variable in generative visual recognition rather
than merely a post-hoc error category.
