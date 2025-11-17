#' @title Vibe Tune: Optimize Prompt Content for Your Extraction Task
#'
#' @description
#' "Vibe tuning" optimizes the actual prompt content by generating and testing
#' multiple prompt variations. Instead of just selecting between strategies,
#' it creates different prompt templates with varying tones, structures, and
#' phrasings to find what works best for your specific extraction task.
#'
#' Inspired by prompt optimization research and evaluation approaches in packages
#' like vitals.
#'
#' @param examples A list of example inputs. Each element should be a list with:
#'   - `text`: The input text to extract from (required)
#'   - `expected`: The expected output (optional, for accuracy checking)
#' @param schema A list defining the desired output structure.
#' @param model The LLM model to use for extraction (e.g., "gpt-4o-mini").
#' @param num_variations Number of prompt variations to generate and test (default: 6).
#' @param max_retries The maximum number of retries for each extraction attempt.
#' @param temperature The sampling temperature for the LLM.
#' @param .progress Logical, whether to show progress feedback.
#'
#' @return A list with class "vibe_tune_result" containing:
#'   - `best_prompt`: The best-performing prompt template
#'   - `best_prompt_id`: Identifier for the best prompt
#'   - `metrics`: A data frame with performance metrics for each prompt variation
#'   - `details`: Detailed results for each prompt-example combination
#'   - `recommendations`: Text recommendations based on the results
#'   - `all_prompts`: All generated prompt templates for reference
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Define your extraction schema
#' schema <- list(
#'   sentiment = c("positive", "negative", "neutral"),
#'   confidence = "numeric",
#'   keywords = list("character")
#' )
#'
#' # Prepare examples to test
#' examples <- list(
#'   list(
#'     text = "This product is amazing! I love it so much.",
#'     expected = list(
#'       sentiment = "positive",
#'       confidence = 0.95,
#'       keywords = list("amazing", "love")
#'     )
#'   ),
#'   list(
#'     text = "Terrible experience, would not recommend."
#'   )
#' )
#'
#' # Run vibe tuning to find optimal prompt
#' result <- vibe_tune(
#'   examples = examples,
#'   schema = schema,
#'   model = "gpt-4o-mini"
#' )
#'
#' # View results
#' print(result)
#' summary(result)
#' plot(result)
#'
#' # Use the optimized prompt
#' optimized_extract <- function(text) {
#'   extract_with_prompt(
#'     text = text,
#'     schema = schema,
#'     prompt_template = result$best_prompt,
#'     model = "gpt-4o-mini"
#'   )
#' }
#' }
vibe_tune <- function(examples,
                      schema,
                      model = "gpt-4o-mini",
                      num_variations = 6,
                      max_retries = 5,
                      temperature = 0.0,
                      .progress = TRUE) {

  # Validate inputs
  if (!is.list(examples) || length(examples) == 0) {
    stop("examples must be a non-empty list", call. = FALSE)
  }

  for (i in seq_along(examples)) {
    if (!is.list(examples[[i]]) || is.null(examples[[i]]$text)) {
      stop("Each example must be a list with a 'text' element", call. = FALSE)
    }
  }

  # Convert schema to JSON Schema
  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  if (.progress) {
    cli::cli_h1("Vibe Tuning: Prompt Optimization")
    cli::cli_alert_info("Generating {num_variations} prompt variations to test")
    cli::cli_alert_info("Testing on {length(examples)} example{?s}")
    cli::cli_alert_info("Model: {model}")
  }

  # Generate prompt variations
  prompt_variations <- generate_prompt_variations(json_schema_str, num_variations)

  if (.progress) {
    cli::cli_alert_success("Generated {length(prompt_variations)} prompt variations")
  }

  # Initialize results storage
  all_results <- list()
  variation_metrics <- list()

  # Test each prompt variation
  for (i in seq_along(prompt_variations)) {
    prompt_id <- names(prompt_variations)[i]
    prompt_template <- prompt_variations[[i]]

    if (.progress) {
      cli::cli_h2("Testing Prompt Variation {i}/{length(prompt_variations)}: {prompt_id}")
    }

    variation_results <- list()
    total_attempts <- 0
    total_time <- 0
    success_count <- 0
    accuracy_scores <- c()

    for (j in seq_along(examples)) {
      example <- examples[[j]]

      if (.progress) {
        cli::cli_alert("Example {j}/{length(examples)}")
      }

      # Time the extraction
      start_time <- Sys.time()

      result <- tryCatch(
        {
          extracted <- extract_with_custom_prompt(
            text = example$text,
            json_schema_str = json_schema_str,
            prompt_template = prompt_template,
            model = model,
            max_retries = max_retries,
            temperature = temperature,
            .progress = FALSE
          )

          attempts <- attr(extracted, "attempts")
          if (is.null(attempts)) attempts <- 1

          # Calculate accuracy if expected output provided
          accuracy <- NA
          if (!is.null(example$expected)) {
            accuracy <- calculate_accuracy(extracted, example$expected)
            accuracy_scores <- c(accuracy_scores, accuracy)
          }

          list(
            success = TRUE,
            result = extracted,
            attempts = attempts,
            accuracy = accuracy,
            error = NA
          )
        },
        error = function(e) {
          list(
            success = FALSE,
            result = NA,
            attempts = max_retries,
            accuracy = 0,
            error = e$message
          )
        }
      )

      end_time <- Sys.time()
      elapsed <- as.numeric(difftime(end_time, start_time, units = "secs"))

      result$time <- elapsed
      variation_results[[j]] <- result

      if (result$success) {
        success_count <- success_count + 1
      }
      total_attempts <- total_attempts + result$attempts
      total_time <- total_time + elapsed
    }

    # Calculate variation metrics
    variation_metrics[[prompt_id]] <- list(
      prompt_id = prompt_id,
      success_rate = success_count / length(examples),
      avg_attempts = total_attempts / length(examples),
      avg_time = total_time / length(examples),
      avg_accuracy = if (length(accuracy_scores) > 0) mean(accuracy_scores, na.rm = TRUE) else NA,
      total_examples = length(examples),
      successful_examples = success_count
    )

    all_results[[prompt_id]] <- variation_results

    if (.progress) {
      cli::cli_alert_success(
        "Success: {round(variation_metrics[[prompt_id]]$success_rate * 100, 1)}% | ",
        "Avg attempts: {round(variation_metrics[[prompt_id]]$avg_attempts, 2)} | ",
        "Avg time: {round(variation_metrics[[prompt_id]]$avg_time, 2)}s"
      )
    }
  }

  # Convert metrics to data frame
  metrics_df <- do.call(rbind, lapply(variation_metrics, function(m) {
    data.frame(
      prompt_id = m$prompt_id,
      success_rate = m$success_rate,
      avg_attempts = m$avg_attempts,
      avg_time = m$avg_time,
      avg_accuracy = m$avg_accuracy,
      successful_examples = m$successful_examples,
      total_examples = m$total_examples,
      stringsAsFactors = FALSE
    )
  }))

  # Determine best prompt
  # Primary: success rate, Secondary: avg_accuracy, Tertiary: avg_attempts, Quaternary: avg_time
  metrics_df$score <- metrics_df$success_rate * 100 +
    ifelse(is.na(metrics_df$avg_accuracy), 0, metrics_df$avg_accuracy * 10) -
    metrics_df$avg_attempts -
    (metrics_df$avg_time / 10)

  best_idx <- which.max(metrics_df$score)
  best_prompt_id <- metrics_df$prompt_id[best_idx]
  best_prompt <- prompt_variations[[best_prompt_id]]

  # Generate recommendations
  recommendations <- generate_recommendations_vibe(metrics_df, best_prompt_id)

  if (.progress) {
    cli::cli_h1("Results")
    cli::cli_alert_success("Best prompt: {best_prompt_id}")
    cli::cli_text(recommendations)
  }

  # Create result object
  result <- structure(
    list(
      best_prompt = best_prompt,
      best_prompt_id = best_prompt_id,
      metrics = metrics_df,
      details = all_results,
      recommendations = recommendations,
      all_prompts = prompt_variations,
      schema = schema,
      model = model
    ),
    class = "vibe_tune_result"
  )

  result
}


#' @title Generate Prompt Variations
#' @description Creates multiple variations of extraction prompts with different
#'   tones, structures, and phrasings.
#' @param json_schema_str The JSON schema as a string
#' @param num_variations Number of variations to generate
#' @return A named list of prompt template functions
#' @keywords internal
generate_prompt_variations <- function(json_schema_str, num_variations = 6) {
  variations <- list()

  # Variation 1: Concise and direct
  variations[["concise_direct"]] <- function(text, schema) {
    paste0(
      "Extract JSON from this text. Match this schema:\n",
      schema,
      "\n\nRules: valid JSON only, no markdown, no explanations.\n\n",
      "Text: ", text, "\n\nJSON:"
    )
  }

  # Variation 2: Detailed and formal
  variations[["detailed_formal"]] <- function(text, schema) {
    paste0(
      "Your task is to extract structured information from the provided text.\n\n",
      "You must produce valid JSON that conforms EXACTLY to this JSON Schema:\n",
      schema,
      "\n\nImportant requirements:\n",
      "1. Output must be valid, parseable JSON\n",
      "2. All required fields must be present\n",
      "3. Field types must match the schema exactly\n",
      "4. Do not include any fields not in the schema\n",
      "5. Do not wrap output in markdown code blocks\n",
      "6. Do not include explanations or comments\n\n",
      "Text to analyze:\n", text,
      "\n\nYour JSON response:\n"
    )
  }

  # Variation 3: Encouraging and supportive
  variations[["encouraging"]] <- function(text, schema) {
    paste0(
      "Please help extract structured data from this text!\n\n",
      "The output should be valid JSON matching this schema:\n",
      schema,
      "\n\nJust focus on:\n",
      "- Creating valid JSON that can be parsed\n",
      "- Matching the schema structure precisely\n",
      "- Including only the fields specified\n",
      "- Outputting raw JSON without any markdown or explanations\n\n",
      "Here's the text:\n", text,
      "\n\nYour JSON output:\n"
    )
  }

  # Variation 4: Example-driven
  variations[["example_driven"]] <- function(text, schema) {
    paste0(
      "Extract structured information as JSON.\n\n",
      "Schema to match:\n", schema,
      "\n\nExample of valid JSON format:\n",
      '{"field1": "value", "field2": 123}\n\n',
      "Important:\n",
      "- Return ONLY the JSON object\n",
      "- No markdown formatting (no ```json blocks)\n",
      "- No explanatory text before or after\n",
      "- Ensure all types match the schema\n\n",
      "Text:\n", text,
      "\n\nJSON:\n"
    )
  }

  # Variation 5: Step-by-step
  variations[["step_by_step"]] <- function(text, schema) {
    paste0(
      "Follow these steps to extract structured data:\n\n",
      "Step 1: Read and understand this text:\n", text,
      "\n\nStep 2: Identify the information needed for this schema:\n",
      schema,
      "\n\nStep 3: Format as valid JSON with:\n",
      "- Correct types for each field\n",
      "- All required fields present\n",
      "- No additional fields\n",
      "- No markdown or explanations\n\n",
      "Step 4: Output the JSON:\n"
    )
  }

  # Variation 6: Minimal and terse
  variations[["minimal"]] <- function(text, schema) {
    paste0(
      "Text: ", text,
      "\n\nSchema: ", schema,
      "\n\nOutput valid JSON only:"
    )
  }

  # Return only the requested number of variations
  variations[1:min(num_variations, length(variations))]
}


#' @title Extract with Custom Prompt Template
#' @description Performs extraction using a custom prompt template
#' @param text The input text
#' @param json_schema_str The JSON schema as string
#' @param prompt_template A function that takes (text, schema) and returns a prompt
#' @param model The model to use
#' @param max_retries Maximum retry attempts
#' @param temperature Sampling temperature
#' @param .progress Show progress
#' @return Extracted data
#' @keywords internal
extract_with_custom_prompt <- function(text,
                                       json_schema_str,
                                       prompt_template,
                                       model,
                                       max_retries,
                                       temperature,
                                       .progress = FALSE) {

  # Build initial prompt using the template
  initial_prompt <- prompt_template(text, json_schema_str)

  # Initial LLM call
  initial_response <- ellmer::chat(
    model = model,
    messages = list(list(role = "user", content = initial_prompt)),
    temperature = temperature
  )$content

  # Create JsonSchema object for validation
  json_schema_obj <- JsonSchema(
    schema = list(),  # We don't need the R schema for validation
    json_schema_str = json_schema_str
  )

  # Validate and fix with default strategy
  result <- validate_and_fix(
    initial_response = initial_response,
    json_schema_obj = json_schema_obj,
    text = text,
    model = model,
    strategy = "direct",  # Use direct strategy for corrections
    max_retries = max_retries,
    .progress = .progress,
    temperature = temperature
  )

  result
}


#' @title Calculate Accuracy Between Extracted and Expected Output
#' @description Compares extracted output with expected output and returns
#'   a similarity score.
#' @param extracted The extracted output from the LLM
#' @param expected The expected output
#' @return A numeric score between 0 and 1
#' @keywords internal
calculate_accuracy <- function(extracted, expected) {
  if (!is.list(extracted) || !is.list(expected)) {
    return(0)
  }

  fields <- unique(c(names(extracted), names(expected)))
  matches <- 0
  total <- 0

  for (field in fields) {
    total <- total + 1

    extracted_val <- extracted[[field]]
    expected_val <- expected[[field]]

    if (is.null(extracted_val) || is.null(expected_val)) {
      next
    } else if (is.character(extracted_val) && is.character(expected_val)) {
      if (identical(extracted_val, expected_val)) {
        matches <- matches + 1
      }
    } else if (is.numeric(extracted_val) && is.numeric(expected_val)) {
      if (abs(extracted_val - expected_val) < 0.1) {
        matches <- matches + 1
      }
    } else if (is.logical(extracted_val) && is.logical(expected_val)) {
      if (identical(extracted_val, expected_val)) {
        matches <- matches + 1
      }
    } else if (is.list(extracted_val) && is.list(expected_val)) {
      matches <- matches + calculate_accuracy(extracted_val, expected_val)
    } else {
      if (identical(extracted_val, expected_val)) {
        matches <- matches + 1
      }
    }
  }

  if (total == 0) return(0)
  matches / total
}


#' @title Generate Recommendations for Vibe Tuning
#' @keywords internal
generate_recommendations_vibe <- function(metrics_df, best_prompt_id) {
  best_metrics <- metrics_df[metrics_df$prompt_id == best_prompt_id, ]

  recommendations <- paste0(
    "\nRecommendations:\n",
    "- Use prompt variation '", best_prompt_id, "' for this extraction task.\n"
  )

  if (best_metrics$success_rate < 1.0) {
    recommendations <- paste0(
      recommendations,
      "- Consider increasing max_retries (current success rate: ",
      round(best_metrics$success_rate * 100, 1), "%).\n"
    )
  }

  if (best_metrics$avg_attempts > 3) {
    recommendations <- paste0(
      recommendations,
      "- Average ", round(best_metrics$avg_attempts, 1),
      " attempts needed. Consider simplifying your schema.\n"
    )
  }

  # Compare variations
  if (nrow(metrics_df) > 1) {
    worst_prompt <- metrics_df$prompt_id[which.min(metrics_df$score)]
    if (worst_prompt != best_prompt_id) {
      worst_metrics <- metrics_df[metrics_df$prompt_id == worst_prompt, ]
      improvement <- (best_metrics$success_rate - worst_metrics$success_rate) * 100
      if (improvement > 5) {
        recommendations <- paste0(
          recommendations,
          "- '", best_prompt_id, "' shows ",
          round(improvement, 1),
          "% better success rate than '", worst_prompt, "'.\n"
        )
      }
    }
  }

  recommendations
}


#' @title Print Method for Vibe Tune Results
#' @export
print.vibe_tune_result <- function(x, ...) {
  cli::cli_h1("Vibe Tuning Results")

  cli::cli_alert_success("Best Prompt: {x$best_prompt_id}")
  cli::cli_text("")

  cli::cli_h2("Performance Metrics")
  print(x$metrics[, c("prompt_id", "success_rate", "avg_attempts", "avg_time", "avg_accuracy")])

  cli::cli_text("")
  cli::cli_text(x$recommendations)

  cli::cli_text("")
  cli::cli_h3("Best Prompt Template Preview")
  sample_text <- "sample text"
  sample_schema <- "{\"type\": \"object\"}"
  preview <- x$best_prompt(sample_text, sample_schema)
  cat(substr(preview, 1, 200), "...\n")

  invisible(x)
}


#' @title Summary Method for Vibe Tune Results
#' @export
summary.vibe_tune_result <- function(object, ...) {
  cat("Vibe Tuning Summary\n")
  cat("===================\n\n")

  cat("Model:", object$model, "\n")
  cat("Best Prompt:", object$best_prompt_id, "\n\n")

  cat("Prompt Variation Comparison:\n")
  print(object$metrics)

  cat("\n")
  cat(object$recommendations)

  invisible(object)
}


#' @title Plot Method for Vibe Tune Results
#' @export
plot.vibe_tune_result <- function(x, ...) {
  metrics <- x$metrics

  old_par <- par(mfrow = c(2, 2), mar = c(5, 4, 2, 1))
  on.exit(par(old_par))

  # Plot 1: Success Rate
  barplot(
    metrics$success_rate,
    names.arg = metrics$prompt_id,
    main = "Success Rate by Prompt",
    ylab = "Success Rate",
    ylim = c(0, 1),
    col = ifelse(metrics$prompt_id == x$best_prompt_id, "darkgreen", "steelblue"),
    las = 2,
    cex.names = 0.7
  )

  # Plot 2: Average Attempts
  barplot(
    metrics$avg_attempts,
    names.arg = metrics$prompt_id,
    main = "Average Attempts by Prompt",
    ylab = "Attempts",
    col = ifelse(metrics$prompt_id == x$best_prompt_id, "darkgreen", "steelblue"),
    las = 2,
    cex.names = 0.7
  )

  # Plot 3: Average Time
  barplot(
    metrics$avg_time,
    names.arg = metrics$prompt_id,
    main = "Average Time by Prompt",
    ylab = "Time (seconds)",
    col = ifelse(metrics$prompt_id == x$best_prompt_id, "darkgreen", "steelblue"),
    las = 2,
    cex.names = 0.7
  )

  # Plot 4: Accuracy
  if (!all(is.na(metrics$avg_accuracy))) {
    barplot(
      metrics$avg_accuracy,
      names.arg = metrics$prompt_id,
      main = "Average Accuracy by Prompt",
      ylab = "Accuracy",
      ylim = c(0, 1),
      col = ifelse(metrics$prompt_id == x$best_prompt_id, "darkgreen", "steelblue"),
      las = 2,
      cex.names = 0.7
    )
  } else {
    plot.new()
    text(0.5, 0.5, "No accuracy data\n(provide 'expected' in examples)")
  }

  invisible(x)
}
