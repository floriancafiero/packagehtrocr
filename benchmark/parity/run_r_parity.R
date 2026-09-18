#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: run_r_parity.R <output.csv>")

d <- read.csv(
  "inst/extdata/toy_recognition.csv",
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

x <- ocrinfer::evaluate_recognition(
  d,
  truth = reference,
  prediction = prediction,
  id = line_id,
  system = system,
  keep = "document_id",
  metrics = c("cer", "wer")
)

cols <- c(
  "line_id", "system", "metric", "rate",
  "n_reference", "n_hypothesis",
  "substitutions", "deletions", "insertions", "distance"
)

out <- x[, cols, drop = FALSE]
out <- out[order(out$line_id, out$system, out$metric), , drop = FALSE]
rownames(out) <- NULL

write.csv(out, args[[1]], row.names = FALSE)
