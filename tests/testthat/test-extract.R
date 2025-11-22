library(testthat)
library(extractoR)
library(S7)

# Tests for as_json_schema ----

test_that("as_json_schema converts basic types correctly", {
  schema <- list(
    name = "character",
    age = "integer",
    is_active = "logical",
    score = "numeric"
  )
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
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
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
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
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
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
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
  expect_equal(json_schema$properties$items$type, "array")
  expect_equal(json_schema$properties$items$items$type, "object")
  expect_equal(json_schema$properties$items$items$properties$name$type, "string")
  expect_equal(json_schema$properties$items$items$properties$price$type, "number")
})

test_that("as_json_schema handles enums", {
  schema <- list(
    status = c("draft", "published", "archived")
  )
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
  expect_equal(json_schema$properties$status$type, "string")
  expect_equal(json_schema$properties$status$enum, c("draft", "published", "archived"))
})

test_that("as_json_schema handles arrays of numeric", {
  schema <- list(scores = list("numeric"))
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
  expect_equal(json_schema$properties$scores$type, "array")
  expect_equal(json_schema$properties$scores$items$type, "number")
})

test_that("as_json_schema handles arrays of logical", {
  schema <- list(flags = list("logical"))
  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
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
  schema_list <- list(
    title = "character",
    year = "integer"
  )
  json_schema_obj <- as_json_schema(schema_list)

  # This should succeed immediately without calling the LLM
  result <- validate_and_fix(
    initial_response = valid_json,
    json_schema_obj = json_schema_obj,
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
  schema_list <- list(
    title = "character",
    year = "integer"
  )
  json_schema_obj <- as_json_schema(schema_list)
  json_schema_str <- json_schema_obj@json_schema_str

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

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

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

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

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

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # Missing 'age' field
  invalid_json <- '{"name": "John"}'

  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})

test_that("schema validation catches enum violations", {
  schema <- list(
    status = c("active", "inactive", "pending")
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # Invalid enum value
  invalid_json <- '{"status": "completed"}'

  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})

# Tests for optional fields ----

test_that("optional() creates OptionalField objects", {
  opt_field <- optional("character")
  expect_s7_class(opt_field, "OptionalField")
  expect_equal(opt_field@value, "character")
})

test_that("is_optional() correctly identifies optional fields", {
  opt_field <- optional("integer")
  reg_field <- "character"

  expect_true(is_optional(opt_field))
  expect_false(is_optional(reg_field))
})

test_that("unwrap_optional() extracts value from optional fields", {
  opt_field <- optional("numeric")
  expect_equal(unwrap_optional(opt_field), "numeric")

  # Should return the same value for non-optional fields
  reg_field <- "character"
  expect_equal(unwrap_optional(reg_field), "character")
})

test_that("as_json_schema handles optional atomic types", {
  schema <- list(
    name = "character",           # required
    age = optional("integer"),    # optional
    email = optional("character") # optional
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_s7_class(json_schema_obj, "JsonSchema")
  expect_equal(json_schema$properties$name$type, "string")
  expect_equal(json_schema$properties$age$type, "integer")
  expect_equal(json_schema$properties$email$type, "string")

  # Only 'name' should be required
  expect_equal(json_schema$required, "name")
})

test_that("as_json_schema handles all optional fields", {
  schema <- list(
    age = optional("integer"),
    email = optional("character")
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  # No required fields
  expect_length(json_schema$required, 0)
  expect_equal(json_schema$properties$age$type, "integer")
  expect_equal(json_schema$properties$email$type, "string")
})

test_that("as_json_schema handles optional arrays", {
  schema <- list(
    name = "character",
    tags = optional(list("character")),
    scores = optional(list("numeric"))
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_equal(json_schema$properties$tags$type, "array")
  expect_equal(json_schema$properties$tags$items$type, "string")
  expect_equal(json_schema$properties$scores$type, "array")
  expect_equal(json_schema$properties$scores$items$type, "number")
  expect_equal(json_schema$required, "name")
})

test_that("as_json_schema handles optional enums", {
  schema <- list(
    name = "character",
    status = optional(c("active", "inactive", "pending"))
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_equal(json_schema$properties$status$type, "string")
  expect_equal(json_schema$properties$status$enum, c("active", "inactive", "pending"))
  expect_equal(json_schema$required, "name")
})

test_that("as_json_schema handles optional nested objects", {
  schema <- list(
    name = "character",
    metadata = optional(list(
      created = "character",
      updated = "character"
    ))
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_equal(json_schema$properties$metadata$type, "object")
  expect_equal(json_schema$properties$metadata$properties$created$type, "string")
  expect_equal(json_schema$properties$metadata$properties$updated$type, "string")
  expect_equal(json_schema$required, "name")
})

test_that("as_json_schema handles optional arrays of objects", {
  schema <- list(
    title = "character",
    comments = optional(list(list(
      user = "character",
      text = "character"
    )))
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema <- jsonlite::fromJSON(json_schema_obj@json_schema_str)

  expect_equal(json_schema$properties$comments$type, "array")
  expect_equal(json_schema$properties$comments$items$type, "object")
  expect_equal(json_schema$properties$comments$items$properties$user$type, "string")
  expect_equal(json_schema$required, "title")
})

test_that("schema validation accepts missing optional fields", {
  schema <- list(
    name = "character",
    age = optional("integer"),
    email = optional("character")
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # Valid: only required field present
  valid_json <- '{"name": "John"}'
  is_valid <- jsonvalidate::json_validate(valid_json, json_schema_str, engine = "ajv")
  expect_true(is_valid)

  # Valid: some optional fields present
  valid_json2 <- '{"name": "John", "age": 30}'
  is_valid2 <- jsonvalidate::json_validate(valid_json2, json_schema_str, engine = "ajv")
  expect_true(is_valid2)

  # Valid: all fields present
  valid_json3 <- '{"name": "John", "age": 30, "email": "john@example.com"}'
  is_valid3 <- jsonvalidate::json_validate(valid_json3, json_schema_str, engine = "ajv")
  expect_true(is_valid3)
})

test_that("schema validation rejects missing required fields even with optional fields present", {
  schema <- list(
    name = "character",
    age = optional("integer")
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # Invalid: missing required field 'name'
  invalid_json <- '{"age": 30}'
  is_valid <- jsonvalidate::json_validate(invalid_json, json_schema_str, engine = "ajv")
  expect_false(is_valid)
})

test_that("complex schema with mix of required and optional fields validates correctly", {
  schema <- list(
    title = "character",
    year = "integer",
    author = list(
      name = "character",
      email = optional("character")
    ),
    tags = optional(list("character")),
    status = optional(c("draft", "published"))
  )

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  # Valid: all required fields, no optional fields
  valid_json <- '{
    "title": "Test Article",
    "year": 2023,
    "author": {
      "name": "John Doe"
    }
  }'
  is_valid <- jsonvalidate::json_validate(valid_json, json_schema_str, engine = "ajv")
  expect_true(is_valid)

  # Valid: all fields including optional
  valid_json2 <- '{
    "title": "Test Article",
    "year": 2023,
    "author": {
      "name": "John Doe",
      "email": "john@example.com"
    },
    "tags": ["R", "testing"],
    "status": "published"
  }'
  is_valid2 <- jsonvalidate::json_validate(valid_json2, json_schema_str, engine = "ajv")
  expect_true(is_valid2)
})
