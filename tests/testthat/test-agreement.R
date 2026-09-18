test_that("fidelity_agreement computes raw agreement and kappa", {
  d <- data.frame(
    annotation_id = rep(sprintf("ann_%02d", 1:4), each = 2),
    annotator = rep(c("A", "B"), times = 4),
    primary_label = c(
      "visual_misrecognition", "visual_misrecognition",
      "content_omission", "content_omission",
      "hallucinated_addition", "visual_misrecognition",
      "repetition", "repetition"
    ),
    stringsAsFactors = FALSE
  )

  out <- fidelity_agreement(d)

  expect_equal(out$n_items, 4)
  expect_equal(out$raw_agreement, 3 / 4)
  expect_true(is.finite(out$cohen_kappa))
})

test_that("fidelity_agreement requires exactly two annotators", {
  d <- data.frame(
    annotation_id = c("a", "a", "a"),
    annotator = c("A", "B", "C"),
    primary_label = rep("visual_misrecognition", 3)
  )

  expect_error(
    fidelity_agreement(d),
    "Exactly two annotators"
  )
})
