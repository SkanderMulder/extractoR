library(testthat)
library(instructoR)

# Tests for as_json_schema ----

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
  expect_equal(json_schema$required, c("name", "age", "is_active", "score"))
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
})

test_that("as_json_schema handles arrays of objects", {
  schema <- list(
    items = list(list(
      name = "character",
      price = "numeric"
    ))
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$items$type, "array")
  expect_equal(json_schema$properties$items$items$type, "object")
  expect_equal(json_schema$properties$items$items$properties$name$type, "string")
  expect_equal(json_schema$properties$items$items$properties$price$type, "number")
})

test_that("as_json_schema handles enums", {
  schema <- list(
    status = c("draft", "published", "archived")
  )
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$status$type, "string")
  expect_equal(json_schema$properties$status$enum, c("draft", "published", "archived"))
})

test_that("as_json_schema handles arrays of numeric", {
  schema <- list(scores = list("numeric"))
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$scores$type, "array")
  expect_equal(json_schema$properties$scores$items$type, "number")
})

test_that("as_json_schema handles arrays of logical", {
  schema <- list(flags = list("logical"))
  json_schema <- as_json_schema(schema)

  expect_equal(json_schema$properties$flags$type, "array")
  expect_equal(json_schema$properties$flags$items$type, "boolean")
})

test_that("as_json_schema throws error for non-list schema", {
  expect_error(as_json_schema("not a list"), "Schema must be a list")
})

test_that("as_json_schema throws error for unsupported atomic type", {
  schema <- list(field = "unsupported_type")
  expect_error(as_json_schema(schema), "Unsupported atomic type")
})

test_that("as_json_schema throws error for unsupported array item type", {
  schema <- list(items = list("unsupported_type"))
  expect_error(as_json_schema(schema), "Unsupported array item type")
})

# Tests for prompt builders ----

test_that("build_extraction_prompt creates correct prompt structure", {
  text <- "Some sample text."
  json_schema_str <- '{"type": "object", "properties": {"key": {"type": "string"}}}'
  prompt <- build_extraction_prompt(text, json_schema_str)

  expect_true(grepl("Extract structured information from the following text as JSON.", prompt, fixed = TRUE))
  expect_true(grepl("You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:", prompt, fixed = TRUE))
  expect_true(grepl(json_schema_str, prompt, fixed = TRUE))
  expect_true(grepl("Some sample text.", prompt, fixed = TRUE))
  expect_true(grepl("Valid JSON:", prompt, fixed = TRUE))
})

test_that("build_reflect_prompt includes all required elements", {
  error_summary <- "Field 'year' must be an integer"
  text <- "Sample text"
  json_schema_str <- '{"type": "object"}'

  prompt <- build_reflect_prompt(error_summary, text, json_schema_str)

  expect_true(grepl("validation errors", prompt, fixed = TRUE))
  expect_true(grepl(error_summary, prompt, fixed = TRUE))
  expect_true(grepl(text, prompt, fixed = TRUE))
  expect_true(grepl(json_schema_str, prompt, fixed = TRUE))
})

test_that("build_direct_prompt includes error summary", {
  error_summary <- "Field 'year' must be an integer"
  prompt <- build_direct_prompt(error_summary)

  expect_true(grepl("validation errors", prompt, fixed = TRUE))
  expect_true(grepl(error_summary, prompt, fixed = TRUE))
  expect_true(grepl("Fix these errors", prompt, fixed = TRUE))
})

test_that("build_polite_prompt uses courteous language", {
  error_summary <- "Field 'year' must be an integer"
  prompt <- build_polite_prompt(error_summary)

  expect_true(grepl("Thank you", prompt, fixed = TRUE))
  expect_true(grepl(error_summary, prompt, fixed = TRUE))
  expect_true(grepl("please", prompt, fixed = TRUE))
})

# Tests for format_validation_errors ----

test_that("format_validation_errors handles single error", {
  errors <- list(list(message = "Error 1", dataPath = ".field", schemaPath = "#/properties/field"))
  formatted <- format_validation_errors(errors)
  expect_true(grepl("- Error 1 (Path: .field, Schema: #/properties/field)", formatted, fixed = TRUE))
})

test_that("format_validation_errors handles multiple errors", {
  errors <- list(
    list(message = "Error 1", dataPath = ".field1", schemaPath = "#/properties/field1"),
    list(message = "Error 2", dataPath = ".field2", schemaPath = "#/properties/field2")
  )
  formatted <- format_validation_errors(errors)

  expect_true(grepl("- Error 1", formatted))
  expect_true(grepl("- Error 2", formatted))
  expect_true(grepl("\n", formatted))
})

test_that("format_validation_errors handles empty errors", {
  errors <- list()
  formatted <- format_validation_errors(errors)
  expect_equal(formatted, "No specific errors reported.")
})

test_that("format_validation_errors handles NULL errors", {
  formatted <- format_validation_errors(NULL)
  expect_equal(formatted, "No specific errors reported.")
})

# Tests for validate_and_fix (without mocking ellmer) ----

test_that("validate_and_fix returns valid response immediately", {
  valid_json <- '{"title": "Test", "year": 2023}'
  json_schema_str <- jsonlite::toJSON(list(
    type = "object",
    properties = list(
      title = list(type = "string"),
      year = list(type = "integer")
    )
  ), auto_unbox = TRUE)

  # This should succeed immediately without calling the LLM
  result <- validate_and_fix(
    initial_response = valid_json,
    json_schema_str = json_schema_str,
    text = "dummy",
    model = "dummy",
    strategy = "direct",
    max_retries = 1,
    .progress = FALSE
  )

  expect_equal(result$title, "Test")
  expect_equal(result$year, 2023)
  expect_equal(attr(result, "attempts"), 1)
})

test_that("validate_and_fix detects invalid JSON", {
  invalid_json <- '{"title": "Test", "year": "not_a_number"}'
  json_schema_str <- jsonlite::toJSON(list(
    type = "object",
    properties = list(
      title = list(type = "string"),
      year = list(type = "integer")
    )
  ), auto_unbox = TRUE)

  # Should fail validation - we test that it fails, not the retry mechanism
  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)

  errors <- attr(jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv", verbose = TRUE), "errors")
  expect_true(length(errors) > 0)
})

# Integration-style tests for schema validation ----

test_that("complex nested schema validates correctly", {
  schema <- list(
    metadata = list(
      title = "character",
      author = list(
        name = "character",
        email = "character"
      )
    ),
    tags = list("character"),
    status = c("draft", "published")
  )

  json_schema <- as_json_schema(schema)
  json_schema_str <- jsonlite::toJSON(json_schema, auto_unbox = TRUE, pretty = TRUE)

  # Valid JSON
  valid_json <- '{
    "metadata": {
      "title": "Test Article",
      "author": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    },
    "tags": ["R", "testing"],
    "status": "published"
  }'

  is_valid <- jsonvalidate::json_validate(valid_json, json_schema_str, engine = "ajv")
  expect_true(is_valid)
})

test_that("schema validation catches type mismatches", {
  schema <- list(
    age = "integer",
    score = "numeric"
  )

  json_schema <- as_json_schema(schema)
  json_schema_str <- jsonlite::toJSON(json_schema, auto_unbox = TRUE)

  # Invalid: age is string instead of integer
  invalid_json <- '{"age": "thirty", "score": 85.5}'

  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})

test_that("schema validation catches missing required fields", {
  schema <- list(
    name = "character",
    age = "integer"
  )

  json_schema <- as_json_schema(schema)
  json_schema_str <- jsonlite::toJSON(json_schema, auto_unbox = TRUE)

  # Missing 'age' field
  invalid_json <- '{"name": "John"}'

  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})

test_that("schema validation catches enum violations", {
  schema <- list(
    status = c("active", "inactive", "pending")
  )

  json_schema <- as_json_schema(schema)
  # Don't use auto_unbox for single-element arrays like 'required'
  json_schema_str <- jsonlite::toJSON(json_schema, pretty = TRUE)

  # Invalid enum value
  invalid_json <- '{"status": "completed"}'

  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})
