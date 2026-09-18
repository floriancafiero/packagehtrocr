#' Normalize text before recognition evaluation
#'
#' @param x Character vector.
#' @param unicode One of "NFC", "NFKC", "NFD", "NFKD", or "none".
#' @param case One of "preserve", "lower", or "upper".
#' @param whitespace One of "preserve", "collapse", or "trim".
#' @param punctuation One of "preserve" or "remove".
#' @return A character vector of the same length as `x`.
#' @export
normalize_text <- function(
  x,
  unicode = c("NFC", "NFKC", "NFD", "NFKD", "none"),
  case = c("preserve", "lower", "upper"),
  whitespace = c("preserve", "collapse", "trim"),
  punctuation = c("preserve", "remove")
) {
  unicode <- match.arg(unicode)
  case <- match.arg(case)
  whitespace <- match.arg(whitespace)
  punctuation <- match.arg(punctuation)

  x <- as.character(x)

  if (unicode == "NFC") x <- stringi::stri_trans_nfc(x)
  if (unicode == "NFKC") x <- stringi::stri_trans_nfkc(x)
  if (unicode == "NFD") x <- stringi::stri_trans_nfd(x)
  if (unicode == "NFKD") x <- stringi::stri_trans_nfkd(x)

  if (case == "lower") x <- stringi::stri_trans_tolower(x)
  if (case == "upper") x <- stringi::stri_trans_toupper(x)

  if (punctuation == "remove") {
    x <- stringi::stri_replace_all_charclass(x, "\\p{P}", "")
  }

  if (whitespace == "collapse") {
    x <- stringi::stri_replace_all_regex(x, "\\s+", " ")
    x <- stringi::stri_trim_both(x)
  } else if (whitespace == "trim") {
    x <- stringi::stri_trim_both(x)
  }

  x
}
