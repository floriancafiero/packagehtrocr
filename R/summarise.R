#' Summarise OCR/HTR evaluation results
#'
#' Computes micro- or macro-averaged error rates from the output of
#' [evaluate_recognition()].
#'
#' Micro averaging pools edit counts before dividing. Macro averaging first
#' computes a pooled error rate within each higher-level unit (for example a
#' document or manuscript) and then gives each unit equal weight.
#'
#' @param x Evaluation data frame returned by [evaluate_recognition()].
#' @param by Character vector of grouping columns, for example "system" or
#'   c("system", "language"). Metric is always kept separate automatically.
#' @param averaging One of "micro" or "macro".
#' @param unit For macro averaging, optional single column name identifying the
#'   higher-level unit that should receive equal weight (for example
#'   "document_id"). If NULL, each input row is treated as one unit.
#'
#' @return A data frame of grouped error-rate summaries.
#' @export
summarise_recognition <- function(
  x,
  by = NULL,
  averaging = c("micro", "macro"),
  unit = NULL
) {
  averaging <- match.arg(averaging)

  required <- c(
    "metric", "rate", "n_reference", "n_hypothesis",
    "substitutions", "deletions", "insertions", "distance"
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
    if (!is.character(by)) stop("`by` must be a character vector.", call. = FALSE)
    missing_by <- setdiff(by, names(x))
    if (length(missing_by) > 0L) {
      stop(sprintf("Unknown grouping columns: %s.", paste(missing_by, collapse = ", ")), call. = FALSE)
    }
  }

  if (!is.null(unit)) {
    if (!is.character(unit) || length(unit) != 1L) {
      stop("`unit` must be NULL or one column name.", call. = FALSE)
    }
    if (!unit %in% names(x)) {
      stop(sprintf("Unknown unit column: %s.", unit), call. = FALSE)
    }
  }

  group_cols <- unique(c(by, "metric"))

  if (nrow(x) == 0L) {
    out <- x[0, group_cols, drop = FALSE]
    out$averaging <- character()
    out$rate <- numeric()
    out$n_rows <- integer()
    out$n_units <- integer()
    out$n_reference <- numeric()
    out$n_hypothesis <- numeric()
    out$substitutions <- numeric()
    out$deletions <- numeric()
    out$insertions <- numeric()
    out$distance <- numeric()
    attr(out, "ocrinfer_policy") <- attr(x, "ocrinfer_policy")
    return(out)
  }

  group_factor <- do.call(
    interaction,
    c(x[group_cols], list(drop = TRUE, lex.order = TRUE))
  )
  grouped_rows <- split(seq_len(nrow(x)), group_factor)

  summarise_one <- function(idx) {
    d <- x[idx, , drop = FALSE]

    total_ref <- sum(d$n_reference)
    total_hyp <- sum(d$n_hypothesis)
    total_sub <- sum(d$substitutions)
    total_del <- sum(d$deletions)
    total_ins <- sum(d$insertions)
    total_dist <- sum(d$distance)

    if (averaging == "micro") {
      rate <- if (total_ref == 0) total_ins else total_dist / total_ref
      n_units <- if (is.null(unit)) nrow(d) else length(unique(d[[unit]]))
    } else {
      if (is.null(unit)) {
        unit_rates <- d$rate
        n_units <- nrow(d)
      } else {
        unit_factor <- factor(d[[unit]], exclude = NULL)
        unit_rows <- split(seq_len(nrow(d)), unit_factor)

        unit_rates <- vapply(unit_rows, function(j) {
          ref <- sum(d$n_reference[j])
          dist <- sum(d$distance[j])
          ins <- sum(d$insertions[j])
          if (ref == 0) ins else dist / ref
        }, numeric(1))

        n_units <- length(unit_rates)
      }

      rate <- mean(unit_rates)
    }

    group_values <- d[1, group_cols, drop = FALSE]

    cbind(
      group_values,
      data.frame(
        averaging = averaging,
        rate = as.numeric(rate),
        n_rows = nrow(d),
        n_units = n_units,
        n_reference = total_ref,
        n_hypothesis = total_hyp,
        substitutions = total_sub,
        deletions = total_del,
        insertions = total_ins,
        distance = total_dist,
        stringsAsFactors = FALSE
      )
    )
  }

  out <- do.call(rbind, lapply(grouped_rows, summarise_one))
  rownames(out) <- NULL
  attr(out, "ocrinfer_policy") <- attr(x, "ocrinfer_policy")
  out
}
