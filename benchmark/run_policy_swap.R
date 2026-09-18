#!/usr/bin/env Rscript

# Generic policy-swap analysis for CMMHWR26 or GT4HistOCR.
#
# Usage:
#   Rscript benchmark/run_policy_swap.R \
#     predictions.csv systems.csv output_dir
#
# predictions.csv must contain:
#   document_id, line_id, system, reference, prediction
#
# systems.csv must contain one row per system with:
#   system, model, model_family, prompt_policy, prompt_condition,
#   model_id, revision, prompt_file

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3L) {
  stop(
    paste(
      "Usage: Rscript benchmark/run_policy_swap.R",
      "<predictions.csv> <systems.csv> <output_dir>"
    ),
    call. = FALSE
  )
}

prediction_path <- args[[1]]
systems_path <- args[[2]]
output_dir <- args[[3]]

if (!requireNamespace("ocrinfer", quietly = TRUE)) {
  stop(
    "Install ocrinfer from the repository root with R CMD INSTALL .",
    call. = FALSE
  )
}

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

predictions <- read.csv(
  prediction_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

systems <- read.csv(
  systems_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

required_predictions <- c(
  "document_id",
  "line_id",
  "system",
  "reference",
  "prediction"
)

required_systems <- c(
  "system",
  "model",
  "model_family",
  "prompt_policy",
  "prompt_condition",
  "model_id",
  "revision",
  "prompt_file"
)

missing_predictions <- setdiff(
  required_predictions,
  names(predictions)
)
if (length(missing_predictions) > 0L) {
  stop(
    sprintf(
      "Predictions missing columns: %s.",
      paste(missing_predictions, collapse = ", ")
    ),
    call. = FALSE
  )
}

missing_systems <- setdiff(
  required_systems,
  names(systems)
)
if (length(missing_systems) > 0L) {
  stop(
    sprintf(
      "Systems manifest missing columns: %s.",
      paste(missing_systems, collapse = ", ")
    ),
    call. = FALSE
  )
}

if (anyDuplicated(systems$system)) {
  stop(
    "systems.csv must contain exactly one row per system.",
    call. = FALSE
  )
}

unknown_systems <- setdiff(
  unique(predictions$system),
  systems$system
)
if (length(unknown_systems) > 0L) {
  stop(
    sprintf(
      "Predictions contain systems absent from systems.csv: %s.",
      paste(unknown_systems, collapse = ", ")
    ),
    call. = FALSE
  )
}

unused_manifest <- setdiff(
  systems$system,
  unique(predictions$system)
)
if (length(unused_manifest) > 0L) {
  warning(
    sprintf(
      "Systems manifest contains unused systems: %s.",
      paste(unused_manifest, collapse = ", ")
    ),
    call. = FALSE
  )
}

# Keep prediction row order stable while attaching run provenance.
system_index <- match(
  predictions$system,
  systems$system
)

for (column in setdiff(required_systems, "system")) {
  predictions[[column]] <- systems[[column]][system_index]
}

if (anyDuplicated(predictions[c("line_id", "system")])) {
  stop(
    "Each line_id × system pair must occur exactly once.",
    call. = FALSE
  )
}

# Within a named model, all prompt conditions must refer to the same public
# model ID and frozen revision; otherwise the comparison is not a pure policy
# intervention.
promptable <- predictions[
  predictions$prompt_condition != "fixed",
  ,
  drop = FALSE
]

if (nrow(promptable) > 0L) {
  model_groups <- split(
    seq_len(nrow(promptable)),
    promptable$model
  )

  for (model_name in names(model_groups)) {
    idx <- model_groups[[model_name]]

    ids <- unique(promptable$model_id[idx])
    revisions <- unique(promptable$revision[idx])

    ids <- ids[!is.na(ids) & nzchar(ids)]
    revisions <- revisions[
      !is.na(revisions) & nzchar(revisions)
    ]

    if (length(ids) != 1L) {
      stop(
        sprintf(
          "Model %s maps to multiple model_id values.",
          model_name
        ),
        call. = FALSE
      )
    }

    if (length(revisions) != 1L) {
      stop(
        sprintf(
          "Model %s maps to multiple revisions.",
          model_name
        ),
        call. = FALSE
      )
    }
  }
}

metadata_candidates <- c(
  "benchmark",
  "subcorpus",
  "task",
  "language",
  "corpus_language",
  "script",
  "script_type",
  "century",
  "year",
  "page_id",
  "document_id",
  "image_path",
  "source_xml",
  "gt_path",
  "hpos",
  "vpos",
  "width",
  "height",
  "polygon",
  "model",
  "model_family",
  "prompt_policy",
  "prompt_condition",
  "model_id",
  "revision",
  "prompt_file"
)

keep <- intersect(
  metadata_candidates,
  names(predictions)
)
keep <- setdiff(
  keep,
  c("line_id", "system")
)

evaluated <- ocrinfer::evaluate_recognition(
  predictions,
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
  file.path(
    output_dir,
    "policy_evaluated_lines.csv"
  ),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)

micro <- ocrinfer::summarise_recognition(
  evaluated,
  by = c(
    "model",
    "model_family",
    "prompt_condition",
    "prompt_policy",
    "system"
  ),
  averaging = "micro"
)

macro <- ocrinfer::summarise_recognition(
  evaluated,
  by = c(
    "model",
    "model_family",
    "prompt_condition",
    "prompt_policy",
    "system"
  ),
  averaging = "macro",
  unit = "document_id"
)

write.csv(
  micro,
  file.path(
    output_dir,
    "policy_summary_micro.csv"
  ),
  row.names = FALSE
)

write.csv(
  macro,
  file.path(
    output_dir,
    "policy_summary_macro_document.csv"
  ),
  row.names = FALSE
)

policy_cer <- ocrinfer::policy_swap_summary(
  evaluated,
  model_col = "model",
  condition_col = "prompt_condition",
  system_col = "system",
  pair_id = "line_id",
  unit = "document_id",
  metric = "cer",
  n_boot = 5000L,
  conf_level = 0.95,
  seed = 2027L
)

policy_wer <- ocrinfer::policy_swap_summary(
  evaluated,
  model_col = "model",
  condition_col = "prompt_condition",
  system_col = "system",
  pair_id = "line_id",
  unit = "document_id",
  metric = "wer",
  n_boot = 5000L,
  conf_level = 0.95,
  seed = 2027L
)

policy_swap <- rbind(
  policy_cer,
  policy_wer
)

write.csv(
  policy_swap,
  file.path(
    output_dir,
    "policy_swap_summary.csv"
  ),
  row.names = FALSE
)

# Add run provenance to the policy-pair table.
if (nrow(policy_swap) > 0L) {
  system_meta <- systems[
    ,
    c(
      "system",
      "prompt_policy",
      "prompt_condition",
      "model_id",
      "revision",
      "prompt_file"
    ),
    drop = FALSE
  ]

  names(system_meta) <- paste0(
    names(system_meta),
    "_a"
  )
  system_meta$system <- system_meta$system_a

  enriched <- merge(
    policy_swap,
    system_meta,
    by.x = "system_a",
    by.y = "system",
    all.x = TRUE,
    sort = FALSE
  )

  system_meta_b <- systems[
    ,
    c(
      "system",
      "prompt_policy",
      "prompt_condition",
      "model_id",
      "revision",
      "prompt_file"
    ),
    drop = FALSE
  ]
  names(system_meta_b) <- paste0(
    names(system_meta_b),
    "_b"
  )
  system_meta_b$system <- system_meta_b$system_b

  enriched <- merge(
    enriched,
    system_meta_b,
    by.x = "system_b",
    by.y = "system",
    all.x = TRUE,
    sort = FALSE
  )

  write.csv(
    enriched,
    file.path(
      output_dir,
      "policy_swap_summary_with_provenance.csv"
    ),
    row.names = FALSE
  )
}

# Policy-sensitive errors remain source-aware. Export all changed predictions
# so a targeted human sample can be drawn after the first pilot.
cer_eval <- evaluated[
  evaluated$metric == "cer",
  ,
  drop = FALSE
]

if (nrow(policy_cer) > 0L) {
  changed_rows <- list()
  changed_i <- 1L

  for (i in seq_len(nrow(policy_cer))) {
    a_id <- policy_cer$system_a[[i]]
    b_id <- policy_cer$system_b[[i]]

    a <- cer_eval[
      cer_eval$system == a_id,
      ,
      drop = FALSE
    ]
    b <- cer_eval[
      cer_eval$system == b_id,
      ,
      drop = FALSE
    ]

    key_a <- paste(
      a$document_id,
      a$line_id,
      sep = "\u001f"
    )
    key_b <- paste(
      b$document_id,
      b$line_id,
      sep = "\u001f"
    )

    b <- b[
      match(key_a, key_b),
      ,
      drop = FALSE
    ]

    changed <- (
      as.character(a$prediction)
      != as.character(b$prediction)
    )

    if (!any(changed)) {
      next
    }

    changed_rows[[changed_i]] <- data.frame(
      model = policy_cer$model[[i]],
      condition_a = policy_cer$condition_a[[i]],
      condition_b = policy_cer$condition_b[[i]],
      system_a = a_id,
      system_b = b_id,
      document_id = a$document_id[changed],
      line_id = a$line_id[changed],
      reference = a$reference[changed],
      prediction_a = a$prediction[changed],
      prediction_b = b$prediction[changed],
      target_rate_a = a$rate[changed],
      target_rate_b = b$rate[changed],
      target_delta_b_minus_a = (
        b$rate[changed]
        - a$rate[changed]
      ),
      stringsAsFactors = FALSE
    )

    changed_i <- changed_i + 1L
  }

  if (length(changed_rows) > 0L) {
    changed_table <- do.call(
      rbind,
      changed_rows
    )
    rownames(changed_table) <- NULL

    write.csv(
      changed_table,
      file.path(
        output_dir,
        "policy_changed_outputs.csv"
      ),
      row.names = FALSE,
      fileEncoding = "UTF-8"
    )
  }
}

manifest <- data.frame(
  predictions_file = normalizePath(
    prediction_path,
    mustWork = FALSE
  ),
  systems_file = normalizePath(
    systems_path,
    mustWork = FALSE
  ),
  n_lines = length(
    unique(predictions$line_id)
  ),
  n_systems = length(
    unique(predictions$system)
  ),
  n_models = length(
    unique(predictions$model)
  ),
  n_policy_pairs = nrow(policy_cer),
  stringsAsFactors = FALSE
)

write.csv(
  manifest,
  file.path(
    output_dir,
    "policy_analysis_manifest.csv"
  ),
  row.names = FALSE
)

message(
  "Policy-swap analysis complete: ",
  normalizePath(
    output_dir,
    mustWork = FALSE
  )
)
