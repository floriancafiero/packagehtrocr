#' Compare two OCR/HTR systems with paired bootstrap uncertainty
#'
#' Compares two systems evaluated on exactly the same recognition units. The
#' bootstrap resamples complete higher-level units (for example manuscripts),
#' preserving the dependence among lines from the same unit.
#'
#' @param x Evaluation output from [evaluate_recognition()]. The original
#'   reference text must be present (the default when `keep_text = TRUE`) so
#'   paired comparisons can verify identical ground truth across systems.
#' @param systems Character vector naming exactly two system levels, in the
#'   order A, B. The reported difference is B - A, so negative values mean
#'   system B has the lower error rate.
#' @param unit Character scalar naming the higher-level resampling unit.
#' @param pair_id Character scalar naming the lowest-level paired observation
#'   (for example line_id). Each pair must occur once per system and metric.
#' @param system_col Character scalar naming the system column.
#' @param estimand Either "macro" (equal weight per higher-level unit) or
#'   "micro" (pool edit counts across all paired material).
#' @param n_boot Number of paired cluster-bootstrap replicates.
#' @param conf_level Confidence level for the percentile bootstrap interval.
#' @param seed Optional integer random seed. When supplied, the previous R RNG
#'   state is restored on exit.
#'
#' @return One row per metric with system estimates, B-A difference, bootstrap
#'   interval, and number of paired higher-level units.
#' @export
compare_systems <- function(
  x,
  systems,
  unit,
  pair_id,
  system_col = "system",
  estimand = c("macro", "micro"),
  n_boot = 2000L,
  conf_level = 0.95,
  seed = NULL
) {
  estimand <- match.arg(estimand)

  if (!is.character(systems) || length(systems) != 2L || systems[1] == systems[2]) {
    stop("`systems` must name exactly two distinct system levels.", call. = FALSE)
  }
  if (!is.character(unit) || length(unit) != 1L || !unit %in% names(x)) {
    stop("`unit` must name one column in `x`.", call. = FALSE)
  }
  if (!is.character(pair_id) || length(pair_id) != 1L || !pair_id %in% names(x)) {
    stop("`pair_id` must name one column in `x`.", call. = FALSE)
  }
  if (!is.character(system_col) || length(system_col) != 1L || !system_col %in% names(x)) {
    stop("`system_col` must name one column in `x`.", call. = FALSE)
  }
  if (!is.numeric(n_boot) || length(n_boot) != 1L || n_boot < 1 || n_boot != as.integer(n_boot)) {
    stop("`n_boot` must be a positive integer.", call. = FALSE)
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must lie strictly between 0 and 1.", call. = FALSE)
  }

  required <- c(
    "metric", "reference", "n_reference", "n_hypothesis",
    "substitutions", "deletions", "insertions", "distance"
  )
  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf("Missing required evaluation columns: %s.", paste(missing_required, collapse = ", ")),
      call. = FALSE
    )
  }

  observed_systems <- unique(as.character(x[[system_col]]))
  missing_systems <- setdiff(systems, observed_systems)
  if (length(missing_systems) > 0L) {
    stop(sprintf("Systems not found: %s.", paste(missing_systems, collapse = ", ")), call. = FALSE)
  }

  if (!is.null(seed)) {
    if (!is.numeric(seed) || length(seed) != 1L || is.na(seed)) {
      stop("`seed` must be NULL or one non-missing number.", call. = FALSE)
    }

    had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)

    on.exit({
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)

    set.seed(seed)
  }

  rate_from_counts <- function(distance, n_reference, insertions) {
    if (n_reference == 0) {
      if (insertions == 0) 0 else insertions
    } else {
      distance / n_reference
    }
  }

  aggregate_units <- function(d) {
    split_rows <- split(seq_len(nrow(d)), d[[unit]], drop = TRUE)

    rows <- lapply(names(split_rows), function(unit_value) {
      j <- split_rows[[unit_value]]
      ref <- sum(d$n_reference[j])
      ins <- sum(d$insertions[j])
      dist <- sum(d$distance[j])

      data.frame(
        unit_value = unit_value,
        n_reference = ref,
        insertions = ins,
        distance = dist,
        rate = rate_from_counts(dist, ref, ins),
        stringsAsFactors = FALSE
      )
    })

    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    out
  }

  metric_results <- lapply(unique(as.character(x$metric)), function(metric_name) {
    d <- x[
      as.character(x$metric) == metric_name &
        as.character(x[[system_col]]) %in% systems,
      ,
      drop = FALSE
    ]

    make_key <- function(d) {
      paste(
        as.character(d[[unit]]),
        as.character(d[[pair_id]]),
        sep = "\u001f"
      )
    }

    a <- d[as.character(d[[system_col]]) == systems[1], , drop = FALSE]
    b <- d[as.character(d[[system_col]]) == systems[2], , drop = FALSE]

    key_a <- make_key(a)
    key_b <- make_key(b)

    if (anyDuplicated(key_a) || anyDuplicated(key_b)) {
      stop(
        sprintf("Each `unit` + `pair_id` combination must occur once per system for metric %s.", metric_name),
        call. = FALSE
      )
    }

    if (!setequal(key_a, key_b)) {
      stop(
        sprintf(
          "Systems are not evaluated on exactly the same paired observations for metric %s.",
          metric_name
        ),
        call. = FALSE
      )
    }

    b <- b[match(key_a, key_b), , drop = FALSE]

    if (!identical(as.character(a$reference), as.character(b$reference))) {
      stop(
        sprintf(
          "Reference texts differ between systems for at least one paired observation in metric %s.",
          metric_name
        ),
        call. = FALSE
      )
    }

    if (!all(a$n_reference == b$n_reference)) {
      stop(
        sprintf(
          "Reference lengths differ between systems for at least one paired observation in metric %s.",
          metric_name
        ),
        call. = FALSE
      )
    }

    a_units <- aggregate_units(a)
    b_units <- aggregate_units(b)
    b_units <- b_units[match(a_units$unit_value, b_units$unit_value), , drop = FALSE]

    if (anyNA(b_units$unit_value)) {
      stop("Internal pairing error while matching higher-level units.", call. = FALSE)
    }

    estimate <- function(tab, idx = seq_len(nrow(tab))) {
      if (estimand == "macro") {
        return(mean(tab$rate[idx]))
      }

      ref <- sum(tab$n_reference[idx])
      ins <- sum(tab$insertions[idx])
      dist <- sum(tab$distance[idx])
      rate_from_counts(dist, ref, ins)
    }

    est_a <- estimate(a_units)
    est_b <- estimate(b_units)
    observed_difference <- est_b - est_a

    n_units <- nrow(a_units)
    boot_diff <- numeric(n_boot)

    for (r in seq_len(n_boot)) {
      sampled <- sample.int(n_units, size = n_units, replace = TRUE)
      boot_diff[r] <- estimate(b_units, sampled) - estimate(a_units, sampled)
    }

    alpha <- (1 - conf_level) / 2
    interval <- stats::quantile(
      boot_diff,
      probs = c(alpha, 1 - alpha),
      names = FALSE,
      type = 7
    )

    data.frame(
      metric = metric_name,
      system_a = systems[1],
      system_b = systems[2],
      estimand = estimand,
      estimate_a = est_a,
      estimate_b = est_b,
      difference_b_minus_a = observed_difference,
      conf_low = interval[1],
      conf_high = interval[2],
      conf_level = conf_level,
      n_units = n_units,
      n_boot = as.integer(n_boot),
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, metric_results)
  rownames(out) <- NULL
  attr(out, "ocrinfer_policy") <- attr(x, "ocrinfer_policy")
  out
}
