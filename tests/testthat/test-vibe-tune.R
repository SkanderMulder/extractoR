test_that("validate_vibe_inputs works correctly", {
  # Valid inputs
  examples <- list(
    list(text = "example 1"),
    list(text = "example 2")
  )
  schema <- list(field = "character")

  expect_silent(validate_vibe_inputs(examples, schema))

  # Invalid: not a list
  expect_error(
    validate_vibe_inputs("not a list", schema),
    "examples must be a non-empty list"
  )

  # Invalid: empty list
  expect_error(
    validate_vibe_inputs(list(), schema),
    "examples must be a non-empty list"
  )

  # Invalid: example without text
  expect_error(
    validate_vibe_inputs(list(list(foo = "bar")), schema),
    "Each example must be a list with a 'text' element"
  )

  # Invalid: schema not a list
  expect_error(
    validate_vibe_inputs(examples, "not a list"),
    "schema must be a list"
  )
})


test_that("generate_prompt_variations creates correct structure", {
  schema_str <- '{"type": "object"}'

  # Test with default number
  variations <- generate_prompt_variations(schema_str, 6)

  expect_type(variations, "list")
  expect_length(variations, 6)
  expect_named(variations, c("concise_direct", "detailed_formal", "encouraging",
                              "example_driven", "step_by_step", "minimal"))

  # Each variation should be a function
  for (var in variations) {
    expect_type(var, "closure")
  }

  # Test that variation functions work
  prompt <- variations$concise_direct("test text", schema_str)
  expect_type(prompt, "character")
  expect_true(nchar(prompt) > 0)
  expect_true(grepl("test text", prompt))
  expect_true(grepl(schema_str, prompt, fixed = TRUE))
})


test_that("generate_prompt_variations respects num_variations", {
  schema_str <- '{"type": "object"}'

  # Test with fewer variations
  variations <- generate_prompt_variations(schema_str, 3)
  expect_length(variations, 3)

  # Test with more than available
  variations <- generate_prompt_variations(schema_str, 10)
  expect_length(variations, 6)  # Max available
})


test_that("calculate_accuracy works correctly", {
  # Perfect match
  extracted <- list(name = "John", age = 30)
  expected <- list(name = "John", age = 30)
  expect_equal(calculate_accuracy(extracted, expected), 1.0)

  # Partial match
  extracted <- list(name = "John", age = 30)
  expected <- list(name = "John", age = 25)
  expect_equal(calculate_accuracy(extracted, expected), 0.5)

  # No match
  extracted <- list(name = "Jane", age = 25)
  expected <- list(name = "John", age = 30)
  expect_equal(calculate_accuracy(extracted, expected), 0.0)

  # Nested structures
  extracted <- list(person = list(name = "John", age = 30))
  expected <- list(person = list(name = "John", age = 30))
  expect_equal(calculate_accuracy(extracted, expected), 1.0)

  # Numeric tolerance
  extracted <- list(score = 0.95)
  expected <- list(score = 0.96)
  expect_equal(calculate_accuracy(extracted, expected), 1.0)  # Within tolerance

  extracted <- list(score = 0.95)
  expected <- list(score = 1.0)
  expect_equal(calculate_accuracy(extracted, expected), 1.0)  # Within tolerance

  extracted <- list(score = 0.95)
  expected <- list(score = 1.1)
  expect_equal(calculate_accuracy(extracted, expected), 0.0)  # Outside tolerance
})


test_that("calculate_accuracy_safe handles NULL and errors", {
  extracted <- list(name = "John")
  expect_true(is.na(calculate_accuracy_safe(extracted, NULL)))

  # Should not error even with mismatched types
  expect_type(calculate_accuracy_safe(list(a = 1), list(a = "string")), "double")
})


test_that("calc_field_match handles different types", {
  # Character match
  expect_equal(calc_field_match("test", "test"), 1)
  expect_equal(calc_field_match("test", "other"), 0)

  # Numeric match
  expect_equal(calc_field_match(5.0, 5.05), 1)  # Within tolerance
  expect_equal(calc_field_match(5.0, 6.0), 0)   # Outside tolerance

  # Logical match
  expect_equal(calc_field_match(TRUE, TRUE), 1)
  expect_equal(calc_field_match(TRUE, FALSE), 0)

  # NULL handling
  expect_equal(calc_field_match(NULL, NULL), 1)
  expect_equal(calc_field_match(NULL, "value"), 0)
  expect_equal(calc_field_match("value", NULL), 0)

  # Nested lists
  expect_equal(
    calc_field_match(list(a = 1), list(a = 1)),
    1
  )
})


test_that("select_best_prompt chooses correctly", {
  metrics_df <- data.frame(
    prompt_id = c("prompt1", "prompt2", "prompt3"),
    success_rate = c(1.0, 0.9, 1.0),
    avg_attempts = c(2, 1, 3),
    avg_time = c(1.0, 1.5, 0.5),
    avg_accuracy = c(0.95, 0.90, 0.98),
    stringsAsFactors = FALSE
  )

  best <- select_best_prompt(metrics_df)

  # Should be one of the prompts
  expect_true(best %in% metrics_df$prompt_id)
  expect_type(best, "character")
})


test_that("NULL coalescing operator works", {
  expect_equal(NULL %||% 5, 5)
  expect_equal(10 %||% 5, 10)
  expect_equal(NA %||% 5, NA)
  expect_equal(0 %||% 5, 0)
  expect_equal(FALSE %||% TRUE, FALSE)
})


test_that("vibe_tune_result structure is correct", {
  # Create a minimal result structure
  result <- structure(
    list(
      best_prompt = function(text, schema) "test",
      best_prompt_id = "test_prompt",
      metrics = data.frame(
        prompt_id = "test_prompt",
        success_rate = 1.0,
        avg_attempts = 1,
        avg_time = 0.5,
        avg_accuracy = 0.95
      ),
      details = list(),
      recommendations = "Test recommendations",
      all_prompts = list(test_prompt = function(text, schema) "test"),
      schema = list(field = "character"),
      model = "test-model"
    ),
    class = "vibe_tune_result"
  )

  expect_s3_class(result, "vibe_tune_result")
  expect_named(result, c("best_prompt", "best_prompt_id", "metrics", "details",
                         "recommendations", "all_prompts", "schema", "model"))

  # Test that methods work
  expect_output(print(result), "Vibe Tuning Results")
  expect_output(summary(result), "Vibe Tuning Summary")
})


test_that("get_prompt_template works", {
  result <- structure(
    list(
      all_prompts = list(
        prompt1 = function(text, schema) "test1",
        prompt2 = function(text, schema) "test2"
      )
    ),
    class = "vibe_tune_result"
  )

  # Get existing prompt
  prompt <- get_prompt_template(result, "prompt1")
  expect_type(prompt, "closure")
  expect_equal(prompt("", ""), "test1")

  # Error on non-existent prompt
  expect_error(
    get_prompt_template(result, "nonexistent"),
    "Prompt 'nonexistent' not found"
  )

  # Error on wrong class
  expect_error(
    get_prompt_template(list(), "prompt1"),
    "result must be a vibe_tune_result object"
  )
})


test_that("save and load vibe_result work together", {
  skip_on_cran()

  # Create a test result
  result <- structure(
    list(
      best_prompt = function(text, schema) paste0(text, schema),
      best_prompt_id = "test_prompt",
      metrics = data.frame(
        prompt_id = "test_prompt",
        success_rate = 1.0
      ),
      details = list(),
      recommendations = "Test",
      all_prompts = list(test_prompt = function(text, schema) "test"),
      schema = list(field = "character"),
      model = "test-model"
    ),
    class = "vibe_tune_result"
  )

  # Save to temp file
  temp_file <- tempfile(fileext = ".rds")
  on.exit(unlink(temp_file))

  expect_message(save_vibe_result(result, temp_file), "Saved")

  # Load it back
  loaded <- suppressMessages(load_vibe_result(temp_file))

  expect_s3_class(loaded, "vibe_tune_result")
  expect_equal(loaded$best_prompt_id, "test_prompt")
  expect_equal(loaded$model, "test-model")

  # Error on non-existent file
  expect_error(
    load_vibe_result("nonexistent.rds"),
    "File not found"
  )

  # Error on wrong object type
  saveRDS(list(foo = "bar"), temp_file)
  expect_error(
    load_vibe_result(temp_file),
    "does not contain a vibe_tune_result object"
  )
})
