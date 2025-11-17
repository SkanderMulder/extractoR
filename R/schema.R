#' Convert R list schema to JSON Schema
#'
#' Converts a simple R list specification into a proper JSON Schema object that
#' can be used for validation. Supports basic types (character, integer, numeric,
#' logical) and nested structures (lists, arrays).
#'
#' @param schema A list describing the expected structure. Use strings for simple
#'   types ("character", "integer", "numeric", "logical"), lists for arrays
#'   (e.g., list("character")), and nested lists for objects.
#' @param required Logical indicating if all properties should be required. Default TRUE.
#'
#' @return A JSON Schema string
#'
#' @examples
#' \dontrun{
#' schema <- list(
#'   name = "character",
#'   age = "integer",
#'   tags = list("character"),
#'   metadata = list(
#'     created = "character",
#'     updated = "character"
#'   )
#' )
#' json_schema <- as_json_schema(schema)
#' }
#'
#' @export
as_json_schema <- function(schema, required = TRUE) {
  if (!is.list(schema)) {
    stop("Schema must be a list", call. = FALSE)
  }

  json_schema <- list(
    `$schema` = "http://json-schema.org/draft-07/schema#",
    type = "object",
    properties = list(),
    additionalProperties = FALSE
  )

  if (required && length(schema) > 0) {
    json_schema$required <- names(schema)
  }

  for (name in names(schema)) {
    json_schema$properties[[name]] <- convert_type(schema[[name]])
  }

  jsonlite::toJSON(json_schema, auto_unbox = TRUE, pretty = TRUE)
}

#' Convert R type specification to JSON Schema type
#'
#' @param type_spec The type specification from the schema
#' @return A list representing the JSON Schema type
#' @keywords internal
convert_type <- function(type_spec) {
  if (is.character(type_spec) && length(type_spec) == 1) {
    type_mapping <- list(
      character = list(type = "string"),
      integer = list(type = "integer"),
      numeric = list(type = "number"),
      logical = list(type = "boolean"),
      string = list(type = "string"),
      number = list(type = "number"),
      boolean = list(type = "boolean")
    )

    result <- type_mapping[[type_spec]]
    if (is.null(result)) {
      stop("Unknown type: ", type_spec, call. = FALSE)
    }
    return(result)
  }

  if (is.character(type_spec) && length(type_spec) > 1) {
    return(list(type = "string", enum = type_spec))
  }

  if (is.list(type_spec) && length(type_spec) == 1) {
    return(list(
      type = "array",
      items = convert_type(type_spec[[1]])
    ))
  }

  if (is.list(type_spec) && length(type_spec) > 1 && !is.null(names(type_spec))) {
    properties <- list()
    for (name in names(type_spec)) {
      properties[[name]] <- convert_type(type_spec[[name]])
    }

    return(list(
      type = "object",
      properties = properties,
      required = names(type_spec),
      additionalProperties = FALSE
    ))
  }

  stop("Cannot convert type specification: ", deparse(type_spec), call. = FALSE)
}
