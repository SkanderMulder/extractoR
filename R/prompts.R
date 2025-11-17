build_extraction_prompt <- function(text, json_schema) {
  paste0(
    "Extract structured information from the following text as JSON.\n\n",
    "You MUST respond with valid JSON that conforms EXACTLY to this JSON Schema:\n",
    json_schema,
    "\n\nRules:\n",
    "- Do not add extra fields\n",
    "- Do not wrap in markdown\n",
    "- Do not add explanations\n",
    "- Output raw JSON only\n\n",
    "Text:\n",
    text,
    "\n\nValid JSON:\n"
  )
}