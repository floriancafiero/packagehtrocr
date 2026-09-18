#' Extract contiguous error spans from OCR/HTR evaluation results
#'
#' Converts token-level alignments into contiguous error spans suitable for
#' qualitative inspection or source-aware annotation. Consecutive non-matching
#' alignment operations are grouped into one span.
#'
#' @param x Evaluation output from [evaluate_recognition()] with preserved text.
#' @param metric Either "cer" or "wer".
#' @param by Optional character vector of metadata columns to preserve, for
#'   example `c("system", "line_id", "document_id")`.
#' @param context Number of aligned tokens to retain before and after each error
#'   span as context.
#'
#' @return A data frame with one row per contiguous error span.
#' @export
extract_error_spans <- function(
  x,
  metric = c("cer", "wer"),
  by = NULL,
  context = 5L
) {
  metric <- match.arg(metric)

  required <- c("metric", "reference", "prediction", "input_row")
  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing required columns: %s. Re-run evaluate_recognition() with keep_text = TRUE.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.null(by)) {
    if (!is.character(by)) {
      stop("`by` must be a character vector.", call. = FALSE)
    }
    missing_by <- setdiff(by, names(x))
    if (length(missing_by) > 0L) {
      stop(
        sprintf(
          "Unknown metadata columns: %s.",
          paste(missing_by, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }

  if (!is.numeric(context) || length(context) != 1L ||
      is.na(context) || context < 0 || context != as.integer(context)) {
    stop("`context` must be a non-negative integer.", call. = FALSE)
  }
  context <- as.integer(context)

  d <- x[as.character(x$metric) == metric, , drop = FALSE]

  empty_result <- function() {
    meta <- if (length(by) > 0L) d[0, by, drop = FALSE] else data.frame()
    cbind(
      meta,
      data.frame(
        input_row = integer(),
        span_id = integer(),
        operation = character(),
        operations = character(),
        reference_span = character(),
        prediction_span = character(),
        reference_start = integer(),
        reference_end = integer(),
        prediction_start = integer(),
        prediction_end = integer(),
        substitutions = integer(),
        deletions = integer(),
        insertions = integer(),
        context_before = character(),
        context_after = character(),
        possible_repetition = logical(),
        reference = character(),
        prediction = character(),
        stringsAsFactors = FALSE
      )
    )
  }

  if (nrow(d) == 0L) return(empty_result())

  policy <- attr(x, "ocrinfer_policy")
  if (is.null(policy)) policy <- list()

  char_unit <- if (!is.null(policy$char_unit)) policy$char_unit else "grapheme"
  unicode <- if (!is.null(policy$unicode)) policy$unicode else "NFC"
  case <- if (!is.null(policy$case)) policy$case else "preserve"
  whitespace <- if (!is.null(policy$whitespace)) policy$whitespace else "preserve"
  punctuation <- if (!is.null(policy$punctuation)) policy$punctuation else "preserve"

  align_unit <- if (metric == "cer") char_unit else "word"
  align_whitespace <- if (metric == "wer" && whitespace == "preserve") {
    "collapse"
  } else {
    whitespace
  }

  collapse_tokens <- function(tokens) {
    tokens <- tokens[!is.na(tokens)]
    if (length(tokens) == 0L) return("")
    sep <- if (metric == "wer") " " else ""
    paste(tokens, collapse = sep)
  }

  is_repeat <- function(alignment, start, end) {
    ops <- alignment$operation[start:end]
    if (!all(ops == "insertion")) return(FALSE)

    inserted <- alignment$hypothesis[start:end]
    inserted <- inserted[!is.na(inserted)]
    k <- length(inserted)
    if (k == 0L) return(FALSE)

    before <- if (start > 1L) {
      alignment$hypothesis[seq_len(start - 1L)]
    } else {
      character()
    }
    before <- before[!is.na(before)]

    after <- if (end < nrow(alignment)) {
      alignment$hypothesis[(end + 1L):nrow(alignment)]
    } else {
      character()
    }
    after <- after[!is.na(after)]

    repeats_before <- length(before) >= k &&
      identical(tail(before, k), inserted)
    repeats_after <- length(after) >= k &&
      identical(head(after, k), inserted)

    repeats_before || repeats_after
  }

  all_spans <- list()
  out_i <- 1L

  for (i in seq_len(nrow(d))) {
    a <- align_text(
      d$reference[[i]],
      d$prediction[[i]],
      unit = align_unit,
      unicode = unicode,
      case = case,
      whitespace = align_whitespace,
      punctuation = punctuation
    )

    if (nrow(a) == 0L || all(a$operation == "equal")) next

    a$reference_position <- cumsum(!is.na(a$reference))
    a$prediction_position <- cumsum(!is.na(a$hypothesis))

    is_error <- a$operation != "equal"
    run <- cumsum(c(TRUE, diff(is_error) != 0L))
    error_runs <- unique(run[is_error])

    for (span_number in seq_along(error_runs)) {
      idx <- which(run == error_runs[[span_number]])
      start <- min(idx)
      end <- max(idx)

      ref_present <- !is.na(a$reference[idx])
      pred_present <- !is.na(a$hypothesis[idx])

      ref_positions <- a$reference_position[idx][ref_present]
      pred_positions <- a$prediction_position[idx][pred_present]

      ops <- a$operation[idx]
      op_unique <- unique(ops)
      operation <- if (length(op_unique) == 1L) op_unique else "mixed"

      before_idx <- if (start > 1L && context > 0L) {
        seq.int(max(1L, start - context), start - 1L)
      } else {
        integer()
      }

      after_idx <- if (end < nrow(a) && context > 0L) {
        seq.int(end + 1L, min(nrow(a), end + context))
      } else {
        integer()
      }

      before_tokens <- if (length(before_idx) > 0L) {
        ifelse(
          !is.na(a$reference[before_idx]),
          a$reference[before_idx],
          a$hypothesis[before_idx]
        )
      } else {
        character()
      }

      after_tokens <- if (length(after_idx) > 0L) {
        ifelse(
          !is.na(a$reference[after_idx]),
          a$reference[after_idx],
          a$hypothesis[after_idx]
        )
      } else {
        character()
      }

      row <- data.frame(
        input_row = d$input_row[[i]],
        span_id = span_number,
        operation = operation,
        operations = paste(ops, collapse = "+"),
        reference_span = collapse_tokens(a$reference[idx]),
        prediction_span = collapse_tokens(a$hypothesis[idx]),
        reference_start = if (length(ref_positions)) min(ref_positions) else NA_integer_,
        reference_end = if (length(ref_positions)) max(ref_positions) else NA_integer_,
        prediction_start = if (length(pred_positions)) min(pred_positions) else NA_integer_,
        prediction_end = if (length(pred_positions)) max(pred_positions) else NA_integer_,
        substitutions = sum(ops == "substitution"),
        deletions = sum(ops == "deletion"),
        insertions = sum(ops == "insertion"),
        context_before = collapse_tokens(before_tokens),
        context_after = collapse_tokens(after_tokens),
        possible_repetition = is_repeat(a, start, end),
        reference = as.character(d$reference[[i]]),
        prediction = as.character(d$prediction[[i]]),
        stringsAsFactors = FALSE
      )

      if (length(by) > 0L) {
        row <- cbind(d[i, by, drop = FALSE], row)
      }

      all_spans[[out_i]] <- row
      out_i <- out_i + 1L
    }
  }

  if (length(all_spans) == 0L) return(empty_result())

  out <- do.call(rbind, all_spans)
  rownames(out) <- NULL
  attr(out, "ocrinfer_policy") <- policy
  out
}
