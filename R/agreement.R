#' Agreement for two fidelity annotators
#'
#' Computes raw agreement and Cohen's kappa for primary source-aware fidelity
#' labels assigned independently to the same annotation items.
#'
#' @param annotations Long-form annotation data.
#' @param id_col Column identifying annotation items.
#' @param annotator_col Column identifying annotators.
#' @param label_col Column containing the primary fidelity label.
#' @param drop_missing If TRUE, use only items labelled by both annotators.
#'
#' @return A one-row data frame with number of paired items, raw agreement,
#'   expected agreement, and Cohen's kappa.
#' @export
fidelity_agreement <- function(
  annotations,
  id_col = "annotation_id",
  annotator_col = "annotator",
  label_col = "primary_label",
  drop_missing = TRUE
) {
  if (!is.data.frame(annotations)) {
    stop("\`annotations\` must be a data frame.", call. = FALSE)
  }

  required <- c(id_col, annotator_col, label_col)
  missing_required <- setdiff(required, names(annotations))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing agreement columns: %s.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  d <- annotations[, required, drop = FALSE]
  names(d) <- c("item", "annotator", "label")

  d$item <- as.character(d$item)
  d$annotator <- as.character(d$annotator)
  d$label <- as.character(d$label)

  annotators <- unique(d$annotator[!is.na(d$annotator) & nzchar(d$annotator)])
  if (length(annotators) != 2L) {
    stop(
      sprintf(
        "Exactly two annotators are required; found %d.",
        length(annotators)
      ),
      call. = FALSE
    )
  }

  duplicated_pairs <- duplicated(d[c("item", "annotator")])
  if (any(duplicated_pairs)) {
    stop(
      "Each annotation item must occur at most once per annotator.",
      call. = FALSE
    )
  }

  a <- d[d$annotator == annotators[[1]], c("item", "label"), drop = FALSE]
  b <- d[d$annotator == annotators[[2]], c("item", "label"), drop = FALSE]
  names(a)[2] <- "label_a"
  names(b)[2] <- "label_b"

  paired <- merge(a, b, by = "item", all = !isTRUE(drop_missing), sort = FALSE)

  if (isTRUE(drop_missing)) {
    paired <- paired[
      !is.na(paired$label_a) & nzchar(paired$label_a) &
        !is.na(paired$label_b) & nzchar(paired$label_b),
      ,
      drop = FALSE
    ]
  }

  if (nrow(paired) == 0L) {
    stop("No paired labelled items are available.", call. = FALSE)
  }

  allowed <- fidelity_codebook()$label
  observed_labels <- unique(c(paired$label_a, paired$label_b))
  observed_labels <- observed_labels[!is.na(observed_labels) & nzchar(observed_labels)]
  invalid <- setdiff(observed_labels, allowed)

  if (length(invalid) > 0L) {
    stop(
      sprintf(
        "Unknown fidelity labels: %s.",
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  levels_used <- union(unique(paired$label_a), unique(paired$label_b))
  levels_used <- levels_used[!is.na(levels_used) & nzchar(levels_used)]

  tab <- table(
    factor(paired$label_a, levels = levels_used),
    factor(paired$label_b, levels = levels_used)
  )

  n <- sum(tab)
  observed <- sum(diag(tab)) / n
  p_a <- rowSums(tab) / n
  p_b <- colSums(tab) / n
  expected <- sum(p_a * p_b)

  kappa <- if (isTRUE(all.equal(expected, 1))) {
    if (isTRUE(all.equal(observed, 1))) 1 else NA_real_
  } else {
    (observed - expected) / (1 - expected)
  }

  data.frame(
    annotator_a = annotators[[1]],
    annotator_b = annotators[[2]],
    n_items = n,
    raw_agreement = observed,
    expected_agreement = expected,
    cohen_kappa = kappa,
    stringsAsFactors = FALSE
  )
}
