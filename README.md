# instructoR <img src="man/figures/logo.png" align="right" height="114" alt="" />

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