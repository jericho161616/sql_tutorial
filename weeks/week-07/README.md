# Week 7 — Window functions

**Time:** ~2.5 hours
**You'll learn:** `OVER`, `PARTITION BY`, `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, running totals

This is the biggest single jump in what you can do with SQL. Window functions answer the
questions that `GROUP BY` cannot: *rank within a group, compare to the previous row, running
total, top N per category.* Before this week those needed application code or a pile of
self-joins. After it, they're a line of SQL.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### The problem window functions solve

`GROUP BY` collapses rows. Six categories in, six rows out — the individual products are gone.

But often you want the aggregate **and** the detail together: each product *and* its
category's average, so you can compare. `GROUP BY` cannot do that, because it has thrown the
products away.

A **window function** computes across a set of rows while **keeping every row**.

```sql
SELECT product_name,
       category,
       unit_price,
       round(avg(unit_price) OVER (PARTITION BY category), 2) AS category_avg
FROM   products
WHERE  NOT is_discontinued;
```

23 rows in, **23 rows out** — every product, each carrying its category's average alongside it.
Compare that to `GROUP BY category`, which gives 6 rows and no products.

### Reading `OVER`

`OVER` is what makes a function a window function. It defines the "window" of rows the
function looks at.

```sql
avg(unit_price) OVER ()                          -- window = the whole result
avg(unit_price) OVER (PARTITION BY category)     -- window = rows sharing a category
avg(unit_price) OVER (ORDER BY created_at)       -- window = all rows up to this one
```

- **`PARTITION BY`** splits rows into groups — like `GROUP BY`, but without collapsing them.
- **`ORDER BY`** inside `OVER` sequences the rows, which is what makes running totals and
  row-to-row comparisons possible.

An empty `OVER ()` means "every row in the result", which is how you compare each row against
a grand total.

### Ranking

```sql
SELECT product_name, category, unit_price,
       ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rn,
       RANK()       OVER (PARTITION BY category ORDER BY unit_price DESC) AS rnk,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) AS dense
FROM   products
WHERE  NOT is_discontinued;
```

They differ only in how they treat ties:

| Prices | `ROW_NUMBER` | `RANK` | `DENSE_RANK` |
|---|---|---|---|
| 100 | 1 | 1 | 1 |
| 90 | 2 | 2 | 2 |
| 90 | 3 | 2 | 2 |
| 80 | 4 | **4** | **3** |

- `ROW_NUMBER` always gives distinct numbers — arbitrary between tied rows.
- `RANK` gives ties the same rank, then **skips** (no 3rd place).
- `DENSE_RANK` gives ties the same rank and **doesn't skip**.

**Use `ROW_NUMBER` when you need exactly one row per group** (e.g. each customer's latest
order). **Use `RANK` or `DENSE_RANK` when ties should genuinely tie** — a "top 3 products" list
built with `ROW_NUMBER` will arbitrarily cut one of two equally-priced products, and nobody
will notice.

### Top N per group — the classic

You can't filter on a window function in `WHERE`, for the same timing reason as aggregates:
window functions are computed *after* `WHERE`. So wrap it in a CTE.

```sql
WITH ranked AS (
    SELECT product_name, category, unit_price,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rn
    FROM   products
    WHERE  NOT is_discontinued
)
SELECT product_name, category, unit_price
FROM   ranked
WHERE  rn <= 2                -- top 2 per category
ORDER  BY category, rn;
```

**Memorise this shape.** "Top N per group" is one of the most frequently asked questions in
SQL interviews and in real work, and this is the answer.

### LAG and LEAD — comparing to other rows

```sql
LAG(revenue)  OVER (ORDER BY month)    -- the previous row's value
LEAD(revenue) OVER (ORDER BY month)    -- the next row's value
```

This is how you calculate change over time without joining a table to itself.

```sql
SELECT month,
       revenue,
       LAG(revenue) OVER (ORDER BY month)                AS prev_month,
       revenue - LAG(revenue) OVER (ORDER BY month)      AS change
FROM   monthly_revenue;
```

The first row's `LAG` is `NULL` — there is no previous month. That's correct, and you must
handle it: `NULL` in a division gives `NULL`, and dividing by a previous value of zero raises
an error. Guard with `NULLIF`:

```sql
round(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
      / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS pct_change
```

`NULLIF(x, 0)` returns `NULL` when `x` is zero, turning a division-by-zero **error** into a
`NULL` **result**. A report with a blank cell beats a report that crashes.

### Running totals

```sql
SUM(revenue) OVER (ORDER BY month) AS running_total
```

Adding `ORDER BY` inside `OVER` changes the window from "all rows" to "all rows **up to and
including this one**". That's what produces a cumulative figure.

This catches people out: `SUM(x) OVER ()` is the grand total on every row, but `SUM(x) OVER
(ORDER BY month)` is a running total. The `ORDER BY` is doing far more than sorting.

### Median — and why you couldn't do it before

```sql
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY spend) AS median_spend
FROM   customer_spend;
```

Week 6 found the mean customer spend was $2,908.92 while the median is $2,380.50 — 22% apart.
Now you can compute both and report whichever honestly describes the data.

### Frames (know they exist)

```sql
AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
```

A three-month moving average. Frame clauses let you define the window precisely. You won't
need them often at this level — just recognise the syntax so it doesn't look alien.

---

## Part 2 — Worked example (~20 min)

**The question:** *How is revenue trending month over month?*

### Step 1: Get monthly revenue

```sql
WITH monthly_revenue AS (
    SELECT   date_trunc('month', o.order_date)::date AS month,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY 1
)
SELECT * FROM monthly_revenue ORDER BY month;
```

### Step 2: Add the comparison

```sql
WITH monthly_revenue AS ( ... as above ... )
SELECT to_char(month, 'YYYY-MM') AS mth,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month,
       round(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS change,
       round(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS pct_change,
       round(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM   monthly_revenue
ORDER  BY month;
```

### The actual result (first nine months)

| mth | revenue | prev_month | change | pct_change | running_total |
|---|---|---|---|---|---|
| 2024-01 | 453.00 | — | — | — | 453.00 |
| 2024-02 | 6,828.50 | 453.00 | 6,375.50 | **1,407.4%** | 7,281.50 |
| 2024-03 | 4,293.95 | 6,828.50 | −2,534.55 | −37.1% | 11,575.45 |
| 2024-04 | 4,164.50 | 4,293.95 | −129.45 | −3.0% | 15,739.95 |
| 2024-05 | 3,350.00 | 4,164.50 | −814.50 | −19.6% | 19,089.95 |
| 2024-06 | 4,285.50 | 3,350.00 | 935.50 | 27.9% | 23,375.45 |
| 2024-07 | 11,627.10 | 4,285.50 | 7,341.60 | **171.3%** | 35,002.55 |
| 2024-08 | 4,268.60 | 11,627.10 | −7,358.50 | **−63.3%** | 39,271.15 |
| 2024-09 | 4,333.50 | 4,268.60 | 64.90 | 1.5% | 43,604.65 |

### Step 3: Read it — this is the important part

**February grew 1,407%.** Nobody's business grew fourteen-fold in a month.

Look at January: revenue of **$453.00**, from a single order. The company didn't grow 1,407%
in February; **January was a partial month** — the data starts on the 17th. The percentage is
arithmetically correct and completely meaningless.

**This is the most common way percentage change lies: a tiny denominator.** When the base is
small, ordinary variation produces spectacular percentages. A change from 1 to 15 is +1400%
and is also just fourteen extra units.

**July's +171% then August's −63%** is the second pattern to distrust. Did something go wrong
in August? Look at the absolute numbers: July was $11,627 against a run rate of about $4,300.
July was the anomaly; August was normal. The −63% "crash" is a return to baseline.

Reporting "revenue fell 63% in August" would be true, alarming, and wrong.

### Step 4: What you'd actually say

> "Revenue runs at roughly $4,300/month. July spiked to $11,627 — worth investigating what
> drove it. August's 63% drop is a return to normal, not a decline. Ignore January's
> percentages entirely; it's a partial month with one order."

**Three habits this teaches:**

1. **Always show the absolute number next to the percentage.** A percentage alone cannot be
   sanity-checked.
2. **Distrust any percentage over ~100%.** Check the denominator before believing it.
3. **Check whether your first and last periods are complete.** Partial periods at either end
   produce fake growth and fake collapse.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-07.sql`](../../solutions/week-07.sql).

### Exercise 7.1 — Rank within groups

For every non-discontinued product, show name, category, price, and its price rank **within
its category** (most expensive = 1). Sort by category, then rank.

*Expected: 23 rows. Then answer: are there any ties? Which ranking function did you use, and
would `RANK` and `ROW_NUMBER` give different output on this data?*

### Exercise 7.2 — Top N per group

Using the pattern from the concepts section, return the **two most expensive products in each
category**, with their rank.

*Expected: 12 rows — six categories, two each. Then ask yourself what this query would return
if a category had only one live product, and whether that's the behaviour you'd want in a
"top 2" report handed to someone else.*

### Exercise 7.3 — Latest row per group

Find each customer's **most recent order**. Show first name, last name, `order_id`,
`order_date` and `status`, most recent first.

Use `ROW_NUMBER()` with `PARTITION BY` and a CTE. One row per customer, no exceptions.

*Expected: 38 rows — every customer who has ever ordered. Then answer: why `ROW_NUMBER` here
rather than `RANK`?*

---

## Part 4 — Mini-project (~30 min)

### A month-over-month growth report you'd actually hand someone

Combine week 6's gap-free scaffold with this week's window functions.

Produce one row per month from January 2024 to October 2025 — **all 22, including any empty
ones** — showing:

- month
- revenue (0.00 if none)
- previous month's revenue
- absolute change
- percentage change (`NULL`, not an error, where undefined)
- running total
- 3-month moving average of revenue

Requirements:

1. Build the month scaffold with `generate_series` and `LEFT JOIN` real data onto it.
2. Use `LAG` for the comparison and `SUM(...) OVER (ORDER BY ...)` for the running total.
3. Guard the percentage against division by zero with `NULLIF`.
4. Use a frame clause for the moving average: `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.

**Then write a short commentary** as comments — five sentences maximum — describing what the
data actually shows. Rules for the commentary:

- Every claim must cite a number from your output.
- You must explicitly flag at least one percentage that is misleading, and say why.
- You must state whether the final month is complete, and what that means for reading the
  trend.

That last requirement is the one that separates a report someone can act on from a report that
sends them chasing a decline that never happened.

---

## Checklist

- [ ] You can explain the difference between `GROUP BY` and `PARTITION BY`
- [ ] You know when to use `ROW_NUMBER` vs `RANK` vs `DENSE_RANK`
- [ ] You can write the "top N per group" pattern from memory
- [ ] You know why a window function can't go in `WHERE`
- [ ] You guard percentage change with `NULLIF`
- [ ] You distrust any percentage change with a small denominator
- [ ] You check whether the first and last periods are complete

**Tick week 7 in [`PLANNER.md`](../../PLANNER.md).**
