#!/usr/bin/env Rscript

# Analyze completed blinded policy-preference annotations.
#
# Usage:
#   Rscript benchmark/analyze_policy_preferences.R \
#     completed_items.csv policy_preference_key_private.csv output_dir

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3L) {
  stop(
    paste(
      "Usage: Rscript benchmark/analyze_policy_preferences.R",
      "<completed_items.csv> <private_key.csv> <output_dir>"
    ),
    call. = FALSE
  )
}

items_path <- args[[1]]
key_path <- args[[2]]
output_dir <- args[[3]]

items <- read.csv(
  items_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

key <- read.csv(
  key_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

required_items <- c(
  "annotation_id",
  "preferred_output",
  "annotator",
  "confidence"
)

required_key <- c(
  "annotation_id",
  "model",
  "condition_A",
  "condition_B",
  "target_rate_A",
  "target_rate_B",
  "target_delta_B_minus_A"
)

missing_items <- setdiff(required_items, names(items))
missing_key <- setdiff(required_key, names(key))

if (length(missing_items) > 0L) {
  stop(
    sprintf(
      "Items missing columns: %s.",
      paste(missing_items, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (length(missing_key) > 0L) {
  stop(
    sprintf(
      "Key missing columns: %s.",
      paste(missing_key, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (anyDuplicated(key$annotation_id)) {
  stop("Private key annotation_id values must be unique.", call. = FALSE)
}

valid_preferences <- c("A", "B", "tie", "ambiguous")

labelled <- !is.na(items$preferred_output) &
  nzchar(items$preferred_output)

invalid <- setdiff(
  unique(items$preferred_output[labelled]),
  valid_preferences
)

if (length(invalid) > 0L) {
  stop(
    sprintf(
      "Unknown preferred_output labels: %s.",
      paste(invalid, collapse = ", ")
    ),
    call. = FALSE
  )
}

items <- items[labelled, , drop = FALSE]

d <- merge(
  items,
  key,
  by = "annotation_id",
  all.x = TRUE,
  sort = FALSE
)

if (any(is.na(d$model))) {
  stop("Some annotated IDs are absent from the private key.", call. = FALSE)
}

d$preferred_condition <- ifelse(
  d$preferred_output == "A",
  d$condition_A,
  ifelse(
    d$preferred_output == "B",
    d$condition_B,
    d$preferred_output
  )
)

tolerance <- sqrt(.Machine$double.eps)

d$cer_preferred_output <- ifelse(
  d$target_delta_B_minus_A < -tolerance,
  "B",
  ifelse(
    d$target_delta_B_minus_A > tolerance,
    "A",
    "tie"
  )
)

d$human_cer_relation <- ifelse(
  d$preferred_output == "ambiguous",
  "ambiguous",
  ifelse(
    d$preferred_output == d$cer_preferred_output,
    "agree",
    ifelse(
      d$preferred_output == "tie" |
        d$cer_preferred_output == "tie",
      "one_tie",
      "disagree"
    )
  )
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

write.csv(
  d,
  file.path(output_dir, "policy_preferences_unblinded.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

# Summary by model and condition pair.
d$condition_pair <- paste(
  pmin(d$condition_A, d$condition_B),
  pmax(d$condition_A, d$condition_B),
  sep = " vs "
)

groups <- interaction(
  d$model,
  d$condition_pair,
  drop = TRUE,
  lex.order = TRUE
)

split_rows <- split(seq_len(nrow(d)), groups)

summaries <- lapply(split_rows, function(idx) {
  z <- d[idx, , drop = FALSE]

  conditions <- sort(unique(c(z$condition_A, z$condition_B)))
  if (length(conditions) != 2L) {
    stop("Each summary group must contain exactly two conditions.", call. = FALSE)
  }

  decisive <- z$preferred_condition %in% conditions
  n_decisive <- sum(decisive)

  preferred_1 <- sum(z$preferred_condition == conditions[[1]])
  preferred_2 <- sum(z$preferred_condition == conditions[[2]])

  ci_1 <- if (n_decisive > 0L) {
    stats::binom.test(preferred_1, n_decisive)$conf.int
  } else {
    c(NA_real_, NA_real_)
  }

  human_decisive <- z$preferred_output %in% c("A", "B")
  cer_decisive <- z$cer_preferred_output %in% c("A", "B")
  both_decisive <- human_decisive & cer_decisive

  agreement_rate <- if (sum(both_decisive) > 0L) {
    mean(
      z$preferred_output[both_decisive] ==
        z$cer_preferred_output[both_decisive]
    )
  } else {
    NA_real_
  }

  data.frame(
    model = z$model[[1]],
    condition_1 = conditions[[1]],
    condition_2 = conditions[[2]],
    n_labelled = nrow(z),
    n_decisive = n_decisive,
    n_tie = sum(z$preferred_output == "tie"),
    n_ambiguous = sum(z$preferred_output == "ambiguous"),
    condition_1_preferred = preferred_1,
    condition_2_preferred = preferred_2,
    condition_1_preference_rate = if (n_decisive > 0L) {
      preferred_1 / n_decisive
    } else {
      NA_real_
    },
    condition_1_conf_low = ci_1[[1]],
    condition_1_conf_high = ci_1[[2]],
    human_vs_cer_agreement = agreement_rate,
    n_human_cer_disagreements = sum(
      z$human_cer_relation == "disagree"
    ),
    stringsAsFactors = FALSE
  )
})

summary_table <- do.call(rbind, summaries)
rownames(summary_table) <- NULL

write.csv(
  summary_table,
  file.path(output_dir, "policy_preference_summary.csv"),
  row.names = FALSE
)

relation <- as.data.frame(
  table(
    model = d$model,
    relation = d$human_cer_relation
  ),
  stringsAsFactors = FALSE
)

write.csv(
  relation,
  file.path(output_dir, "human_vs_cer_relation.csv"),
  row.names = FALSE
)

# Export the strongest paper candidates: decisive human/CER disagreements.
disagreements <- d[
  d$human_cer_relation == "disagree",
  ,
  drop = FALSE
]

write.csv(
  disagreements,
  file.path(output_dir, "human_cer_disagreement_cases.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

message(
  "Policy-preference analysis written to: ",
  normalizePath(output_dir, mustWork = FALSE)
)
