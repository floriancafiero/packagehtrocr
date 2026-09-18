#' Summarise paired transcription-policy swaps
#'
#' Compares outputs from the same model under different prompt/transcription
#' policy conditions while holding evaluation material fixed.
#'
#' For each pair of policy conditions, the function reports how often the
#' prediction changes, the normalized grapheme distance between the two outputs,
#' whether the second condition moves closer to the benchmark target, and a
#' document-level paired bootstrap interval for the target error-rate change.
#'
#' @param x Evaluation output from [evaluate_recognition()] with preserved
#'   reference and prediction text plus model/prompt metadata.
#' @param model_col Column identifying the underlying model/weights family to
#'   compare within.
#' @param condition_col Column identifying policy/prompt condition.
#' @param system_col Column identifying the unique run/system.
#' @param pair_id Column identifying the recognition unit shared across
#'   conditions, for example `"line_id"`.
#' @param unit Higher-level cluster used for bootstrap resampling.
#' @param metric Metric to analyze, `"cer"` or `"wer"`.
#' @param n_boot Number of document-level bootstrap replicates.
#' @param conf_level Bootstrap confidence level.
#' @param seed Random seed forwarded to [compare_systems()].
#'
#' @return A data frame with one row per model and pair of policy conditions.
#' @export
policy_swap_summary <- function(
  x,
  model_col = "model",
  condition_col = "prompt_condition",
  system_col = "system",
  pair_id = "line_id",
  unit = "document_id",
  metric = c("cer", "wer"),
  n_boot = 2000L,
  conf_level = 0.95,
  seed = 2027L
) {
  metric <- match.arg(metric)

  required <- c(
    "metric", "reference", "prediction", "rate",
    model_col, condition_col, system_col, pair_id, unit
  )
  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing policy-swap columns: %s.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  d <- x[as.character(x$metric) == metric, , drop = FALSE]
  if (nrow(d) == 0L) {
    return(data.frame(
      model = character(),
      condition_a = character(),
      condition_b = character(),
      system_a = character(),
      system_b = character(),
      n_lines = integer(),
      output_change_rate = numeric(),
      mean_output_distance = numeric(),
      median_output_distance = numeric(),
      improved_toward_target = numeric(),
      worsened_from_target = numeric(),
      unchanged_target_error = numeric(),
      mean_line_delta_b_minus_a = numeric(),
      target_difference_b_minus_a = numeric(),
      conf_low = numeric(),
      conf_high = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  model_values <- unique(as.character(d[[model_col]]))
  model_values <- model_values[!is.na(model_values) & nzchar(model_values)]

  normalized_output_distance <- function(a, b) {
    counts <- edit_counts(
      a,
      b,
      unit = "grapheme",
      unicode = "NFC",
      case = "preserve",
      whitespace = "preserve",
      punctuation = "preserve"
    )

    denom <- max(
      counts$n_reference,
      counts$n_hypothesis
    )

    if (denom == 0L) {
      return(0)
    }

    as.numeric(counts$distance / denom)
  }

  result_rows <- list()
  result_i <- 1L

  for (model_value in model_values) {
    m <- d[
      as.character(d[[model_col]]) == model_value,
      ,
      drop = FALSE
    ]

    conditions <- unique(as.character(m[[condition_col]]))
    conditions <- conditions[!is.na(conditions) & nzchar(conditions)]

    if (length(conditions) < 2L) {
      next
    }

    system_by_condition <- lapply(conditions, function(condition) {
      values <- unique(as.character(
        m[[system_col]][
          as.character(m[[condition_col]]) == condition
        ]
      ))
      values <- values[!is.na(values) & nzchar(values)]

      if (length(values) != 1L) {
        stop(
          sprintf(
            "Model %s condition %s must map to exactly one system; found %d.",
            model_value,
            condition,
            length(values)
          ),
          call. = FALSE
        )
      }

      values[[1]]
    })
    names(system_by_condition) <- conditions

    condition_pairs <- utils::combn(
      conditions,
      2L,
      simplify = FALSE
    )

    for (pair in condition_pairs) {
      condition_a <- pair[[1]]
      condition_b <- pair[[2]]
      system_a <- system_by_condition[[condition_a]]
      system_b <- system_by_condition[[condition_b]]

      a <- m[
        as.character(m[[condition_col]]) == condition_a,
        ,
        drop = FALSE
      ]
      b <- m[
        as.character(m[[condition_col]]) == condition_b,
        ,
        drop = FALSE
      ]

      make_key <- function(z) {
        paste(
          as.character(z[[unit]]),
          as.character(z[[pair_id]]),
          sep = "\u001f"
        )
      }

      key_a <- make_key(a)
      key_b <- make_key(b)

      if (anyDuplicated(key_a) || anyDuplicated(key_b)) {
        stop(
          sprintf(
            "Duplicate paired observations for model %s (%s vs %s).",
            model_value,
            condition_a,
            condition_b
          ),
          call. = FALSE
        )
      }

      if (!setequal(key_a, key_b)) {
        stop(
          sprintf(
            "Policy conditions are not evaluated on identical observations for model %s (%s vs %s).",
            model_value,
            condition_a,
            condition_b
          ),
          call. = FALSE
        )
      }

      b <- b[match(key_a, key_b), , drop = FALSE]

      if (!identical(
        as.character(a$reference),
        as.character(b$reference)
      )) {
        stop(
          sprintf(
            "Reference text differs across policy conditions for model %s.",
            model_value
          ),
          call. = FALSE
        )
      }

      output_changed <- as.character(a$prediction) != as.character(b$prediction)
      output_distance <- vapply(
        seq_len(nrow(a)),
        function(i) {
          normalized_output_distance(
            a$prediction[[i]],
            b$prediction[[i]]
          )
        },
        numeric(1)
      )

      target_delta <- as.numeric(b$rate - a$rate)
      tolerance <- sqrt(.Machine$double.eps)

      inference <- compare_systems(
        m,
        systems = c(system_a, system_b),
        unit = unit,
        pair_id = pair_id,
        system_col = system_col,
        estimand = "macro",
        n_boot = n_boot,
        conf_level = conf_level,
        seed = seed
      )
      inference <- inference[
        as.character(inference$metric) == metric,
        ,
        drop = FALSE
      ]

      if (nrow(inference) != 1L) {
        stop(
          sprintf(
            "Unexpected comparison result for %s: %s vs %s.",
            model_value,
            condition_a,
            condition_b
          ),
          call. = FALSE
        )
      }

      result_rows[[result_i]] <- data.frame(
        model = model_value,
        condition_a = condition_a,
        condition_b = condition_b,
        system_a = system_a,
        system_b = system_b,
        metric = metric,
        n_lines = nrow(a),
        output_change_rate = mean(output_changed),
        mean_output_distance = mean(output_distance),
        median_output_distance = stats::median(output_distance),
        improved_toward_target = mean(target_delta < -tolerance),
        worsened_from_target = mean(target_delta > tolerance),
        unchanged_target_error = mean(abs(target_delta) <= tolerance),
        mean_line_delta_b_minus_a = mean(target_delta),
        target_difference_b_minus_a = inference$difference_b_minus_a,
        conf_low = inference$conf_low,
        conf_high = inference$conf_high,
        conf_level = inference$conf_level,
        n_units = inference$n_units,
        stringsAsFactors = FALSE
      )

      result_i <- result_i + 1L
    }
  }

  if (length(result_rows) == 0L) {
    return(data.frame(
      model = character(),
      condition_a = character(),
      condition_b = character(),
      system_a = character(),
      system_b = character(),
      metric = character(),
      n_lines = integer(),
      output_change_rate = numeric(),
      mean_output_distance = numeric(),
      median_output_distance = numeric(),
      improved_toward_target = numeric(),
      worsened_from_target = numeric(),
      unchanged_target_error = numeric(),
      mean_line_delta_b_minus_a = numeric(),
      target_difference_b_minus_a = numeric(),
      conf_low = numeric(),
      conf_high = numeric(),
      conf_level = numeric(),
      n_units = integer(),
      stringsAsFactors = FALSE
    ))
  }

  out <- do.call(rbind, result_rows)
  rownames(out) <- NULL
  out
}
