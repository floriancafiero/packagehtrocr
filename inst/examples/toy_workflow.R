# Minimal end-to-end example using the bundled toy predictions.

toy_path <- system.file(
  "extdata",
  "toy_recognition.csv",
  package = "ocrinfer"
)

toy <- read.csv(
  toy_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8"
)

results <- evaluate_recognition(
  toy,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = "document_id",
  metrics = c("cer", "wer")
)

# Global micro-averaged error rate by system.
summarise_recognition(
  results,
  by = "system",
  averaging = "micro"
)

# Give each document equal weight.
summarise_recognition(
  results,
  by = "system",
  averaging = "macro",
  unit = "document_id"
)

# Paired document-level comparison of systems A and B.
compare_systems(
  results,
  systems = c("A", "B"),
  unit = "document_id",
  pair_id = "line_id",
  estimand = "macro",
  n_boot = 500,
  seed = 1
)
