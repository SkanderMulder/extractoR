#' Validate and fix LLM response with retry loop
#'
#' Attempts to validate an LLM response against a JSON Schema. If validation
#' fails, retries with error feedback until successful or max retries reached.
#'
#' @param initial_response The initial response from the LLM
#' @param json_schema_str JSON Schema as a string
#' @param text Original text being processed
#' @param model Model identifier for ellmer
#' @param strategy Retry strategy: "reflect", "direct", or "polite"
#' @param max_retries Maximum number of retry attempts
#' @param temperature Temperature for LLM calls
#' @param .progress Show progress messages
#'
#' @return Parsed JSON as an R list
#' @keywords internal
validate_and_fix <- function(initial_response,
                             json_schema_str,
                             text,
                             model,
                             strategy = "reflect",
                             max_retries = 5,
                             temperature = 0.0,
                             .progress = TRUE) {
  attempt <- 1
  response <- initial_response

  while (attempt <= max_retries) {
    response_clean <- clean_json_response(response)

    valid <- tryCatch({
      jsonvalidate::json_validate(
        response_clean,
        json_schema_str,
        engine = "ajv",
        error = TRUE
      )
    }, error = function(e) {
      structure(FALSE, errors = e$message)
    })

    if (isTRUE(valid)) {
      if (.progress) {
        cli::cli_alert_success("Validation successful")
      }
      return(jsonlite::fromJSON(response_clean, simplifyVector = FALSE))
    }

    errors <- attr(valid, "errors")
    error_summary <- format_validation_errors(errors)

    if (.progress) {
      cli::cli_alert_warning("Attempt {attempt}/{max_retries} failed")
      cli::cli_text("{cli::col_red(error_summary)}")
    }

    if (attempt >= max_retries) {
      break
    }

    prompt_fix <- build_correction_prompt(
      text = text,
      json_schema = json_schema_str,
      error_summary = error_summary,
      strategy = strategy
    )

    if (.progress) {
      cli::cli_alert_info("Retrying with feedback...")
    }

    response <- tryCatch({
      result <- ellmer::chat(
        model = model,
        system = "You are a helpful assistant that outputs valid JSON.",
        turns = list(list(role = "user", content = prompt_fix)),
        temperature = temperature
      )
      extract_content(result)
    }, error = function(e) {
      stop("LLM call failed: ", e$message, call. = FALSE)
    })

    attempt <- attempt + 1
  }

  cli::cli_abort(
    c(
      "Failed to extract valid structure after {max_retries} attempts",
      "x" = "Last error: {error_summary}",
      "i" = "Try increasing max_retries or simplifying the schema"
    )
  )
}

#' Format JSON validation errors into a human-readable summary
#'
#' @param errors The errors attribute from jsonvalidate::json_validate
#' @return A character string summarizing the errors
#' @keywords internal
format_validation_errors <- function(errors) {
  if (is.null(errors) || length(errors) == 0) {
    return("No specific validation errors reported.")
  }

  error_messages <- apply(errors, 1, function(error) {
    path <- if (nzchar(error["instancePath"])) paste0(" at '", error["instancePath"], "'") else ""
    paste0("- ", error["message"], path, " (Schema: ", error["schemaPath"], ")")
  })
  paste(error_messages, collapse = "\n")
}

#' Clean JSON response from LLM
#'
#' Removes markdown code blocks and extra whitespace from LLM responses
#'#'
#' @param response Raw response text
#' @return Cleaned JSON string
#' @keywords internal
clean_json_response <- function(response) {
  response <- trimws(response)
  response <- gsub("^```json\\s*", "", response)
  response <- gsub("^```\\s*", "", response)
  response <- gsub("\\s*```$", "", response)
  trimws(response)
}

#' Extract content from ellmer response
#'
#' Handles different ellmer response formats
#'
#' @param result Result from ellmer::chat
#' @return Content string
#' @keywords internal
extract_content <- function(result) {
  if (is.character(result)) {
    return(result)
  }

  if (is.list(result)) {
    if (!is.null(result$content)) {
      return(result$content)
    }
    if (!is.null(result$choices) && length(result$choices) > 0) {
      choice <- result$choices[[1]]
      if (!is.null(choice$message$content)) {
        return(choice$message$content)
      }
    }
    if (!is.null(result$text)) {
      return(result$text)
    }
  }

  stop("Unable to extract content from LLM response", call. = FALSE)
}
