test_that("confusion_table reconstructs substitutions", {
  d <- data.frame(
    line_id = "l1",
    system = "A",
    reference = "abc",
    prediction = "axd",
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    id = line_id,
    system = system,
    metrics = "cer"
  )

  out <- confusion_table(x, metric = "cer", by = "system")

  expect_equal(sum(out$n), 2)
  expect_true(all(out$operation == "substitution"))
  expect_true(all(c("b", "c") %in% out$reference_token))
  expect_true(all(c("x", "d") %in% out$prediction_token))
})

test_that("confusion_table represents gaps explicitly", {
  d <- data.frame(
    reference = c("ab", "ab"),
    prediction = c("a", "abc"),
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    metrics = "cer"
  )

  out <- confusion_table(x, metric = "cer")

  expect_true("<eps>" %in% out$reference_token)
  expect_true("<eps>" %in% out$prediction_token)
})

test_that("error_profile decomposes total error rate", {
  d <- data.frame(
    system = c("A", "A"),
    reference = c("abc", "abc"),
    prediction = c("axc", "ab"),
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    system = system,
    metrics = "cer"
  )

  out <- error_profile(x, by = "system")

  expect_equal(out$substitutions, 1)
  expect_equal(out$deletions, 1)
  expect_equal(out$insertions, 0)
  expect_equal(out$distance, 2)
  expect_equal(out$error_rate, 2 / 6)
})
