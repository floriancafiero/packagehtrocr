#' Align reference and recognition output
#'
#' @param reference Ground-truth string.
#' @param hypothesis Recognized/predicted string.
#' @param unit Evaluation unit: "grapheme", "codepoint", or "word".
#' @param unicode,case,whitespace,punctuation Normalization settings.
#' @return A data frame with aligned tokens and edit operations.
#' @export
align_text <- function(
  reference,
  hypothesis,
  unit = c("grapheme", "codepoint", "word"),
  unicode = "NFC",
  case = "preserve",
  whitespace = "preserve",
  punctuation = "preserve"
) {
  .validate_pair(reference, hypothesis)
  unit <- match.arg(unit)

  reference <- normalize_text(reference, unicode, case, whitespace, punctuation)
  hypothesis <- normalize_text(hypothesis, unicode, case, whitespace, punctuation)

  ref <- .tokenize_text(reference, unit)
  hyp <- .tokenize_text(hypothesis, unit)
  n <- length(ref)
  m <- length(hyp)

  d <- matrix(0L, nrow = n + 1L, ncol = m + 1L)
  if (n > 0L) d[, 1L] <- 0:n
  if (m > 0L) d[1L, ] <- 0:m

  if (n > 0L && m > 0L) {
    for (i in seq_len(n)) {
      for (j in seq_len(m)) {
        cost <- if (identical(ref[[i]], hyp[[j]])) 0L else 1L
        d[i + 1L, j + 1L] <- min(
          d[i, j] + cost,
          d[i, j + 1L] + 1L,
          d[i + 1L, j] + 1L
        )
      }
    }
  }

  i <- n
  j <- m
  rows <- list()

  while (i > 0L || j > 0L) {
    if (i > 0L && j > 0L) {
      cost <- if (identical(ref[[i]], hyp[[j]])) 0L else 1L
      if (d[i + 1L, j + 1L] == d[i, j] + cost) {
        rows[[length(rows) + 1L]] <- data.frame(
          reference = ref[[i]],
          hypothesis = hyp[[j]],
          operation = if (cost == 0L) "equal" else "substitution",
          stringsAsFactors = FALSE
        )
        i <- i - 1L
        j <- j - 1L
        next
      }
    }

    if (i > 0L && d[i + 1L, j + 1L] == d[i, j + 1L] + 1L) {
      rows[[length(rows) + 1L]] <- data.frame(
        reference = ref[[i]],
        hypothesis = NA_character_,
        operation = "deletion",
        stringsAsFactors = FALSE
      )
      i <- i - 1L
      next
    }

    rows[[length(rows) + 1L]] <- data.frame(
      reference = NA_character_,
      hypothesis = hyp[[j]],
      operation = "insertion",
      stringsAsFactors = FALSE
    )
    j <- j - 1L
  }

  if (length(rows) == 0L) {
    return(data.frame(
      reference = character(),
      hypothesis = character(),
      operation = character(),
      stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, rev(rows))
  rownames(out) <- NULL
  out
}

#' Count recognition edit operations
#' @inheritParams align_text
#' @return One-row data frame of edit counts and lengths.
#' @export
edit_counts <- function(
  reference,
  hypothesis,
  unit = c("grapheme", "codepoint", "word"),
  unicode = "NFC",
  case = "preserve",
  whitespace = "preserve",
  punctuation = "preserve"
) {
  .validate_pair(reference, hypothesis)
  unit <- match.arg(unit)

  ref_norm <- normalize_text(reference, unicode, case, whitespace, punctuation)
  hyp_norm <- normalize_text(hypothesis, unicode, case, whitespace, punctuation)

  ref_tokens <- .tokenize_text(ref_norm, unit)
  hyp_tokens <- .tokenize_text(hyp_norm, unit)

  a <- align_text(reference, hypothesis, unit, unicode, case, whitespace, punctuation)
  tab <- table(factor(
    a$operation,
    levels = c("equal", "substitution", "deletion", "insertion")
  ))

  data.frame(
    n_reference = length(ref_tokens),
    n_hypothesis = length(hyp_tokens),
    equal = unname(tab[["equal"]]),
    substitutions = unname(tab[["substitution"]]),
    deletions = unname(tab[["deletion"]]),
    insertions = unname(tab[["insertion"]]),
    distance = unname(tab[["substitution"]] + tab[["deletion"]] + tab[["insertion"]]),
    stringsAsFactors = FALSE
  )
}
