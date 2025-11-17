# Utility functions for instructoR

#' @title Format JSON Validation Errors
#'
#' @description
#' Helper function to format a list of JSON validation errors into a human-readable string.
#'
#' @param errors A list of error objects returned by `jsonvalidate::json_validate()`.
#'
#' @return A character string summarizing the validation errors.
#' @keywords internal
format_validation_errors <- function(errors) {
  if (is.null(errors) || length(errors) == 0) {
    return("No specific errors reported.")
  }
  error_messages <- sapply(errors, function(err) {
    paste0("- ", err$message, " (Path: ", err$dataPath, ", Schema: ", err$schemaPath, ")")
  })
  paste(error_messages, collapse = "\n")
}