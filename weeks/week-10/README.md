# Week 10 — Writing data safely

**Time:** ~2.5 hours
**You'll learn:** `INSERT`, `UPDATE`, `DELETE`, `RETURNING`, transactions, ACID, upsert

Every query so far has been read-only — the worst outcome was a wrong answer. This week you
start changing data, where the worst outcome is losing it.

The single most valuable thing in this week is a habit that takes four seconds and prevents
the mistake that ends careers. It's in Part 1. Read it before you write a single `UPDATE`.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### The habit: SELECT first, always

Before every `UPDATE` or `DELETE`, run the **exact same `WHERE` clause** as a `SELECT`.

```sql
-- 1. Look at what you are about to change
SELECT * FROM products WHERE category = 'Cables';        -- 3 rows. Expected 3. Good.

-- 2. Only now change it
UPDATE products SET unit_price = unit_price * 1.1 WHERE category = 'Cables';
```

Four seconds. It catches the typo, the missing condition, the `WHERE` that matches 8,000 rows
instead of 3.

**The mistake it prevents:**

```sql
UPDATE products SET unit_price = unit_price * 1.1;   -- no WHERE clause
```

That silently repriced the entire catalogue. Postgres does not warn you. It reports
`UPDATE 25` and you have no idea anything went wrong until a customer does.

`SELECT` first. Every time. Including when you're certain — *especially* when you're certain,
because certainty is what stops people checking.

### INSERT

```sql
INSERT INTO suppliers (name, country, payment_terms)
VALUES ('Cablewerks GmbH', 'Germany', 'net30');

-- several rows at once
INSERT INTO suppliers (name, country, payment_terms) VALUES
    ('Cablewerks GmbH', 'Germany', 'net30'),
    ('Pacific Components', 'Singapore', 'net60');

-- from a query
INSERT INTO archive_orders (order_id, order_date, status)
SELECT order_id, order_date, status FROM orders WHERE order_date < '2024-06-01';
```

**Always name your columns.** `INSERT INTO suppliers VALUES (...)` depends on column order, so
adding a column later silently breaks it — or worse, puts values in the wrong fields.

### RETURNING — Postgres's best small feature

```sql
INSERT INTO suppliers (name, country, payment_terms)
VALUES ('Cablewerks GmbH', 'Germany', 'net30')
RETURNING supplier_id, name;
```

Get back the generated ID without a second query. Works on `UPDATE` and `DELETE` too, which
makes it a safety tool:

```sql
DELETE FROM suppliers WHERE is_active = false
RETURNING supplier_id, name;      -- see exactly what you removed
```

### UPDATE

```sql
UPDATE products
SET    unit_price = unit_price * 1.10,
       updated_at = now()
WHERE  category = 'Cables';
```

Update several columns in one statement, separated by commas. `SET a = 1, b = 2`, not two
statements.

**`UPDATE` with data from another table** uses `FROM`:

```sql
UPDATE orders o
SET    ship_country = c.country
FROM   customers c
WHERE  c.customer_id = o.customer_id
  AND  o.ship_country IS NULL;
```

Note the join condition lives in `WHERE`. Omit it and you get a cross join — every order
updated with an arbitrary customer's country. This is `UPDATE`'s version of fan-out and it is
just as quiet.

### DELETE

```sql
DELETE FROM suppliers WHERE supplier_id = 7;
DELETE FROM suppliers;              -- every row. No warning. No undo outside a transaction.
```

`TRUNCATE suppliers;` is faster for emptying a table but can't be filtered and is harder to
undo.

**Soft delete** is often better than deleting:

```sql
UPDATE suppliers SET is_active = false WHERE supplier_id = 7;
```

The row survives, history stays intact, foreign keys don't break, and it's reversible. Most
production systems soft-delete far more than they delete. Our `customers.is_active` column is
exactly this.

### Transactions — the important part

A transaction groups statements so they **all succeed or all fail**.

```sql
BEGIN;

UPDATE products SET stock_qty = stock_qty - 5 WHERE product_id = 1;
UPDATE products SET stock_qty = stock_qty + 5 WHERE product_id = 2;

-- check before you commit
SELECT product_id, stock_qty FROM products WHERE product_id IN (1, 2);

COMMIT;      -- or ROLLBACK; to undo everything
```

Between `BEGIN` and `COMMIT`, nothing is visible to anyone else and nothing is permanent. If
the second `UPDATE` fails, `ROLLBACK` undoes the first as well — you never end up with stock
removed from one product and not added to the other.

**This is your undo button.** When you're about to do something risky:

```sql
BEGIN;
DELETE FROM orders WHERE order_date < '2024-01-01';
SELECT count(*) FROM orders;      -- is this the number you expected?
ROLLBACK;                          -- nothing happened. Try again properly.
```

You can run the destructive statement, inspect the result, and undo it. Getting into the habit
of wrapping risky work in `BEGIN` costs nothing and has saved a great many people.

> **In the Supabase SQL editor**, each Run is typically its own transaction, so a `BEGIN` in
> one execution may not still be open in the next. Run the whole `BEGIN ... ROLLBACK` block as
> a single Run rather than line by line.

### ACID

The four guarantees a transactional database gives you:

- **Atomicity** — all statements in a transaction happen, or none do.
- **Consistency** — constraints hold before and after; a transaction can't leave the database
  breaking its own rules.
- **Isolation** — concurrent transactions don't see each other's half-finished work.
- **Durability** — once `COMMIT` returns, the data survives a power cut.

This is the actual difference between a database and a pile of files, and it's why financial
systems run on databases.

### Upsert — insert or update

```sql
INSERT INTO suppliers (supplier_id, name, country, payment_terms)
VALUES (1, 'Cablewerks GmbH', 'Germany', 'net60')
ON CONFLICT (supplier_id)
DO UPDATE SET name          = EXCLUDED.name,
              country       = EXCLUDED.country,
              payment_terms = EXCLUDED.payment_terms;
```

If the key exists, update; otherwise insert. `EXCLUDED` refers to the row you *tried* to
insert. This is essential for data pipelines that reload the same source repeatedly and must
be safe to re-run.

`ON CONFLICT DO NOTHING` skips duplicates silently instead.

---

## Part 2 — Worked example (~20 min)

**The task:** *Apply a 10% price rise to all Cables products — safely.*

### Step 1: Look first

```sql
SELECT product_id, product_name, unit_price
FROM   products
WHERE  category = 'Cables';
```

Three rows: Cat6 Cable 34.00, HDMI 2.1 Cable 24.00, USB-C to USB-C 17.50.

**Three is what I expected.** If it had returned 25, my `WHERE` clause is wrong and I've just
found out for free.

### Step 2: Wrap it in a transaction

```sql
BEGIN;

UPDATE products
SET    unit_price = round(unit_price * 1.10, 2)
WHERE  category = 'Cables'
RETURNING product_id, product_name, unit_price;
```

`RETURNING` shows exactly what changed: 37.40, 26.40, 19.25.

### Step 3: Verify before committing

```sql
SELECT category, count(*), round(avg(unit_price), 2)
FROM   products
WHERE  category = 'Cables'
GROUP  BY category;
```

Three rows changed. No other category touched. The numbers are 10% higher.

```sql
COMMIT;
```

Or, if anything looks wrong, `ROLLBACK;` and nothing happened.

### Step 4: What the careless version would have done

```sql
UPDATE products SET unit_price = round(unit_price * 1.10, 2);
```

One missing `WHERE`. Every product repriced. Postgres reports `UPDATE 25` and moves on.

And here is the part that matters: **you cannot undo it after `COMMIT`.** The old prices are
gone. `products` has no history — the previous value existed only in the row you just
overwrote. Recovery means restoring a backup, and if the backup is from last night, you've lost
today.

Three things would have caught it: the `SELECT` first, the `BEGIN`, or the `RETURNING`. Any
one of them. That's why the habit is cheap insurance — it's three independent safety nets, and
you only need one to hold.

---

## Part 3 — Exercises (~60 min)

**Work inside transactions.** Where an exercise changes data, wrap it in `BEGIN ... ROLLBACK`
so you can run it repeatedly. Where it must persist, commit deliberately.

Attempt before opening [`solutions/week-10.sql`](../../solutions/week-10.sql).

### Exercise 10.1 — Insert with RETURNING

Insert two new suppliers into the table you built in week 9, returning their generated IDs.
Then insert a third that violates a constraint, and show the error.

### Exercise 10.2 — A safe, verified UPDATE

Every product in the `Software` category should be marked as having no physical stock, and
week 1 established that `stock_qty = 0` wrongly reads as "sold out" for these.

Add a nullable `is_physical boolean` column to `products`, then set it to `false` for Software
and `true` for everything else.

Do it properly: `SELECT` first to see the affected rows, run inside a transaction, use
`RETURNING`, verify, then commit. Show every step.

### Exercise 10.3 — Transaction and rollback

Simulate a stock transfer: move 10 units from product 6 to product 7.

Write it as a transaction that:
1. Checks both current stock levels
2. Decrements one, increments the other
3. Verifies the total across both products is unchanged
4. Rolls back

Then explain what would go wrong if step 2's two statements ran outside a transaction and the
connection died between them.

Finally, write a version that would **correctly fail** — try to move 10,000 units from a
product that doesn't have them, and show which constraint stops you.

---

## Part 4 — Mini-project (~30 min)

### A safe stock-adjustment procedure

Warehouse staff need to record stock adjustments — damage, recounts, deliveries. Build it so
mistakes are recoverable.

**1. Create an audit table:**

```sql
CREATE TABLE stock_adjustments (
    adjustment_id integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id    integer     NOT NULL REFERENCES products (product_id),
    qty_before    integer     NOT NULL,
    qty_change    integer     NOT NULL CHECK (qty_change <> 0),
    qty_after     integer     NOT NULL CHECK (qty_after >= 0),
    reason        text        NOT NULL CHECK (reason IN ('damage','recount','delivery','theft')),
    adjusted_by   text        NOT NULL,
    adjusted_at   timestamptz NOT NULL DEFAULT now()
);
```

**2. Write a transaction** that adjusts a product's stock *and* records the adjustment, so the
two can never disagree.

**3. Prove it's safe** by writing an adjustment that would take stock negative, and showing it
fails cleanly with nothing written to either table.

**Then answer, in comments:**

1. Why record `qty_before` and `qty_after` when `qty_change` implies them?
2. Why must both statements be in one transaction? What's the specific failure if they aren't?
3. `adjusted_by` is `text`. What's wrong with that, and what would you do in a real system?
4. Should `stock_adjustments` rows ever be updated or deleted? Argue your position.

Question 4 is about what an audit log is *for*. A log that can be edited answers a different
question from one that can't.

---

## Checklist

- [ ] You run the `SELECT` before every `UPDATE` and `DELETE`, without exception
- [ ] You wrap risky changes in `BEGIN` so you can `ROLLBACK`
- [ ] You use `RETURNING` to see what actually changed
- [ ] You always name columns in an `INSERT`
- [ ] You can explain all four ACID properties
- [ ] You know when soft delete beats `DELETE`
- [ ] You know what `EXCLUDED` refers to in an upsert

**Tick week 10 in [`PLANNER.md`](../../PLANNER.md).**
