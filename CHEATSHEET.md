# SQL cheat sheet

One page. Every command you'll use, with a plain-English translation.

Keep this open in a tab while you work.

---

## The shape of a query

```sql
SELECT   columns          -- WHICH COLUMNS you want
FROM     table            -- WHICH TABLE they come from
JOIN     other ON ...     -- WHICH OTHER TABLES to attach
WHERE    condition        -- WHICH ROWS qualify
GROUP BY columns          -- sort rows into piles
HAVING   condition        -- WHICH PILES qualify
ORDER BY columns          -- WHAT ORDER to return them
LIMIT    n;               -- HOW MANY to return
```

**But the database runs them in this order** — which explains most beginner errors:

```
FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY → LIMIT
```

`WHERE` runs before `SELECT`, so it can't see your aliases.
`ORDER BY` runs after, so it can.

---

## Choosing rows and columns

```sql
SELECT *                        -- every column (fine to explore, bad to save)
SELECT a, b                     -- just these
SELECT DISTINCT country         -- unique values only
SELECT price * 2 AS doubled     -- calculate, and name it

WHERE price > 100               -- numbers: no quotes
WHERE category = 'Storage'      -- text: SINGLE quotes, case-sensitive
WHERE is_active                 -- booleans need no comparison
WHERE NOT is_discontinued
WHERE a = 1 AND b = 2           -- both
WHERE a = 1 OR  b = 2           -- either
WHERE (a = 1 OR b = 2) AND c    -- BRACKET when mixing AND/OR
WHERE country IN ('a','b','c')  -- tidier than three ORs
WHERE price BETWEEN 50 AND 150  -- inclusive at BOTH ends
WHERE name LIKE 'Nimbus%'       -- % = any chars, _ = one char
WHERE name ILIKE '%ssd%'        -- case-insensitive (Postgres)
WHERE country IS NULL           -- NEVER "= NULL"
WHERE country IS NOT NULL

ORDER BY price DESC             -- biggest first (ASC is default)
ORDER BY category, price DESC   -- group by first, sort within
LIMIT 10
```

---

## NULL — read this twice

```sql
NULL              -- means UNKNOWN. Not zero. Not empty text.
= NULL            -- ✗ NEVER works, silently matches nothing
IS NULL           -- ✓ the only way to test
IS NOT NULL

WHERE country <> 'Nigeria'                    -- 33 rows: drops the unknowns
WHERE country <> 'Nigeria' OR country IS NULL -- 37 rows: keeps them
WHERE country IS DISTINCT FROM 'Nigeria'      -- 37 rows: same, shorter

COALESCE(country, 'Unknown')    -- first non-NULL value
NULLIF(x, 0)                    -- NULL if x is 0 → divide-by-zero guard
```

**The check that catches NULL bugs:** split a table in two, and the two sizes must add up to
the total. If they don't, `NULL` is involved.

---

## Counting and grouping

```sql
count(*)             -- counts ROWS
count(column)        -- counts NON-NULL values  ← different!
count(DISTINCT col)  -- counts unique values
sum(x)  avg(x)  min(x)  max(x)       -- all IGNORE NULLs
round(avg(price), 2) -- 2 decimal places

SELECT   category, count(*) AS n
FROM     products
WHERE    NOT is_discontinued      -- filters ROWS, before grouping
GROUP BY category
HAVING   count(*) >= 3            -- filters GROUPS, after
ORDER BY n DESC;

-- count subsets side by side, one pass
count(*) FILTER (WHERE status = 'completed')

-- median (the average often lies)
percentile_cont(0.5) WITHIN GROUP (ORDER BY spend)
```

**`WHERE` = about one row. `HAVING` = about a whole group.**

---

## Joining tables

```sql
-- keep only matching rows on both sides
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id

-- keep ALL of the left table, matched or not
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id

-- three tables
FROM orders o
JOIN order_items oi ON oi.order_id  = o.order_id
JOIN products    p  ON p.product_id = oi.product_id

-- a table joined to itself
FROM      employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id

-- rows with NO match (anti-join)
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)
```

### ⚠ After a LEFT JOIN

```sql
count(*)              -- ✗ counts the empty row: returns 1 where the answer is 0
count(o.order_id)     -- ✓ counts a RIGHT-table column, skips NULLs
```

### ⚠ Fan-out

Joining a parent to its children **multiplies the parent's rows**.

```sql
SELECT count(*) FROM orders;                   -- 120
SELECT count(*) FROM orders JOIN order_items…; -- 300  ← one row is now a LINE ITEM
```

Anything order-level you `SUM` after that is counted once per line.

```sql
max(o.shipping_fee)   -- ✓ once per group
sum(o.shipping_fee)   -- ✗ once per line item
```

**Count your rows before and after every join.**

---

## Subqueries and CTEs

```sql
-- one value
WHERE price > (SELECT avg(price) FROM products)

-- a list
WHERE id IN (SELECT customer_id FROM orders WHERE status = 'refunded')

-- does a match exist? (cannot fan out)
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)

-- named steps, top to bottom  ← use these
WITH totals AS (
    SELECT customer_id, sum(amount) AS total
    FROM   payments
    GROUP  BY customer_id
),
ranked AS (
    SELECT * FROM totals WHERE total > 1000
)
SELECT * FROM ranked;
```

**Debugging trick:** run any CTE on its own to see what it produces.
`WITH totals AS (...) SELECT * FROM totals LIMIT 10;`

---

## Window functions

Calculate across rows **while keeping every row**.

```sql
avg(price) OVER (PARTITION BY category)      -- category average on every row
sum(x)     OVER (ORDER BY month)             -- running total
lag(x)     OVER (ORDER BY month)             -- previous row's value
lead(x)    OVER (ORDER BY month)             -- next row's value

ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC)  -- 1,2,3 always distinct
RANK()       OVER (...)                       -- ties share, then SKIP  (1,2,2,4)
DENSE_RANK() OVER (...)                       -- ties share, no skip    (1,2,2,3)

-- 3-month moving average
avg(x) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
```

**Top N per group** — memorise this shape:

```sql
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY price DESC) AS rn
    FROM   products
)
SELECT * FROM ranked WHERE rn <= 2;
```

**% change, safely:**
```sql
round(100.0 * (rev - lag(rev) OVER (ORDER BY m))
      / NULLIF(lag(rev) OVER (ORDER BY m), 0), 1)
```

---

## Dates, text, types

```sql
CURRENT_DATE
order_date + 30                          -- 30 days later
date_trunc('month', order_date)::date    -- first day of that month
EXTRACT(YEAR FROM order_date)
AGE(CURRENT_DATE, signup_date)
to_char(order_date, 'YYYY-MM')           -- '2024-07'
to_date('05/04/2024', 'DD/MM/YYYY')      -- ⚠ ambiguous format — ask, don't guess

'49.00'::numeric                         -- cast text to number
CAST('49.00' AS numeric)                 -- same, portable

lower(x)  upper(x)  initcap(x)
btrim(x)                                 -- trim both ends
length(x)
replace(x, ',', '')
split_part(email, '@', 2)
a || b                                   -- join text together

x ~ '^[0-9]+$'                           -- matches this pattern
regexp_replace(x, '[^0-9.]', '', 'g')    -- strip non-numeric ('g' = all)
```

**Safe date range for timestamps** — avoids losing the last day:
```sql
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'
```

**Fill gaps in a time series:**
```sql
SELECT generate_series(DATE '2024-01-01', DATE '2025-10-01', INTERVAL '1 month')::date
```
…then `LEFT JOIN` your real data onto it, so empty months appear as zeros.

---

## Creating and changing

```sql
CREATE TABLE suppliers (
    supplier_id integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        text        NOT NULL,
    email       text        UNIQUE,
    terms       text        NOT NULL DEFAULT 'net30'
                            CHECK (terms IN ('net30','net60','prepaid')),
    created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE t ADD COLUMN x integer;
ALTER TABLE t ALTER COLUMN x SET NOT NULL;
DROP TABLE t;
```

**Type choices that matter:**

| Use | Not |
|---|---|
| `numeric(10,2)` for money | ⚠ never `float` — it can't store 0.10 exactly |
| `text` | `varchar(255)` — a limit you invented |
| `timestamptz` | `timestamp` — no time zone |
| `boolean` | `'Y'`/`'N'` text |

---

## Writing data — safely

```sql
-- 1. ALWAYS look first, with the SAME where clause
SELECT * FROM products WHERE category = 'Cables';   -- 3 rows. Expected 3. Good.

-- 2. Then change it, inside a transaction
BEGIN;
UPDATE products SET unit_price = unit_price * 1.10
WHERE  category = 'Cables'
RETURNING product_id, product_name, unit_price;     -- see what changed
-- check it looks right, then:
COMMIT;    -- keep it
ROLLBACK;  -- undo everything
```

```sql
INSERT INTO t (a, b) VALUES (1, 2) RETURNING id;    -- always name your columns
UPDATE t SET a = 1 WHERE id = 5;
DELETE FROM t WHERE id = 5;

-- insert, or update if it exists
INSERT INTO t (id, name) VALUES (1, 'x')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;
```

**The four-second habit that prevents the career-defining mistake:**
run your `WHERE` as a `SELECT` before you run it as an `UPDATE` or `DELETE`.

`UPDATE products SET price = price * 1.1;` — one missing `WHERE`, whole catalogue repriced,
no warning, no undo after `COMMIT`.

---

## Speed

```sql
EXPLAIN         SELECT ...      -- show the plan, don't run it
EXPLAIN ANALYZE SELECT ...      -- run it and show real times  ⚠ really does write on UPDATE

CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_cust_date   ON orders (customer_id, order_date);  -- order matters
CREATE INDEX idx_orders_pending     ON orders (order_date) WHERE status = 'pending';
ANALYZE orders;                 -- refresh planner statistics — free, fixes bad plans

-- which indexes is nobody using?
SELECT relname, indexrelname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0;
```

**In a plan, look for:** `Rows Removed by Filter` (work thrown away), and estimated vs actual
rows (a big gap means run `ANALYZE`).

**Index every foreign key.** Postgres indexes primary keys automatically but **not** foreign
keys.

---

## Views and permissions

```sql
CREATE OR REPLACE VIEW live_products AS
SELECT * FROM products WHERE NOT is_discontinued;    -- saved query, no data stored

CREATE MATERIALIZED VIEW mv AS SELECT ...;           -- stores data, can go stale
REFRESH MATERIALIZED VIEW mv;

CREATE ROLE analyst NOLOGIN;
GRANT USAGE ON SCHEMA shop TO analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO analyst;
GRANT SELECT (customer_id, country) ON customers TO analyst;   -- specific columns only
```

---

## Inspecting any database

```sql
SET search_path TO shop, public;         -- run this first, every session

SELECT * FROM products LIMIT 5;          -- ALWAYS look before you query

SELECT table_name FROM information_schema.tables WHERE table_schema = 'shop';

SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'shop' AND table_name = 'orders';
```

---

## The five checks before you trust a number

1. Did I exclude `cancelled` and `refunded`? *(12 of 120 orders)*
2. Did a join multiply my rows? *(count before and after)*
3. Do my two groups add up to the total? *(if not — `NULL`)*
4. Am I using `oi.unit_price` (at sale) rather than `p.unit_price` (today)?
5. Is my first or last time period **complete**? *(partial periods fake growth and collapse)*
