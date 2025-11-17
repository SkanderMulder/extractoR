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

**Zero manual parsing. Zero malformed JSON. Zero prayers.**

<!-- Placeholder for animated GIF of retry loop -->
![Retry Loop GIF Placeholder](https://via.placeholder.com/600x400?text=Animated+GIF+of+Retry+Loop)
