# extractoR (development version)

## New Features

* Added support for optional fields in schemas using `optional()` function (#1)
  - Fields can now be marked as optional, allowing for more flexible extraction
  - Works with all field types: atomic, arrays, enums, and nested objects
  - Example: `schema <- list(name = "character", email = optional("character"))`

# extractoR 0.1.0

## Initial Release

* Self-correcting structured extraction from text using LLMs
* Automatic retry with validation feedback until schema compliance
* JSON Schema validation for R list schemas
* Three self-correction strategies: reflect, direct, and polite
* Integration with ellmer for LLM backend support
* Progress tracking with cli
* Ollama local model support
