# Example of using instructoR with a local Ollama model
#
# This script demonstrates how to use the `extract()` function from the
# `instructoR` package to extract structured information from text using a
# local model served by Ollama.
#
# Prerequisites:
# 1. Make sure you have installed the `instructoR` package.
#    - You can install it from the local source:
#      # devtools::install(".")
#
# 2. Make sure your Ollama server is running.
#    - You can start it by running `ollama serve` in your terminal.
#
# 3. Make sure you have pulled the model you want to use.
#    - For example, to pull the 'gemma:2b' model, run in your terminal:
#      # ollama pull gemma:2b

# Load the instructoR package
library(instructoR)

# 1. Define the text you want to extract from
article_text <- "The new smartphone was released in 2024. It has a great camera and a long-lasting battery. However, some users have reported that the screen is easily scratched."

# 2. Define the schema of the information you want to extract
my_schema <- list(
  model_name = "character",
  release_year = "integer",
  features = list(
    list(
      name = "character",
      sentiment = c("positive", "negative", "neutral")
    )
  )
)

# 3. Call the extract() function with your local Ollama model
#    - Replace "ollama/gemma:2b" with the Ollama model you want to use.
#    - The format is "ollama/<model_name>:<tag>"
#    - The ellmer package, used by instructoR, will automatically connect to
#      your local Ollama server (by default at http://localhost:11434).
cat("--- Calling local Ollama model for extraction ---\n")
result <- tryCatch({
  extract(
    text = article_text,
    schema = my_schema,
    model = "ollama/gemma:2b",
    .progress = TRUE
  )
}, error = function(e) {
  cat("\n--- ERROR ---\n")
  cat("Failed to connect to Ollama or extract information.\n")
  cat("Please ensure your Ollama server is running and you have pulled the model.\n")
  cat("Error message:", e$message, "\n")
  NULL
})

# 4. Print the result
if (!is.null(result)) {
  cat("\n--- Extraction successful! ---\n")
  str(result)
}
