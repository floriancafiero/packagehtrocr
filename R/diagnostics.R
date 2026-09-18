#' Build a token-level confusion table
#'
#' Reconstructs alignments from evaluation results and counts token-to-token
#' substitutions, deletions, and insertions under the same evaluation policy.
#'
#' @param x Evaluation output from [evaluate_recognition()] with preserved text.
#' @param metric Either "cer" or "wer".
#' @param by Optional character vector of metadata columns for stratified
#'   confusion tables (for example "system" or "script_type").
#' @param include_equal Logical. Include correctly matched tokens if TRUE.
#' @param epsilon Label used for the missing side of insertions/deletions.
#'
#' @return A data frame of aligned token pairs, operation type, and counts.
#' @export
confusion_table <- function(
  x,
  metric = c("cer", "wer"),
  by = NULL,
  include_equal = FALSE,
  epsilon = "<eps>"
) {
  metric <- match.arg(metric)

  required <- c("metric", "reference", "prediction")
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
        sprintf("Unknown grouping columns: %s.", paste(missing_by, collapse = ", ")),
        call. = FALSE
      )
    }
  }

  if (!is.logical(include_equal) || length(include_equal) != 1L || is.na(include_equal)) {
    stop("`include_equal` must be TRUE or FALSE.", call. = FALSE)
  }

  if (!is.character(epsilon) || length(epsilon) != 1L || is.na(epsilon)) {
    stop("`epsilon` must be one non-missing string.", call. = FALSE)
  }

  d <- x[as.character(x$metric) == metric, , drop = FALSE]
  if (nrow(d) == 0L) {
    out <- data.frame(
      reference_token = character(),
      prediction_token = character(),
      operation = character(),
      n = integer(),
      stringsAsFactors = FALSE
    )
    return(out)
  }

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

  rows <- lapply(seq_len(nrow(d)), function(i) {
    a <- align_text(
      d$reference[[i]],
      d$prediction[[i]],
      unit = align_unit,
      unicode = unicode,
      case = case,
      whitespace = align_whitespace,
      punctuation = punctuation
    )

    if (!isTRUE(include_equal)) {
      a <- a[a$operation != "equal", , drop = FALSE]
    }

    if (nrow(a) == 0L) return(NULL)

    a$reference_token <- ifelse(
      is.na(a$reference),
      epsilon,
      as.character(a$reference)
    )
    a$prediction_token <- ifelse(
      is.na(a$hypothesis),
      epsilon,
      as.character(a$hypothesis)
    )

    keep_cols <- c("reference_token", "prediction_token", "operation")
    a <- a[, keep_cols, drop = FALSE]

    if (length(by) > 0L) {
      meta <- d[rep(i, nrow(a)), by, drop = FALSE]
      a <- cbind(meta, a)
    }

    a
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    out <- data.frame(
      reference_token = character(),
      prediction_token = character(),
      operation = character(),
      n = integer(),
      stringsAsFactors = FALSE
    )
    if (length(by) > 0L) {
      out <- cbind(d[0, by, drop = FALSE], out)
    }
    return(out)
  }

  aligned <- do.call(rbind, rows)
  rownames(aligned) <- NULL

  group_cols <- c(by, "reference_token", "prediction_token", "operation")
  aligned$.one <- 1L

  out <- stats::aggregate(
    aligned$.one,
    by = aligned[group_cols],
    FUN = sum
  )
  names(out)[names(out) == "x"] <- "n"

  out <- out[order(-out$n), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' Summarise recognition error types
#'
#' Produces micro-aggregated substitution, deletion, insertion, and total error
#' rates, optionally stratified by system or metadata.
#'
#' @param x Evaluation output from [evaluate_recognition()].
#' @param by Optional character vector of grouping columns.
#'
#' @return A data frame with counts and error-type rates.
#' @export
error_profile <- function(x, by = NULL) {
  required <- c(
    "metric", "n_reference", "substitutions",
    "deletions", "insertions", "distance"
  )
  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing required evaluation columns: %s.",
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
        sprintf("Unknown grouping columns: %s.", paste(missing_by, collapse = ", ")),
        call. = FALSE
      )
    }
  }

  group_cols <- unique(c(by, "metric"))

  if (nrow(x) == 0L) {
    out <- x[0, group_cols, drop = FALSE]
    out$n_rows <- integer()
    out$n_reference <- numeric()
    out$substitutions <- numeric()
    out$deletions <- numeric()
    out$insertions <- numeric()
    out$distance <- numeric()
    out$substitution_rate <- numeric()
    out$deletion_rate <- numeric()
    out$insertion_rate <- numeric()
    out$error_rate <- numeric()
    return(out)
  }

  group_factor <- do.call(
    interaction,
    c(x[group_cols], list(drop = TRUE, lex.order = TRUE))
  )
  grouped_rows <- split(seq_len(nrow(x)), group_factor)

  rows <- lapply(grouped_rows, function(idx) {
    d <- x[idx, , drop = FALSE]
    ref <- sum(d$n_reference)
    sub <- sum(d$substitutions)
    del <- sum(d$deletions)
    ins <- sum(d$insertions)
    dist <- sum(d$distance)

    denominator_rate <- function(num) {
      if (ref == 0) NA_real_ else num / ref
    }

    cbind(
      d[1, group_cols, drop = FALSE],
      data.frame(
        n_rows = nrow(d),
        n_reference = ref,
        substitutions = sub,
        deletions = del,
        insertions = ins,
        distance = dist,
        substitution_rate = denominator_rate(sub),
        deletion_rate = denominator_rate(del),
        insertion_rate = denominator_rate(ins),
        error_rate = if (ref == 0) {
          if (ins == 0) 0 else ins
        } else {
          dist / ref
        },
        stringsAsFactors = FALSE
      )
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "ocrinfer_policy") <- attr(x, "ocrinfer_policy")
  out
}
