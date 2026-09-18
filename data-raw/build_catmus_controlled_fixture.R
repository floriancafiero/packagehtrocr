# Rebuild the controlled CATMuS normalization fixture.
#
# This script deliberately creates transformations of public ground truth.
# They are NOT HTR model predictions. See inst/extdata/CATMUS_ATTRIBUTION.md.

source_path <- file.path(
  "inst",
  "extdata",
  "catmus_medieval_public_fixture.csv"
)

output_path <- file.path(
  "inst",
  "extdata",
  "catmus_medieval_controlled_predictions.csv"
)

source_data <- read.csv(
  source_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

make_variant <- function(data, system, transform) {
  out <- data
  out$system <- system
  out$prediction <- transform(out$reference)

  names(out)[names(out) == "fixture_id"] <- "line_id"
  names(out)[names(out) == "shelfmark"] <- "document_id"

  out[
    ,
    c(
      "line_id",
      "document_id",
      "century",
      "script_type",
      "language",
      "gen_split",
      "system",
      "reference",
      "prediction"
    )
  ]
}

exact <- make_variant(
  source_data,
  "exact",
  identity
)

nfd_equivalent <- make_variant(
  source_data,
  "nfd_equivalent",
  stringi::stri_trans_nfd
)

punctuation_dropped <- make_variant(
  source_data,
  "punctuation_dropped",
  function(x) {
    stringi::stri_replace_all_charclass(x, "\\p{P}", "")
  }
)

controlled <- rbind(
  exact,
  nfd_equivalent,
  punctuation_dropped
)

write.csv(
  controlled,
  output_path,
  row.names = FALSE,
  fileEncoding = "UTF-8",
  qmethod = "double"
)
