#' Source-aware visual transcription fidelity codebook
#'
#' Returns the proposed annotation categories for distinguishing perceptual
#' recognition errors from generative interventions in OCR/HTR output.
#'
#' @return A data frame with label, definition, and annotation guidance.
#' @export
fidelity_codebook <- function() {
  data.frame(
    label = c(
      "visual_misrecognition",
      "content_omission",
      "hallucinated_addition",
      "repetition",
      "orthographic_normalization",
      "linguistic_correction",
      "abbreviation_change",
      "unsupported_completion",
      "other",
      "ambiguous"
    ),
    definition = c(
      "Visible source content is transcribed as different characters or words without a plausible normalization/correction interpretation.",
      "Visible source content is missing from the prediction.",
      "Prediction contains content that is not supported by visible source evidence.",
      "Prediction duplicates visible or previously generated content beyond the source.",
      "Prediction replaces a visible historical, non-standard, or variant written form with a normalized orthographic form.",
      "Prediction changes a visible source form toward a linguistically more probable or grammatically corrected form.",
      "Prediction expands, contracts, or otherwise changes the representation of a visible abbreviation relative to the reference convention.",
      "Prediction supplies plausible content where the visual evidence is insufficient to support that content confidently.",
      "Error is source-aware but does not fit the current categories.",
      "The image/reference evidence is insufficient to assign a reliable category."
    ),
    requires_image = c(
      TRUE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, TRUE, TRUE
    ),
    stringsAsFactors = FALSE
  )
}

#' Prepare a blinded fidelity-annotation batch
#'
#' Extracts error spans, optionally samples them across user-specified strata,
#' randomizes their order, and separates model identity from the annotation
#' sheet.
#'
#' @param x Evaluation output from [evaluate_recognition()] with preserved text.
#' @param metric Either "cer" or "wer".
#' @param system_col Column containing model/system identity.
#' @param id_col Column identifying the source line or recognition unit.
#' @param keep Additional metadata columns to include in annotation items.
#' @param strata Optional columns used to balance a sample, for example
#'   `c("system", "language")`.
#' @param n Optional maximum number of error spans to sample. If NULL, keep all.
#' @param context Number of alignment tokens shown before and after each span.
#' @param seed Random seed for reproducible sampling and item ordering.
#' @param blind If TRUE, omit `system_col` from annotation items and return it
#'   only in the separate key.
#'
#' @return A list with `items`, `key`, and `codebook`.
#' @export
prepare_fidelity_annotation <- function(
  x,
  metric = c("cer", "wer"),
  system_col = "system",
  id_col = "line_id",
  keep = NULL,
  strata = NULL,
  n = NULL,
  context = 5L,
  seed = 1L,
  blind = TRUE
) {
  metric <- match.arg(metric)

  required_meta <- unique(c(system_col, id_col, keep, strata))
  missing_meta <- setdiff(required_meta, names(x))
  if (length(missing_meta) > 0L) {
    stop(
      sprintf(
        "Unknown annotation metadata columns: %s.",
        paste(missing_meta, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1L || is.na(n) ||
        n < 1 || n != as.integer(n)) {
      stop("`n` must be NULL or a positive integer.", call. = FALSE)
    }
    n <- as.integer(n)
  }

  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
    stop("`seed` must be one non-missing number.", call. = FALSE)
  }

  if (!is.logical(blind) || length(blind) != 1L || is.na(blind)) {
    stop("`blind` must be TRUE or FALSE.", call. = FALSE)
  }

  spans <- extract_error_spans(
    x,
    metric = metric,
    by = required_meta,
    context = context
  )

  if (nrow(spans) == 0L) {
    return(list(
      items = spans,
      key = data.frame(),
      codebook = fidelity_codebook()
    ))
  }

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  set.seed(seed)

  candidate_rows <- seq_len(nrow(spans))

  if (!is.null(n) && n < length(candidate_rows)) {
    if (!is.null(strata) && length(strata) > 0L) {
      stratum <- do.call(
        interaction,
        c(spans[strata], list(drop = TRUE, lex.order = TRUE))
      )
      split_rows <- split(candidate_rows, stratum)
      per_stratum <- max(1L, floor(n / length(split_rows)))

      selected <- unlist(
        lapply(split_rows, function(idx) {
          sample(idx, min(length(idx), per_stratum), replace = FALSE)
        }),
        use.names = FALSE
      )

      selected <- unique(selected)

      if (length(selected) < n) {
        remaining <- setdiff(candidate_rows, selected)
        if (length(remaining) > 0L) {
          selected <- c(
            selected,
            sample(
              remaining,
              min(length(remaining), n - length(selected)),
              replace = FALSE
            )
          )
        }
      }

      if (length(selected) > n) {
        selected <- sample(selected, n, replace = FALSE)
      }

      candidate_rows <- selected
    } else {
      candidate_rows <- sample(candidate_rows, n, replace = FALSE)
    }
  }

  candidate_rows <- sample(candidate_rows, length(candidate_rows), replace = FALSE)
  sampled <- spans[candidate_rows, , drop = FALSE]
  rownames(sampled) <- NULL

  annotation_id <- sprintf("ann_%06d", seq_len(nrow(sampled)))

  key_cols <- unique(c(system_col, id_col, keep, strata))
  key <- cbind(
    data.frame(
      annotation_id = annotation_id,
      source_input_row = sampled$input_row,
      source_span_id = sampled$span_id,
      stringsAsFactors = FALSE
    ),
    sampled[, key_cols, drop = FALSE]
  )

  item_drop <- if (isTRUE(blind)) system_col else character()
  item_cols <- setdiff(names(sampled), item_drop)

  items <- cbind(
    data.frame(
      annotation_id = annotation_id,
      stringsAsFactors = FALSE
    ),
    sampled[, item_cols, drop = FALSE]
  )

  items$primary_label <- NA_character_
  items$secondary_label <- NA_character_
  items$annotator <- NA_character_
  items$confidence <- NA_integer_
  items$notes <- NA_character_

  attr(items, "ocrinfer_fidelity_codebook") <- fidelity_codebook()

  list(
    items = items,
    key = key,
    codebook = fidelity_codebook()
  )
}

#' Summarise source-aware fidelity annotations
#'
#' @param annotations Completed annotation data with `annotation_id` and a
#'   label column.
#' @param key Optional blinding key returned by
#'   [prepare_fidelity_annotation()]. When supplied, its metadata are joined
#'   before summarisation.
#' @param by Character vector of grouping columns, commonly `"system"`.
#' @param label_col Column containing the primary fidelity label.
#' @param include_unlabelled Logical. If FALSE, missing/blank labels are dropped.
#'
#' @return A data frame with counts and within-group proportions by label.
#' @export
fidelity_profile <- function(
  annotations,
  key = NULL,
  by = "system",
  label_col = "primary_label",
  include_unlabelled = FALSE
) {
  if (!is.data.frame(annotations)) {
    stop("`annotations` must be a data frame.", call. = FALSE)
  }

  required <- c("annotation_id", label_col)
  missing_required <- setdiff(required, names(annotations))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing annotation columns: %s.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  d <- annotations

  if (!is.null(key)) {
    if (!is.data.frame(key) || !"annotation_id" %in% names(key)) {
      stop("`key` must be NULL or a data frame containing annotation_id.", call. = FALSE)
    }

    if (anyDuplicated(key$annotation_id)) {
      stop("`key$annotation_id` must be unique.", call. = FALSE)
    }

    key_extra <- setdiff(names(key), names(d))
    d <- merge(
      d,
      key[, c("annotation_id", key_extra), drop = FALSE],
      by = "annotation_id",
      all.x = TRUE,
      sort = FALSE
    )
  }

  missing_by <- setdiff(by, names(d))
  if (length(missing_by) > 0L) {
    stop(
      sprintf(
        "Unknown profile grouping columns: %s.",
        paste(missing_by, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  labels <- as.character(d[[label_col]])
  unlabelled <- is.na(labels) | !nzchar(labels)

  if (isTRUE(include_unlabelled)) {
    labels[unlabelled] <- "unlabelled"
  } else {
    d <- d[!unlabelled, , drop = FALSE]
    labels <- labels[!unlabelled]
  }

  if (nrow(d) == 0L) {
    out <- d[0, by, drop = FALSE]
    out$label <- character()
    out$n <- integer()
    out$proportion <- numeric()
    return(out)
  }

  allowed <- fidelity_codebook()$label
  invalid <- setdiff(unique(labels), c(allowed, "unlabelled"))
  if (length(invalid) > 0L) {
    stop(
      sprintf(
        "Unknown fidelity labels: %s.",
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  d$.fidelity_label <- labels
  group_cols <- c(by, ".fidelity_label")
  d$.one <- 1L

  counts <- stats::aggregate(
    d$.one,
    by = d[group_cols],
    FUN = sum
  )
  names(counts)[names(counts) == "x"] <- "n"
  names(counts)[names(counts) == ".fidelity_label"] <- "label"

  if (length(by) == 0L) {
    counts$proportion <- counts$n / sum(counts$n)
  } else {
    denom_factor <- do.call(
      interaction,
      c(counts[by], list(drop = TRUE, lex.order = TRUE))
    )
    denominators <- ave(counts$n, denom_factor, FUN = sum)
    counts$proportion <- counts$n / denominators
  }

  counts <- counts[order(-counts$proportion, -counts$n), , drop = FALSE]
  rownames(counts) <- NULL
  counts
}
