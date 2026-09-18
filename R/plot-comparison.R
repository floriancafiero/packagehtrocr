#' Plot a paired recognition-system comparison
#'
#' Visualises the B - A error-rate difference and its bootstrap confidence
#' interval returned by [compare_systems()].
#'
#' @param x Data frame returned by [compare_systems()].
#' @param percent Logical. If TRUE, display the scale in percentage points.
#' @return A ggplot object.
#' @export
plot_comparison <- function(x, percent = TRUE) {
  required <- c(
    "metric", "system_a", "system_b",
    "difference_b_minus_a", "conf_low", "conf_high"
  )

  missing_required <- setdiff(required, names(x))
  if (length(missing_required) > 0L) {
    stop(
      sprintf(
        "Missing comparison columns: %s.",
        paste(missing_required, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (!is.logical(percent) || length(percent) != 1L || is.na(percent)) {
    stop("`percent` must be TRUE or FALSE.", call. = FALSE)
  }

  plot_data <- x
  multiplier <- if (isTRUE(percent)) 100 else 1

  plot_data$difference_plot <- plot_data$difference_b_minus_a * multiplier
  plot_data$conf_low_plot <- plot_data$conf_low * multiplier
  plot_data$conf_high_plot <- plot_data$conf_high * multiplier
  plot_data$comparison <- paste0(
    plot_data$system_b,
    " - ",
    plot_data$system_a
  )

  axis_label <- if (isTRUE(percent)) {
    "Difference in error rate (B - A), percentage points"
  } else {
    "Difference in error rate (B - A)"
  }

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = .data[["metric"]], y = .data[["difference_plot"]])
  ) +
    ggplot2::geom_hline(yintercept = 0, linetype = 2) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = .data[["conf_low_plot"]], ymax = .data[["conf_high_plot"]]),
      width = 0.15
    ) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::coord_flip() +
    ggplot2::facet_wrap("comparison") +
    ggplot2::labs(
      x = NULL,
      y = axis_label
    ) +
    ggplot2::theme_minimal()
}
