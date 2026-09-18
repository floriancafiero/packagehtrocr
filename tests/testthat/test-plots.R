test_that("plot_comparison returns a ggplot", {
  x <- data.frame(
    metric = c("cer", "wer"),
    system_a = c("A", "A"),
    system_b = c("B", "B"),
    difference_b_minus_a = c(-0.01, -0.03),
    conf_low = c(-0.02, -0.05),
    conf_high = c(0, -0.01)
  )

  p <- plot_comparison(x)
  expect_s3_class(p, "ggplot")
})

test_that("plot_error_profile returns a ggplot", {
  x <- data.frame(
    system = c("A", "B"),
    metric = c("cer", "cer"),
    substitution_rate = c(0.02, 0.01),
    deletion_rate = c(0.01, 0.01),
    insertion_rate = c(0.005, 0.002)
  )

  p <- plot_error_profile(x, group = "system")
  expect_s3_class(p, "ggplot")
})


test_that("plot_comparison supports several system pairs", {
  x <- data.frame(
    metric = c("cer", "cer", "cer"),
    system_a = c("A", "A", "B"),
    system_b = c("B", "C", "C"),
    difference_b_minus_a = c(-0.01, 0.02, 0.03),
    conf_low = c(-0.02, 0.01, 0.01),
    conf_high = c(0, 0.03, 0.05)
  )

  p <- plot_comparison(x)
  expect_s3_class(p, "ggplot")
  expect_equal(length(unique(p$data$comparison)), 3)
})
