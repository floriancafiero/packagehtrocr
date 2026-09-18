#' Plot an OCR/HTR error profile
#'
#' Visualises substitution, deletion, and insertion rates from
#' [error_profile()].
#'
#' @param x Data frame returned by [error_profile()].
#' @param group Optional single column name used on the horizontal axis.
#' @param percent Logical. If TRUE, display rates as percentages.
#' @return A ggplot object.
#' @export
plot_error_profile <- function(x, group = NULL, percent = TRUE) {
  required <- c(
    "metric",
    "substitution_rate",
    "deletion_rate",
    "insertion_rate"
  )

  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing error-profile columns: %s.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.null(group)) {
    if (!is.character(group) || length(group) != 1L || !group %in% names(x)) {
      stop("`group` must be NULL or one column name in `x`.", call. = FALSE)
    }
  }

  if (!is.logical(percent) || length(percent) != 1L || is.na(percent)) {
    stop("`percent` must be TRUE or FALSE.", call. = FALSE)
  }

  multiplier <- if (isTRUE(percent)) 100 else 1
  group_value <- if (is.null(group)) {
    rep("All data", nrow(x))
  } else {
    as.character(x[[group]])
  }

  make_part <- function(rate_column, error_type) {
    data.frame(
      group_value = group_value,
      metric = as.character(x$metric),
      error_type = error_type,
      rate = x[[rate_column]] * multiplier,
      stringsAsFactors = FALSE
    )
  }

  plot_data <- rbind(
    make_part("substitution_rate", "Substitution"),
    make_part("deletion_rate", "Deletion"),
    make_part("insertion_rate", "Insertion")
  )

  axis_label <- if (isTRUE(percent)) "Error rate (%)" else "Error rate"

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = group_value,
      y = rate,
      fill = error_type
    )
  ) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::facet_wrap(ggplot2::vars(metric)) +
    ggplot2::labs(
      x = if (is.null(group)) NULL else group,
      y = axis_label,
      fill = "Error type"
    ) +
    ggplot2::theme_minimal()
}
