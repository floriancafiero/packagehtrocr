test_that("CATMuS NFC-equivalent strings illustrate Unicode sensitivity", {
  path <- system.file(
    "extdata",
    "catmus_medieval_controlled_predictions.csv",
    package = "ocrinfer"
  )

  d <- read.csv(
    path,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8",
    check.names = FALSE
  )

  nfc_rows <- d[d$system == "nfc_equivalent", , drop = FALSE]

  raw <- evaluate_recognition(
    nfc_rows,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    metrics = "cer",
    char_unit = "codepoint",
    unicode = "none"
  )

  canonical <- evaluate_recognition(
    nfc_rows,
    truth = reference,
    prediction = prediction,
    id = line_id,
    system = system,
    metrics = "cer",
    char_unit = "grapheme",
    unicode = "NFC"
  )

  expect_true(any(raw$rate > 0))
  expect_true(all(canonical$rate == 0))
})

test_that("punctuation-only controlled differences disappear when punctuation is ignored", {
  path <- system.file(
    "extdata",
    "catmus_medieval_controlled_predictions.csv",
    package = "ocrinfer"
  )

  d <- read.csv(
    path,
    stringsAsFactors = FALSE,
    fileEncoding = "UTF-8",
    check.names = FALSE
  )

  punctuation_rows <- d[
    d$system == "punctuation_dropped",
    ,
    drop = FALSE
  ]

  strict <- evaluate_recognition(
    punctuation_rows,
    truth = reference,
    prediction = prediction,
    metrics = "cer",
    punctuation = "preserve"
  )

  ignored <- evaluate_recognition(
    punctuation_rows,
    truth = reference,
    prediction = prediction,
    metrics = "cer",
    punctuation = "remove"
  )

  expect_true(any(strict$rate > 0))
  expect_true(all(ignored$rate == 0))
})
