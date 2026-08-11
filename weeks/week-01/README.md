# Week 1 — Reading data

**Time:** ~2.5 hours
**You'll learn:** `SELECT`, `FROM`, `WHERE`, `ORDER BY`, `LIMIT`, aliases, comments

By the end of this week you can pull any subset of rows and columns out of a single
table, in any order you like. That is genuinely most of day-to-day SQL.

---

## Before you start

Open the SQL editor: **https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql**

Run this first, every session:

```sql
SET search_path TO shop, public;
```

Without it you get `relation "products" does not exist`. With it, Postgres knows to look
in our `shop` schema. Run it once per editor tab.

---

## Part 1 — Concepts (~30 min)

### A query is a question, not a command

This is the mental shift that makes SQL click. You don't tell the database *how* to find
the data — you describe *what you want* and let it work out the how.

"Give me the names of every product costing more than $200" is a description. The
database decides whether to scan the table, use an index, or parallelise. That's its
problem, not yours.

### The four clauses that do 90% of the work

```sql
SELECT   product_name, unit_price   -- WHICH COLUMNS you want back
FROM     products                   -- WHICH TABLE they come from
WHERE    unit_price > 200           -- WHICH ROWS qualify
ORDER BY unit_price DESC;           -- WHAT ORDER to return them in
```

Run it. Six rows come back.

Two things to notice immediately:

**The semicolon ends the statement.** Postgres mostly tolerates its absence, but get in
the habit — the moment you run two statements at once, it stops being optional.

**Capitalisation is a convention, not a rule.** `select` works exactly like `SELECT`.
Keywords are conventionally uppercased so your eye can separate the SQL from the table
and column names. Follow the convention; whoever reads your query next will thank you,
and often that person is you in six months.

### SELECT — choosing columns

```sql
SELECT * FROM products;                    -- every column
SELECT product_name FROM products;         -- one column
SELECT product_name, category FROM products;  -- several, in the order you name them
```

`SELECT *` is fine while exploring. It is a bad habit in anything you save, because the
moment somebody adds a column your query silently starts returning it — and if your code
depended on column positions, it breaks. Name your columns.

### Aliases — renaming output columns

```sql
SELECT product_name AS product,
       unit_price   AS price_usd
FROM   products;
```

The `AS` keyword renames a column *in the output only*. The table is untouched. This
matters more than it looks: once you start calculating things, the default column names
become unreadable.

```sql
SELECT product_name,
       unit_price - cost_price AS margin      -- without the alias this column
FROM   products;                              -- would be named "?column?"
```

You can do arithmetic right in the `SELECT` list. `+`, `-`, `*`, `/` all work.

### WHERE — choosing rows

`WHERE` is a test applied to every row. Rows that pass come back; rows that fail don't.

```sql
WHERE unit_price > 200          -- greater than
WHERE unit_price >= 200         -- greater than or equal
WHERE category = 'Storage'      -- exactly equal (note: ONE equals sign)
WHERE category <> 'Storage'     -- not equal (<> and != both work)
WHERE is_discontinued = true    -- booleans need no comparison at all:
WHERE is_discontinued           -- ...this is identical to the line above
```

**Single quotes for text. Always.** `'Storage'` is a text value. `"Storage"` with double
quotes means something completely different in Postgres — it refers to a *column named*
Storage — and you'll get `column "Storage" does not exist`. This trips up everyone coming
from other languages exactly once.

Numbers and booleans take no quotes: `unit_price > 200`, not `unit_price > '200'`.

### ORDER BY — sorting

```sql
ORDER BY unit_price            -- ascending (the default)
ORDER BY unit_price ASC        -- ascending, said out loud
ORDER BY unit_price DESC       -- descending, biggest first
ORDER BY category, unit_price DESC   -- by category; within each, price descending
```

That last form is worth dwelling on. Sorting by two columns means "group them by the
first, then sort within each group by the second". It's how you produce a readable report
rather than a wall of rows.

**Without `ORDER BY`, row order is not guaranteed.** It might look stable today and change
tomorrow when the table grows or the plan changes. If order matters, say so explicitly.

### LIMIT — stopping early

```sql
SELECT * FROM products ORDER BY unit_price DESC LIMIT 5;
```

Ten most expensive? `LIMIT 10`. Use it constantly while exploring — there's no reason to
pull 300 rows into your browser when you only wanted to see the shape of the data.

`LIMIT` without `ORDER BY` gives you five *arbitrary* rows, not the top five. The database
returns whatever it finds first. Almost every time you write `LIMIT`, you want `ORDER BY`
above it.

### Comments

```sql
-- Everything after two dashes on a line is ignored.

/* This form spans
   several lines. */
```

Use them. A query explaining *why* it filters `status <> 'cancelled'` is worth more than
one that just does it.

### The one execution-order fact worth knowing now

You write clauses in this order:

```
SELECT ... FROM ... WHERE ... ORDER BY ... LIMIT ...
```

The database evaluates them in roughly this order:

```
FROM      →  find the table
WHERE     →  throw away rows that fail the test
SELECT    →  keep only the requested columns, compute expressions
ORDER BY  →  sort what's left
LIMIT     →  take the first N
```

Notice `WHERE` runs **before** `SELECT`. That single fact explains an error you are going
to hit this week:

```sql
SELECT unit_price - cost_price AS margin
FROM   products
WHERE  margin > 100;             -- ERROR: column "margin" does not exist
```

The alias `margin` is created by `SELECT`, which hasn't run yet when `WHERE` is evaluated.
The fix is to repeat the expression:

```sql
WHERE unit_price - cost_price > 100      -- works
```

Slightly annoying, entirely logical. (`ORDER BY` *can* see aliases, because it runs after
`SELECT`. Yes, that's inconsistent. Yes, everyone finds it odd.)

---

## Part 2 — Worked example (~20 min)

**The question:** *What are our five most expensive networking products?*

### Step 1: What do I need, and where does it live?

Products, with prices and categories — all in `products`. One table, so no joins. Good.

Start by looking at the raw material:

```sql
SELECT * FROM products LIMIT 5;
```

Always do this first. You'll see the columns you have — `category`, `unit_price`,
`is_discontinued` — and their actual values. Guessing at column names wastes more time
than looking.

### Step 2: Get the rows you want

```sql
SELECT * FROM products WHERE category = 'Networking';
```

Six rows. But how did I know the value is exactly `'Networking'` and not `'networking'`
or `'Network'`? I looked in step 1. **Text comparison is case-sensitive** —
`WHERE category = 'networking'` returns zero rows, and zero rows is an easy thing to
misread as "there is no networking data".

### Step 3: Get the columns you want

```sql
SELECT product_name, unit_price
FROM   products
WHERE  category = 'Networking';
```

### Step 4: Sort and cut

```sql
SELECT product_name, unit_price
FROM   products
WHERE  category = 'Networking'
ORDER  BY unit_price DESC
LIMIT  5;
```

### The actual result

| product_name | unit_price |
|---|---|
| 24-Port Managed Switch | 429.00 |
| Nimbus Router 2000 Pro | 349.00 |
| Nimbus Router 1000 | 189.00 |
| Ceiling Access Point 300 | 159.00 |
| Nimbus Router 500 (EOL) | 99.00 |

### Step 5: Look at the result and be suspicious

That last row says **(EOL)** — end of life. It's a discontinued product we no longer sell.
Should it be in a list of "our most expensive networking products"?

Almost certainly not. And notice that nothing failed — no error, no warning. The query did
exactly what I asked. I just asked slightly the wrong question.

```sql
SELECT product_name, unit_price
FROM   products
WHERE  category = 'Networking'
  AND  NOT is_discontinued        -- exclude products we don't sell any more
ORDER  BY unit_price DESC
LIMIT  5;
```

**This is the single most important habit in this entire course.** Getting a result is
easy. Getting the *right* result means reading what came back and asking whether it makes
sense. A query that runs without error can still be completely wrong, and SQL will never
tell you — only your own suspicion will.

---

## Part 3 — Exercises (~60 min)

Write these yourself. Attempt each one properly before opening
[`solutions/week-01.sql`](../../solutions/week-01.sql) — and if you're stuck, be stuck for
15 minutes first. That struggle is the lesson.

### Exercise 1.1 — Warm-up

List every product in the **Storage** category, showing only the product name and unit
price, most expensive first.

*Expected: 5 rows.*

### Exercise 1.2 — Two-column sort

Show the product name, category and unit price for every product that is **not**
discontinued. Sort by category (A–Z), and within each category by price (highest first).

*Expected: 23 rows. Check that both sorts are actually applied — categories in
alphabetical order, and prices descending inside each one.*

### Exercise 1.3 — Calculation, alias, filter

For every product, show the name, the unit price, the cost price, and a calculated column
called `margin` (unit price minus cost price). Return only products where the margin is
above $100, highest margin first.

*Expected: 6 rows. This one contains the alias trap from the concepts section — you will
probably hit the error. Hitting it is the point; make sure you understand why before you
fix it.*

---

## Part 4 — Mini-project (~30 min)

### Nimbus product catalogue report

The operations team wants a clean catalogue of everything currently for sale.

Write **one query** returning, for every product that is not discontinued:

- the SKU
- the product name
- the category
- the unit price, aliased as `price`
- the margin (unit price − cost price), aliased as `margin`
- the stock quantity, aliased as `in_stock`

Sorted by category alphabetically, then by margin (highest first) within each category.

Add a comment at the top saying what the query is for.

**Then answer these by reading your own output** — no new queries needed:

1. Which category has the highest-margin product overall?
2. Two products show `in_stock` of 0 but are not discontinued. Look at their names and
   suggest why that might be perfectly correct rather than a data error.
3. If the ops team asked "which products should we reorder?", what column would you need
   that this schema doesn't have?

Question 3 has no right answer in the data. It's asking you to notice a *gap* in the
schema — which is exactly the instinct week 9 is built on.

---

## Checklist

Before moving to week 2, you should be able to write, without looking anything up:

- [ ] A query selecting specific columns from one table
- [ ] A `WHERE` clause comparing text (with single quotes) and numbers (without)
- [ ] A sort on two columns with different directions
- [ ] A calculated column with a sensible alias
- [ ] An explanation of why `WHERE margin > 100` fails when `margin` is a `SELECT` alias

If any of those are shaky, redo the exercises rather than pushing on. Week 2 assumes all
five.

**Tick week 1 in [`PLANNER.md`](../../PLANNER.md).**
