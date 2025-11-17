#' @import S7
#' @importFrom S7 new_class
NULL

#' @title S7 Class for JSON Schema
#'
#' @description
#' An S7 class to represent a JSON schema, including its R list definition
#' and its string representation.
#'
#' @slot schema An R list representing the desired output structure.
#' @slot json_schema_str The JSON schema as a string.
#' @export
JsonSchema <- new_class(
  "JsonSchema",
  properties = list(
    schema = class_list,
    json_schema_str = class_character
  ),
  validator = function(self) {
    if (!is.list(self@schema)) {
      "@schema must be a list."
    }
  }
)

#' @title Convert R List to JSON Schema
#'
#' @description
#' Converts a simple R list schema definition into a proper JSON Schema object.
#' This function supports basic R types like "character", "integer", "numeric",
#' "logical", and nested lists for complex objects or arrays.
#'
#' @param schema An R list representing the desired output structure.
#'   - Atomic types: Use character strings like "character", "integer", "numeric", "logical".
#'   - Arrays: Use `list("character")` for an array of strings, `list(list(name = "character"))` for an array of objects.
#'   - Nested objects: Use nested lists.
#'
#' @return A list representing the JSON Schema.
#' @export
#'
#' @examples
#' as_json_schema(list(
#'   title = "character",
#'   year = "integer",
#'   topics = list("character"),
#'   is_open_access = "logical",
#'   details = list(
#'     publisher = "character",
#'     pages = "integer"
#'   )
#' ))
#'
#' as_json_schema(list(
#'   sentiment = c("positive", "negative", "neutral"),
#'   confidence = "numeric",
#'   keywords = list("character"),
#'   entities = list(list(name = "character", type = "character"))
#' ))
as_json_schema <- function(schema) {
  if (!is.list(schema)) {
    stop("Schema must be a list.", call. = FALSE)
  }

  json_schema_list <- list(
    type = "object",
    properties = list(),
    required = names(schema) # Assume all top-level fields are required
  )

  for (name in names(schema)) {
    value <- schema[[name]]
    property <- list()

    if (is.character(value) && length(value) == 1) {
      # Handle atomic types
      if (value == "character") {
        property$type <- "string"
      } else if (value == "integer") {
        property$type <- "integer"
      } else if (value == "numeric") {
        property$type <- "number"
      } else if (value == "logical") {
        property$type <- "boolean"
      } else {
        stop("Unsupported atomic type: ", value, call. = FALSE)
      }
    } else if (is.character(value) && length(value) > 1) {
      # Handle enums (e.g., c("positive", "negative"))
      property$type <- "string"
      property$enum <- value
    } else if (is.list(value) && length(value) == 1) {
      # Handle arrays
      property$type <- "array"
      items_def <- value[[1]]
      if (is.character(items_def) && length(items_def) == 1) {
        # Array of atomic types
        if (items_def == "character") {
          property$items <- list(type = "string")
        } else if (items_def == "integer") {
          property$items <- list(type = "integer")
        } else if (items_def == "numeric") {
          property$items <- list(type = "number")
        } else if (items_def == "logical") {
          property$items <- list(type = "boolean")
        } else {
          stop("Unsupported array item type: ", items_def, call. = FALSE)
        }
      } else if (is.list(items_def)) {
        # Array of objects (recursive call)
        property$items <- as_json_schema(items_def)@schema # Extract schema from JsonSchema object
      } else {
        stop("Unsupported array definition: ", deparse(value), call. = FALSE)
      }
    } else if (is.list(value) && length(value) > 1) {
      # Handle nested objects (recursive call)
      property <- as_json_schema(value)@schema # Extract schema from JsonSchema object
    } else {
      stop("Unsupported schema definition for '", name, "': ", deparse(value), call. = FALSE)
    }
    json_schema_list$properties[[name]] <- property
  }

  create_JsonSchema(
    schema = schema,
    json_schema_str = jsonlite::toJSON(json_schema_list, auto_unbox = TRUE, pretty = TRUE)
  )
}

#' @title Create a new JsonSchema object
#' @description Helper function to create a new JsonSchema object.
#' @param schema An R list representing the desired output structure.
#' @param json_schema_str The JSON schema as a string.
#' @return A JsonSchema S7 object.
#' @export
create_JsonSchema <- function(schema, json_schema_str) {
  JsonSchema(schema = schema, json_schema_str = json_schema_str)
}