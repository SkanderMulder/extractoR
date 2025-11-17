library(testthat)
library(instructoR)

test_that("as_json_schema converts basic types correctly", {
  schema <- list(
    name = "character",
    age = "integer",
    is_active = "logical",
    score = "numeric"
  )
  json_schema <- as_json_schema(schema)

  expect_type(json_schema, "list")
  expect_equal(json_schema$type, "object")
  expect_equal(json_schema$properties$name$type, "string")
  expect_equal(json_schema$properties$age$type, "integer")
  expect_equal(json_schema$properties$is_active$type, "boolean")
  expect_equal(json_schema$properties$score$type, "number")
  expect_equal(json_schema$required, c("name", "age", "is_active", "score") )
})

test_that("as_json_schema handles arrays of atomic types", {
  schema <- list(
    tags = list("character"),
    numbers = list("integer")
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$tags$type, "array")
  expect_equal(json_schema$properties$tags$items$type, "string")
  expect_equal(json_schema$properties$numbers$type, "array")
  expect_equal(json_schema$properties$numbers$items$type, "integer")
})

test_that("as_json_schema handles nested objects", {
  schema <- list(
    person = list(
      name = "character",
      address = list(
        street = "character",
        zip = "integer"
      )
    )
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$person$type, "object")
  expect_equal(json_schema$properties$person$properties$name$type, "string")
  expect_equal(json_schema$properties$person$properties$address$type, "object")
  expect_equal(json_schema$properties$person$properties$address$properties$street$type, "string")
  expect_equal(json_schema$properties$person$properties$address$properties$zip$type, "integer")
})

test_that("as_json_schema handles arrays of objects", {
  schema <- list(
    entities = list(list(name = "character", type = "character"))
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$entities$type, "array")
  expect_equal(json_schema$properties$entities$items$type, "object")
  expect_equal(json_schema$properties$entities$items$properties$name$type, "string")
  expect_equal(json_schema$properties$entities$items$properties$type$type, "string")
})

test_that("as_json_schema handles enums", {
  schema <- list(
    sentiment = c("positive", "negative", "neutral")
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$sentiment$type, "string")
  expect_equal(json_schema$properties$sentiment$enum, c("positive", "negative", "neutral") )
})

test_that("build_extraction_prompt creates correct prompt structure", {
  text <- "Some sample text."
  json_schema_str <- '{"type": "object", "properties": {"key": {"type": "string"}}}'
  prompt <- build_extraction_prompt(text, json_schema_str)

  expect_true(grepl("Extract structured information from the following text as JSON.", prompt))
  expect_true(grepl("You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:", prompt))
  expect_true(grepl(json_schema_str, prompt))
  expect_true(grepl("Text:\n    Some sample text.", prompt))
  expect_true(grepl("Valid JSON:", prompt))
})

test_that("format_validation_errors handles single error", {
  errors <- list(list(message = "Error 1", dataPath = ".field", schemaPath = "#/properties/field"))
  formatted <- format_validation_errors(errors)
  expect_true(grepl("- Error 1 (Path: .field, Schema: #/properties/field)", formatted))
})

test_that("format_validation_errors handles multiple errors", {
  errors <- list(
    list(message = "Error 1", dataPath = ".field1", schemaPath = "#/properties/field1"),
    list(message = "Error 2", dataPath = ".field2", schemaPath = "#/properties/field2")
  )
  formatted <- format_validation_errors(errors)
  expect_true(grepl("- Error 1", formatted))
  expect_true(grepl("- Error 2", formatted))
  expect_true(grepl("\n", formatted)) # Check for line breaks between errors
})

# Mock ellmer::chat for testing extract and validate_and_fix without actual API calls
mock_chat_success <- function(...) {
  list(content = '{"title": "Test Title", "year": 2023, "topics": ["R", "Testing"], "is_open_access": true}')
}

mock_chat_fail_then_success <- function(...) {
  args <- list(...)
  messages <- args$messages
  last_message <- messages[[length(messages)]]$content

  if (grepl("FIX THIS JSON", last_message) || grepl("You previously failed", last_message)) {
    # Second attempt, return valid JSON
    list(content = '{"title": "Corrected Title", "year": 2024, "topics": ["Corrected"], "is_open_access": false}')
  } else {
    # First attempt, return invalid JSON
    list(content = '{"title": "Invalid", "year": "not_a_number"}')
  }
}

test_that("extract works with valid initial response", {
  # Temporarily mock ellmer::chat
  with_mocked_bindings(
    chat = mock_chat_success,
    .package = "ellmer",
    {
      schema <- list(
        title = "character",
        year = "integer",
        topics = list("character"),
        is_open_access = "logical"
      )
      result <- extract(
        text = "Some text",
        schema = schema,
        model = "mock-model",
        max_retries = 1,
        .progress = FALSE
      )
      expect_equal(result$title, "Test Title")
      expect_equal(result$year, 2023)
      expect_equal(result$topics, c("R", "Testing") )
      expect_equal(result$is_open_access, TRUE)
      expect_equal(attr(result, "attempts"), 1)
    }
  )
})

test_that("extract retries and fixes malformed JSON", {
  # Temporarily mock ellmer::chat
  with_mocked_bindings(
    chat = mock_chat_fail_then_success,
    .package = "ellmer",
    {
      schema <- list(
        title = "character",
        year = "integer",
        topics = list("character"),
        is_open_access = "logical"
      )
      result <- extract(
        text = "Some text",
        schema = schema,
        model = "mock-model",
        max_retries = 2,
        strategy = "direct",
        .progress = FALSE
      )
      expect_equal(result$title, "Corrected Title")
      expect_equal(result$year, 2024)
      expect_equal(attr(result, "attempts"), 2)
    }
  )
})

test_that("extract stops and errors after max_retries", {
  # Temporarily mock ellmer::chat to always return invalid JSON
  mock_chat_always_fail <- function(...) {
    list(content = '{"title": "Invalid", "year": "not_a_number"}')
  }

  with_mocked_bindings(
    chat = mock_chat_always_fail,
    .package = "ellmer",
    {
      schema <- list(
        title = "character",
        year = "integer",
        topics = list("character"),
        is_open_access = "logical"
      )
      expect_error(
        extract(
          text = "Some text",
          schema = schema,
          model = "mock-model",
          max_retries = 1,
          .progress = FALSE
        ),
        "Failed to extract valid structure after 1 attempts."
      )
    }
  )
})