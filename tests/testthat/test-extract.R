library(testthat)
library(instructoR)
library(jsonlite)
library(jsonvalidate)
library(withr)
library(ellmer) # For mocking

# Mock ellmer::chat for testing purposes
mock_ellmer_chat <- function(model, system = NULL, turns, temperature) {
  # This mock function will return different responses based on the prompt
  # For simplicity, let's assume the first call is always invalid, and the second is valid
  # In a real scenario, you might inspect 'turns' to decide the response
  
  last_user_message <- turns[[length(turns)]]$content

  if (grepl("FIX THIS JSON", last_user_message) || grepl("You previously failed", last_user_message)) {
    # This is a retry call, return valid JSON
    return(list(content = '{"name": "Valid Name", "age": 30}'))
  } else {
    # This is the initial call, return invalid JSON
    return(list(content = '{"name": "Invalid Name", "age": "thirty"}'))
  }
}

# Test as_json_schema
test_that("as_json_schema converts R list to JSON Schema correctly", {
  schema <- list(
    name = "character",
    age = "integer",
    topics = list("character"),
    metadata = list(
      created = "character",
      updated = "character"
    )
  )
  json_schema_str <- as_json_schema(schema)
  json_schema <- fromJSON(json_schema_str)

  expect_equal(json_schema$type, "object")
  expect_equal(json_schema$properties$name$type, "string")
  expect_equal(json_schema$properties$age$type, "integer")
  expect_equal(json_schema$properties$topics$type, "array")
  expect_equal(json_schema$properties$topics$items$type, "string")
  expect_equal(json_schema$properties$metadata$type, "object")
  expect_true("name" %in% json_schema$required)
  expect_true("created" %in% json_schema$properties$metadata$required)
})

test_that("as_json_schema handles enum types", {
  schema <- list(
    sentiment = c("positive", "negative", "neutral")
  )
  json_schema_str <- as_json_schema(schema)
  json_schema <- fromJSON(json_schema_str)

  expect_equal(json_schema$properties$sentiment$type, "string")
  expect_equal(json_schema$properties$sentiment$enum, c("positive", "negative", "neutral"))
})

# Test format_validation_errors
test_that("format_validation_errors formats errors correctly", {
  errors_df <- data.frame(
    instancePath = c("/age", "/name"),
    schemaPath = c("#/properties/age/type", "#/properties/name/type"),
    keyword = c("type", "type"),
    message = c("expected integer, got string", "expected string, got number"),
    params = c("integer", "string"),
    schema = c("integer", "string"),
    data = c("thirty", "123"),
    stringsAsFactors = FALSE
  )
  
  # Simulate the structure returned by jsonvalidate::json_validate(error = TRUE)
  errors_attr <- list(
    list(instancePath = "/age", message = "expected integer, got string", schemaPath = "#/properties/age/type"),
    list(instancePath = "/name", message = "expected string, got number", schemaPath = "#/properties/name/type")
  )
  attr(errors_df, "errors") <- errors_attr

  formatted_errors <- format_validation_errors(attr(errors_df, "errors"))
  expect_true(grepl("- expected integer, got string at '/age'", formatted_errors))
  expect_true(grepl("- expected string, got number at '/name'", formatted_errors))
})

# Test clean_json_response
test_that("clean_json_response removes markdown and trims whitespace", {
  response_md <- "```json\n{\"key\": \"value\"}\n```"
  response_plain <- "  {\"key\": \"value\"}  "
  response_mixed <- "```\n{\"key\": \"value\"}\n```"

  expect_equal(clean_json_response(response_md), '{"key": "value"}')
  expect_equal(clean_json_response(response_plain), '{"key": "value"}')
  expect_equal(clean_json_response(response_mixed), '{"key": "value"}')
})

# Test extract_content
test_that("extract_content extracts content from ellmer results", {
  # ellmer::chat returns a list with a 'content' element
  result1 <- list(content = "Hello")
  expect_equal(extract_content(result1), "Hello")

  # ellmer::chat might return a list with choices (e.g., OpenAI API)
  result2 <- list(
    choices = list(
      list(
        message = list(content = "World")
      )
    )
  )
  expect_equal(extract_content(result2), "World")

  # ellmer::chat might return a simple character string
  result3 <- "Simple string"
  expect_equal(extract_content(result3), "Simple string")

  # Test for error when content cannot be extracted
  result_bad <- list(foo = "bar")
  expect_error(extract_content(result_bad), "Unable to extract content from LLM response")
})

# Test build_extraction_prompt
test_that("build_extraction_prompt creates correct prompt", {
  text <- "Some text."
  json_schema <- '{"type": "object"}'
  prompt <- build_extraction_prompt(text, json_schema)

  expect_true(grepl("Extract structured information from the following text as JSON.", prompt))
  expect_true(grepl("You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:", prompt))
  expect_true(grepl('{"type": "object"}', prompt))
  expect_true(grepl("Text:\nSome text.", prompt))
  expect_true(grepl("Output raw JSON only", prompt))
})

# Test build_correction_prompt
test_that("build_correction_prompt creates correct prompt for reflect strategy", {
  text <- "Some text."
  json_schema <- '{"type": "object"}'
  error_summary <- "Error: Invalid type."
  prompt <- build_correction_prompt(text, json_schema, error_summary, strategy = "reflect")

  expect_true(grepl("You previously failed to produce valid JSON.", prompt))
  expect_true(grepl("Here is the validation error:\nError: Invalid type.", prompt))
  expect_true(grepl("Think step-by-step:", prompt))
  expect_true(grepl("Now output ONLY the corrected JSON.", prompt))
  expect_true(grepl("Text: Some text.", prompt))
  expect_true(grepl('Schema: {"type": "object"}', prompt))
})

test_that("build_correction_prompt creates correct prompt for direct strategy", {
  text <- "Some text."
  json_schema <- '{"type": "object"}'
  error_summary <- "Error: Invalid type."
  prompt <- build_correction_prompt(text, json_schema, error_summary, strategy = "direct")

  expect_true(grepl("FIX THIS JSON. Errors:\nError: Invalid type.", prompt))
  expect_true(grepl("Correct JSON only:", prompt))
})

test_that("build_correction_prompt creates correct prompt for polite strategy", {
  text <- "Some text."
  json_schema <- '{"type": "object"}'
  error_summary <- "Error: Invalid type."
  prompt <- build_correction_prompt(text, json_schema, error_summary, strategy = "polite")

  expect_true(grepl("Please fix the following validation errors and respond with valid JSON only:", prompt))
  expect_true(grepl("Expected schema:\n", prompt))
  expect_true(grepl('{"type": "object"}', prompt))
})

# Test validate_and_fix
test_that("validate_and_fix retries and returns valid JSON", {
  # Temporarily replace ellmer::chat with our mock
  with_mocked_bindings(
    ellmer::chat = mock_ellmer_chat,
    .package = "ellmer", # Specify the package where ellmer::chat is defined
    {
      initial_response_invalid <- '{"name": "Invalid Name", "age": "thirty"}'
      json_schema_str <- as_json_schema(list(name = "character", age = "integer"))
      
      result <- validate_and_fix(
        initial_response = initial_response_invalid,
        json_schema_str = json_schema_str,
        text = "Some text",
        model = "mock-model",
        max_retries = 2,
        .progress = FALSE
      )
      
      expect_type(result, "list")
      expect_equal(result$name, "Valid Name")
      expect_equal(result$age, 30)
    }
  )
})

test_that("validate_and_fix stops after max_retries if still invalid", {
  # Temporarily replace ellmer::chat with a mock that always returns invalid JSON
  with_mocked_bindings(
    ellmer::chat = function(...) {
      list(content = '{"name": "Still Invalid", "age": "not-a-number"}')
    },
    .package = "ellmer",
    {
      initial_response_invalid <- '{"name": "Invalid Name", "age": "thirty"}'
      json_schema_str <- as_json_schema(list(name = "character", age = "integer"))
      
      expect_error(
        validate_and_fix(
          initial_response = initial_response_invalid,
          json_schema_str = json_schema_str,
          text = "Some text",
          model = "mock-model",
          max_retries = 1, # Only one retry allowed
          .progress = FALSE
        ),
        "Failed to extract valid structure after 1 attempts"
      )
    }
  )
})

# Test extract (integration test with mock)
test_that("extract function works end-to-end with mocking", {
  # Temporarily replace ellmer::chat with our mock
  with_mocked_bindings(
    ellmer::chat = mock_ellmer_chat,
    .package = "ellmer",
    {
      schema <- list(name = "character", age = "integer")
      text <- "John Doe is 30 years old."
      
      result <- extract(
        text = text,
        schema = schema,
        model = "mock-model",
        max_retries = 2,
        .progress = FALSE
      )
      
      expect_type(result, "list")
      expect_equal(result$name, "Valid Name")
      expect_equal(result$age, 30)
    }
  )
})
