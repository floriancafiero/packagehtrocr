test_that("evaluate_recognition returns long-form metrics", {
  d <- data.frame(
    line_id = c("l1", "l2"),
    system = c("A", "A"),
    reference = c("abc", "hello world"),
    prediction = c("axc", "hello duck"),
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    metrics = c("cer", "wer")
  )

  expect_equal(nrow(x), 4)
  expect_true(all(c(
    "line_id", "system", "reference", "prediction", "metric", "rate",
    "substitutions", "deletions", "insertions"
  ) %in% names(x)))
})

test_that("evaluate_recognition handles empty data", {
  d <- data.frame(reference = character(), prediction = character())
  x <- evaluate_recognition(d, reference, prediction)
  expect_equal(nrow(x), 0)
})


test_that("text retention can be disabled explicitly", {
  d <- data.frame(reference = "abc", prediction = "axc")
  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    metrics = "cer",
    keep_text = FALSE
  )
  expect_false("reference" %in% names(x))
  expect_false("prediction" %in% names(x))
})
