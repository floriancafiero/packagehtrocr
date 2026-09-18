# Controlled public CATMuS example.
#
# IMPORTANT: "exact", "nfc_equivalent", and "punctuation_dropped" are
# controlled transformations, NOT OCR/HTR systems. See CATMUS_ATTRIBUTION.md.

path <- system.file(
  "extdata",
  "catmus_medieval_controlled_predictions.csv",
  package = "ocrinfer"
)

catmus_controlled <- read.csv(
  path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

sensitivity <- normalization_sensitivity(
  catmus_controlled,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = c(
    "document_id",
    "century",
    "script_type",
    "language"
  ),
  policies = list(
    raw_codepoints = list(
      unicode = "none",
      char_unit = "codepoint"
    ),
    nfc_graphemes = list(
      unicode = "NFC",
      char_unit = "grapheme"
    ),
    ignore_punctuation = list(
      unicode = "NFC",
      char_unit = "grapheme",
      punctuation = "remove"
    )
  ),
  metrics = "cer",
  summarise = TRUE,
  by = "system",
  averaging = "macro",
  unit = "document_id"
)

sensitivity
