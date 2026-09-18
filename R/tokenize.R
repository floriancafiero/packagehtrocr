.tokenize_text <- function(x, unit = c("grapheme", "codepoint", "word")) {
  unit <- match.arg(unit)

  if (length(x) != 1L || is.na(x)) {
    stop("Internal error: tokenisation expects one non-missing string.", call. = FALSE)
  }
  if (identical(x, "")) return(character())

  if (unit == "grapheme") {
    return(stringi::stri_split_boundaries(x, type = "character", simplify = FALSE)[[1L]])
  }

  if (unit == "codepoint") {
    ints <- utf8ToInt(enc2utf8(x))
    if (length(ints) == 0L) return(character())
    return(intToUtf8(ints, multiple = TRUE))
  }

  stringi::stri_split_regex(x, "\\s+", omit_empty = TRUE, simplify = FALSE)[[1L]]
}
