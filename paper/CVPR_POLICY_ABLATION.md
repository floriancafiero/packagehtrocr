# Policy-factor ablation

## Why

The main matched/conflicting prompts intentionally represent coherent
transcription policies. They therefore change several rules simultaneously.

That is appropriate for the main question:

> Can a generative visual recognizer be moved toward a different transcription
> convention by instruction alone?

It is not sufficient for attributing the effect to a specific policy dimension.

## Secondary ablation

Run a smaller stratified subset with a neutral base prompt and one added rule at
a time:

1. preserve abbreviations;
2. modernize segmentation;
3. standardize allographs;
4. force u/i rather than v/j;
5. prohibit unsupported completion.

Everything else in the prompt remains identical.

## Design

Use the same:
- images;
- model weights/revision;
- decoding parameters;
- output format;
- line subset.

Only one instruction sentence changes.

Suggested pilot size: 300–500 lines chosen to contain enough examples relevant to
the corresponding factor. A fully random subset would waste inference on lines
where, for example, no abbreviation or u/v distinction exists.

## Primary outcomes

For each factor:
- output-change rate relative to the base prompt;
- direction of CER change;
- rate of changes on factor-relevant lines;
- human preference under the benchmark target convention;
- source-aware reason labels for changed outputs.

## Interpretation

A positive result is not merely that prompts change text. The stronger result is:

> The intervention changes outputs specifically on source phenomena governed by
> the manipulated transcription rule, and the direction of change is predictable
> from the requested policy.

This is substantially stronger evidence for controllable transcription policy
than comparing two long prompts that differ in many ways.

## Scope

This is an ablation, not the main benchmark. The main paper should still compare
complete coherent policies because real transcription projects specify bundles
of conventions rather than isolated rules.
