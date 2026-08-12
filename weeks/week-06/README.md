# Week 6 — Subqueries & CTEs

**Time:** ~2.5 hours
**You'll learn:** scalar subqueries, `IN`/`EXISTS`, derived tables, and `WITH` (CTEs)

Up to now, hard questions needed one clever query. This week you learn the alternative:
break a hard question into three easy queries and stack them. It's the single biggest
improvement you can make to how readable your SQL is — and readability is what makes SQL
maintainable.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### A subquery is a query inside a query

They come in three shapes, distinguished by what they return.

### Shape 1: scalar subquery — returns one value

```sql
SELECT product_name, unit_price
FROM   products
WHERE  NOT is_discontinued
  AND  unit_price > (SELECT avg(unit_price) FROM products WHERE NOT is_discontinued);
```

The inner query returns a single number (160.13). The outer query compares each row against
it. **8 rows** come back.

This solves a problem you couldn't solve before: you cannot write `WHERE unit_price > avg(unit_price)`,
because `WHERE` runs before aggregation. The subquery computes the average *first*, as a
separate step, and hands down one value.

Note the inner query repeats `WHERE NOT is_discontinued`. That's deliberate — you want the
average of *live* products, not of everything. Forget it and you're comparing live products
against an average dragged down by dead ones. Subqueries need their own filters; they don't
inherit the outer query's.

### Shape 2: subquery returning a list — for `IN`

```sql
SELECT first_name, last_name
FROM   customers
WHERE  customer_id IN (SELECT customer_id FROM orders WHERE status = 'refunded');
```

"Customers whose ID appears in this list of IDs."

Careful: if the inner query can return `NULL`, `NOT IN` breaks in the way week 2 described —
it returns nothing at all. This is the single best reason to prefer `EXISTS`.

### Shape 3: correlated subquery — `EXISTS`

```sql
SELECT c.first_name, c.last_name
FROM   customers c
WHERE  EXISTS (SELECT 1 FROM orders o
               WHERE o.customer_id = c.customer_id      -- refers to the OUTER query
                 AND o.status = 'refunded');
```

This one is *correlated*: the inner query references `c.customer_id` from the outer query, so
it runs once per outer row, asking "does this particular customer have a refunded order?"

`SELECT 1` looks odd. It's idiomatic — `EXISTS` only cares *whether* rows come back, never
what's in them, so you select a constant rather than pretending to fetch a column.

**`EXISTS` vs `IN` vs `JOIN` — when to use which:**

| Use | When |
|---|---|
| `JOIN` | You need columns from the other table |
| `EXISTS` | You only need to know a match exists |
| `NOT EXISTS` | You need rows with no match |
| `IN` | Small, fixed list; you're confident there are no `NULL`s |

The key advantage of `EXISTS` over `JOIN`: **it cannot fan out.** It answers yes/no and stops.
If a customer has 8 matching orders, `EXISTS` still yields one row. `JOIN` would yield 8.
After week 5 you should feel the weight of that.

### Shape 4: derived table — a subquery in `FROM`

```sql
SELECT avg(order_total) AS avg_order_value
FROM  (SELECT o.order_id,
              sum(oi.quantity * oi.unit_price) AS order_total
       FROM   orders o
       JOIN   order_items oi ON oi.order_id = o.order_id
       GROUP  BY o.order_id) AS order_totals;
```

You cannot nest aggregates — `avg(sum(x))` is an error. So you compute the sums in an inner
query, treat that result as a table, and average it in the outer query.

**This is also the clean fix for fan-out**, exactly as week 5 showed: aggregate the child
table down to one row per parent first, then join.

Derived tables in Postgres must be aliased. Leave off `AS order_totals` and you get
`subquery in FROM must have an alias`.

### CTEs — the same thing, but readable

A **Common Table Expression** moves the subquery to the top, gives it a name, and lets the
main query read like a sentence.

```sql
WITH order_totals AS (
    SELECT o.order_id,
           sum(oi.quantity * oi.unit_price) AS order_total
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    GROUP  BY o.order_id
)
SELECT avg(order_total) AS avg_order_value
FROM   order_totals;
```

Identical result. Vastly easier to read, and the difference compounds as queries grow.

**Multiple CTEs chain, and later ones can use earlier ones:**

```sql
WITH order_totals AS (
    SELECT o.order_id, o.customer_id,
           sum(oi.quantity * oi.unit_price) AS order_total
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    WHERE  o.status IN ('completed','shipped')
    GROUP  BY o.order_id, o.customer_id
),
customer_spend AS (
    SELECT customer_id,
           sum(order_total) AS lifetime_value,
           count(*)         AS orders
    FROM   order_totals              -- uses the CTE above
    GROUP  BY customer_id
)
SELECT c.first_name, c.last_name, s.orders, s.lifetime_value
FROM   customer_spend s
JOIN   customers c ON c.customer_id = s.customer_id
ORDER  BY s.lifetime_value DESC
LIMIT  10;
```

Read that top to bottom: *work out each order's total; roll those up per customer; attach
names and show the top ten.* Three simple steps, each independently checkable.

**The debugging superpower.** You can run any CTE on its own to see what it produces:

```sql
WITH order_totals AS ( ... )
SELECT * FROM order_totals LIMIT 10;    -- just look at step one
```

When a five-step query gives a wrong answer, this is how you find which step broke it. That
alone justifies writing CTEs instead of nested subqueries.

**Style that pays off:** name CTEs after what they *contain* (`order_totals`, `monthly_sales`),
not what they do (`step1`, `temp`). And keep each CTE to one job — if you can't name it in
two words, it's doing two things.

### generate_series — inventing rows that don't exist

Week 3 left a problem unsolved: a month with no orders produces no row, so a chart silently
skips it. Here's the fix.

```sql
SELECT generate_series(DATE '2024-01-01', DATE '2025-10-01', INTERVAL '1 month')::date AS month;
```

That produces **22 rows** — every month in the range, whether or not any order exists in it.
`LEFT JOIN` your real data onto that scaffold and empty months survive as genuine zeros:

```sql
WITH months AS (
    SELECT generate_series(DATE '2024-01-01', DATE '2025-10-01', INTERVAL '1 month')::date AS month
)
SELECT m.month,
       count(o.order_id) AS orders          -- count a right-table column, per week 4
FROM      months m
LEFT JOIN orders o ON date_trunc('month', o.order_date)::date = m.month
GROUP BY  m.month
ORDER BY  m.month;
```

Now a dead month appears as `0` rather than vanishing. This pattern — build a complete
scaffold, `LEFT JOIN` reality onto it — is one of the most useful things in this course, and
it applies to any dimension with gaps: dates, categories, statuses, regions.

---

## Part 2 — Worked example (~20 min)

**The question:** *Which customers spend more than the average customer?*

### Step 1: Notice it's three questions

1. What did each customer spend?
2. What is the average of those totals?
3. Which customers are above it?

Trying to write that as one query is how people end up with something unreadable. Write three
steps instead.

### Step 2: Spend per customer

```sql
WITH customer_spend AS (
    SELECT   o.customer_id,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS spend
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed', 'shipped')
    GROUP BY o.customer_id
)
SELECT * FROM customer_spend ORDER BY spend DESC LIMIT 5;
```

**37 rows** — customers with at least one completed or shipped order. Run this on its own
first and eyeball it. Do the numbers look like plausible money? Good. Continue.

### Step 3: Add the comparison

```sql
WITH customer_spend AS (
    SELECT   o.customer_id,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS spend
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed', 'shipped')
    GROUP BY o.customer_id
)
SELECT   c.first_name,
         c.last_name,
         c.country,
         s.spend,
         round((SELECT avg(spend) FROM customer_spend), 2) AS avg_spend
FROM     customer_spend s
JOIN     customers c ON c.customer_id = s.customer_id
WHERE    s.spend > (SELECT avg(spend) FROM customer_spend)
ORDER BY s.spend DESC;
```

**12 rows.** Twelve customers out of 37 are above average.

### Step 4: Read the result properly

Twelve out of 37 is **32%**, not 50%. If "above average" strikes you as something roughly
half the customers should be, that instinct is wrong — and the gap is the interesting finding.

Spending is **skewed**: a few large customers drag the mean upward, so most customers sit
below it. This is normal for revenue data and it means **the mean is a poor summary here**.
The median would describe a typical customer far better.

That's not a flaw in your query. It's a fact about the data that your query revealed — and
noticing it is the difference between running a query and doing analysis. If someone asks
"how much does a typical customer spend?", answering with the mean would mislead them.

### Step 5: Note what you'd say

> "12 of our 37 buying customers spend above the average of $2,908.92. But the average is
> pulled up by a handful of large accounts — the median customer spends $2,380.50, about 22%
> less. If you want a figure describing a typical customer, use the median."

Those two numbers being 22% apart is the whole story. Our largest customer, Carlos Mendoza,
spent $8,930.55 — roughly four times the median — and a single account like that is enough to
drag the mean away from anything typical.

You'll compute the median properly in week 7. For now, notice the habit: **when you report an
average, check whether the median disagrees with it.** If they're close, the average is a fair
summary. If they're far apart, the average is describing a distribution rather than a person,
and saying "the average customer spends $2,908" puts a number in someone's head that describes
almost nobody.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-06.sql`](../../solutions/week-06.sql).

### Exercise 6.1 — Scalar subquery

List every non-discontinued product priced **above the average price of non-discontinued
products**. Show name, category, price, and the average as a column so the comparison is
visible. Most expensive first.

*Expected: 8 rows, average 160.13. Watch the inner filter — if your average comes out
different, you've probably included discontinued products in it.*

### Exercise 6.2 — EXISTS

Find every customer who has bought at least one product in the **Storage** category. Show
first name, last name and country, sorted by last name.

Use `EXISTS`, not `JOIN`. Then write a comment explaining what would go wrong with a plain
`JOIN` here.

*Expected: 29 rows. A `JOIN` version would return far more — work out why before checking.*

### Exercise 6.3 — Rewrite as a CTE

Here is a working but unpleasant query:

```sql
SELECT c.first_name, c.last_name, t.orders, t.total
FROM   customers c
JOIN  (SELECT o.customer_id,
              count(DISTINCT o.order_id) AS orders,
              round(sum(oi.quantity * oi.unit_price), 2) AS total
       FROM   orders o
       JOIN   order_items oi ON oi.order_id = o.order_id
       WHERE  o.status IN ('completed','shipped')
       GROUP  BY o.customer_id) t ON t.customer_id = c.customer_id
WHERE  t.total > 3000
ORDER  BY t.total DESC;
```

Rewrite it using a CTE so it reads top to bottom. The result must be identical. Then add a
second CTE that also brings in each customer's **most recent order date**, and include that
as a column.

*Hint for the second part: build the second CTE from `orders` alone with `max(order_date)`,
then join both CTEs. Do not add another join to `order_items` — that's the fan-out trap.*

---

## Part 4 — Mini-project (~30 min)

### The monthly report, with no missing months

Week 3 built a monthly summary and left a hole in it: a month with zero orders produces no
row, so any chart drawn from it silently skips the gap. Fix that now.

Build a query that returns **one row for every month from January 2024 to October 2025
inclusive** — all 22 of them — showing:

- the month
- orders placed (0 where none)
- completed orders (0 where none)
- revenue from completed and shipped orders (0.00 where none)
- the number of distinct customers who ordered that month

Requirements:

1. Use `generate_series` to build the month scaffold.
2. Use at least two CTEs.
3. `LEFT JOIN` real data onto the scaffold, never the other way round.
4. No month may be missing, and no `NULL`s in the output — use `COALESCE` to turn absent data
   into `0`.

**Then verify and answer, in comments:**

1. Confirm you have exactly 22 rows.
2. Confirm your total order count sums to 120... and if it doesn't, explain why not before
   assuming you're wrong.
3. Now **delete every order from March 2024** in a scratch copy of your query (add
   `WHERE order_date NOT BETWEEN '2024-03-01' AND '2024-03-31'` to the orders CTE) and re-run.
   Does March still appear, with zeros? If it doesn't, your `LEFT JOIN` is pointing the wrong
   way — and that's the whole lesson of this mini-project.

Question 3 is the real test. It's easy to write a query that *looks* like it handles gaps and
only proves it when a gap actually exists.

---

## Checklist

- [ ] You can explain why `WHERE price > avg(price)` fails but a scalar subquery works
- [ ] You use `EXISTS` when you only need to test for a match
- [ ] You can rewrite a nested subquery as a CTE
- [ ] You run individual CTEs on their own to debug a long query
- [ ] You can build a complete date scaffold with `generate_series` and `LEFT JOIN` onto it
- [ ] You noticed the mean is a bad summary of skewed data

**Tick week 6 in [`PLANNER.md`](../../PLANNER.md).**
