.error_rate <- function(reference, hypothesis, unit, unicode, case, whitespace, punctuation) {
  counts <- edit_counts(
    reference, hypothesis, unit,
    unicode, case, whitespace, punctuation
  )

  if (counts$n_reference == 0L) {
    if (counts$n_hypothesis == 0L) return(0)
    return(as.numeric(counts$insertions))
  }

  as.numeric(counts$distance / counts$n_reference)
}

#' Character error rate
#'
#' By default, a character is a Unicode grapheme cluster.
#' @param reference Ground-truth string.
#' @param hypothesis Recognized/predicted string.
#' @param unit "grapheme" or "codepoint".
#' @param unicode,case,whitespace,punctuation Normalization settings.
#' @return Numeric scalar. Lower is better.
#' @export
cer <- function(
  reference,
  hypothesis,
  unit = c("grapheme", "codepoint"),
  unicode = "NFC",
  case = "preserve",
  whitespace = "preserve",
  punctuation = "preserve"
) {
  unit <- match.arg(unit)
  .error_rate(reference, hypothesis, unit, unicode, case, whitespace, punctuation)
}

#' Word error rate
#'
#' Words are currently whitespace-separated tokens.
#' @inheritParams cer
#' @return Numeric scalar.
#' @export
wer <- function(
  reference,
  hypothesis,
  unicode = "NFC",
  case = "preserve",
  whitespace = "collapse",
  punctuation = "preserve"
) {
  .error_rate(reference, hypothesis, "word", unicode, case, whitespace, punctuation)
}
