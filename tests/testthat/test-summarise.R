test_that("micro averaging pools edit counts", {
  x <- data.frame(
    system = c("A", "A"),
    metric = c("cer", "cer"),
    rate = c(1 / 2, 1 / 8),
    n_reference = c(2, 8),
    n_hypothesis = c(2, 8),
    substitutions = c(1, 1),
    deletions = c(0, 0),
    insertions = c(0, 0),
    distance = c(1, 1)
  )

  out <- summarise_recognition(x, by = "system", averaging = "micro")
  expect_equal(out$rate, 2 / 10)
})

test_that("macro averaging gives each document equal weight", {
  x <- data.frame(
    system = c("A", "A", "A"),
    document_id = c("short", "long", "long"),
    metric = c("cer", "cer", "cer"),
    rate = c(1, 0.1, 0.1),
    n_reference = c(1, 5, 5),
    n_hypothesis = c(1, 5, 5),
    substitutions = c(1, 0, 1),
    deletions = c(0, 0, 0),
    insertions = c(0, 0, 0),
    distance = c(1, 0, 1)
  )

  out <- summarise_recognition(
    x,
    by = "system",
    averaging = "macro",
    unit = "document_id"
  )

  expect_equal(out$n_units, 2)
  expect_equal(out$rate, mean(c(1, 0.1)))
})

test_that("evaluation metadata can be preserved for later grouping", {
  d <- data.frame(
    document_id = c("d1", "d1"),
    line_id = c("l1", "l2"),
    system = c("A", "A"),
    reference = c("abc", "def"),
    prediction = c("abc", "dxf")
  )

  x <- evaluate_recognition(
    d,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    keep = "document_id",
    metrics = "cer"
  )

  expect_true("document_id" %in% names(x))
  expect_identical(attr(x, "ocrinfer_policy")$unicode, "NFC")
})
