#' @title Vibe Tune: LLM-Driven Prompt Optimization
#'
#' @description
#' True "vibe tuning" where the LLM generates its own prompt variations based
#' on observed errors and feedback. Instead of hardcoded strategies, the LLM
#' analyzes failures and creates better prompts iteratively.
#'
#' @param examples A list of example inputs. Each element should be a list with:
#'   - `text`: The input text to extract from (required)
#'   - `expected`: The expected output (optional, for accuracy checking)
#' @param schema A list defining the desired output structure.
#' @param model The LLM model to use for extraction (e.g., "gpt-4o-mini").
#' @param num_iterations Number of improvement iterations (default: 3).
#' @param variations_per_iteration Number of prompt variations to generate per iteration (default: 3).
#' @param max_retries The maximum number of retries for each extraction attempt.
#' @param temperature The sampling temperature for the LLM.
#' @param meta_model Model to use for generating prompt variations (default: same as extraction model).
#' @param .progress Logical, whether to show progress feedback.
#'
#' @return A list with class "vibe_tune_result" containing:
#'   - `best_prompt`: The best-performing prompt template
#'   - `best_prompt_id`: Identifier for the best prompt
#'   - `metrics`: A data frame with performance metrics for each prompt variation
#'   - `evolution`: History of how prompts evolved
#'   - `recommendations`: Text recommendations based on the results
#'   - `all_prompts`: All generated prompt templates for reference
#'
#' @export
vibe_tune <- function(examples,
                      schema,
                      model = "gpt-4o-mini",
                      num_iterations = 3,
                      variations_per_iteration = 3,
                      max_retries = 5,
                      temperature = 0.0,
                      meta_model = NULL,
                      .progress = TRUE) {

  validate_vibe_inputs(examples, schema)
  meta_model <- meta_model %||% model

  json_schema_obj <- as_json_schema(schema)
  json_schema_str <- json_schema_obj@json_schema_str

  if (.progress) {
    cli::cli_h1("Vibe Tuning: LLM-Driven Prompt Optimization")
    cli::cli_alert_info("LLM will generate {variations_per_iteration} prompt variations per iteration")
    cli::cli_alert_info("Running {num_iterations} improvement iterations")
    cli::cli_alert_info("Testing on {length(examples)} example{?s}")
    cli::cli_alert_info("Model: {model} | Meta-model: {meta_model}")
  }

  # Start with a baseline prompt
  baseline_prompt <- create_baseline_prompt()

  all_prompts <- list(baseline = baseline_prompt)
  all_results <- list()
  evolution <- list()

  # Iteratively improve prompts
  for (iter in seq_len(num_iterations)) {
    if (.progress) {
      cli::cli_h2("Iteration {iter}/{num_iterations}")
    }

    # Test current prompt
    current_prompt <- all_prompts[[length(all_prompts)]]
    current_results <- test_prompt_on_examples(
      prompt_template = current_prompt,
      examples = examples,
      json_schema_str = json_schema_str,
      model = model,
      max_retries = max_retries,
      temperature = temperature,
      .progress = .progress
    )

    # Analyze failures and generate improvements
    failures <- extract_failures(current_results, examples)

    if (length(failures) == 0) {
      if (.progress) {
        cli::cli_alert_success("Perfect performance! No failures to improve upon.")
      }
      break
    }

    if (.progress) {
      cli::cli_alert_info("Found {length(failures)} failure{?s}. Generating improved prompts...")
    }

    # Let LLM generate better prompts based on failures
    new_prompts <- generate_improved_prompts(
      current_prompt = current_prompt,
      failures = failures,
      schema_str = json_schema_str,
      meta_model = meta_model,
      num_variations = variations_per_iteration,
      .progress = .progress
    )

    # Add new prompts to collection
    for (i in seq_along(new_prompts)) {
      prompt_id <- paste0("iter", iter, "_var", i)
      all_prompts[[prompt_id]] <- new_prompts[[i]]
    }

    # Track evolution
    evolution[[iter]] <- list(
      iteration = iter,
      num_failures = length(failures),
      generated_prompts = length(new_prompts)
    )
  }

  if (.progress) {
    cli::cli_h2("Final Evaluation")
    cli::cli_alert_info("Testing all {length(all_prompts)} generated prompts...")
  }

  # Test all prompts on all examples
  final_results <- test_all_prompts(
    prompts = all_prompts,
    examples = examples,
    json_schema_str = json_schema_str,
    model = model,
    max_retries = max_retries,
    temperature = temperature,
    .progress = .progress
  )

  # Calculate metrics
  metrics_df <- calculate_variation_metrics(final_results, examples)

  # Select best
  best_prompt_id <- select_best_prompt(metrics_df)
  best_prompt <- all_prompts[[best_prompt_id]]

  # Generate recommendations
  recommendations <- generate_recommendations_vibe(metrics_df, best_prompt_id, evolution)

  if (.progress) {
    cli::cli_h1("Results")
    cli::cli_alert_success("Best prompt: {best_prompt_id}")
    cli::cli_text(recommendations)
  }

  structure(
    list(
      best_prompt = best_prompt,
      best_prompt_id = best_prompt_id,
      metrics = metrics_df,
      details = final_results,
      evolution = evolution,
      recommendations = recommendations,
      all_prompts = all_prompts,
      schema = schema,
      model = model,
      meta_model = meta_model
    ),
    class = "vibe_tune_result"
  )
}


#' @title Create Baseline Prompt
#' @keywords internal
create_baseline_prompt <- function() {
  function(text, schema) {
    paste0(
      "Extract structured information from the following text as JSON.\n\n",
      "Schema:\n", schema, "\n\n",
      "Text:\n", text, "\n\n",
      "Respond with valid JSON only, no markdown, no explanations."
    )
  }
}


#' @title Generate Improved Prompts Using LLM
#' @keywords internal
generate_improved_prompts <- function(current_prompt,
                                     failures,
                                     schema_str,
                                     meta_model,
                                     num_variations,
                                     .progress) {

  # Create a meta-prompt that asks LLM to generate better prompts
  meta_prompt <- build_meta_prompt(current_prompt, failures, schema_str, num_variations)

  if (.progress) {
    cli::cli_alert("Asking {meta_model} to generate improved prompts...")
  }

  response <- ellmer::chat(
    model = meta_model,
    messages = list(list(role = "user", content = meta_prompt)),
    temperature = 0.7  # Higher temperature for creativity
  )$content

  # Parse the LLM's prompt variations
  parse_prompt_variations(response, num_variations)
}


#' @title Build Meta-Prompt for Generating New Prompts
#' @keywords internal
build_meta_prompt <- function(current_prompt, failures, schema_str, num_variations) {

  # Show current prompt
  sample_current <- current_prompt("SAMPLE_TEXT", schema_str)

  # Summarize failures
  failure_summary <- vapply(seq_along(failures), function(i) {
    f <- failures[[i]]
    paste0(
      "Example ", i, ":\n",
      "Text: ", substr(f$text, 1, 100), "...\n",
      "Error: ", f$error, "\n",
      if (!is.null(f$expected)) paste0("Expected fields: ", paste(names(f$expected), collapse = ", "), "\n") else ""
    )
  }, character(1))

  paste0(
    "You are a prompt engineering expert. Your task is to generate BETTER prompt templates for structured data extraction.\n\n",
    "CURRENT PROMPT TEMPLATE:\n",
    "```\n", sample_current, "\n```\n\n",
    "FAILURES WITH CURRENT PROMPT:\n",
    paste(failure_summary, collapse = "\n"), "\n\n",
    "SCHEMA:\n", schema_str, "\n\n",
    "Generate ", num_variations, " IMPROVED prompt templates that fix these issues.\n\n",
    "Requirements:\n",
    "- Each prompt should be complete and self-contained\n",
    "- Address the specific errors observed\n",
    "- Use different approaches (e.g., more explicit instructions, examples, structured steps)\n",
    "- Each prompt MUST include placeholders: {{TEXT}} and {{SCHEMA}}\n\n",
    "Output format:\n",
    "---PROMPT-1---\n",
    "[Your first improved prompt with {{TEXT}} and {{SCHEMA}} placeholders]\n",
    "---PROMPT-2---\n",
    "[Your second improved prompt]\n",
    "...\n\n",
    "Generate the prompts now:"
  )
}


#' @title Parse Prompt Variations from LLM Response
#' @keywords internal
parse_prompt_variations <- function(response, expected_count) {

  # Split by separator
  parts <- strsplit(response, "---PROMPT-\\d+---")[[1]]
  parts <- parts[nchar(trimws(parts)) > 0]  # Remove empty parts

  if (length(parts) < expected_count) {
    cli::cli_alert_warning("Expected {expected_count} prompts, got {length(parts)}")
  }

  # Convert each part into a prompt function
  lapply(parts[seq_len(min(length(parts), expected_count))], function(template_str) {
    template_str <- trimws(template_str)

    function(text, schema) {
      # Replace placeholders
      prompt <- gsub("\\{\\{TEXT\\}\\}", text, template_str, fixed = FALSE)
      prompt <- gsub("\\{\\{SCHEMA\\}\\}", schema, prompt, fixed = FALSE)

      # Fallback if no placeholders found - append text and schema
      if (!grepl(text, prompt, fixed = TRUE)) {
        prompt <- paste0(prompt, "\n\nText:\n", text)
      }
      if (!grepl(schema, prompt, fixed = TRUE)) {
        prompt <- paste0(prompt, "\n\nSchema:\n", schema)
      }

      prompt
    }
  })
}


#' @title Extract Failures from Results
#' @keywords internal
extract_failures <- function(results, examples) {
  failures <- list()

  for (i in seq_along(results)) {
    if (!results[[i]]$success) {
      failures[[length(failures) + 1]] <- list(
        text = examples[[i]]$text,
        expected = examples[[i]]$expected,
        error = results[[i]]$error,
        example_index = i
      )
    }
  }

  failures
}


#' @title Test Single Prompt on All Examples
#' @keywords internal
test_prompt_on_examples <- function(prompt_template,
                                   examples,
                                   json_schema_str,
                                   model,
                                   max_retries,
                                   temperature,
                                   .progress) {

  lapply(seq_along(examples), function(j) {
    example <- examples[[j]]

    if (.progress) {
      cli::cli_alert("Example {j}/{length(examples)}")
    }

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

        attempts <- attr(extracted, "attempts") %||% 1
        accuracy <- calculate_accuracy_safe(extracted, example$expected)

        list(
          success = TRUE,
          result = extracted,
          attempts = attempts,
          accuracy = accuracy,
          error = NA_character_
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
    result$time <- as.numeric(difftime(end_time, start_time, units = "secs"))
    result
  })
}


#' @title Test All Prompts on All Examples
#' @keywords internal
test_all_prompts <- function(prompts,
                            examples,
                            json_schema_str,
                            model,
                            max_retries,
                            temperature,
                            .progress) {

  results <- lapply(seq_along(prompts), function(i) {
    prompt_id <- names(prompts)[i]
    prompt_template <- prompts[[i]]

    if (.progress) {
      cli::cli_alert("Testing prompt: {prompt_id}")
    }

    example_results <- test_prompt_on_examples(
      prompt_template = prompt_template,
      examples = examples,
      json_schema_str = json_schema_str,
      model = model,
      max_retries = max_retries,
      temperature = temperature,
      .progress = FALSE
    )

    list(prompt_id = prompt_id, results = example_results)
  })

  setNames(
    lapply(results, `[[`, "results"),
    vapply(results, `[[`, "prompt_id", FUN.VALUE = character(1))
  )
}


#' @title Validate Vibe Tuning Inputs
#' @keywords internal
validate_vibe_inputs <- function(examples, schema) {
  stopifnot(
    "examples must be a non-empty list" = is.list(examples) && length(examples) > 0,
    "schema must be a list" = is.list(schema)
  )

  has_text <- vapply(examples, function(ex) {
    is.list(ex) && !is.null(ex$text)
  }, logical(1))

  if (!all(has_text)) {
    stop("Each example must be a list with a 'text' element", call. = FALSE)
  }

  invisible(TRUE)
}


#' @title Calculate Metrics for All Variations
#' @keywords internal
calculate_variation_metrics <- function(details, examples) {
  metrics_list <- lapply(names(details), function(prompt_id) {
    variation_results <- details[[prompt_id]]

    successes <- vapply(variation_results, `[[`, "success", FUN.VALUE = logical(1))
    attempts <- vapply(variation_results, `[[`, "attempts", FUN.VALUE = numeric(1))
    times <- vapply(variation_results, `[[`, "time", FUN.VALUE = numeric(1))
    accuracies <- vapply(variation_results, function(r) r$accuracy %||% NA_real_, FUN.VALUE = numeric(1))

    data.frame(
      prompt_id = prompt_id,
      success_rate = sum(successes) / length(successes),
      avg_attempts = mean(attempts),
      avg_time = mean(times),
      avg_accuracy = mean(accuracies, na.rm = TRUE),
      successful_examples = sum(successes),
      total_examples = length(examples),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, metrics_list)
}


#' @title Select Best Prompt Based on Metrics
#' @keywords internal
select_best_prompt <- function(metrics_df) {
  metrics_df$score <- with(metrics_df, {
    success_rate * 100 +
      ifelse(is.na(avg_accuracy), 0, avg_accuracy * 10) -
      avg_attempts -
      (avg_time / 10)
  })

  metrics_df$prompt_id[which.max(metrics_df$score)]
}


#' @title Extract with Optimized Prompt Template
#' @export
extract_with_prompt <- function(text,
                                schema,
                                prompt_template,
                                model = "gpt-4o-mini",
                                max_retries = 5,
                                temperature = 0.0,
                                .progress = FALSE) {

  json_schema_obj <- as_json_schema(schema)

  extract_with_custom_prompt(
    text = text,
    json_schema_str = json_schema_obj@json_schema_str,
    prompt_template = prompt_template,
    model = model,
    max_retries = max_retries,
    temperature = temperature,
    .progress = .progress
  )
}


#' @title Extract with Custom Prompt Template (Internal)
#' @keywords internal
extract_with_custom_prompt <- function(text,
                                       json_schema_str,
                                       prompt_template,
                                       model,
                                       max_retries,
                                       temperature,
                                       .progress = FALSE) {

  initial_prompt <- prompt_template(text, json_schema_str)

  initial_response <- ellmer::chat(
    model = model,
    messages = list(list(role = "user", content = initial_prompt)),
    temperature = temperature
  )$content

  json_schema_obj <- JsonSchema(
    schema = list(),
    json_schema_str = json_schema_str
  )

  validate_and_fix(
    initial_response = initial_response,
    json_schema_obj = json_schema_obj,
    text = text,
    model = model,
    strategy = "direct",
    max_retries = max_retries,
    .progress = .progress,
    temperature = temperature
  )
}


#' @title Safe Accuracy Calculation
#' @keywords internal
calculate_accuracy_safe <- function(extracted, expected) {
  if (is.null(expected)) return(NA_real_)
  tryCatch(
    calculate_accuracy(extracted, expected),
    error = function(e) NA_real_
  )
}


#' @title Calculate Accuracy Between Extracted and Expected Output
#' @keywords internal
calculate_accuracy <- function(extracted, expected) {
  if (!is.list(extracted) || !is.list(expected)) return(0)

  fields <- unique(c(names(extracted), names(expected)))
  if (length(fields) == 0) return(0)

  matches <- vapply(fields, function(field) {
    calc_field_match(extracted[[field]], expected[[field]])
  }, FUN.VALUE = numeric(1))

  mean(matches)
}


#' @title Calculate Match for a Single Field
#' @keywords internal
calc_field_match <- function(extracted_val, expected_val) {
  if (is.null(extracted_val) && is.null(expected_val)) return(1)
  if (is.null(extracted_val) || is.null(expected_val)) return(0)

  if (is.list(extracted_val) && is.list(expected_val)) {
    return(calculate_accuracy(extracted_val, expected_val))
  }

  if (is.character(extracted_val) && is.character(expected_val)) {
    return(as.numeric(identical(extracted_val, expected_val)))
  }

  if (is.numeric(extracted_val) && is.numeric(expected_val)) {
    return(as.numeric(abs(extracted_val - expected_val) < 0.1))
  }

  if (is.logical(extracted_val) && is.logical(expected_val)) {
    return(as.numeric(identical(extracted_val, expected_val)))
  }

  as.numeric(identical(extracted_val, expected_val))
}


#' @title Generate Recommendations for Vibe Tuning
#' @keywords internal
generate_recommendations_vibe <- function(metrics_df, best_prompt_id, evolution) {
  best_metrics <- metrics_df[metrics_df$prompt_id == best_prompt_id, ]

  recommendations <- paste0(
    "\nRecommendations:\n",
    "- Use prompt: '", best_prompt_id, "' (LLM-generated)\n"
  )

  if (length(evolution) > 0) {
    total_failures <- sum(vapply(evolution, `[[`, "num_failures", FUN.VALUE = numeric(1)))
    recommendations <- paste0(
      recommendations,
      "- Evolved through ", length(evolution), " iterations, addressing ",
      total_failures, " total failures\n"
    )
  }

  if (best_metrics$success_rate < 1.0) {
    recommendations <- paste0(
      recommendations,
      "- Success rate: ", round(best_metrics$success_rate * 100, 1),
      "%. Consider more iterations or different examples.\n"
    )
  }

  recommendations
}


#' @title Print Method for Vibe Tune Results
#' @export
print.vibe_tune_result <- function(x, ...) {
  cli::cli_h1("Vibe Tuning Results (LLM-Generated Prompts)")
  cli::cli_alert_success("Best Prompt: {x$best_prompt_id}")

  if (length(x$evolution) > 0) {
    cli::cli_alert_info("Evolved through {length(x$evolution)} iteration{?s}")
  }

  cli::cli_text("")
  cli::cli_h2("Performance Metrics")
  print(x$metrics[, c("prompt_id", "success_rate", "avg_attempts", "avg_time")])

  cli::cli_text("")
  cli::cli_text(x$recommendations)

  invisible(x)
}


#' @title Summary Method for Vibe Tune Results
#' @export
summary.vibe_tune_result <- function(object, ...) {
  cat("Vibe Tuning Summary (LLM-Generated Prompts)\n")
  cat("==========================================\n\n")

  cat("Model:", object$model, "\n")
  cat("Meta-model:", object$meta_model, "\n")
  cat("Best Prompt:", object$best_prompt_id, "\n")
  cat("Iterations:", length(object$evolution), "\n\n")

  cat("All Prompts:\n")
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

  colors <- ifelse(metrics$prompt_id == x$best_prompt_id, "darkgreen", "steelblue")

  barplot(
    metrics$success_rate,
    names.arg = metrics$prompt_id,
    main = "Success Rate (LLM-Generated Prompts)",
    ylab = "Success Rate",
    ylim = c(0, 1),
    col = colors,
    las = 2,
    cex.names = 0.6
  )

  barplot(
    metrics$avg_attempts,
    names.arg = metrics$prompt_id,
    main = "Average Attempts",
    ylab = "Attempts",
    col = colors,
    las = 2,
    cex.names = 0.6
  )

  barplot(
    metrics$avg_time,
    names.arg = metrics$prompt_id,
    main = "Average Time",
    ylab = "Time (seconds)",
    col = colors,
    las = 2,
    cex.names = 0.6
  )

  if (!all(is.na(metrics$avg_accuracy))) {
    barplot(
      metrics$avg_accuracy,
      names.arg = metrics$prompt_id,
      main = "Average Accuracy",
      ylab = "Accuracy",
      ylim = c(0, 1),
      col = colors,
      las = 2,
      cex.names = 0.6
    )
  } else {
    # Plot evolution instead
    if (length(x$evolution) > 0) {
      failures <- vapply(x$evolution, `[[`, "num_failures", FUN.VALUE = numeric(1))
      plot(seq_along(failures), failures,
           type = "b", pch = 19, col = "red",
           main = "Evolution: Failures per Iteration",
           xlab = "Iteration", ylab = "Number of Failures")
    } else {
      plot.new()
      text(0.5, 0.5, "No evolution data")
    }
  }

  invisible(x)
}


#' @title Save Vibe Tune Results
#' @export
save_vibe_result <- function(result, file) {
  stopifnot("result must be a vibe_tune_result object" = inherits(result, "vibe_tune_result"))
  saveRDS(result, file)
  cli::cli_alert_success("Saved vibe tune result to {file}")
  invisible(file)
}


#' @title Load Vibe Tune Results
#' @export
load_vibe_result <- function(file) {
  stopifnot("File not found" = file.exists(file))
  result <- readRDS(file)
  stopifnot("File does not contain a vibe_tune_result object" = inherits(result, "vibe_tune_result"))

  cli::cli_alert_success("Loaded vibe tune result from {file}")
  cli::cli_alert_info("Best prompt: {result$best_prompt_id}")
  cli::cli_alert_info("Model: {result$model}")

  result
}


#' @title Get Prompt Template by Name
#' @export
get_prompt_template <- function(result, prompt_id) {
  stopifnot("result must be a vibe_tune_result object" = inherits(result, "vibe_tune_result"))

  if (!prompt_id %in% names(result$all_prompts)) {
    available <- paste(names(result$all_prompts), collapse = ", ")
    stop("Prompt '", prompt_id, "' not found. Available: ", available, call. = FALSE)
  }

  result$all_prompts[[prompt_id]]
}


# Utility: NULL coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x
