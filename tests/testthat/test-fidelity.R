test_that("fidelity codebook contains source-aware categories", {
  cb <- fidelity_codebook()
  expect_true(all(c(
    "visual_misrecognition",
    "orthographic_normalization",
    "linguistic_correction",
    "unsupported_completion",
    "hallucinated_addition",
    "ambiguous"
  ) %in% cb$label))
})

test_that("annotation preparation blinds system identity", {
  d <- data.frame(
    document_id = c("d1", "d1"),
    line_id = c("l1", "l1"),
    system = c("A", "B"),
    language = c("Latin", "Latin"),
    reference = c("abc", "abc"),
    prediction = c("axc", "ayc"),
    stringsAsFactors = FALSE
  )

  x <- evaluate_recognition(
    d,
    reference,
    prediction,
    id = line_id,
    system = system,
    keep = c("document_id", "language"),
    metrics = "cer"
  )

  batch <- prepare_fidelity_annotation(
    x,
    metric = "cer",
    keep = c("document_id", "language"),
    strata = "system",
    seed = 7
  )

  expect_false("system" %in% names(batch$items))
  expect_true("system" %in% names(batch$key))
  expect_true(all(batch$items$annotation_id %in% batch$key$annotation_id))
  expect_equal(nrow(batch$items), 2)
})

test_that("fidelity profiles recover blinded system groups", {
  annotations <- data.frame(
    annotation_id = c("ann_000001", "ann_000002", "ann_000003"),
    primary_label = c(
      "visual_misrecognition",
      "hallucinated_addition",
      "visual_misrecognition"
    ),
    stringsAsFactors = FALSE
  )

  key <- data.frame(
    annotation_id = c("ann_000001", "ann_000002", "ann_000003"),
    system = c("A", "A", "B"),
    stringsAsFactors = FALSE
  )

  out <- fidelity_profile(
    annotations,
    key = key,
    by = "system"
  )

  expect_equal(sum(out$n), 3)
  expect_equal(
    out$proportion[
      out$system == "A" &
        out$label == "visual_misrecognition"
    ],
    0.5
  )
  expect_equal(
    out$proportion[
      out$system == "B" &
        out$label == "visual_misrecognition"
    ],
    1
  )
})
