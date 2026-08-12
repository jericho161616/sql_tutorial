# Error decoder

Every error you're likely to hit, in plain English, with the fix.

**First, the good news:** PostgreSQL error messages are unusually precise. They almost always
name the exact problem. The difficulty is that they name it in database vocabulary — and once
you can translate that, most errors fix themselves.

**Getting errors is not a sign you're bad at this.** It's the normal working rhythm. Experienced
people hit these too; they just recognise them faster.

Use `Ctrl+F` / `Cmd+F` to find your error.

---

## `relation "products" does not exist`

**The most common error in week 1.**

**Translation:** "Relation" means *table*. So: *there's no table called `products`.*

**Why:** You haven't told Postgres which schema to look in. Our tables live in `shop`.

**Fix — run this once at the top of your session:**
```sql
SET search_path TO shop, public;
```

Or write the full name every time: `SELECT * FROM shop.products;`

*(In the Study Console app this is already done for you.)*

---

## `column "margin" does not exist`

**Translation:** You used a name in `WHERE` that `SELECT` creates.

**Why:** The database runs `WHERE` **before** `SELECT`. When `WHERE` is evaluated, your alias
doesn't exist yet — `SELECT` hasn't run.

```sql
SELECT unit_price - cost_price AS margin
FROM   products
WHERE  margin > 100;              -- ✗ margin doesn't exist yet
```

**Fix — repeat the expression:**
```sql
WHERE unit_price - cost_price > 100      -- ✓
```

**Oddly, `ORDER BY margin DESC` works fine**, because `ORDER BY` runs *after* `SELECT`. Yes,
that's inconsistent. It follows from the execution order.

**Also check:** a simple typo. `frist_name` produces this same error.

---

## `column reference "unit_price" is ambiguous`

**Translation:** Two tables in your query both have that column, so the database doesn't know
which you mean.

**Fix — say which table:**
```sql
SELECT oi.unit_price      -- the price at time of sale
FROM   order_items oi
JOIN   products p ON p.product_id = oi.product_id;
```

**This error is doing you a favour.** In this database, `order_items.unit_price` is what the
customer paid and `products.unit_price` is today's price. Picking the wrong one silently
corrupts historical revenue, so the database refuses to guess.

**Habit:** once you have two tables, alias them and qualify every column.

---

## `column "products.product_name" must appear in the GROUP BY clause or be used in an aggregate function`

**Translation:** You asked for one row per group, but also asked for a column that has many
different values within each group. Which one should it show?

```sql
SELECT category, product_name, count(*)
FROM   products
GROUP  BY category;              -- ✗ Storage has 5 different names
```

**Three fixes, depending on what you actually wanted:**
```sql
GROUP BY category, product_name              -- one row per category+name
max(product_name)                            -- pick one, deterministically
string_agg(product_name, ', ')               -- squash them all into one cell
```

**Rule:** every column in `SELECT` must be in the `GROUP BY` **or** inside an aggregate.

> **If you came from MySQL:** MySQL historically allowed this and returned an arbitrary value.
> Postgres is stricter and correct — the query genuinely has no right answer.

---

## `aggregate functions are not allowed in WHERE`

**Translation:** You tried to filter on a `count`/`sum`/`avg` in `WHERE`.

**Why:** `WHERE` runs while the database is still looking at individual rows — before any
grouping. The count doesn't exist yet.

**Fix — use `HAVING`:**
```sql
SELECT   category, count(*)
FROM     products
GROUP BY category
HAVING   count(*) >= 3;          -- ✓ HAVING filters groups, after counting
```

**The rule in one line:** `WHERE` is about one row. `HAVING` is about a whole group.

---

## `window functions are not allowed in WHERE`

Same cause. `ROW_NUMBER()`, `RANK()`, `LAG()` are computed after `WHERE`.

**Fix — compute in a CTE, filter outside it:**
```sql
WITH ranked AS (
    SELECT product_name, category,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rn
    FROM   products
)
SELECT * FROM ranked WHERE rn <= 2;      -- ✓
```

This two-step shape is the standard "top N per group" pattern. Worth memorising.

---

## `syntax error at or near "..."`

**Translation:** Something is malformed. The quoted word is where Postgres *gave up*, so the
real problem is often just **before** it.

**Check, in this order:**

1. **A missing comma** between columns — `SELECT a b FROM t`
2. **An extra comma** before `FROM` — `SELECT a, b, FROM t`
3. **Unbalanced brackets** — count your `(` and `)`
4. **A missing quote** — `WHERE country = 'Japan` swallows the rest of the query
5. **A reserved word used as a name** — `month`, `order`, `user`, `group`, `table`. Wrap it in
   double quotes: `AS "month"`, or rename it: `AS order_month`

**Tip:** if a long query fails, delete half of it and run again. Repeat. You'll find the line
in about a minute — much faster than staring.

---

## `operator does not exist: text = integer`

**Translation:** You compared a text column to a number, or vice versa.

```sql
WHERE customer_id = '8'     -- comparing integer to text
WHERE sku = 3               -- comparing text to integer
```

**Fix — match the types.** Numbers get no quotes, text gets single quotes:
```sql
WHERE customer_id = 8
WHERE sku = 'NW-SWT-8'
```

**Remember:** single quotes for text, no quotes for numbers and booleans.

---

## `invalid input syntax for type numeric: "$49.00"`

**Translation:** You tried to convert text into a number, and it isn't one.

**Why:** `$`, commas, spaces and empty strings all break a cast. And **one bad row aborts the
entire statement.**

**Fix — clean before casting:**
```sql
regexp_replace(monthly_spend, '[^0-9.\-]', '', 'g')::numeric
```

**Better — validate first, cast only what passes:**
```sql
CASE WHEN monthly_spend ~ '^-?\d+(\.\d+)?$'
     THEN monthly_spend::numeric
     ELSE NULL
END
```

Same applies to dates: check the format with a regex before calling `to_date`.

---

## `division by zero`

**Fix — guard with `NULLIF`:**
```sql
100.0 * change / NULLIF(previous, 0)
```

`NULLIF(x, 0)` returns `NULL` when `x` is zero, turning a crash into a blank cell. A report
with a gap beats a report that dies.

---

## `subquery in FROM must have an alias`

**Translation:** A subquery in `FROM` needs a name.

```sql
FROM (SELECT ...) AS totals      -- ✓ the AS totals is required
```

**Better — use a CTE instead**, which names it up front and reads far better:
```sql
WITH totals AS (SELECT ...)
SELECT * FROM totals;
```

---

## `missing FROM-clause entry for table "c"`

**Translation:** You used the alias `c.` but never defined `c`.

**Usual causes:** a typo in the alias, or you removed a `JOIN` and left its columns behind.

---

## `duplicate key value violates unique constraint`

**Translation:** You tried to insert a value that must be unique and already exists.

**This is the database protecting you.** Two customers with the same email, or the same
product twice on one order.

**Fixes:**
- Insert something different
- Update the existing row instead
- Use an upsert: `INSERT ... ON CONFLICT (id) DO UPDATE SET ...`
- Skip silently: `ON CONFLICT DO NOTHING`

---

## `null value in column "name" violates not-null constraint`

**Translation:** A required column was left empty.

**Fix:** provide a value. If it genuinely can be unknown, the *column* is wrong, not your
insert — but changing that is a schema decision, not a quick patch.

---

## `insert or update on table "orders" violates foreign key constraint`

**Translation:** You pointed at something that doesn't exist — an order for customer 9999 when
there's no such customer.

**Fix:** check the ID exists first. Create the parent before the child.

**On a `DELETE`, it means the opposite:** you're deleting a parent that still has children.
Delete the children first, or reconsider — this error is usually correct to refuse.

---

## `new row violates check constraint "products_stock_qty_check"`

**Translation:** A business rule said no. The constraint name tells you which column.

`products_stock_qty_check` is `CHECK (stock_qty >= 0)` — you tried to make stock negative.

**This is the system working.** Someone wrote that rule deliberately, and it just stopped a
bug. Don't remove the constraint; fix the value.

---

## `UNION types text and integer cannot be matched`

**Translation:** Two branches of a `UNION` have different types in the same column position.

**Fix — cast them to match:**
```sql
SELECT 'total', count(*)::text FROM orders
UNION ALL
SELECT 'label', 'some text'
```

---

## `canceling statement due to statement timeout`

**Translation:** The query ran too long and was stopped.

**Usual causes:** an accidental cross join (missing `ON` condition), or a genuinely huge scan.

**Check first:** does every `JOIN` have an `ON`? A missing one multiplies every row by every
row.

---

# Not errors — but they feel like errors

## The query ran but returned **zero rows**

Nothing is broken. Your filter matched nothing. In order of likelihood:

1. **Capitalisation.** `'storage'` ≠ `'Storage'`. Text comparison is case-sensitive.
   Check with `SELECT DISTINCT category FROM products;`
2. **`NULL`s were dropped.** `WHERE country <> 'Nigeria'` excludes rows where country is
   unknown. Add `OR country IS NULL`.
3. **`NOT IN` with a `NULL` in the list** — returns nothing, always. Use `NOT EXISTS`.
4. **A date range that misses the data.** Our orders run 2024-01-17 to 2025-10-18.
5. **Conditions that can't both be true** — `WHERE category = 'Storage' AND category = 'Power'`

**Debug by removing conditions one at a time** until rows appear. The last one you removed is
the culprit.

## I got **more rows** than I expected

You have fan-out. A join multiplied your rows.

```sql
SELECT count(*) FROM orders;                                       -- 120
SELECT count(*) FROM orders o JOIN order_items oi USING (order_id); -- 300
```

**Ask: what does one row mean now?** Before the join, one order. After, one *line item*.

Any order-level column you `SUM` after that is counted once per line item — which is how
shipping revenue reads $2,938.50 instead of $976.50.

**Fixes:** don't join if you don't need the child table; use `MAX()` for parent columns;
aggregate the child down to one row per parent *before* joining; or use `EXISTS` if you only
need to check something is there.

## My number looks wrong but nothing errored

**The most dangerous case**, because nothing warns you. Check these five:

1. **Did you exclude cancelled and refunded orders?** 12 of 120. Forgetting overstates revenue
   ~10%.
2. **Fan-out?** Count rows before and after each join.
3. **`NULL`s dropped?** Your two groups should add up to the total. If they don't, `NULL` is
   involved.
4. **Right `unit_price`?** `oi.unit_price` for history, `p.unit_price` for today.
5. **`count(*)` after a `LEFT JOIN`?** It counts the empty row too — returns 1 where the answer
   is 0. Use `count(right_table.column)`.

## A percentage looks absurd

Check the denominator before believing it. February 2024 shows **+1,407% growth** — because
January had one order in a partial month. Small or partial denominators produce spectacular,
meaningless percentages.

**Always publish the absolute number next to the percentage.**

---

## When you're properly stuck

1. **Read the error again, slowly.** Postgres usually names the exact column or constraint.
2. **Run a smaller piece.** Break the query down until it works, then add back one step.
3. **Look at the data.** `SELECT * FROM table LIMIT 5;` settles most "why is this empty".
4. **Count your rows** at each stage.
5. **Ask me.** Use [`prompts/05-fix-my-broken-query.md`](prompts/05-fix-my-broken-query.md) —
   paste your query, the error, and what you expected.

**Error not listed here?** Tell me what it said and I'll add it. This page should cover
everything you actually hit.
