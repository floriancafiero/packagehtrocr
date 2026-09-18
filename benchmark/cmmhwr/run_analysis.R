#!/usr/bin/env Rscript

# Reproducible CMMHWR26 analysis for the CVPR project.
#
# Usage:
#   Rscript benchmark/cmmhwr/run_analysis.R \
#     benchmark/cmmhwr/cmmhwr_predictions.csv \
#     benchmark/cmmhwr/output
#
# Optional third argument: number of error spans in the blinded annotation
# pilot (default: 400).

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2L || length(args) > 3L) {
  stop(
    paste(
      "Usage:",
      "Rscript benchmark/cmmhwr/run_analysis.R",
      "<predictions.csv> <output_dir> [annotation_n]"
    ),
    call. = FALSE
  )
}

input_path <- args[[1]]
output_dir <- args[[2]]
annotation_n <- if (length(args) >= 3L) as.integer(args[[3]]) else 400L

if (is.na(annotation_n) || annotation_n < 1L) {
  stop("annotation_n must be a positive integer.", call. = FALSE)
}

if (!requireNamespace("ocrinfer", quietly = TRUE)) {
  stop(
    paste(
      "Package 'ocrinfer' is not installed.",
      "From the repository root run: R CMD INSTALL ."
    ),
    call. = FALSE
  )
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

d <- read.csv(
  input_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

required <- c(
  "document_id",
  "page_id",
  "line_id",
  "system",
  "reference",
  "prediction"
)

missing_required <- setdiff(required, names(d))
if (length(missing_required) > 0L) {
  stop(
    sprintf(
      "Missing required columns: %s.",
      paste(missing_required, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (anyDuplicated(d[c("line_id", "system")])) {
  stop(
    "Each line_id × system combination must occur exactly once.",
    call. = FALSE
  )
}

systems <- sort(unique(d$system))
if (length(systems) < 2L) {
  stop("At least two systems are required.", call. = FALSE)
}

# Verify exact pairing before any metric is computed.
ids_by_system <- split(d$line_id, d$system)
canonical_ids <- sort(ids_by_system[[systems[[1]]]])

for (system_name in systems[-1]) {
  if (!identical(canonical_ids, sort(ids_by_system[[system_name]]))) {
    stop(
      sprintf(
        "System %s is not evaluated on exactly the same line IDs.",
        system_name
      ),
      call. = FALSE
    )
  }
}

reference_lookup <- d[
  d$system == systems[[1]],
  c("line_id", "reference"),
  drop = FALSE
]
reference_lookup <- reference_lookup[order(reference_lookup$line_id), ]
rownames(reference_lookup) <- NULL

for (system_name in systems[-1]) {
  candidate <- d[
    d$system == system_name,
    c("line_id", "reference"),
    drop = FALSE
  ]
  candidate <- candidate[order(candidate$line_id), ]
  rownames(candidate) <- NULL

  if (!identical(reference_lookup, candidate)) {
    stop(
      sprintf(
        "Reference text differs for system %s.",
        system_name
      ),
      call. = FALSE
    )
  }
}

metadata_candidates <- c(
  "benchmark",
  "task",
  "language",
  "script",
  "script_type",
  "century",
  "page_id",
  "document_id",
  "image_path",
  "source_xml",
  "hpos",
  "vpos",
  "width",
  "height",
  "polygon"
)

keep <- intersect(metadata_candidates, names(d))
keep <- setdiff(keep, c("line_id", "system"))

evaluated <- ocrinfer::evaluate_recognition(
  d,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = keep,
  metrics = c("cer", "wer"),
  char_unit = "grapheme",
  unicode = "NFC",
  case = "preserve",
  whitespace = "preserve",
  punctuation = "preserve"
)

write.csv(
  evaluated,
  file.path(output_dir, "evaluated_lines.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

micro <- ocrinfer::summarise_recognition(
  evaluated,
  by = "system",
  averaging = "micro"
)

macro_document <- ocrinfer::summarise_recognition(
  evaluated,
  by = "system",
  averaging = "macro",
  unit = "document_id"
)

write.csv(
  micro,
  file.path(output_dir, "summary_micro.csv"),
  row.names = FALSE
)

write.csv(
  macro_document,
  file.path(output_dir, "summary_macro_document.csv"),
  row.names = FALSE
)

# Optional stratified summaries when metadata exist.
for (stratum in intersect(c("task", "language", "script_type", "century"), names(evaluated))) {
  stratified <- ocrinfer::summarise_recognition(
    evaluated,
    by = c("system", stratum),
    averaging = "macro",
    unit = "document_id"
  )

  write.csv(
    stratified,
    file.path(
      output_dir,
      paste0("summary_macro_by_", stratum, ".csv")
    ),
    row.names = FALSE
  )
}

system_pairs <- combn(systems, 2L, simplify = FALSE)

compare_pair <- function(pair, estimand) {
  ocrinfer::compare_systems(
    evaluated,
    systems = pair,
    unit = "document_id",
    pair_id = "line_id",
    estimand = estimand,
    n_boot = 5000L,
    conf_level = 0.95,
    seed = 2027L
  )
}

pairwise_macro <- do.call(
  rbind,
  lapply(system_pairs, compare_pair, estimand = "macro")
)
pairwise_micro <- do.call(
  rbind,
  lapply(system_pairs, compare_pair, estimand = "micro")
)

write.csv(
  pairwise_macro,
  file.path(output_dir, "pairwise_macro_document.csv"),
  row.names = FALSE
)

write.csv(
  pairwise_micro,
  file.path(output_dir, "pairwise_micro.csv"),
  row.names = FALSE
)

profile <- ocrinfer::error_profile(
  evaluated,
  by = "system"
)

write.csv(
  profile,
  file.path(output_dir, "error_profile.csv"),
  row.names = FALSE
)

spans_keep <- intersect(
  c(
    "system",
    "line_id",
    "document_id",
    "page_id",
    "task",
    "language",
    "script_type",
    "century",
    "image_path",
    "source_xml",
    "hpos",
    "vpos",
    "width",
    "height",
    "polygon"
  ),
  names(evaluated)
)

cer_spans <- ocrinfer::extract_error_spans(
  evaluated,
  metric = "cer",
  by = spans_keep,
  context = 8L
)

write.csv(
  cer_spans,
  file.path(output_dir, "cer_error_spans.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Blinded source-fidelity pilot. Balance first by system and then, where
# available, by the main benchmark strata.
annotation_strata <- intersect(
  c("system", "task", "language"),
  names(evaluated)
)

annotation_keep <- intersect(
  c(
    "document_id",
    "page_id",
    "task",
    "language",
    "script_type",
    "century",
    "image_path",
    "source_xml",
    "hpos",
    "vpos",
    "width",
    "height",
    "polygon"
  ),
  names(evaluated)
)

batch <- if (nrow(cer_spans) > 0L) {
  ocrinfer::prepare_fidelity_annotation(
    evaluated,
    metric = "cer",
    system_col = "system",
    id_col = "line_id",
    keep = annotation_keep,
    strata = annotation_strata,
    n = min(annotation_n, nrow(cer_spans)),
    context = 8L,
    seed = 2027L,
    blind = TRUE
  )
} else {
  list(
    items = data.frame(),
    key = data.frame(),
    codebook = ocrinfer::fidelity_codebook()
  )
}

write.csv(
  batch$items,
  file.path(output_dir, "annotation_items_blinded.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  batch$key,
  file.path(output_dir, "annotation_key_private.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  batch$codebook,
  file.path(output_dir, "fidelity_codebook.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Publication-oriented plots.
grDevices::pdf(
  file.path(output_dir, "pairwise_macro_document.pdf"),
  width = 7,
  height = 4.5
)
print(ocrinfer::plot_comparison(pairwise_macro))
grDevices::dev.off()

grDevices::pdf(
  file.path(output_dir, "error_profile.pdf"),
  width = 8,
  height = 5
)
print(ocrinfer::plot_error_profile(profile, group = "system"))
grDevices::dev.off()

# Record a compact machine-readable manifest.
manifest <- data.frame(
  input_file = normalizePath(input_path, mustWork = FALSE),
  n_rows = nrow(d),
  n_lines = length(unique(d$line_id)),
  n_documents = length(unique(d$document_id)),
  n_systems = length(systems),
  systems = paste(systems, collapse = ";"),
  annotation_n = nrow(batch$items),
  stringsAsFactors = FALSE
)

write.csv(
  manifest,
  file.path(output_dir, "analysis_manifest.csv"),
  row.names = FALSE
)

message("Analysis complete: ", normalizePath(output_dir, mustWork = FALSE))
