.resolve_column <- function(expr, data, arg_name) {
  if (is.null(expr)) return(NULL)

  if (is.symbol(expr)) {
    name <- as.character(expr)
  } else if (is.character(expr) && length(expr) == 1L) {
    name <- expr
  } else {
    stop(sprintf("`%s` must be an unquoted column name or a single string.", arg_name), call. = FALSE)
  }

  if (!name %in% names(data)) {
    stop(sprintf("Column `%s` supplied to `%s` was not found in `data`.", name, arg_name), call. = FALSE)
  }
  name
}

.validate_pair <- function(reference, hypothesis) {
  if (length(reference) != 1L || length(hypothesis) != 1L) {
    stop("`reference` and `hypothesis` must each be a single string.", call. = FALSE)
  }
  if (is.na(reference) || is.na(hypothesis)) {
    stop("`reference` and `hypothesis` must not be NA.", call. = FALSE)
  }
  invisible(TRUE)
}
