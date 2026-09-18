test_that("paired comparison reports B minus A", {
  d <- data.frame(
    document_id = rep(c("d1", "d2"), each = 4),
    line_id = rep(c("l1", "l2", "l1", "l2"), times = 2),
    system = rep(c("A", "A", "B", "B"), times = 2),
    metric = "cer",
    reference = rep(c("abcdefghij", "klmnopqrst", "abcdefghij", "klmnopqrst"), times = 2),
    rate = c(0.2, 0.2, 0.1, 0.1, 0.4, 0.2, 0.2, 0.1),
    n_reference = 10,
    n_hypothesis = 10,
    substitutions = c(2, 2, 1, 1, 4, 2, 2, 1),
    deletions = 0,
    insertions = 0,
    distance = c(2, 2, 1, 1, 4, 2, 2, 1)
  )

  out <- compare_systems(
    d,
    systems = c("A", "B"),
    unit = "document_id",
    pair_id = "line_id",
    estimand = "macro",
    n_boot = 50,
    seed = 42
  )

  expect_equal(out$estimate_a, mean(c(0.2, 0.3)))
  expect_equal(out$estimate_b, mean(c(0.1, 0.15)))
  expect_equal(out$difference_b_minus_a, out$estimate_b - out$estimate_a)
  expect_equal(out$n_units, 2)
  expect_true(out$conf_low <= out$difference_b_minus_a)
  expect_true(out$conf_high >= out$difference_b_minus_a)
})

test_that("comparison refuses unpaired observations", {
  d <- data.frame(
    document_id = c("d1", "d1", "d1"),
    line_id = c("l1", "l1", "l2"),
    system = c("A", "B", "A"),
    metric = "cer",
    reference = c("abc", "abc", "def"),
    rate = c(0, 0, 0),
    n_reference = 3,
    n_hypothesis = 3,
    substitutions = 0,
    deletions = 0,
    insertions = 0,
    distance = 0
  )

  expect_error(
    compare_systems(
      d,
      systems = c("A", "B"),
      unit = "document_id",
      pair_id = "line_id",
      n_boot = 10
    ),
    "same paired observations"
  )
})


test_that("comparison refuses mismatched reference text", {
  d <- data.frame(
    document_id = c("d1", "d1"),
    line_id = c("l1", "l1"),
    system = c("A", "B"),
    metric = "cer",
    reference = c("abc", "xyz"),
    rate = c(0, 0),
    n_reference = c(3, 3),
    n_hypothesis = c(3, 3),
    substitutions = c(0, 0),
    deletions = c(0, 0),
    insertions = c(0, 0),
    distance = c(0, 0)
  )

  expect_error(
    compare_systems(
      d,
      systems = c("A", "B"),
      unit = "document_id",
      pair_id = "line_id",
      n_boot = 10
    ),
    "Reference texts differ"
  )
})
