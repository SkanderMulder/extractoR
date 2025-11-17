# instructoR  — Never Get Bad JSON Again

Like [instructor](https://github.com/jxnl/instructor) (Python) but for R.

Automatically retries LLM calls with validation feedback until the output **perfectly matches** your schema.

```r
library(instructoR)

schema <- list(
  sentiment = c("positive", "negative", "neutral"),
  confidence = "numeric",
  keywords = list("character"),
  entities = list(list(name = "character", type = "character"))
)

result <- extract(my_review_text, schema, model = "gpt-4o-mini")
# → guaranteed valid or controlled failure
```

### Using with Ollama

You can also use `extractoR` with local models via Ollama. Make sure your Ollama server is running and you have pulled the model you want to use.

```r
# Example with Ollama
result_ollama <- extract(
  text = "The new phone has a great camera, but the battery life is poor.",
  schema = list(
    sentiment = c("positive", "negative", "neutral"),
    features = list(list(name = "character", rating = c("good", "bad", "average")))
  ),
  model = "ollama/gemma:2b" # or any other Ollama model
)
```

**Zero manual parsing. Zero malformed JSON. Zero prayers.**

<!-- Placeholder for animated GIF of retry loop -->
![Retry Loop GIF Placeholder](https://via.placeholder.com/600x400?text=Animated+GIF+of+Retry+Loop)
