library(S7)

#' @title Extract Structured Information from Text using LLMs
#'
#' @description
#' Main user function to extract structured information from unstructured text
#' using Large Language Models (LLMs) with automatic self-correction.
#'
#' @param text The input text from which to extract information.
#' @param schema A list defining the desired output structure. This will be
#'   converted into a JSON Schema for validation.
#' @param model The LLM model to use for extraction (e.g., "gpt-4o-mini").
#' @param max_retries The maximum number of times to retry the LLM call with
#'   validation feedback if the initial response is malformed.
#' @param strategy The self-correction strategy to use: "reflect", "direct", or "polite".
#' @param temperature The sampling temperature for the LLM. A value of 0.0
#'   encourages deterministic output.
#' @param .progress Logical, whether to show progress feedback using `cli`.
#'
#' @return A list with the extracted information, guaranteed to conform to the
#'   provided schema.
#' @export
#'
#' @examples
#' \dontrun{
#' # Example usage (requires an LLM API key configured for ellmer)
#' # Sys.setenv(ELLMER_API_KEY = "YOUR_API_KEY")
#'
#' schema <- list(
#'   title = "character",
#'   year = "integer",
#'   topics = list("character"),
#'   is_open_access = "logical"
#' )
#'
#' article_text <- "The paper 'Large Language Models Are Zero-Shot Reasoners'
#'   was published in 2022. It covers topics like natural language processing
#'   and artificial intelligence. It is an open-access publication."
#'
#' result <- extract(
#'   text = article_text,
#'   schema = schema,
#'   model = "gpt-4o-mini",
#'   .progress = FALSE # Set to TRUE to see progress
#' )
#'
#' str(result)
#' # Should return a list like:
#' # List of 4
#' #  $ title         : chr "Large Language Models Are Zero-Shot Reasoners"
#' #  $ year          : int 2022
#' #  $ topics        : List of 2
#' #   ..$ : chr "natural language processing"
#' #   ..$ : chr "artificial intelligence"
#' #  $ is_open_access: logi TRUE
#' }
extract <- function(text,
                    schema,
                    model = "gpt-4o-mini",
                    max_retries = 5,
                    strategy = c("reflect", "direct", "polite"),
                    temperature = 0.0,
                    .progress = TRUE) {
  strategy <- match.arg(strategy)

  # 1. Convert R schema to JSON Schema S7 object
  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # 2. Build initial extraction prompt
  initial_prompt <- build_extraction_prompt(text, json_schema_str)

  if (.progress) {
    cli::cli_h1("Starting Extraction")
    cli::cli_alert_info("Model: {model}")
    cli::cli_alert_info("Max retries: {max_retries}")
    cli::cli_alert_info("Strategy: {strategy}")
    cli::cli_alert_info("Schema: {json_schema_str}")
    cli::cli_alert_info("Sending initial request to LLM...")
  }

  # 3. Initial LLM call
  initial_response <- ellmer::chat(
    model = model,
    messages = list(list(role = "user", content = initial_prompt)),
    temperature = temperature
  )$content

  if (.progress) {
    cli::cli_alert_info("Received initial response. Validating...")
  }

  # 4. Validate and fix loop
  result <- validate_and_fix(
    initial_response = initial_response,
    json_schema_obj = json_schema_obj,
    text = text,
    model = model,
    strategy = strategy,
    max_retries = max_retries,
    .progress = .progress
  )

  if (.progress) {
    cli::cli_alert_success("Extraction successful after {attr(result, 'attempts')} attempts.")
  }

  result
}