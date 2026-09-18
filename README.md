# ocrinfer

Experimental R package for statistically explicit evaluation of OCR and handwritten text recognition (HTR).

The package name `ocrinfer` is provisional. This repository develops the software and reproducibility materials for a possible **R Journal** submission.

## Current scope

Implemented:

- Unicode-aware normalization;
- grapheme-, codepoint-, and word-level alignment;
- CER and WER;
- edit-operation summaries;
- tidy row-level evaluation;
- preservation of document/page/metadata columns;
- micro- and macro-averaged recognition summaries;
- paired comparison of two recognition systems;
- cluster bootstrap uncertainty by document/manuscript;
- toy recognition data, tests, vignette, and automated `R CMD check`.

Planned next:

- normalization sensitivity analysis;
- confusion/error profiles;
- publication-oriented plots;
- small frozen public benchmark subsets;
- CRAN-quality generated documentation.

## Toy workflow

The bundled toy data contain two systems evaluated on several lines nested in documents.

```r
toy <- read.csv(
  system.file("extdata", "toy_recognition.csv", package = "ocrinfer"),
  stringsAsFactors = FALSE
)

results <- evaluate_recognition(
  toy,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = "document_id"
)

# Pool all edit counts.
summarise_recognition(
  results,
  by = "system",
  averaging = "micro"
)

# Give each document equal weight.
summarise_recognition(
  results,
  by = "system",
  averaging = "macro",
  unit = "document_id"
)

# Difference is reported as B - A; negative means B has lower error.
compare_systems(
  results,
  systems = c("A", "B"),
  unit = "document_id",
  pair_id = "line_id",
  estimand = "macro",
  n_boot = 2000,
  seed = 1
)
```

## Design principles

1. **Evaluation policy must be explicit.** NFC is applied by default; case, punctuation, and whitespace changes are not silently imposed.
2. **Lines from the same document are not treated as independent evidence.**
3. **System comparisons are paired.** The comparison function checks that both systems were evaluated on the same line IDs before resampling higher-level units.
4. **The package evaluates recognition output; it does not run OCR/HTR models.**

See `PROJECT_SPEC.md` for the research and release roadmap.
