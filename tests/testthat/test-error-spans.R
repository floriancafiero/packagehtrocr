test_that("extract_error_spans groups contiguous edit operations", {
  d <- data.frame(
    line_id = "l1",
    system = "A",
    reference = "abcdef",
    prediction = "abXYef",
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    metrics = "cer"
  )

  spans <- extract_error_spans(
    x,
    metric = "cer",
    by = c("system", "line_id"),
    context = 2
  )

  expect_equal(nrow(spans), 1)
  expect_equal(spans$reference_span, "cd")
  expect_equal(spans$prediction_span, "XY")
  expect_equal(spans$substitutions, 2)
  expect_equal(spans$context_before, "ab")
  expect_equal(spans$context_after, "ef")
})

test_that("extract_error_spans flags simple duplicated insertions", {
  d <- data.frame(
    line_id = "l1",
    system = "A",
    reference = "abc",
    prediction = "abbc",
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

  spans <- extract_error_spans(
    x,
    metric = "cer",
    by = c("system", "line_id")
  )

  expect_true(any(spans$possible_repetition))
})

test_that("correct lines produce no error spans", {
  d <- data.frame(reference = "abc", prediction = "abc")
  x <- evaluate_recognition(d, reference, prediction, metrics = "cer")
  spans <- extract_error_spans(x, metric = "cer")
  expect_equal(nrow(spans), 0)
})
