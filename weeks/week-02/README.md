# Week 2 — Filtering properly

**Time:** ~2.5 hours
**You'll learn:** `AND`/`OR`/`NOT`, precedence, `IN`, `BETWEEN`, `LIKE`, `IS NULL`, `DISTINCT`

This is the week `NULL` stops being intuitive and starts being understood. Do not skip it.
The bug it teaches you to see is one that ships to production constantly, in code written
by people with years of experience, because it produces *plausible* wrong answers rather
than errors.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Combining conditions

```sql
WHERE category = 'Storage' AND unit_price > 100   -- both must be true
WHERE category = 'Storage' OR  category = 'Power' -- either will do
WHERE NOT is_discontinued                         -- flips true and false
```

### Precedence: the bug that hides in plain sight

`AND` binds tighter than `OR`. That is, SQL evaluates all the `AND`s first, exactly like
`×` before `+` in arithmetic.

```sql
-- What you probably meant: (Storage or Power) products over $100
-- What this actually says: Storage products, OR any Power product at any price
WHERE category = 'Storage' OR category = 'Power' AND unit_price > 100
```

The database reads that as `category = 'Storage' OR (category = 'Power' AND unit_price > 100)`.
You get every Storage product regardless of price, plus expensive Power products. No error.
Just a wrong answer that looks fine.

**Use brackets whenever `AND` and `OR` appear in the same `WHERE` clause.** Not because
you've forgotten the rule — because the next person reading it shouldn't have to remember
it either.

```sql
WHERE (category = 'Storage' OR category = 'Power')
  AND unit_price > 100
```

### IN — the readable OR

```sql
WHERE country = 'Ireland' OR country = 'United Kingdom' OR country = 'Germany'
WHERE country IN ('Ireland', 'United Kingdom', 'Germany')     -- identical, far better
```

`NOT IN` inverts it — and carries a `NULL` landmine we'll get to below.

### BETWEEN — inclusive at both ends

```sql
WHERE unit_price BETWEEN 50 AND 150      -- same as: >= 50 AND <= 150
```

**`BETWEEN` includes both endpoints.** A product at exactly 50.00 is included. This bites
hardest with dates:

```sql
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'   -- fine for a date column
```

That's correct here because `order_date` is a `date`. But if a column is a *timestamp*,
`'2024-12-31'` means `2024-12-31 00:00:00` — and you silently lose everything that
happened during that final day. The safe habit for timestamps is a half-open range:

```sql
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'
```

`>=` start, `<` next start. It's correct for dates and timestamps alike, and it never
needs you to remember how many days are in February.

### LIKE — pattern matching

Two wildcards: `%` matches any number of characters, `_` matches exactly one.

```sql
WHERE product_name LIKE 'Nimbus%'      -- starts with Nimbus
WHERE email        LIKE '%@example.com' -- ends with @example.com
WHERE product_name LIKE '%SSD%'         -- contains SSD anywhere
WHERE sku          LIKE 'NW-___-%'      -- NW-, exactly 3 chars, then a dash
```

`LIKE` is case-sensitive. Postgres offers `ILIKE` for case-insensitive matching:

```sql
WHERE product_name ILIKE '%ssd%'        -- matches SSD, ssd, Ssd
```

`ILIKE` is a Postgres extension, not standard SQL. It won't work in MySQL or SQL Server.
Worth knowing when you're following a tutorial written for a different database.

### DISTINCT — unique values only

```sql
SELECT DISTINCT category FROM products;              -- 6 rows
SELECT DISTINCT category, is_discontinued FROM products;  -- unique COMBINATIONS
```

`DISTINCT` applies to the whole row of selected columns, not just the first one. That
second query gives unique category+flag *pairs*, which is usually what you want but rarely
what beginners expect.

---

### NULL — the important part of this week

`NULL` does not mean zero. It does not mean empty string. **It means "unknown".**

Four of our customers have `NULL` in `country` — they never filled the field in. We don't
know where they live. That is genuinely different from living nowhere.

Once you accept "unknown", the strange behaviour becomes obvious:

```sql
SELECT NULL = NULL;      -- NULL, not true
```

Is one unknown value equal to another unknown value? You can't say. Two people whose ages
you don't know might be the same age, or might not. The honest answer is "unknown", and
`NULL` is how SQL says that.

**So `NULL` fails every comparison** — including `=`, `<>`, `>`, and `<`. It doesn't
return false; it returns `NULL`, which `WHERE` treats as "don't include this row".

#### The trap, with real numbers

We have 40 customers. Three of them live in Nigeria. So how many do *not* live in Nigeria?

You'd say 37. Here's what SQL says:

```sql
SELECT count(*) FROM customers WHERE country <> 'Nigeria';   -- 33
```

**Thirty-three.** Four customers vanished — the four with `NULL` country. For each of
them, SQL asked "is unknown different from 'Nigeria'?" and answered, correctly, "unknown".
Unknown is not true, so the row was excluded.

No error. No warning. Just four missing people and a number that looks perfectly
reasonable. If this were a mailing list, four customers never got the email. If it were a
compliance report, you under-reported.

#### Testing for NULL

You cannot use `=`. You must use `IS`:

```sql
WHERE country IS NULL          -- correct
WHERE country IS NOT NULL      -- correct
WHERE country = NULL           -- always matches nothing. Never an error. Never right.
```

`WHERE country = NULL` returning zero rows silently is arguably SQL's least friendly
design decision.

#### Fixing the trap

Decide what you want and say it explicitly:

```sql
-- "Not Nigeria, and I want the unknowns counted as not-Nigeria" - 37 rows
WHERE country <> 'Nigeria' OR country IS NULL

-- Postgres shorthand for exactly the same thing
WHERE country IS DISTINCT FROM 'Nigeria'

-- "Not Nigeria, and I only want customers whose country I actually know" - 33 rows
WHERE country <> 'Nigeria' AND country IS NOT NULL
```

All three are defensible. What is *not* defensible is writing `<> 'Nigeria'` without
having thought about it — because then you don't know which of these you got.

#### NOT IN with NULLs — the nastier version

```sql
WHERE country NOT IN ('Nigeria', NULL)     -- returns ZERO rows. Always.
```

If the list contains a `NULL`, `NOT IN` can never be true for any row, so you get nothing
back. This is genuinely surprising and it is the reason experienced people prefer
`NOT EXISTS` (week 6) when the list comes from a subquery that might contain `NULL`s.

#### COALESCE — substituting a default

```sql
SELECT first_name,
       COALESCE(country, 'Unknown') AS country
FROM   customers;
```

`COALESCE` returns its first non-`NULL` argument. Handy for display. Be careful using it in
`WHERE` clauses — replacing unknowns with a made-up value can hide the very gap you should
be reporting.

#### NULL in aggregates (a preview of week 3)

```sql
SELECT count(*)       FROM customers;   -- 40 - counts rows
SELECT count(country) FROM customers;   -- 36 - counts NON-NULL values
```

`count(*)` counts rows. `count(column)` counts non-null values in that column. The
difference between those two numbers is exactly your missing-data count — which makes it a
free data-quality check.

---

## Part 2 — Worked example (~20 min)

**The question:** *Which customers are outside our three core European markets?*

Core markets are Ireland, the United Kingdom, and Germany.

### The obvious attempt

```sql
SELECT first_name, last_name, country
FROM   customers
WHERE  country NOT IN ('Ireland', 'United Kingdom', 'Germany');
```

**29 rows.**

### Check the arithmetic

40 customers total. How many *are* in the core markets?

```sql
SELECT count(*) FROM customers
WHERE country IN ('Ireland', 'United Kingdom', 'Germany');    -- 7
```

40 − 7 = 33. But our query returned **29**. Four customers are in neither result.

They're the four with `NULL` country. `NOT IN` couldn't decide about them, so they fell
out of both — present in neither the "core market" list nor the "outside core markets"
list. They have quietly disappeared from the business.

### Now decide what you actually meant

If the question is "who should our non-core sales team contact?", those four unknowns are
*exactly* the people worth calling — you don't know where they are, so nobody has claimed
them.

```sql
SELECT first_name,
       last_name,
       COALESCE(country, '(unknown)') AS country
FROM   customers
WHERE  country NOT IN ('Ireland', 'United Kingdom', 'Germany')
   OR  country IS NULL
ORDER  BY country NULLS LAST, last_name;
```

**33 rows.** Now 7 + 33 = 40, and every customer is accounted for exactly once.

`NULLS LAST` in the `ORDER BY` controls where unknowns sort. By default Postgres sorts
`NULL`s last ascending and first descending, which is one more thing not to leave to
chance.

### The habit worth stealing

**When you filter a table into two groups, the two group sizes should add up to the
total.** If they don't, `NULL` is involved. That thirty-second check catches this entire
class of bug, forever, and it costs you one `count(*)`.

---

## Part 3 — Exercises (~60 min)

Attempt properly before opening [`solutions/week-02.sql`](../../solutions/week-02.sql).

### Exercise 2.1 — IN

List the first name, last name, country and city of every customer in Ireland, the United
Kingdom, or Germany. Sort by country, then last name.

*Expected: 7 rows.*

### Exercise 2.2 — BETWEEN and a compound condition

Find every product priced between $50 and $150 inclusive that is **not** discontinued.
Show name, category and price, cheapest first.

*Expected: 9 rows. Then check: is the product priced at exactly $64.00 in your results?
It should be — confirm you understand why `BETWEEN` includes it. Also note that dropping
the discontinued filter gives 10 rows, so the extra row is a product you can't actually
sell.*

### Exercise 2.3 — The NULL trap, on purpose

Write a query listing every customer who is **not** in Nigeria.

Write it twice:

- **(a)** the naive way, using `<> 'Nigeria'`
- **(b)** the way that includes customers whose country is unknown

Report both row counts, and write a one-sentence comment explaining the difference.

*Expected: (a) 33, (b) 37. If you get 33 for both, you haven't handled the NULLs yet.*

---

## Part 4 — Mini-project (~30 min)

### A data-quality audit of `customers`

You've been asked: *"Can we trust the customer table?"* Answer it with evidence.

Write **separate queries** to establish each of the following, then write up your findings
as SQL comments:

1. How many customers are there in total?
2. How many have a `NULL` country? Which ones? (Show their names and emails.)
3. How many have a `NULL` city?
4. How many distinct countries appear? (Careful: does `count(DISTINCT country)` include
   `NULL` as a value? Verify rather than assuming.)
5. Are there customers who look like test accounts rather than real people? Find them
   with a `LIKE`/`ILIKE` pattern on name or email. *(Hint: two of our 40 are unmistakably
   fake. Two more are arguable — and the argument is the interesting part.)*
6. How many customers are marked inactive?
7. Do any customers have a `NULL` country but a non-`NULL` city, or vice versa? What would
   that tell you about how the data was collected?

**Then write a short verdict**, as a comment at the bottom: can this table be trusted for
a country-level sales report, yes or no, and what would you tell the person who asked?

There's no single correct verdict. What's being marked is whether your answer is supported
by the numbers you just produced — which is the actual job.

---

## Checklist

- [ ] You can explain why `WHERE country <> 'Nigeria'` returns 33 rather than 37
- [ ] You always bracket `AND`/`OR` combinations
- [ ] You use `IS NULL`, never `= NULL`
- [ ] You know why `NOT IN (..., NULL)` returns nothing
- [ ] You know the difference between `count(*)` and `count(column)`

**Tick week 2 in [`PLANNER.md`](../../PLANNER.md).**
