# 8. Exploratory data analysis

**Use when:** you're facing an unfamiliar table and don't know what's in it.

---

```
Perform a structured exploratory analysis of my «sales / customer / events»
dataset.

Schema:
«schema»

My objective: «the decision or question this is meant to inform».

Dialect: PostgreSQL 17.

Write queries covering:
- record counts, and the date range the data actually spans
- missing values per column, as both a count and a percentage
- duplicates, on whatever key should be unique
- distributions of the important numeric columns — min, max, mean, AND median,
  so I can see whether the data is skewed
- trends over time, using a complete date scaffold so empty periods appear as
  zeros rather than vanishing
- top categories, and how concentrated they are
- unusual changes or outliers
- meaningful differences between segments

For EVERY query tell me:
- what it measures
- how to interpret the result
- what value or pattern would be worth investigating further

Two things I specifically want you to check and tell me about:
- whether the first and last time periods are COMPLETE, since partial periods
  fake both growth and collapse
- whether the mean and median disagree substantially on any numeric column, and
  what that means for how I should summarise it
```

---

**The last two checks catch the mistakes that survive review.** A partial final month looks
exactly like a business decline, and a mean quoted for skewed data describes almost nobody.
