# Week 11 — Indexes & performance

**Time:** ~2.5 hours
**You'll learn:** `EXPLAIN`, `EXPLAIN ANALYZE`, scan types, B-tree and composite indexes, the cost of indexing

The schema was built with **no indexes on any foreign key**. That was deliberate — this week
you'll see the sequential scans, add the indexes yourself, and watch the plans change.

This is core DBA work, and it's the week that separates someone who writes SQL from someone
who can be trusted with a database.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### What an index actually is

A book's index lets you find "normalisation" without reading every page. A database index does
the same: a separate, sorted structure that maps values to row locations.

Without one, finding `WHERE customer_id = 8` means reading **every row** in the table and
checking each. That's a **sequential scan**. With an index, the database jumps more or less
straight there.

The trade-off is real and worth stating plainly: an index makes reads faster and **writes
slower**, because every `INSERT`, `UPDATE` and `DELETE` must also update the index. Indexes
also consume disk. An unused index is pure cost.

### EXPLAIN — see the plan without running it

```sql
EXPLAIN
SELECT * FROM orders WHERE customer_id = 8;
```

```
Seq Scan on orders  (cost=0.00..3.50 rows=3 width=45)
  Filter: (customer_id = 8)
```

Read it as: *scan the whole table, keep rows where `customer_id = 8`.*

The `cost=0.00..3.50` numbers are the planner's **estimates** in arbitrary units — startup
cost, then total cost. They aren't milliseconds. They're only useful for comparing two plans
for the same query.

### EXPLAIN ANALYZE — actually run it and measure

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 8;
```

```
Seq Scan on orders  (cost=0.00..3.50 rows=3 width=45)
                    (actual time=0.015..0.042 rows=4 loops=1)
  Filter: (customer_id = 8)
  Rows Removed by Filter: 116
Planning Time: 0.089 ms
Execution Time: 0.061 ms
```

Now you get **actual** times and row counts alongside the estimates.

**Two things to look at first, every time:**

1. **`Rows Removed by Filter: 116`** — the database examined 120 rows to return 4. It threw
   away 97% of its work. That's the signature of a missing index.
2. **estimated `rows=3` vs actual `rows=4`** — close, so the planner's statistics are good.
   When these differ by 100× or more, the planner is making decisions on bad information and
   `ANALYZE tablename;` to refresh statistics is often the fix.

> `EXPLAIN ANALYZE` **executes the query.** On an `UPDATE` or `DELETE` it really does modify
> data. Wrap it in `BEGIN ... ROLLBACK` if you need to analyse a write.

### Scan types, worst to best

| Plan node | Meaning | Concern |
|---|---|---|
| **Seq Scan** | Read every row | Fine on small tables, bad on large ones |
| **Index Scan** | Use the index, then fetch rows | Good |
| **Index Only Scan** | Answer entirely from the index | Best — never touches the table |
| **Bitmap Heap Scan** | Index finds many rows, fetched in disk order | Good for medium result sets |

**A `Seq Scan` is not automatically wrong.** On our 120-row `orders` table it's genuinely
faster than an index — the whole table fits in one page, and the planner knows it. That's why
you'll see Postgres ignore indexes you just created on small tables. It's right to.

Indexes matter at scale. The habits matter now.

### Creating indexes

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- composite: column order matters enormously
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);

-- partial: index only the rows you actually query
CREATE INDEX idx_orders_pending ON orders (order_date) WHERE status = 'pending';

-- unique: a constraint and an index at once
CREATE UNIQUE INDEX idx_customers_email ON customers (lower(email));
```

**Composite index column order.** An index on `(customer_id, order_date)` helps queries
filtering on `customer_id` alone, or on both. It does **not** help a query filtering only on
`order_date` — same as a phone book sorted by surname then first name being useless for
finding everyone called "James".

**Rule: most-selective and most-frequently-filtered column first.**

**Partial indexes** are underused. If 90% of your rows are `completed` and you only ever query
`pending`, a partial index is a fraction of the size and faster to maintain.

### What to index

Index these:

- **Foreign key columns.** Almost always. Postgres indexes primary keys automatically but
  **not** foreign keys — a genuine trap, and the reason our schema is currently unindexed.
- Columns you filter on frequently.
- Columns you join on.
- Columns you sort by, when the sort is expensive.

Don't index these:

- Small tables (the planner will ignore it).
- Low-cardinality columns on their own — a boolean with two values doesn't narrow anything.
- Columns you rarely filter on. Every index is a tax on every write.

### Why your index isn't being used

**Functions on the column disable it:**

```sql
WHERE lower(email) = 'x@y.com'          -- index on email NOT used
WHERE email = 'x@y.com'                 -- index used
```

The index stores `email`, not `lower(email)`. Fix by indexing the expression:
`CREATE INDEX ON customers (lower(email));`

**Leading wildcards disable it:**

```sql
WHERE product_name LIKE '%switch%'      -- cannot use a B-tree index
WHERE product_name LIKE 'Nimbus%'       -- can
```

An index is sorted by the start of the value. A leading `%` means you don't know the start.
Full-text search or a trigram index solves this.

**Type mismatches disable it.** Comparing an `integer` column to a text value forces a cast on
every row.

### Maintenance basics

```sql
ANALYZE orders;              -- refresh planner statistics
VACUUM ANALYZE orders;       -- reclaim dead rows and refresh stats

-- find indexes nobody uses
SELECT relname, indexrelname, idx_scan
FROM   pg_stat_user_indexes
WHERE  idx_scan = 0;
```

Postgres autovacuums by default. Knowing these exist matters when something is slow and the
statistics are stale.

---

## Part 2 — Worked example (~20 min)

**The task:** *Find out why a query is slow, and fix it.*

### Step 1: Baseline

```sql
EXPLAIN ANALYZE
SELECT o.order_id, o.order_date, o.status
FROM   orders o
WHERE  o.customer_id = 8;
```

You'll see a `Seq Scan` with `Rows Removed by Filter` around 116. All 120 rows examined to
return a handful.

### Step 2: Add the index

```sql
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
ANALYZE orders;
```

`ANALYZE` afterwards matters — the planner needs fresh statistics before it will trust the new
index.

### Step 3: Re-run

```sql
EXPLAIN ANALYZE
SELECT o.order_id, o.order_date, o.status
FROM   orders o
WHERE  o.customer_id = 8;
```

**On 120 rows, you may well still see a `Seq Scan`** — and that is the correct answer. The
table occupies one page; reading it costs a single I/O. Using the index would mean reading the
index *and then* the table: strictly more work.

**The planner is not ignoring your index out of stubbornness. It's doing arithmetic you'd
agree with.**

### Step 4: Force it, to see the difference

```sql
SET enable_seqscan = off;      -- session only, for experimentation

EXPLAIN ANALYZE
SELECT o.order_id FROM orders o WHERE o.customer_id = 8;

SET enable_seqscan = on;       -- put it back
```

Now you'll see `Index Scan using idx_orders_customer_id`. Compare the costs — the index plan
may well be *more* expensive at this size, which is exactly why the planner rejected it.

**Never leave `enable_seqscan = off` on in anything real.** It's a diagnostic toy, not a fix.

### Step 5: The lesson

The index isn't useless — it's *not yet necessary*. At 120 rows a sequential scan is optimal;
at 12 million it would be catastrophic, and the same index becomes essential.

**This is why you index foreign keys as a matter of course.** Not because today's query is
slow, but because the table will grow and the index needs to exist before it hurts. Adding an
index to a large busy table is far more disruptive than having created it at the start.

Two more reasons to index foreign keys even when reads are fine:

1. `ON DELETE CASCADE` must find child rows to delete. Without an index that's a full scan of
   the child table **per deleted parent row**.
2. Postgres takes locks when checking foreign key references. Unindexed FKs are a well-known
   source of lock contention under concurrent writes.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-11.sql`](../../solutions/week-11.sql).

### Exercise 11.1 — Read a plan

Run `EXPLAIN ANALYZE` on this and interpret the output:

```sql
SELECT c.first_name, c.last_name, count(o.order_id) AS orders
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name;
```

In comments, identify: which scan types appear, which join algorithm Postgres chose (`Hash
Join`, `Nested Loop`, or `Merge Join`), how many rows it estimated versus actually got, and
the total execution time.

### Exercise 11.2 — Index every foreign key

Our schema has unindexed foreign keys on `orders.customer_id`, `order_items.order_id`,
`order_items.product_id` and `payments.order_id`.

Create an index on each, following a consistent naming convention. Run `ANALYZE` afterwards.
Then re-run exercise 11.1's query and compare the plan.

Write a comment on whether the plan changed, and **why that is or isn't what you expected**.

### Exercise 11.3 — Make an index that gets used

Write a query where Postgres genuinely chooses an index scan on this data.

*Hint: make the query highly selective — returning one or two rows out of hundreds — and query
a column with many distinct values. `order_items` has 300 rows, the largest table here.*

Show the query and the plan proving the index was used. If you can't get one, say what you
tried and explain why the planner refused.

---

## Part 4 — Mini-project (~30 min)

### Index the database and measure it

**1. Baseline.** Pick four realistic queries — a lookup by foreign key, a join across three
tables, a filtered aggregate, and a sort. Record `EXPLAIN ANALYZE` output for each *before*
any indexes exist.

**2. Index.** Add indexes on all four foreign keys, plus one composite index on
`orders (customer_id, order_date)` and one partial index on pending orders.

**3. Re-measure.** Run all four again. Record the new plans and times.

**4. Report** in comments:

- A table of before/after execution times.
- Which plans changed and which didn't.
- Which of your indexes are actually being used — check `pg_stat_user_indexes`.
- Your recommendation: which indexes would you keep in production, and which would you drop?

**5. The honest conclusion.** Most of your indexes probably made no measurable difference on
120 rows. Write two or three sentences on what that means: when *should* you add an index, if
not when the query is currently slow? Is "it might help later" a good enough reason?

That final question is a real professional judgement with no clean answer, and it's worth
forming a view on. Indexing everything "just in case" is a recognisable and expensive mistake;
so is discovering you need an index during an outage.

---

## Checklist

- [ ] You can read an `EXPLAIN ANALYZE` plan and find `Rows Removed by Filter`
- [ ] You know the difference between estimated and actual rows, and why it matters
- [ ] You know why Postgres correctly ignores indexes on small tables
- [ ] You index foreign keys as a default, and can give two reasons beyond read speed
- [ ] You know why `lower(email) = ...` and `LIKE '%x%'` defeat a normal index
- [ ] You can state the cost of an index, not just the benefit

**Tick week 11 in [`PLANNER.md`](../../PLANNER.md).**
