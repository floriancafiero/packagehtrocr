#!/usr/bin/env Rscript

# Build a blinded A/B annotation batch from policy_changed_outputs.csv.
#
# Usage:
#   Rscript benchmark/make_policy_preference_batch.R \
#     policy_changed_outputs.csv output_dir 300
#
# The input is produced by benchmark/run_policy_swap.R.
# The annotator sees the same reference plus two anonymous outputs A/B.
# The private key records which prompt condition generated each side.

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2L || length(args) > 3L) {
  stop(
    paste(
      "Usage: Rscript benchmark/make_policy_preference_batch.R",
      "<policy_changed_outputs.csv> <output_dir> [n]"
    ),
    call. = FALSE
  )
}

input_path <- args[[1]]
output_dir <- args[[2]]
n_target <- if (length(args) == 3L) as.integer(args[[3]]) else 300L

if (is.na(n_target) || n_target < 1L) {
  stop("n must be a positive integer.", call. = FALSE)
}

d <- read.csv(
  input_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

required <- c(
  "model",
  "condition_a",
  "condition_b",
  "system_a",
  "system_b",
  "document_id",
  "line_id",
  "reference",
  "prediction_a",
  "prediction_b",
  "target_rate_a",
  "target_rate_b",
  "target_delta_b_minus_a"
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

d <- d[
  as.character(d$prediction_a) != as.character(d$prediction_b),
  ,
  drop = FALSE
]

if (nrow(d) == 0L) {
  stop("No changed outputs are available for annotation.", call. = FALSE)
}

set.seed(2027L)

# Balance the pilot across model and condition-pair strata as far as possible.
d$.stratum <- interaction(
  d$model,
  d$condition_a,
  d$condition_b,
  drop = TRUE,
  lex.order = TRUE
)

split_rows <- split(seq_len(nrow(d)), d$.stratum)
per_stratum <- max(1L, floor(n_target / length(split_rows)))

selected <- unlist(
  lapply(split_rows, function(idx) {
    sample(idx, min(length(idx), per_stratum))
  }),
  use.names = FALSE
)
selected <- unique(selected)

if (length(selected) < min(n_target, nrow(d))) {
  remaining <- setdiff(seq_len(nrow(d)), selected)
  selected <- c(
    selected,
    sample(
      remaining,
      min(length(remaining), n_target - length(selected))
    )
  )
}

if (length(selected) > n_target) {
  selected <- sample(selected, n_target)
}

sampled <- d[selected, , drop = FALSE]
sampled <- sampled[sample(seq_len(nrow(sampled))), , drop = FALSE]
rownames(sampled) <- NULL

swap <- stats::runif(nrow(sampled)) < 0.5

output_A <- ifelse(
  swap,
  sampled$prediction_b,
  sampled$prediction_a
)
output_B <- ifelse(
  swap,
  sampled$prediction_a,
  sampled$prediction_b
)

condition_A <- ifelse(
  swap,
  sampled$condition_b,
  sampled$condition_a
)
condition_B <- ifelse(
  swap,
  sampled$condition_a,
  sampled$condition_b
)

system_A <- ifelse(
  swap,
  sampled$system_b,
  sampled$system_a
)
system_B <- ifelse(
  swap,
  sampled$system_a,
  sampled$system_b
)

annotation_id <- sprintf(
  "policy_%06d",
  seq_len(nrow(sampled))
)

metadata_candidates <- c(
  "task",
  "language",
  "script_type",
  "century",
  "page_id",
  "image_path",
  "source_xml",
  "hpos",
  "vpos",
  "width",
  "height",
  "polygon"
)

metadata <- intersect(metadata_candidates, names(sampled))

items <- cbind(
  data.frame(
    annotation_id = annotation_id,
    document_id = sampled$document_id,
    line_id = sampled$line_id,
    reference = sampled$reference,
    output_A = output_A,
    output_B = output_B,
    preferred_output = NA_character_,
    reason_label = NA_character_,
    annotator = NA_character_,
    confidence = NA_integer_,
    notes = NA_character_,
    stringsAsFactors = FALSE
  ),
  sampled[, metadata, drop = FALSE]
)

key <- data.frame(
  annotation_id = annotation_id,
  model = sampled$model,
  condition_A = condition_A,
  condition_B = condition_B,
  system_A = system_A,
  system_B = system_B,
  target_rate_A = ifelse(
    swap,
    sampled$target_rate_b,
    sampled$target_rate_a
  ),
  target_rate_B = ifelse(
    swap,
    sampled$target_rate_a,
    sampled$target_rate_b
  ),
  target_delta_B_minus_A = ifelse(
    swap,
    -sampled$target_delta_b_minus_a,
    sampled$target_delta_b_minus_a
  ),
  stringsAsFactors = FALSE
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  items,
  file.path(output_dir, "policy_preference_items_blinded.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

write.csv(
  key,
  file.path(output_dir, "policy_preference_key_private.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

manifest <- data.frame(
  source_file = normalizePath(input_path, mustWork = FALSE),
  n_available_changed_outputs = nrow(d),
  n_annotation_items = nrow(items),
  n_models = length(unique(sampled$model)),
  seed = 2027L,
  stringsAsFactors = FALSE
)

write.csv(
  manifest,
  file.path(output_dir, "policy_preference_manifest.csv"),
  row.names = FALSE
)

message(
  "Blinded policy-preference batch written to: ",
  normalizePath(output_dir, mustWork = FALSE)
)
