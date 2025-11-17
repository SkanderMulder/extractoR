
### AGENT BRIEF: Build instructoR — The Instructor/Outlines Equivalent for R (using ellmer)

*Goal*: Create a new R package named instructoR that provides *guaranteed structured extraction* from unstructured text using LLMs via ellmer, with *automatic self-correction loops* until the output matches a user-defined schema.

*Core philosophy*:  
> “Never return malformed JSON. Keep hitting the model until it’s valid — or die trying (with a good error).”

*Primary dependency*: [ellmer](https://github.com/mkearney/ellmer) — the modern, tidy, streaming-friendly LLM interface for R.

---

### Package Requirements

r
Package: instructoR
Title: Self-Correcting Structured Extraction with LLMs in R
Version: 0.1.0
Description: Like Python's 'instructor' or 'outlines'. Automatically retries LLM calls with validation feedback until output matches your schema.
License: MIT
Depends: R (>= 4.1)
Imports:
  ellmer (>= 0.4.0),
  jsonlite,
  jsonvalidate,
  cli,
  rlang,
   withr
Suggests:
  testthat (>= 3.0.0),
  covr,
  spelling,
  usethis
LazyData: true
Encoding: UTF-8
Roxygen: list(markdown = TRUE)


---

### Core Functions to Implement (MVP → v0.1.0)

| Function | Purpose | Priority |
|--------|--------|---------|
| extract() | Main user function | ★★★★★ |
| define_schema() | Optional S7/pydantic-like schema (future-proof) | ★★★★ |
| as_json_schema() | Convert R list → JSON Schema | ★★★★★ |
| validate_and_fix() | Internal retry loop engine | ★★★★★ |
| ellmer_chat() wrapper | Internal, with error injection | ★★★★ |

---

### Detailed Implementation Plan

#### 1. extract() — The One Function Users Will Love

r
extract <- function(text,
                    schema,
                    model = "gpt-4o-mini",
                    max_retries = 5,
                    strategy = c("reflect", "direct", "polite"),
                    temperature = 0.0,
                    .progress = TRUE) {
  # Main public function
}


*Example usage*:
r
library(instructoR)

schema <- list(
  title = "character",
  year = "integer",
  topics = list("character"),
  is_open_access = "logical"
)

result <- extract(
  text = article_text,
  schema = schema,
  model = "claude-3-haiku-20240307"
)

str(result)
# → list with guaranteed structure


#### 2. Schema → JSON Schema Conversion (as_json_schema())

r
as_json_schema <- function(schema) {
  # Convert simple R list schema to proper JSON Schema
  # Supports: character, integer, numeric, logical, vector types, nested lists
  # Uses conventions like: list(items = "character") → array of strings
}


#### 3. Core Loop: validate_and_fix()

r
validate_and_fix <- function(initial_response,
                             json_schema_str,
                             text,
                             model,
                             strategy,
                             max_retries) {
  attempt <- 1
  response <- initial_response

  while (attempt <= max_retries) {
    valid <- jsonvalidate::json_validate(response, json_schema_str, engine = "ajv")
    
    if (valid) {
      return(jsonlite::fromJSON(response, simplifyVector = FALSE))
    }

    errors <- attr(valid, "errors")
    error_summary <- format_validation_errors(errors)

    cli::cli_alert_warning("Attempt {attempt} failed. Retrying with feedback...")

    prompt_fix <- switch(strategy,
      reflect = glue::glue("
        You previously failed to produce valid JSON. Here is the validation error:
        {error_summary}

        Think step-by-step:
        1. What exactly went wrong?
        2. How should it be fixed?
        3. Now output ONLY the corrected JSON.

        Text: {text}
        Schema: {json_schema_str}
      "),
      direct = glue::glue("FIX THIS JSON. Errors:\n{error_summary}\n\nCorrect JSON only:"),
      polite = "Please fix the following validation errors and respond with valid JSON only:\n{error_summary}"
    )

    response <- ellmer::chat(
      model = model,
      messages = list(list(role = "user", content = prompt_fix)),
      temperature = 0.0
    )$content

    attempt <- attempt + 1
  }

  stop("Failed to extract valid structure after ", max_retries, " attempts.")
}


#### 4. Internal Prompt Builder

r
build_extraction_prompt <- function(text, json_schema) {
  glue::glue('
    Extract structured information from the following text as JSON.

    You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:
    {json_schema}

    Rules:
    - Do not add extra fields
    - Do not wrap in markdown
    - Do not add explanations
    - Output raw JSON only

    Text:
    {text}

    Valid JSON:
  ')
}


#### 5. Bonus: Future-Proof with S7 Objects (v0.2+)

r
Paper <- define_schema(
  title = character(),
  authors = character() |> vector(),
  year = integer() |> range(1900, 2030),
  doi = character() |> pattern("^10\\.[0-9]+/")
)

paper <- extract(text, Paper, model = "gpt-4o")
# → returns validated S7 object


---

### Folder Structure to Create


instructoR/
├── R/
│   ├── extract.R
│   ├── schema.R
│   ├── validate.R
│   ├── utils.R
│   └── prompts.R
├── inst/
│   └── prompts/extraction.txt
├── tests/
│   └── testthat/
├── man/
├── DESCRIPTION
├── NAMESPACE
├── README.md
└── .github/workflows/R-CMD-check.yml


---

### README.md (First Draft)

markdown
# instructoR  — Never Get Bad JSON Again

Like [instructor](https://github.com/jxnl/instructor) (Python) but for R.

Automatically retries LLM calls with validation feedback until the output **perfectly matches** your schema.

r
library(instructoR)

schema <- list(
  sentiment = c("positive", "negative", "neutral"),
  confidence = "numeric",
  keywords = list("character"),
  entities = list(list(name = "character", type = "character"))
)

result <- extract(my_review_text, schema, model = "gpt-4o-mini")
# → guaranteed valid or controlled failure


**Zero manual parsing. Zero malformed JSON. Zero prayers.**


---

### Final Agent Instructions (Copy-Paste This)

text
You are an expert R package developer.

Your task: Build the R package 'instructoR' from scratch using 'usethis' workflow.

Requirements:
- Use ellmer as the only LLM interface
- Implement automatic retry-with-error-feedback loop using jsonvalidate + AJV engine
- Main function: extract(text, schema, model = "gpt-4o-mini", max_retries = 5)
- Schema is a simple R list (e.g. list(name = "character", tags = list("character")))
- Convert schema → full JSON Schema using as_json_schema()
- Use cli for beautiful progress feedback
- Include 10+ comprehensive tests
- Write full roxygen2 documentation
- Add README with animated GIF of retry loop (generate placeholder)
- Use MIT license
- Target CRAN-readiness from day one

Start by running:
usethis::create_package("~/instructoR")
Then implement the functions above in order.

Prioritize correctness, user experience, and robustness.

