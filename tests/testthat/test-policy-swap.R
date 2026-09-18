test_that("policy_swap_summary measures within-model prompt effects", {
  d <- data.frame(
    document_id = rep(c("d1", "d2"), each = 4),
    line_id = rep(c("l1", "l1", "l2", "l2"), times = 2),
    system = rep(
      c("qwen_neutral", "qwen_matched"),
      times = 4
    ),
    model = "Qwen",
    prompt_condition = rep(
      c("neutral", "matched"),
      times = 4
    ),
    reference = rep(
      c("abc", "abc", "def", "def"),
      times = 2
    ),
    prediction = c(
      "axc", "abc",
      "def", "def",
      "abc", "abc",
      "dxf", "def"
    ),
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    id = line_id,
    system = system,
    keep = c(
      "document_id",
      "model",
      "prompt_condition"
    ),
    metrics = "cer"
  )

  out <- policy_swap_summary(
    x,
    metric = "cer",
    n_boot = 50,
    seed = 42
  )

  expect_equal(nrow(out), 1)
  expect_equal(out$model, "Qwen")
  expect_equal(out$condition_a, "neutral")
  expect_equal(out$condition_b, "matched")
  expect_equal(out$n_lines, 4)
  expect_equal(out$output_change_rate, 0.5)
  expect_gt(out$improved_toward_target, 0)
  expect_lt(out$target_difference_b_minus_a, 0)
})

test_that("policy_swap_summary ignores models with one condition", {
  d <- data.frame(
    document_id = "d1",
    line_id = "l1",
    system = "kraken",
    model = "Kraken",
    prompt_condition = "fixed",
    reference = "abc",
    prediction = "abc"
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    id = line_id,
    system = system,
    keep = c(
      "document_id",
      "model",
      "prompt_condition"
    ),
    metrics = "cer"
  )

  out <- policy_swap_summary(
    x,
    n_boot = 10
  )

  expect_equal(nrow(out), 0)
})
