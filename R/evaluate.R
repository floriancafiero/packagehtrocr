#' Evaluate OCR/HTR output row by row
#'
#' @param data A data frame.
#' @param truth Unquoted column name or string identifying ground truth.
#' @param prediction Unquoted column name or string identifying recognition output.
#' @param id Optional unit identifier.
#' @param system Optional system identifier.
#' @param metrics Any of "cer" and "wer".
#' @param char_unit "grapheme" or "codepoint".
#' @param unicode,case,whitespace,punctuation Normalization settings.
#' @return Long-form data frame of rates and edit counts.
#' @export
evaluate_recognition <- function(
  data,
  truth,
  prediction,
  id = NULL,
  system = NULL,
  metrics = c("cer", "wer"),
  char_unit = c("grapheme", "codepoint"),
  unicode = "NFC",
  case = "preserve",
  whitespace = "preserve",
  punctuation = "preserve"
) {
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)

  truth_name <- .resolve_column(substitute(truth), data, "truth")
  pred_name <- .resolve_column(substitute(prediction), data, "prediction")
  id_name <- .resolve_column(if (missing(id)) NULL else substitute(id), data, "id")
  system_name <- .resolve_column(if (missing(system)) NULL else substitute(system), data, "system")

  metrics <- unique(match.arg(metrics, c("cer", "wer"), several.ok = TRUE))
  char_unit <- match.arg(char_unit)

  if (nrow(data) == 0L) {
    return(data.frame(
      input_row = integer(), metric = character(), rate = numeric(),
      n_reference = integer(), n_hypothesis = integer(),
      substitutions = integer(), deletions = integer(),
      insertions = integer(), distance = integer()
    ))
  }

  base_cols <- c(if (!is.null(id_name)) id_name, if (!is.null(system_name)) system_name)
  out <- vector("list", nrow(data) * length(metrics))
  k <- 1L

  for (i in seq_len(nrow(data))) {
    ref <- data[[truth_name]][[i]]
    hyp <- data[[pred_name]][[i]]

    if (is.na(ref) || is.na(hyp)) {
      stop(sprintf("Missing reference or prediction at input row %d.", i), call. = FALSE)
    }

    for (metric in metrics) {
      unit <- if (metric == "cer") char_unit else "word"
      metric_ws <- if (metric == "wer" && whitespace == "preserve") "collapse" else whitespace

      counts <- edit_counts(
        ref, hyp, unit,
        unicode, case, metric_ws, punctuation
      )

      rate <- if (counts$n_reference == 0L) {
        if (counts$n_hypothesis == 0L) 0 else counts$insertions
      } else {
        counts$distance / counts$n_reference
      }

      row <- data.frame(
        input_row = i,
        metric = metric,
        rate = as.numeric(rate),
        n_reference = counts$n_reference,
        n_hypothesis = counts$n_hypothesis,
        substitutions = counts$substitutions,
        deletions = counts$deletions,
        insertions = counts$insertions,
        distance = counts$distance,
        stringsAsFactors = FALSE
      )

      if (length(base_cols) > 0L) {
        row <- cbind(data[i, base_cols, drop = FALSE], row)
      }

      out[[k]] <- row
      k <- k + 1L
    }
  }

  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result
}
