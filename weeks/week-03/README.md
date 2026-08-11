# Week 3 — Aggregation

**Time:** ~2.5 hours
**You'll learn:** `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING`

So far every query returned rows that already existed. This week you start producing
numbers that don't exist in any row — totals, averages, counts. This is where SQL stops
being a way to look things up and starts being a way to answer questions.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Aggregate functions collapse many rows into one

```sql
SELECT count(*)          AS how_many,
       avg(unit_price)   AS average_price,
       min(unit_price)   AS cheapest,
       max(unit_price)   AS dearest,
       sum(stock_qty)    AS total_units
FROM   products;
```

One row out, no matter how many rows went in. That's what "aggregate" means: many
in, one out.

### The five you need

| Function | Does | Ignores NULL? |
|---|---|---|
| `count(*)` | Counts **rows** | n/a — counts rows regardless |
| `count(col)` | Counts **non-null values** in that column | **Yes** |
| `count(DISTINCT col)` | Counts unique non-null values | **Yes** |
| `sum(col)` | Adds values | Yes |
| `avg(col)` | Mean of values | Yes |
| `min(col)` / `max(col)` | Smallest / largest | Yes |

**Every aggregate except `count(*)` skips `NULL`s.** This matters more than it sounds:

```sql
SELECT count(*)       AS rows,      -- 40
       count(country) AS with_country  -- 36
FROM   customers;
```

The gap between those two numbers is your missing-data count, free of charge.

It matters most for `avg()`. If ten products have prices and two are `NULL`, `avg()`
divides by **ten**, not twelve. That is usually right — you can't average an unknown — but
if you assumed it divided by twelve, your number is quietly wrong.

### GROUP BY — one row per group instead of one row overall

```sql
SELECT category,
       count(*) AS products
FROM   products
GROUP  BY category;
```

Six rows out — one per distinct category. `GROUP BY category` says: sort the rows into
piles by category, then run the aggregates once per pile.

### The rule that causes most GROUP BY errors

**Every column in your `SELECT` must either be in the `GROUP BY`, or be inside an
aggregate function.** No exceptions.

```sql
SELECT category,
       product_name,          -- ERROR
       count(*)
FROM   products
GROUP  BY category;

-- ERROR: column "products.product_name" must appear in the GROUP BY
--        clause or be used in an aggregate function
```

Think about why. You asked for one row per category. The Storage pile has five different
product names in it. Which one should go in that single output row? The question has no
answer, so Postgres refuses to guess.

Three legitimate fixes, depending on what you actually wanted:

```sql
GROUP BY category, product_name    -- one row per category+name pair
max(product_name)                  -- pick one deterministically
string_agg(product_name, ', ')     -- squash them all into one text value
```

That last one is a Postgres favourite and genuinely useful:

```sql
SELECT category,
       count(*) AS products,
       string_agg(product_name, ', ' ORDER BY product_name) AS items
FROM   products
GROUP  BY category;
```

> **MySQL warning.** MySQL historically allowed the error above, returning an arbitrary
> product name without complaint. Postgres is stricter, and it's right to be — the query
> genuinely has no correct answer. If you follow a MySQL tutorial and it works there but
> fails here, this is usually why.

### HAVING — filtering the groups

`WHERE` filters **rows, before grouping**. `HAVING` filters **groups, after aggregating**.

```sql
SELECT   category, count(*) AS products
FROM     products
WHERE    NOT is_discontinued      -- drop dead products BEFORE counting
GROUP BY category
HAVING   count(*) >= 5            -- keep only categories with 5+ survivors
ORDER BY products DESC;
```

You cannot use an aggregate in `WHERE`:

```sql
WHERE count(*) > 5      -- ERROR: aggregate functions are not allowed in WHERE
```

The reason is timing. `WHERE` runs while the database is still looking at individual rows,
before any grouping has happened — `count(*)` doesn't exist yet, because no group exists
yet. `HAVING` runs afterwards, when the counts are known.

**The practical version of that rule:** if your condition is about a single row, it goes in
`WHERE`. If it's about a whole group, it goes in `HAVING`. And prefer `WHERE` when you have
the choice — filtering rows before grouping is less work than grouping rows you're about to
throw away.

### Updated execution order

```
FROM      →  get the table
WHERE     →  drop rows that fail the test
GROUP BY  →  sort surviving rows into piles
HAVING    →  drop whole piles that fail the test
SELECT    →  compute the output columns
ORDER BY  →  sort the result
LIMIT     →  take the first N
```

This single sequence explains nearly every "why doesn't this work" in aggregation:

- `WHERE` can't see aggregates — they don't exist yet
- `HAVING` can't see `SELECT` aliases — `SELECT` hasn't run yet
- `ORDER BY` *can* see `SELECT` aliases — it runs afterwards

### FILTER — counting subsets in one pass

A Postgres feature worth learning early, because it's a genuine superpower:

```sql
SELECT count(*)                                   AS all_orders,
       count(*) FILTER (WHERE status = 'completed') AS completed,
       count(*) FILTER (WHERE status = 'cancelled') AS cancelled
FROM   orders;
```

One pass over the table, three different counts, side by side as columns. Without `FILTER`
you'd need three separate queries or a pile of `CASE WHEN` expressions.

---

## Part 2 — Worked example (~20 min)

**The question:** *Which product category earns us the most per sale?*

### Step 1: Say what "earns the most" means

It could mean total revenue, or average price, or margin. The question is ambiguous, and
ambiguity is normally where you go and ask. Let's read it as **average margin per product**
— what we typically make when one unit sells.

Being explicit about this *before writing SQL* is most of the skill. A query answers the
question you actually asked, not the one you meant.

### Step 2: Filter first

Discontinued products shouldn't be in a forward-looking question. `WHERE`, not `HAVING`,
because it's a per-row test.

```sql
SELECT * FROM products WHERE NOT is_discontinued;   -- 23 rows
```

### Step 3: Group and aggregate

```sql
SELECT   category,
         count(*)                            AS products,
         round(avg(unit_price), 2)           AS avg_price,
         round(avg(unit_price - cost_price), 2) AS avg_margin
FROM     products
WHERE    NOT is_discontinued
GROUP BY category
ORDER BY avg_margin DESC;
```

`round(x, 2)` trims the output to two decimal places. Without it `avg()` returns a long
trail of digits that makes the result hard to read.

### The actual result

| category | products | avg_price | avg_margin |
|---|---|---|---|
| Software | 2 | 174.00 | 139.00 |
| Networking | 5 | 241.10 | 104.00 |
| Storage | 5 | 197.80 | 80.10 |
| Peripherals | 5 | 137.00 | 62.60 |
| Power | 3 | 126.67 | 53.00 |
| Cables | 3 | 25.17 | 15.27 |

### Step 4: Read it sceptically

Software wins on margin — 139.00, well clear of Networking's 104.00. Software costs almost
nothing to reproduce, so that's believable.

**But look at the `products` column: Software has 2.** That average is computed from two
items. One unusual product would move it enormously. Networking's 104.00 rests on five
products, which is still a small sample but a less fragile one.

**This is why you should almost always include `count(*)` alongside an average.** An
average without a count is an unfalsifiable number. It gives you no way to tell a robust
finding from a coincidence, and it's how "our best category is Software" ends up in a slide
deck on the strength of two rows.

Notice too that the highest average *price* (Networking, 241.10) is not the highest average
*margin*. Expensive and profitable are different things — Networking hardware costs a lot to
buy in, Software doesn't.

### Step 5: State the caveat in the answer

> "Software has the highest average margin at $139, but that's across only two products, so
> treat it as indicative rather than solid. Networking is the strongest well-evidenced
> category at $104 across five products."

That sentence is worth more than the query. Reporting the number *and its reliability* is
the difference between an analyst and a query-runner.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-03.sql`](../../solutions/week-03.sql).

### Exercise 3.1 — Basic grouping

Count how many products are in each category, including discontinued ones. Show category
and count, biggest category first.

*Expected: 6 rows, totalling 25.*

### Exercise 3.2 — Grouping with a total check

Count orders by status. Show status and count, most common first.

*Expected: 5 rows. **Verify the counts sum to 120** — the total number of orders. Make that
check a habit; it catches grouped rows going missing.*

### Exercise 3.3 — WHERE vs HAVING together

For products that are **not discontinued**, show each category's product count and average
price, but only for categories with **3 or more** products. Sort by average price, highest
first.

*Expected: 5 rows, not 6 — one category is excluded by the `HAVING`. Work out which one
and why before checking. This uses `WHERE` and `HAVING` in the same query doing different
jobs; write a comment explaining which does what and why they can't be swapped.*

---

## Part 4 — Mini-project (~30 min)

### A monthly order summary

Management wants to see order volume over time.

Using the `orders` table only, produce **one row per calendar month**, showing:

- the month
- total orders placed
- how many were `completed`
- how many were `cancelled`
- total shipping fees collected

Sorted oldest month first.

**Getting the month out of a date.** Two ways, both fine:

```sql
date_trunc('month', order_date)::date   -- 2024-03-01  (first day of that month)
to_char(order_date, 'YYYY-MM')          -- '2024-03'   (text)
```

`date_trunc` keeps the value a real date, which means it sorts correctly. `to_char` gives
prettier output, and because the format is `YYYY-MM` it happens to sort correctly as text
too. Use either — but if you ever use `to_char(order_date, 'MM-YYYY')`, your months will
sort alphabetically and January 2025 will land next to January 2024. Try it and see.

Use `count(*) FILTER (WHERE ...)` for the status breakdowns.

**Then answer, in comments:**

1. Which month had the most orders?
2. Do the monthly totals sum to 120? Check it with a query rather than adding them up by
   eye.
3. Are there any months with **no orders at all** in your output? Think carefully — if a
   month had zero orders, would it appear as a row with 0, or not appear at all? What does
   that imply about reading a trend from this output?

Question 3 is the real lesson of this mini-project. `GROUP BY` can only produce groups for
data that exists. A month with no orders produces no row — so a chart built directly on
this output would draw a straight line between the surrounding months and hide the gap
entirely. Fixing that properly needs a technique from week 6.

---

## Checklist

- [ ] You can explain why `SELECT category, product_name, count(*) GROUP BY category` fails
- [ ] You know when a condition belongs in `WHERE` vs `HAVING`
- [ ] You know `count(*)` and `count(col)` give different answers, and why
- [ ] You include a count next to every average you report
- [ ] You check that grouped counts sum to the expected total

**Tick week 3 in [`PLANNER.md`](../../PLANNER.md).**
