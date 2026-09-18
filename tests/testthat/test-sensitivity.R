test_that("normalization sensitivity can change reported CER", {
  d <- data.frame(
    line_id = "l1",
    system = "A",
    reference = "Hello, world!",
    prediction = "hello world",
    stringsAsFactors = FALSE
  )

  out <- normalization_sensitivity(
    d,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    policies = list(
      strict = list(),
      relaxed = list(
        case = "lower",
        punctuation = "remove",
        whitespace = "collapse"
      )
    ),
    metrics = "cer"
  )

  strict <- out$rate[out$policy == "strict"]
  relaxed <- out$rate[out$policy == "relaxed"]

  expect_gt(strict, relaxed)
  expect_equal(relaxed, 0)
})

test_that("normalization sensitivity can summarise by system", {
  d <- data.frame(
    document_id = c("d1", "d1"),
    line_id = c("l1", "l2"),
    system = c("A", "A"),
    reference = c("abc", "def"),
    prediction = c("abc", "dEf"),
    stringsAsFactors = FALSE
  )

  out <- normalization_sensitivity(
    d,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    keep = "document_id",
    policies = list(
      strict = list(),
      lower = list(case = "lower")
    ),
    metrics = "cer",
    summarise = TRUE,
    by = "system",
    averaging = "micro"
  )

  expect_equal(sort(unique(out$policy)), c("lower", "strict"))
  expect_equal(out$rate[out$policy == "lower"], 0)
})
