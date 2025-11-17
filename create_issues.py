#!/usr/bin/env python3
"""
Script to create GitHub issues for extractoR roadmap.
Requires GITHUB_TOKEN environment variable.
"""

import os
import sys
import json
import time
import requests

# GitHub API configuration
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN')
REPO_OWNER = 'SkanderMulder'
REPO_NAME = 'extractoR'
API_URL = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues'

if not GITHUB_TOKEN:
    print("Error: GITHUB_TOKEN environment variable not set")
    print("Please set it with: export GITHUB_TOKEN='your_token_here'")
    sys.exit(1)

headers = {
    'Authorization': f'token {GITHUB_TOKEN}',
    'Accept': 'application/vnd.github.v3+json',
}

# Define all issues
issues = [
    # Phase 1: CRAN Preparation
    {
        'title': 'Run full CRAN checks and fix all NOTEs/WARNINGs',
        'body': '''Run comprehensive CRAN checks to ensure the package meets all CRAN requirements.

## Tasks
- [ ] Run `devtools::check()` and document all errors, warnings, and notes
- [ ] Fix all ERRORs (blocking)
- [ ] Fix all WARNINGs (blocking)
- [ ] Address all NOTEs (may be acceptable with explanation)
- [ ] Run `goodpractice::gp()` and implement recommendations
- [ ] Test on Windows, macOS, and Linux (use GitHub Actions or R-hub)
- [ ] Ensure all examples run successfully
- [ ] Check that all documented functions are exported properly

## Success Criteria
- `devtools::check()` passes with 0 errors, 0 warnings, 0 notes (or justified notes)
- `goodpractice::gp()` shows no critical issues

## Timeline
Week 1-3 (Phase 1)
''',
        'labels': ['cran', 'priority-high', 'phase-1'],
        'milestone': None,
    },
    {
        'title': 'Set up comprehensive GitHub Actions CI pipeline',
        'body': '''Implement GitHub Actions workflows for automated testing, R CMD check, and code coverage.

## Tasks
- [ ] Add `usethis::use_github_action("check-standard")` for R CMD check
- [ ] Add `usethis::use_github_action("test-coverage")` for covr
- [ ] Add `usethis::use_github_action("pkgdown")` for documentation
- [ ] Test on multiple R versions (oldrel, release, devel)
- [ ] Test on multiple OS (ubuntu, macos, windows)
- [ ] Add status badges to README
- [ ] Configure caching to speed up CI runs

## Success Criteria
- All CI workflows pass on main branch
- Status badges visible in README
- Tests run on push and PR

## Timeline
Week 1-3 (Phase 1)
''',
        'labels': ['ci-cd', 'priority-high', 'phase-1', 'good-first-issue'],
        'milestone': None,
    },
    {
        'title': 'Achieve 90%+ test coverage with comprehensive tests',
        'body': '''Expand test suite to cover edge cases and ensure reliability.

## Tasks
- [ ] Run `covr::package_coverage()` to identify untested code
- [ ] Add tests for invalid JSON handling
- [ ] Add tests for type coercion edge cases
- [ ] Add tests for retry logic (max retries, retry failures)
- [ ] Add tests for edge schemas (empty arrays, nested enums, null values)
- [ ] Add tests for different model providers (OpenAI, Ollama, Claude)
- [ ] Add tests for validation error messages
- [ ] Add tests for schema conversion from different input types
- [ ] Mock LLM API calls to avoid external dependencies
- [ ] Document testing strategy in `tests/testthat/README.md`

## Success Criteria
- Test coverage ≥ 90% (check with `covr::package_coverage()`)
- All edge cases documented and tested
- Tests run in < 30 seconds

## Timeline
Week 1-3 (Phase 1)
''',
        'labels': ['testing', 'priority-high', 'phase-1'],
        'milestone': None,
    },
    {
        'title': 'Create pkgdown website and deploy to GitHub Pages',
        'body': '''Build professional documentation website to improve discoverability and usability.

## Tasks
- [ ] Run `usethis::use_pkgdown()`
- [ ] Customize `_pkgdown.yml` with extractoR branding
- [ ] Organize reference section by functionality
- [ ] Add custom CSS/theme if desired
- [ ] Deploy to GitHub Pages (skandermulder.github.io/extractoR)
- [ ] Add site URL to DESCRIPTION
- [ ] Ensure all examples render correctly
- [ ] Add search functionality
- [ ] Link to GitHub issues and discussions

## Success Criteria
- Professional-looking site deployed
- All documentation renders correctly
- Site is indexed and accessible

## Timeline
Week 1-3 (Phase 1)

## Quick Win
This can be completed in 48 hours!
''',
        'labels': ['documentation', 'priority-critical', 'phase-1', 'quick-win'],
        'milestone': None,
    },
    {
        'title': 'Submit package to CRAN',
        'body': '''Submit extractoR to CRAN following all guidelines and respond to reviewer feedback.

## Tasks
- [ ] Ensure 2 clean consecutive `devtools::check()` runs
- [ ] Review CRAN policies: https://cran.r-project.org/web/packages/policies.html
- [ ] Write `cran-comments.md` explaining submission
- [ ] Run `devtools::check_win_devel()` and `devtools::check_rhub()`
- [ ] Submit using `devtools::release()`
- [ ] Monitor submission email and respond promptly to reviewers
- [ ] Fix any issues raised and resubmit if needed
- [ ] Update README with CRAN installation instructions after acceptance

## Success Criteria
- Package accepted to CRAN
- CRAN badge added to README
- Installation via `install.packages("extractoR")` works

## Timeline
Week 3 (Phase 1)

## Note
This depends on completing issues #1-4 first.
''',
        'labels': ['cran', 'priority-high', 'phase-1'],
        'milestone': None,
    },

    # Phase 2: Usability & Developer Experience
    {
        'title': 'Implement auto-schema inference from examples',
        'body': '''Allow users to automatically infer schemas from example data, reducing manual schema writing.

## Example API
```r
# Infer schema from sample texts
schema <- infer_schema(
  sample_reviews,
  model = "gpt-4o-mini",
  fields = c("sentiment", "score", "key_topics")
)

# Use inferred schema for extraction
results <- extract_text(new_reviews, schema = schema)
```

## Tasks
- [ ] Create `infer_schema()` function
- [ ] Design prompt for schema inference
- [ ] Support inference from 1-10 examples
- [ ] Return valid JSON schema format
- [ ] Add parameter to specify expected field types
- [ ] Add validation to ensure inferred schema works
- [ ] Write comprehensive documentation
- [ ] Add vignette example
- [ ] Add tests for various data types

## Success Criteria
- Function works with ≤5 examples
- Generates valid, reusable schemas
- Documentation includes clear examples

## Timeline
Week 4-6 (Phase 2)
''',
        'labels': ['feature', 'priority-medium', 'phase-2', 'enhancement'],
        'milestone': None,
    },
    {
        'title': 'Create one-liner extraction for simple use cases',
        'body': '''Enable simple extractions without requiring explicit schema definition.

## Example API
```r
# Extract specific fields without schema
extract_text(
  "Contact John Doe at john@example.com",
  fields = c("name", "email")
)
# Returns: list(name = "John Doe", email = "john@example.com")
```

## Tasks
- [ ] Extend `extract_text()` to accept `fields` parameter
- [ ] Auto-generate simple schema from field names
- [ ] Infer types from field names (e.g., "email" → string with validation)
- [ ] Support common field types (email, phone, date, number, text)
- [ ] Add parameter for type hints: `field_types = c(age = "integer")`
- [ ] Write documentation with examples
- [ ] Add tests for various field combinations

## Success Criteria
- Works for 80% of simple use cases
- No schema required for basic extractions
- Clear error messages for ambiguous cases

## Timeline
Week 4-6 (Phase 2)
''',
        'labels': ['feature', 'priority-medium', 'phase-2', 'enhancement'],
        'milestone': None,
    },
    {
        'title': 'Add progress indicators and spinner integration',
        'body': '''Improve user experience during long-running extractions with progress indicators.

## Example API
```r
# With built-in progress
extract_text(texts, schema, .progress = TRUE)

# With custom spinner (using cli package)
with_spinner(
  extract_text(texts, schema),
  message = "Extracting data..."
)
```

## Tasks
- [ ] Add `.progress` parameter to `extract_text()` and `batch_extract()`
- [ ] Use `cli::cli_progress_bar()` for batch operations
- [ ] Show retry attempts in progress indicator
- [ ] Add spinner for single extractions
- [ ] Make progress optional (default = interactive())
- [ ] Add progress callback for custom handling
- [ ] Document progress options
- [ ] Test that progress doesn't break functionality

## Success Criteria
- Progress shows during batch operations
- Spinner appears during API calls
- Can be disabled for non-interactive use

## Timeline
Week 4-6 (Phase 2)

## Quick Win
Add progress examples to docs immediately!
''',
        'labels': ['feature', 'priority-medium', 'phase-2', 'ui-ux', 'quick-win'],
        'milestone': None,
    },
    {
        'title': 'Implement batch_extract() with parallel processing support',
        'body': '''Enable efficient batch processing of large document collections with parallel execution.

## Example API
```r
# Sequential batch
results <- batch_extract(texts, schema)

# Parallel batch with furrr
results <- batch_extract(
  texts,
  schema,
  .parallel = TRUE,
  .workers = 4
)
```

## Tasks
- [ ] Create `batch_extract()` function
- [ ] Support sequential processing (default)
- [ ] Add `.parallel` parameter for parallel execution
- [ ] Integrate with `furrr` package for parallelization
- [ ] Add rate limiting to respect API limits
- [ ] Handle errors gracefully (continue on failure)
- [ ] Add progress bar integration
- [ ] Support result caching
- [ ] Add parameter to control batch size
- [ ] Write documentation with performance tips
- [ ] Add benchmarks comparing sequential vs parallel

## Success Criteria
- Handles 1000+ documents efficiently
- Parallel mode shows significant speedup
- Respects rate limits
- Clear error reporting

## Timeline
Week 4-6 (Phase 2)
''',
        'labels': ['feature', 'priority-high', 'phase-2', 'performance'],
        'milestone': None,
    },
    {
        'title': 'Enhance error messages with actionable feedback',
        'body': '''Improve error messages to show diffs and suggest fixes.

## Example Output
```
✖ Validation failed: Field 'age' should be numeric, got "twenty"
→ Try: "age": 20

Expected schema:
  {
    "age": <number>,
    "name": <string>
  }

Received:
  {
    "age": "twenty",  ← ERROR: should be number
    "name": "John"
  }
```

## Tasks
- [ ] Use `cli` package for rich formatting
- [ ] Show expected vs actual types
- [ ] Highlight problematic fields
- [ ] Suggest corrections
- [ ] Add context (which document, which retry)
- [ ] Make errors informative but not overwhelming
- [ ] Add `verbose` parameter for detailed debugging
- [ ] Test error messages for common failure modes

## Success Criteria
- Errors are actionable and clear
- Users can fix issues without reading source code
- Formatted output works in terminal and RStudio

## Timeline
Week 4-6 (Phase 2)
''',
        'labels': ['enhancement', 'priority-medium', 'phase-2', 'ui-ux'],
        'milestone': None,
    },
    {
        'title': 'Create schema templates with use_extract_schema()',
        'body': '''Provide ready-to-use schema templates for common extraction tasks.

## Example API
```r
# Create invoice extraction template
use_extract_schema("invoice")
# Creates: inst/extdata/schema_invoice.R

# Available templates: invoice, resume, email, review, article
```

## Tasks
- [ ] Create template infrastructure using `usethis` patterns
- [ ] Design schemas for common use cases:
  - Invoice (items, total, date, vendor)
  - Resume (name, experience, education, skills)
  - Email (sender, recipient, subject, body, date)
  - Review (rating, sentiment, summary, pros, cons)
  - Article (title, author, date, summary, key points)
- [ ] Store templates in `inst/templates/`
- [ ] Create `use_extract_schema()` function
- [ ] Add documentation for each template
- [ ] Include example usage in templates
- [ ] Add tests

## Success Criteria
- 5+ templates available
- Templates are copy-paste ready
- Clear documentation for customization

## Timeline
Week 4-6 (Phase 2)

## Quick Win
Start with invoice template - can be done in hours!
''',
        'labels': ['feature', 'priority-medium', 'phase-2', 'documentation', 'quick-win'],
        'milestone': None,
    },

    # Phase 3: Ecosystem Integration
    {
        'title': 'Auto-detect model type from string identifiers',
        'body': '''Support multiple LLM providers with automatic detection and configuration.

## Example API
```r
# All of these should work:
extract_text(text, schema, model = "gpt-4o")
extract_text(text, schema, model = "claude-3-sonnet")
extract_text(text, schema, model = "ollama/llama3")
extract_text(text, schema, model = "gemini-pro")
```

## Tasks
- [ ] Detect provider from model string pattern
- [ ] Support OpenAI models (gpt-*)
- [ ] Support Anthropic models (claude-*)
- [ ] Support Ollama models (ollama/*)
- [ ] Support Google models (gemini-*, palm-*)
- [ ] Support Cohere models
- [ ] Create provider configuration abstraction
- [ ] Handle provider-specific parameters
- [ ] Add model aliases (e.g., "gpt4" → "gpt-4-turbo")
- [ ] Document supported providers
- [ ] Add tests for each provider

## Success Criteria
- Works with all major LLM providers
- Auto-detection is reliable
- Easy to add new providers

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-high', 'phase-3', 'integration'],
        'milestone': None,
    },
    {
        'title': 'Integrate with tidymodels/recipes for preprocessing',
        'body': '''Enable extractoR as a preprocessing step in tidymodels workflows.

## Example API
```r
library(recipes)

recipe(~ text, data = reviews) %>%
  step_extract(
    text,
    schema = sentiment_schema,
    model = "gpt-4o-mini",
    new_cols = c("sentiment", "score")
  ) %>%
  prep() %>%
  bake(new_data = NULL)
```

## Tasks
- [ ] Create `step_extract()` function for recipes
- [ ] Follow recipes API conventions
- [ ] Support tidyselect for column selection
- [ ] Handle training vs prediction modes
- [ ] Cache LLM results during prep()
- [ ] Add parameter for batch processing
- [ ] Write integration vignette
- [ ] Submit example to tidymodels documentation
- [ ] Add tests using recipes test infrastructure

## Success Criteria
- Works seamlessly with recipes
- Follows tidymodels conventions
- Documented in vignette

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-medium', 'phase-3', 'integration'],
        'milestone': None,
    },
    {
        'title': 'Add targets/drake integration with caching',
        'body': '''Enable smart caching of LLM calls in targets pipelines.

## Example API
```r
# _targets.R
library(targets)
library(extractoR)

tar_option_set(
  packages = c("extractoR")
)

list(
  tar_target(texts, read_texts("data/")),
  tar_extract(results, texts, schema, model = "gpt-4o")
)
```

## Tasks
- [ ] Create `tar_extract()` target factory
- [ ] Hash by (text content + schema + model + parameters)
- [ ] Avoid re-running expensive extractions
- [ ] Support batch mode
- [ ] Handle errors gracefully in pipeline
- [ ] Add caching documentation
- [ ] Create targets workflow example
- [ ] Add tests with targets infrastructure

## Success Criteria
- Unchanged inputs don't re-run extraction
- Works in targets pipelines
- Clear documentation

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-medium', 'phase-3', 'integration'],
        'milestone': None,
    },
    {
        'title': 'Create Shiny module for reactive extraction with progress',
        'body': '''Provide Shiny module for interactive extraction in dashboards.

## Example API
```r
# In UI
extractModuleUI("extractor")

# In server
extracted_data <- extractModuleServer(
  "extractor",
  text_input = reactive(input$text),
  schema = schema
)
```

## Tasks
- [ ] Create Shiny module for extraction UI
- [ ] Add schema input/editor
- [ ] Show extraction progress
- [ ] Display results in reactive table
- [ ] Add validation status indicators
- [ ] Support live editing and re-extraction
- [ ] Create example Shiny app
- [ ] Add documentation
- [ ] Test reactive behavior

## Success Criteria
- Works in Shiny dashboards
- Provides good UX
- Example app demonstrates features

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-low', 'phase-3', 'integration', 'shiny'],
        'milestone': None,
    },
    {
        'title': 'Add Plumber API integration with examples',
        'body': '''Provide examples and utilities for deploying extractoR as REST API.

## Example API
```r
# plumber.R
library(extractoR)

#* Extract structured data
#* @post /extract
#* @param text The text to extract from
#* @param schema JSON schema
function(text, schema) {
  extract_text(text, jsonlite::fromJSON(schema))
}
```

## Tasks
- [ ] Create example Plumber API
- [ ] Add rate limiting
- [ ] Add authentication example
- [ ] Add error handling
- [ ] Create Docker deployment example
- [ ] Add API documentation
- [ ] Add performance tips
- [ ] Create tests for API endpoints

## Success Criteria
- Working API example
- Production-ready template
- Documented deployment

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-low', 'phase-3', 'integration', 'api'],
        'milestone': None,
    },
    {
        'title': 'Support inline extraction in R Markdown/Quarto',
        'body': '''Enable seamless extraction in literate programming documents.

## Example Usage
````markdown
```{r extract-sentiment}
library(extractoR)
sentiment_data <- extract_text(
  article_text,
  schema = sentiment_schema
)
```

The article sentiment is `r sentiment_data$sentiment`.
````

## Tasks
- [ ] Ensure extract functions work in knitr chunks
- [ ] Add caching support for chunks
- [ ] Create R Markdown template
- [ ] Create Quarto template
- [ ] Add examples in vignettes
- [ ] Handle progress output in rendered docs
- [ ] Document best practices
- [ ] Add tests for rendering

## Success Criteria
- Works in both R Markdown and Quarto
- Caching prevents re-runs
- Templates available

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['feature', 'priority-low', 'phase-3', 'integration', 'documentation'],
        'milestone': None,
    },
    {
        'title': 'Submit PR to ellmer for extractoR recommendation',
        'body': '''Get extractoR recommended as the extraction layer in ellmer documentation.

## Tasks
- [ ] Review ellmer documentation structure
- [ ] Prepare PR with extractoR examples
- [ ] Add extractoR to "Related Packages" section
- [ ] Create integration examples
- [ ] Coordinate with ellmer maintainers
- [ ] Update extractoR docs to reference ellmer
- [ ] Cross-link documentation

## Success Criteria
- PR accepted and merged
- extractoR mentioned in ellmer docs
- Mutual documentation links

## Timeline
Week 7-10 (Phase 3)
''',
        'labels': ['community', 'priority-medium', 'phase-3'],
        'milestone': None,
    },

    # Phase 4: Performance & Production Readiness
    {
        'title': 'Implement streaming extraction for large texts',
        'body': '''Support streaming for processing large documents without loading entire responses into memory.

## Example API
```r
# Stream large document extraction
stream_extract(
  large_text,
  schema,
  chunk_size = 1000,
  callback = function(chunk_result) {
    # Process each chunk as it arrives
    write_to_db(chunk_result)
  }
)
```

## Tasks
- [ ] Use httr2 streaming capabilities
- [ ] Implement chunked JSON parsing
- [ ] Add callback for incremental results
- [ ] Handle partial responses
- [ ] Add progress tracking
- [ ] Support resumption on failure
- [ ] Document streaming benefits
- [ ] Add benchmarks vs non-streaming
- [ ] Add tests

## Success Criteria
- Handles documents > 100KB efficiently
- Lower memory footprint
- Maintains accuracy

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-medium', 'phase-4', 'performance'],
        'milestone': None,
    },
    {
        'title': 'Create persistent caching layer with cache_extract()',
        'body': '''Implement disk-based caching to avoid redundant LLM calls.

## Example API
```r
# Cache to disk
cache_extract(
  text,
  schema,
  model = "gpt-4o",
  cache_dir = "cache/extractions/"
)

# Clear cache
clear_extract_cache(cache_dir)
```

## Tasks
- [ ] Create caching infrastructure
- [ ] Hash inputs: (text + schema + model + params)
- [ ] Store results in organized directory structure
- [ ] Support cache expiration (TTL)
- [ ] Add cache statistics
- [ ] Support cache invalidation
- [ ] Add option to bypass cache
- [ ] Document caching strategy
- [ ] Add cache management utilities
- [ ] Add tests

## Success Criteria
- Repeated calls use cache
- Significant cost savings demonstrated
- Easy cache management

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-high', 'phase-4', 'performance'],
        'milestone': None,
    },
    {
        'title': 'Add rate limiting and cost tracking',
        'body': '''Implement rate limiting and cost tracking for production use.

## Example API
```r
# Set rate limits
options(
  extractoR.max_requests_per_minute = 60,
  extractoR.max_tokens_per_day = 1000000
)

# Extract with tracking
results <- extract_text(texts, schema)

# View costs
get_extraction_stats()
# Returns: total_tokens, total_cost, avg_cost_per_doc
```

## Tasks
- [ ] Implement token counting
- [ ] Track costs by provider
- [ ] Add rate limiting (requests/minute, tokens/hour)
- [ ] Create cost estimation function
- [ ] Log all API calls
- [ ] Add cost reporting
- [ ] Support custom pricing
- [ ] Add warnings for high costs
- [ ] Export cost data
- [ ] Add tests

## Success Criteria
- Accurate cost tracking
- Rate limits prevent overage
- Clear reporting

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-high', 'phase-4', 'production'],
        'milestone': None,
    },
    {
        'title': 'Create validation-only mode for post-processing',
        'body': '''Enable validation of existing JSON output without calling LLM.

## Example API
```r
# Validate existing output
validation_result <- validate_json(
  output = existing_json,
  schema = schema
)

if (!validation_result$valid) {
  print(validation_result$errors)
}
```

## Tasks
- [ ] Extract validation logic to standalone function
- [ ] Create `validate_json()` function
- [ ] Return detailed validation errors
- [ ] Support batch validation
- [ ] Add validation statistics
- [ ] Create validation report
- [ ] Document validation rules
- [ ] Add tests

## Success Criteria
- Fast validation without LLM calls
- Detailed error reporting
- Reusable across workflows

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-medium', 'phase-4', 'validation'],
        'milestone': None,
    },
    {
        'title': 'Implement audit logging for compliance',
        'body': '''Add comprehensive audit logging for production environments.

## Example API
```r
# Enable audit logging
extract_text(
  text,
  schema,
  audit_log = TRUE,
  audit_dir = "logs/extraction/"
)

# Query audit logs
audit_summary <- read_audit_logs("logs/extraction/")
```

## Tasks
- [ ] Log all extraction attempts
- [ ] Record retry history
- [ ] Store feedback prompts
- [ ] Log confidence scores
- [ ] Add timestamps and metadata
- [ ] Create queryable log format (JSON Lines)
- [ ] Add log rotation
- [ ] Create audit report generator
- [ ] Document audit schema
- [ ] Add privacy considerations
- [ ] Add tests

## Success Criteria
- Complete audit trail
- Queryable log format
- GDPR/compliance friendly

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-medium', 'phase-4', 'production', 'compliance'],
        'milestone': None,
    },
    {
        'title': 'Create extractoR Pro mode with SQLite backend',
        'body': '''Offer advanced mode with SQLite backend for audit trails and caching.

## Example API
```r
# Initialize Pro mode
init_extractor_pro("my_project.db")

# All extractions now use SQLite backend
extract_text(text, schema)  # Auto-cached and logged

# Query history
get_extraction_history(since = "2024-01-01")
```

## Tasks
- [ ] Design database schema
- [ ] Create SQLite backend
- [ ] Integrate with existing functions
- [ ] Add migration utilities
- [ ] Create query interface
- [ ] Add analytics functions
- [ ] Document Pro mode
- [ ] Add performance benchmarks
- [ ] Add tests

## Success Criteria
- Seamless upgrade path
- Better performance at scale
- Rich querying capabilities

## Timeline
Week 11-14 (Phase 4)
''',
        'labels': ['feature', 'priority-low', 'phase-4', 'enhancement'],
        'milestone': None,
    },

    # Phase 5: Community & Dominance
    {
        'title': 'Write comprehensive vignettes for all skill levels',
        'body': '''Create three essential vignettes covering beginner to production use.

## Vignettes to Create

### 1. Beginner: "Extract Sentiment in 3 Lines"
- Getting started with extractoR
- Simple extraction examples
- Common patterns

### 2. Advanced: "Self-Correcting Nested Schemas"
- Complex schema design
- Nested objects and arrays
- Validation strategies
- Performance optimization

### 3. Production: "Batching 1M Documents with Caching"
- Batch processing
- Caching strategies
- Cost optimization
- Error handling
- Monitoring

## Tasks
- [ ] Create vignette structure
- [ ] Write beginner vignette
- [ ] Write advanced vignette
- [ ] Write production vignette
- [ ] Add real-world examples
- [ ] Include benchmarks
- [ ] Add troubleshooting sections
- [ ] Get community feedback
- [ ] Build vignettes in CI

## Success Criteria
- 3 comprehensive vignettes
- Clear progression path
- Practical examples

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['documentation', 'priority-high', 'phase-5', 'good-first-issue'],
        'milestone': None,
    },
    {
        'title': 'Create usethis-style project templates',
        'body': '''Provide project templates that include extractoR setup.

## Example API
```r
# Create new extraction project
create_extraction_project("my_sentiment_analysis")

# Includes:
# - Pre-configured schema templates
# - Example extraction scripts
# - Testing infrastructure
# - README with instructions
```

## Tasks
- [ ] Design project template structure
- [ ] Create `create_extraction_project()` function
- [ ] Include schema templates
- [ ] Add example data
- [ ] Include best practices
- [ ] Add pre-configured scripts
- [ ] Create template documentation
- [ ] Add tests

## Success Criteria
- Quick project setup
- Best practices included
- Clear documentation

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['feature', 'priority-medium', 'phase-5', 'documentation'],
        'milestone': None,
    },
    {
        'title': 'Give talks and write blog posts',
        'body': '''Build community awareness through talks and writing.

## Planned Content

### 1. useR! 2026 Lightning Talk
- Submit proposal
- Prepare slides
- Demo extractoR live

### 2. RStudio Community Post
- "Introducing extractoR: Self-Correcting LLM Extraction in R"
- Include examples
- Link to documentation

### 3. Blog Post: "Why R Beats Python for Safe LLM Extraction"
- Technical comparison
- Benchmark results
- Code examples

## Tasks
- [ ] Draft useR! proposal
- [ ] Create presentation slides
- [ ] Write RStudio Community post
- [ ] Write technical blog post
- [ ] Share on social media
- [ ] Post to r/rstats
- [ ] Cross-post to relevant forums
- [ ] Collect feedback

## Success Criteria
- Talk accepted/delivered
- Posts published
- Community engagement

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['community', 'priority-medium', 'phase-5', 'outreach'],
        'milestone': None,
    },
    {
        'title': 'Create comprehensive benchmarks vs Python alternatives',
        'body': '''Benchmark extractoR against Python's instructor and outlines on accuracy, speed, and cost.

## Comparison Dimensions
- Accuracy (correctness of extraction)
- Speed (time per extraction)
- Cost (tokens used)
- Reliability (success rate)
- Developer experience (code complexity)

## Tasks
- [ ] Set up benchmark infrastructure
- [ ] Create equivalent test cases
- [ ] Benchmark vs instructor (Python)
- [ ] Benchmark vs outlines (Python)
- [ ] Test on multiple model providers
- [ ] Measure accuracy metrics
- [ ] Measure performance metrics
- [ ] Measure cost metrics
- [ ] Create visualization of results
- [ ] Write benchmark report
- [ ] Publish results
- [ ] Add to documentation

## Success Criteria
- Comprehensive comparison
- Published results
- Demonstrates extractoR advantages

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['benchmarking', 'priority-high', 'phase-5', 'research'],
        'milestone': None,
    },
    {
        'title': 'Partner with Posit for feature/promotion',
        'body': '''Collaborate with Posit to get extractoR featured in their ecosystem.

## Opportunities
- Posit AI blog feature
- posit::conf() presentation
- RStudio Community spotlight
- Integration with Posit products

## Tasks
- [ ] Research Posit partnership opportunities
- [ ] Prepare pitch/proposal
- [ ] Contact Posit team
- [ ] Prepare feature content
- [ ] Coordinate timing
- [ ] Provide examples
- [ ] Support integration efforts
- [ ] Promote collaboration

## Success Criteria
- Posit partnership established
- Feature published
- Increased visibility

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['community', 'priority-medium', 'phase-5', 'partnership'],
        'milestone': None,
    },
    {
        'title': 'Create community contribution guidelines',
        'body': '''Make it easy for external contributors to participate.

## Tasks
- [ ] Create CONTRIBUTING.md
- [ ] Add code of conduct
- [ ] Document development workflow
- [ ] Create issue templates
- [ ] Add PR template
- [ ] Label good first issues
- [ ] Create contributor recognition
- [ ] Document testing requirements
- [ ] Add style guide
- [ ] Create onboarding guide

## Success Criteria
- Clear contribution path
- 3+ external contributors
- Active PR reviews

## Timeline
Week 4+ (Phase 5, ongoing)
''',
        'labels': ['community', 'priority-high', 'phase-5', 'good-first-issue'],
        'milestone': None,
    },

    # Bonus Features
    {
        'title': 'Implement zero-shot schema learning from examples',
        'body': '''Automatically learn optimal schema from small sample of texts.

## Example API
```r
# Learn schema from examples
schema <- learn_schema(
  texts = sample_docs[1:5],
  hint = "Extract product information"
)

# Apply to new data
extract_text(new_docs, schema)
```

## Tasks
- [ ] Design schema learning algorithm
- [ ] Create prompt for schema discovery
- [ ] Support few-shot learning (1-10 examples)
- [ ] Validate learned schema
- [ ] Allow manual refinement
- [ ] Add confidence scores
- [ ] Document approach
- [ ] Add tests
- [ ] Benchmark quality

## Success Criteria
- Works with 3-5 examples
- Produces usable schemas
- Reduces manual work

## Timeline
Future (Bonus Feature)
''',
        'labels': ['feature', 'priority-medium', 'bonus', 'ml'],
        'milestone': None,
    },
    {
        'title': 'Add human-in-the-loop fallback UI',
        'body': '''When extraction fails after max retries, open browser UI for manual correction.

## Example Behavior
```r
# After max retries failed
extract_text(
  difficult_text,
  schema,
  hitl = TRUE  # Human-in-the-loop mode
)
# Opens browser with:
# - Original text
# - Failed extraction
# - Schema requirements
# - Edit interface
```

## Tasks
- [ ] Design correction UI
- [ ] Create local server for editing
- [ ] Show original text and schema
- [ ] Allow inline editing
- [ ] Validate edits against schema
- [ ] Return corrected result
- [ ] Log corrections for learning
- [ ] Document HITL mode
- [ ] Add tests

## Success Criteria
- Graceful fallback
- Good UX
- Useful for annotation

## Timeline
Future (Bonus Feature)
''',
        'labels': ['feature', 'priority-low', 'bonus', 'ui-ux'],
        'milestone': None,
    },
    {
        'title': 'Export results to Arrow/DuckDB',
        'body': '''Enable efficient export of extraction results to modern data formats.

## Example API
```r
# Extract and save to Parquet
extract_to_table(
  texts,
  schema,
  output = "results.parquet",
  format = "arrow"
)

# Extract and save to DuckDB
extract_to_table(
  texts,
  schema,
  output = "data.duckdb",
  format = "duckdb",
  table = "extractions"
)
```

## Tasks
- [ ] Add arrow dependency
- [ ] Add duckdb dependency
- [ ] Create `extract_to_table()` function
- [ ] Support Parquet output
- [ ] Support DuckDB output
- [ ] Handle schema conversion
- [ ] Support incremental writes
- [ ] Add compression options
- [ ] Document format benefits
- [ ] Add tests

## Success Criteria
- Efficient export
- Preserves types correctly
- Documented examples

## Timeline
Future (Bonus Feature)
''',
        'labels': ['feature', 'priority-medium', 'bonus', 'integration'],
        'milestone': None,
    },
    {
        'title': 'Build evaluation framework for extraction quality',
        'body': '''Provide tools to measure extraction quality against ground truth.

## Example API
```r
# Evaluate extractions
evaluation <- evaluate_extraction(
  predictions = extracted_data,
  ground_truth = labeled_data,
  schema = schema
)

# Returns precision, recall, F1 per field
print(evaluation$metrics)
```

## Tasks
- [ ] Design evaluation metrics
- [ ] Implement `evaluate_extraction()`
- [ ] Calculate precision/recall per field
- [ ] Handle nested objects
- [ ] Support partial matches
- [ ] Add confusion matrices
- [ ] Create evaluation reports
- [ ] Add visualization
- [ ] Document methodology
- [ ] Add tests

## Success Criteria
- Meaningful quality metrics
- Easy to use
- Actionable insights

## Timeline
Future (Bonus Feature)
''',
        'labels': ['feature', 'priority-high', 'bonus', 'quality'],
        'milestone': None,
    },
    {
        'title': 'Create model comparison and selection utilities',
        'body': '''Help users choose the best model for their use case.

## Example API
```r
# Compare models
comparison <- compare_models(
  texts = sample_data,
  schema = schema,
  models = c("gpt-4o-mini", "gpt-4o", "claude-3-sonnet"),
  metrics = c("accuracy", "cost", "speed")
)

# Recommend best model
recommend_model(comparison, priority = "cost")
```

## Tasks
- [ ] Create `compare_models()` function
- [ ] Measure accuracy
- [ ] Measure speed
- [ ] Measure cost
- [ ] Calculate trade-offs
- [ ] Create recommendation engine
- [ ] Visualize comparison
- [ ] Document methodology
- [ ] Add tests

## Success Criteria
- Objective comparison
- Clear recommendations
- Cost-aware decisions

## Timeline
Future (Bonus Feature)
''',
        'labels': ['feature', 'priority-medium', 'bonus', 'tooling'],
        'milestone': None,
    },

    # Meta/Tracking
    {
        'title': 'Set up analytics dashboard for package metrics',
        'body': '''Track success metrics mentioned in roadmap.

## Metrics to Track
- CRAN downloads (monthly)
- GitHub stars
- GitHub issues/PRs
- ellmer issues mentioning extractoR
- Vignette views
- Contributors
- Dependent packages

## Target Metrics (6 Months)
- CRAN downloads: 5,000+/mo
- GitHub stars: 500+
- ellmer mentions: 10+
- Vignette views: 1,000+/mo
- Contributors: 3+ external PRs

## Tasks
- [ ] Set up CRAN download tracking
- [ ] Create metrics dashboard
- [ ] Automate data collection
- [ ] Create visualization
- [ ] Set target alerts
- [ ] Share monthly reports

## Success Criteria
- Automated tracking
- Visible dashboard
- Regular reporting

## Timeline
Ongoing
''',
        'labels': ['analytics', 'priority-medium', 'tracking'],
        'milestone': None,
    },

    # Additional Quick Wins
    {
        'title': 'Post to r/rstats for community feedback',
        'body': '''Share extractoR with R community and gather early feedback.

## Post Content
- Introduce extractoR
- Explain the problem it solves
- Show compelling examples
- Request feedback
- Link to documentation

## Tasks
- [ ] Write engaging post
- [ ] Include examples
- [ ] Post to r/rstats
- [ ] Respond to feedback
- [ ] Incorporate suggestions
- [ ] File issues from community feedback

## Success Criteria
- Community awareness
- Feedback collected
- Issues filed by community

## Timeline
Immediate (Quick Win)
''',
        'labels': ['community', 'priority-high', 'quick-win'],
        'milestone': None,
    },
]

def create_issue(issue_data):
    """Create a single GitHub issue."""
    try:
        response = requests.post(
            API_URL,
            headers=headers,
            json=issue_data
        )

        if response.status_code == 201:
            issue = response.json()
            print(f"✓ Created issue #{issue['number']}: {issue['title']}")
            return True
        else:
            print(f"✗ Failed to create issue: {issue_data['title']}")
            print(f"  Status: {response.status_code}")
            print(f"  Response: {response.text}")
            return False
    except Exception as e:
        print(f"✗ Error creating issue: {issue_data['title']}")
        print(f"  Error: {str(e)}")
        return False

def main():
    """Create all roadmap issues on GitHub."""
    print(f"Creating {len(issues)} issues for {REPO_OWNER}/{REPO_NAME}...")
    print()

    created = 0
    failed = 0

    for i, issue in enumerate(issues, 1):
        print(f"[{i}/{len(issues)}] ", end="")
        if create_issue(issue):
            created += 1
        else:
            failed += 1

        # Be respectful of GitHub API rate limits
        if i < len(issues):
            time.sleep(1)  # Wait 1 second between requests

    print()
    print("=" * 60)
    print(f"Summary:")
    print(f"  Created: {created}")
    print(f"  Failed: {failed}")
    print(f"  Total: {len(issues)}")
    print("=" * 60)

    if failed > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
