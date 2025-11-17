#' @title Build Initial Extraction Prompt
#' @description Creates the initial prompt for extracting structured data
#' @param text The input text to extract from
#' @param json_schema The JSON schema as a string
#' @return A character string containing the prompt
#' @keywords internal
build_extraction_prompt <- function(text, json_schema) {
  paste0(
    "Extract structured information from the following text as JSON.\n\n",
    "You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:\n",
    json_schema,
    "\n\nRules:\n",
    "- Do not add extra fields\n",
    "- Do not wrap in markdown\n",
    "- Do not add explanations\n",
    "- Output raw JSON only\n\n",
    "Text:\n",
    text,
    "\n\nValid JSON:\n"
  )
}

#' @title Build Reflect Strategy Prompt
#' @description Creates a correction prompt using the reflect strategy
#' @param error_summary Summary of validation errors
#' @param text The original input text
#' @param json_schema_str The JSON schema as a string
#' @return A character string containing the correction prompt
#' @keywords internal
build_reflect_prompt <- function(error_summary, text, json_schema_str) {
  paste0(
    "Your previous response had validation errors:\n",
    error_summary,
    "\n\nPlease reflect on these errors and provide a corrected JSON response that:\n",
    "1. Fixes all validation errors\n",
    "2. Conforms to this JSON Schema:\n",
    json_schema_str,
    "\n\n3. Is based on this text:\n",
    text,
    "\n\nProvide ONLY valid JSON, no explanations.\n"
  )
}

#' @title Build Direct Strategy Prompt
#' @description Creates a correction prompt using the direct strategy
#' @param error_summary Summary of validation errors
#' @return A character string containing the correction prompt
#' @keywords internal
build_direct_prompt <- function(error_summary) {
  paste0(
    "Your response had these validation errors:\n",
    error_summary,
    "\n\nFix these errors and provide valid JSON only.\n"
  )
}

#' @title Build Polite Strategy Prompt
#' @description Creates a correction prompt using the polite strategy
#' @param error_summary Summary of validation errors
#' @return A character string containing the correction prompt
#' @keywords internal
build_polite_prompt <- function(error_summary) {
  paste0(
    "Thank you for your response. However, there were some validation issues:\n",
    error_summary,
    "\n\nCould you please provide a corrected JSON response? Thank you!\n"
  )
}