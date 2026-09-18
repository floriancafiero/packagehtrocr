#' Compare recognition results across normalization policies
#'
#' Re-evaluates the same recognition output under several explicit text
#' normalization policies. This is intended to show how evaluation choices
#' such as Unicode normalization, case folding, whitespace handling, and
#' punctuation removal affect reported CER/WER.
#'
#' @param data Original data frame containing references and predictions.
#' @param truth,prediction,id,system,keep,metrics,char_unit Passed to
#'   [evaluate_recognition()].
#' @param policies Named list of policy specifications. Each element must be a
#'   list and may contain any of: `unicode`, `case`, `whitespace`,
#'   `punctuation`, and `char_unit`. Unspecified values use the conservative
#'   defaults from [evaluate_recognition()].
#' @param summarise Logical. If TRUE, return micro- or macro-averaged summaries
#'   rather than row-level evaluations.
#' @param by Grouping columns used when `summarise = TRUE`.
#' @param averaging Passed to [summarise_recognition()].
#' @param unit Higher-level unit for macro averaging.
#'
#' @return A data frame with a `policy` column identifying the normalization
#'   specification used for each result.
#' @export
normalization_sensitivity <- function(
  data,
  truth,
  prediction,
  id = NULL,
  system = NULL,
  keep = NULL,
  policies,
  metrics = c("cer", "wer"),
  char_unit = "grapheme",
  summarise = FALSE,
  by = NULL,
  averaging = c("micro", "macro"),
  unit = NULL
) {
  averaging <- match.arg(averaging)

  if (missing(policies) || !is.list(policies) || length(policies) == 0L) {
    stop("`policies` must be a non-empty named list.", call. = FALSE)
  }

  policy_names <- names(policies)
  if (is.null(policy_names) || any(!nzchar(policy_names)) || anyDuplicated(policy_names)) {
    stop("`policies` must have unique non-empty names.", call. = FALSE)
  }

  allowed <- c("unicode", "case", "whitespace", "punctuation", "char_unit")
  defaults <- list(
    unicode = "NFC",
    case = "preserve",
    whitespace = "preserve",
    punctuation = "preserve",
    char_unit = char_unit
  )

  truth_expr <- substitute(truth)
  prediction_expr <- substitute(prediction)
  id_expr <- if (missing(id)) NULL else substitute(id)
  system_expr <- if (missing(system)) NULL else substitute(system)

  evaluate_one <- function(policy_name, spec) {
    if (!is.list(spec)) {
      stop(sprintf("Policy `%s` must be a list.", policy_name), call. = FALSE)
    }

    unknown <- setdiff(names(spec), allowed)
    if (length(unknown) > 0L) {
      stop(
        sprintf(
          "Unknown setting(s) in policy `%s`: %s.",
          policy_name,
          paste(unknown, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    settings <- utils::modifyList(defaults, spec)

    call_args <- list(
      data = data,
      truth = truth_expr,
      prediction = prediction_expr,
      metrics = metrics,
      char_unit = settings$char_unit,
      unicode = settings$unicode,
      case = settings$case,
      whitespace = settings$whitespace,
      punctuation = settings$punctuation
    )

    if (!is.null(id_expr)) call_args$id <- id_expr
    if (!is.null(system_expr)) call_args$system <- system_expr
    if (!is.null(keep)) call_args$keep <- keep

    # Construct the call so that unquoted column expressions remain column
    # expressions rather than being evaluated before evaluate_recognition().
    eval_call <- as.call(c(list(quote(evaluate_recognition)), call_args))
    result <- eval(eval_call, envir = parent.frame())

    result$policy <- policy_name
    result$policy_unicode <- settings$unicode
    result$policy_case <- settings$case
    result$policy_whitespace <- settings$whitespace
    result$policy_punctuation <- settings$punctuation
    result$policy_char_unit <- settings$char_unit

    if (isTRUE(summarise)) {
      summary_by <- unique(c(by, "policy"))
      result <- summarise_recognition(
        result,
        by = summary_by,
        averaging = averaging,
        unit = unit
      )

      # summarise_recognition() retains policy but not the policy-setting
      # descriptor columns, so add them back explicitly.
      result$policy_unicode <- settings$unicode
      result$policy_case <- settings$case
      result$policy_whitespace <- settings$whitespace
      result$policy_punctuation <- settings$punctuation
      result$policy_char_unit <- settings$char_unit
    }

    result
  }

  out <- lapply(seq_along(policies), function(i) {
    evaluate_one(policy_names[[i]], policies[[i]])
  })

  result <- do.call(rbind, out)
  rownames(result) <- NULL
  result
}
