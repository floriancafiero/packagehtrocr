test_that("NFC makes canonically equivalent strings identical", {
  composed <- "\u00e9"
  decomposed <- "e\u0301"

  expect_identical(
    normalize_text(composed, unicode = "NFC"),
    normalize_text(decomposed, unicode = "NFC")
  )
})

test_that("case, whitespace and punctuation policies are explicit", {
  x <- "  Hello,   WORLD!  "

  expect_identical(
    normalize_text(
      x,
      case = "lower",
      whitespace = "collapse",
      punctuation = "remove"
    ),
    "hello world"
  )
})
