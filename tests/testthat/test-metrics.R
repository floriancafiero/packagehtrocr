test_that("CER handles exact matches and substitutions", {
  expect_equal(cer("abc", "abc"), 0)
  expect_equal(cer("abc", "axc"), 1 / 3)
})

test_that("WER handles a one-word substitution", {
  expect_equal(wer("hello world", "hello duck"), 1 / 2)
})

test_that("empty references have explicit behaviour", {
  expect_equal(cer("", ""), 0)
  expect_equal(cer("", "abc"), 3)
  expect_equal(wer("", "two words"), 2)
})

test_that("normalization can remove canonical Unicode differences", {
  composed <- "\u00e9"
  decomposed <- "e\u0301"

  expect_equal(cer(composed, decomposed, unicode = "none"), 1)
  expect_equal(cer(composed, decomposed, unicode = "NFC"), 0)
})

test_that("edit counts distinguish operation types", {
  x <- edit_counts("abc", "axcd", unit = "codepoint")
  expect_equal(x$substitutions, 1)
  expect_equal(x$insertions, 1)
  expect_equal(x$deletions, 0)
  expect_equal(x$distance, 2)
})
