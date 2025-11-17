#' Extract structured information from text using LLMs
#'
#' This is the main function to extract structured information from unstructured
#' text using a Large Language Model (LLM) and a user-defined schema. It
#' includes an automatic self-correction loop to ensure the output conforms
#' to the schema.
#'
#' @param text A character string containing the unstructured text to extract from.
#' @param schema A list defining the desired output structure. This will be
#'   converted into a JSON Schema for validation.
#'   Example: `list(title = "character", year = "integer", topics = list("character"))`
#' @param model A character string specifying the LLM to use (e.g., "gpt-4o-mini").
#' @param max_retries An integer specifying the maximum number of retry attempts
#'   if the LLM initially returns malformed JSON.
#' @param strategy A character string specifying the retry strategy:
#'   "reflect" (default, provides detailed feedback to the LLM),
#'   "direct" (sends only errors), or "polite" (a softer request for correction).
#' @param temperature A numeric value for the LLM's temperature (0.0 to 1.0).
#'   Lower values make the output more deterministic.
#' @param .progress A logical value indicating whether to show progress messages.
#'
#' @return A list containing the extracted and validated information, conforming
#'   to the specified schema.
#' @export
#'
#' @examples
#' \dontrun{
#'   # Assuming you have an ellmer API key set up
#'   # Sys.setenv(ELLMER_API_KEY = "YOUR_API_KEY")
#'
#'   article_text <- "The quick brown fox jumps over the lazy dog. This is a test article from 2023."
#'   my_schema <- list(
#'     main_subject = "character",
#'     year_published = "integer",
#'     keywords = list("character")
#'   )
#'
#'   result <- extract(
#'     text = article_text,
#'     schema = my_schema,
#'     model = "gpt-4o-mini"
#'   )
#'
#'   str(result)
#'
#'   # Example with Ollama (make sure Ollama is running)
#'   # result_ollama <- extract(
#'   #   text = "The new phone has a great camera, but the battery life is poor.",
#'   #   schema = list(
#'   #     sentiment = c("positive", "negative", "neutral"),
#'   #     features = list(list(name = "character", rating = c("good", "bad", "average")))
#'   #   ),
#'   #   model = "ollama/gemma:2b"
#'   # )
#' }
extract <- function(text,
                    schema,
                    model = "gpt-4o-mini",
                    max_retries = 5,
                    strategy = c("reflect", "direct", "polite"),
                    temperature = 0.0,
                    .progress = TRUE) {
  # Validate strategy argument
  strategy <- match.arg(strategy)

  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Package 'ellmer' is required but not installed. Please install it.", call. = FALSE)
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required but not installed. Please install it.", call. = FALSE)
  }
  if (!requireNamespace("jsonvalidate", quietly = TRUE)) {
    stop("Package 'jsonvalidate' is required but not installed. Please install it.", call. = FALSE)
  }
  if (!requireNamespace("cli", quietly = TRUE)) {
    stop("Package 'cli' is required but not installed. Please install it.", call. = FALSE)
  }
  if (!requireNamespace("glue", quietly = TRUE)) {
    stop("Package 'glue' is required but not installed. Please install it.", call. = FALSE)
  }

  if (.progress) {
    cli::cli_h1("Starting instructoR extraction")
    cli::cli_alert_info("Converting R schema to JSON Schema...")
  }

  # Convert R schema to JSON Schema string
  json_schema_str <- as_json_schema(schema)

  if (.progress) {
    cli::cli_alert_info("Building initial extraction prompt...")
  }

  # Build initial prompt
  initial_prompt <- build_extraction_prompt(text, json_schema_str)

  if (.progress) {
    cli::cli_alert_info("Calling LLM for initial extraction (model: {model})...")
  }

  # Initial LLM call
  initial_response <- tryCatch({
    result <- ellmer::chat(
      model = model,
      system = "You are a helpful assistant that outputs valid JSON.",
      turns = list(list(role = "user", content = initial_prompt)),
      temperature = temperature
    )
    extract_content(result)
  }, error = function(e) {
    stop("Initial LLM call failed: ", e$message, call. = FALSE)
  })

  if (.progress) {
    cli::cli_alert_info("Validating and potentially fixing LLM response...")
  }

  # Validate and fix
  final_result <- validate_and_fix(
    initial_response = initial_response,
    json_schema_str = json_schema_str,
    text = text,
    model = model,
    strategy = strategy,
    max_retries = max_retries,
    temperature = temperature,
    .progress = .progress
  )

  if (.progress) {
    cli::cli_alert_success("Extraction complete!")
  }

  return(final_result)
}