# ocrinfer

Experimental R package for **statistically explicit evaluation of OCR and handwritten text recognition (HTR)**.

The package name `ocrinfer` is provisional. The repository now supports a **CVPR 2027 research project on visual transcription fidelity in the VLM era**; a later R Journal software paper remains a secondary objective.

The package does **not** run OCR/HTR models. It starts from reference transcriptions and recognition outputs and asks how recognition quality should be measured, aggregated, compared, and diagnosed.

## Why another evaluation package?

Computing one CER or WER is easy. Research evaluation is harder when:

- lines are nested in pages and manuscripts;
- systems are evaluated on the same material and should be compared as paired observations;
- long documents dominate pooled error rates;
- Unicode-equivalent strings have different code-point representations;
- punctuation, case, or whitespace policies change reported performance;
- a global error rate hides systematic substitutions, deletions, or insertions.

`ocrinfer` is being built around those problems.

## Current API

### Text policy and elementary metrics

```r
normalize_text()
align_text()
edit_counts()
cer()
wer()
```

Character evaluation uses Unicode grapheme clusters by default. Code-point evaluation remains available explicitly.

### Dataset evaluation

```r
results <- evaluate_recognition(
  data,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = c("document_id", "language", "script_type")
)
```

The output preserves reference/prediction text by default, edit counts, the requested metadata, and the evaluation policy.

### Micro and macro aggregation

```r
summarise_recognition(
  results,
  by = "system",
  averaging = "micro"
)

summarise_recognition(
  results,
  by = "system",
  averaging = "macro",
  unit = "document_id"
)
```

**Micro averaging** pools edit counts before dividing.  
**Macro averaging** first calculates a rate for each higher-level unit and then gives each unit equal weight.

### Paired system comparison

```r
comparison <- compare_systems(
  results,
  systems = c("A", "B"),
  unit = "document_id",
  pair_id = "line_id",
  estimand = "macro",
  n_boot = 2000,
  seed = 1
)
```

The comparison is reported as **B - A**. Negative values therefore mean that system B has the lower error rate.

Before bootstrapping, `compare_systems()` checks that the systems contain the same paired IDs and the same reference text. Complete documents/manuscripts are resampled rather than individual lines.

### Sensitivity to evaluation policy

```r
normalization_sensitivity(
  data,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  policies = list(
    raw_codepoints = list(
      unicode = "none",
      char_unit = "codepoint"
    ),
    nfc_graphemes = list(
      unicode = "NFC",
      char_unit = "grapheme"
    ),
    ignore_punctuation = list(
      unicode = "NFC",
      punctuation = "remove"
    )
  ),
  metrics = "cer"
)
```

This makes evaluation choices part of the analysis rather than invisible preprocessing.

### Diagnostics

```r
profile <- error_profile(results, by = "system")

confusions <- confusion_table(
  results,
  metric = "cer",
  by = "system"
)
```

`confusion_table()` reconstructs token alignments and represents insertion/deletion gaps explicitly as `<eps>`.

### Publication-oriented plots

```r
plot_comparison(comparison)
plot_error_profile(profile, group = "system")
```

Both functions return ordinary `ggplot` objects and can therefore be extended with standard ggplot2 layers/themes.

## Included examples

### Toy two-system workflow

`inst/extdata/toy_recognition.csv` is a tiny artificial example used to exercise the full workflow.

### Public CATMuS fixture

The repository also contains a small text-only fixture selected from the openly licensed **CATMuS Medieval Samples** dataset:

- `inst/extdata/catmus_medieval_public_fixture.csv`
- `inst/extdata/catmus_medieval_controlled_predictions.csv`

The second file contains **controlled transformations, not model outputs**:

- `exact`;
- `nfc_equivalent`;
- `punctuation_dropped`.

It exists to test Unicode and normalization semantics. It must not be interpreted as a recognition-system benchmark. Attribution and licensing information are in `inst/extdata/CATMUS_ATTRIBUTION.md`.

The main empirical benchmark is now planned around the public CMMHWR26 post-competition test set with frozen predictions from specialized HTR and generative VLM systems. A second domain will be added for the CVPR study.

## Design principles

1. **Evaluation policy is explicit.** NFC is the conservative default; case, punctuation, and whitespace changes are not silently imposed.
2. **The statistical unit matters.** Lines from the same document/manuscript are not treated as independent evidence when comparing systems.
3. **System comparisons are genuinely paired.** Same IDs and same reference text are required.
4. **Raw evidence remains inspectable.** Evaluation results retain source and predicted text by default.
5. **Controlled examples are clearly separated from model benchmarks.**
6. **The package evaluates recognition; it does not become an OCR engine.**

## Development status

Current development includes unit tests, a vignette, public fixtures, and automated `R CMD check` on GitHub Actions.

Current status: `R CMD check --as-cran` passes with **Status: OK** on GitHub Actions.

Next priorities:

- generate frozen CMMHWR26 predictions for Kraken/CATMuS and generative VLMs;
- pilot and validate the source-aware transcription-fidelity taxonomy;
- add a second OCR/HTR domain;
- test whether conventional CER/WER hides substantive model-family differences;
- prepare the CVPR 2027 submission by 16 November 2026.

See `paper/CVPR_POSITIONING.md`, `paper/CVPR_EXPERIMENT_PLAN.md`, and `benchmark/CMMHWR26_PLAN.md`.
