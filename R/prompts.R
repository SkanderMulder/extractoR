#' Build extraction prompt for LLM
#'
#' Creates a prompt that instructs the LLM to extract structured information
#' from text according to a JSON Schema.
#'
#' @param text The text to extract information from
#' @param json_schema The JSON Schema as a string
#'
#' @return A character string containing the prompt
#' @keywords internal
build_extraction_prompt <- function(text, json_schema) {
  glue::glue('
Extract structured information from the following text as JSON.

You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:
{json_schema}

Rules:
- Do not add extra fields
- Do not wrap in markdown code blocks
- Do not add explanations
- Output raw JSON only

Text:
{text}

Valid JSON:
  ')
}

#' Build correction prompt
#'
#' Creates a prompt to ask the LLM to fix validation errors
#'
#' @param text Original text
#' @param json_schema JSON Schema string
#' @param error_summary Formatted error messages
#' @param strategy Correction strategy: "reflect", "direct", or "polite"
#'
#' @return A character string containing the correction prompt
#' @keywords internal
build_correction_prompt <- function(text, json_schema, error_summary, strategy = "reflect") {
  switch(strategy,
    reflect = glue::glue("
You previously failed to produce valid JSON. Here is the validation error:
{error_summary}

Think step-by-step:
1. What exactly went wrong?
2. How should it be fixed?
3. Now output ONLY the corrected JSON.

Text: {text}
Schema: {json_schema}

Corrected JSON:
    "),
    direct = glue::glue("
FIX THIS JSON. Errors:
{error_summary}

Correct JSON only:
    "),
    polite = glue::glue("
Please fix the following validation errors and respond with valid JSON only:
{error_summary}

Expected schema:
{json_schema}

Corrected JSON:
    ")
  )
}
