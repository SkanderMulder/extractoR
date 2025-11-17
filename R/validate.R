#' @title Validate and Fix LLM JSON Response
#'
#' @description
#' Internal function to validate an LLM's JSON response against a JSON schema
#' and, if invalid, generate feedback for the LLM to self-correct.
#'
#' @param initial_response The initial JSON string response from the LLM.
#' @param json_schema_str The JSON schema as a string.
#' @param text The original input text that was sent to the LLM.
#' @param model The LLM model being used.
#' @param strategy The self-correction strategy ("reflect", "direct", "polite").
#' @param max_retries The maximum number of retry attempts.
#' @param .progress Logical, whether to show progress feedback using `cli`.
#'
#' @return A list representing the valid JSON response, or an error if validation
#'  fails after `max_retries`.
#' @keywords internal
validate_and_fix <- function(
  initial_response,
  json_schema_str,
  text,
  model,
  strategy,
  max_retries,
  .progress = TRUE
) {
  attempt <- 1
  response <- initial_response

  while (attempt <= max_retries) {
    valid <- jsonvalidate::json_validate(response, json_schema_str, engine = "ajv")

    if (valid) {
      result <- jsonlite::fromJSON(response, simplifyVector = FALSE)
      attr(result, "attempts") <- attempt
      return(result)
    }

    errors <- attr(valid, "errors")
    error_summary <- format_validation_errors(errors)

    if (.progress) {
      cli::cli_alert_warning("Attempt {attempt} failed. Retrying with feedback...")
      cli::cli_alert_info("Validation errors: {error_summary}")
    }

    prompt_fix <- switch(strategy,
      reflect = build_reflect_prompt(error_summary, text, json_schema_str),
      direct = build_direct_prompt(error_summary),
      polite = build_polite_prompt(error_summary)
    )

    response <- ellmer::chat(
      model = model,
      messages = list(list(role = "user", content = prompt_fix)),
      temperature = 0.0
    )$content

    attempt <- attempt + 1
  }

  stop("Failed to extract valid structure after ", max_retries, " attempts. Last error: ", error_summary, call. = FALSE)
}