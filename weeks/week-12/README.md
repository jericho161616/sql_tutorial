# Week 12 — Views, security & capstone

**Time:** ~2.5 hours (capstone may take longer — that's fine)
**You'll learn:** views, materialised views, roles, `GRANT`, row-level security — then everything at once

The last week. Two short topics that matter in production, then a capstone that uses the whole
course.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Views — a saved query that behaves like a table

```sql
CREATE VIEW live_products AS
SELECT product_id, sku, product_name, category, unit_price,
       unit_price - cost_price AS margin
FROM   products
WHERE  NOT is_discontinued;

SELECT * FROM live_products WHERE category = 'Storage';
```

A view stores **no data**. It's a named query that runs fresh every time, so it's always
current.

What views are for:

- **Hiding complexity.** A five-CTE revenue query becomes `SELECT * FROM monthly_revenue`.
- **Enforcing consistency.** If "revenue" means completed and shipped orders excluding
  cancellations, encode that once. Otherwise six people write six slightly different
  definitions and produce six different numbers in the same meeting.
- **Security.** Grant access to a view exposing three columns instead of a table with fifteen.

You met this in week 8: `clean_signups` is a view precisely so the raw table stays untouched.

**Cost:** a view is re-executed on every query. A view over a view over a view can produce a
plan nobody can debug. Two levels is usually plenty.

### Materialised views — a cached result

```sql
CREATE MATERIALIZED VIEW monthly_revenue_mv AS
SELECT date_trunc('month', o.order_date)::date AS month,
       round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.status IN ('completed','shipped')
GROUP  BY 1;

REFRESH MATERIALIZED VIEW monthly_revenue_mv;
```

This one **does** store data. Queries against it are fast because the work is already done —
but the data is only as fresh as the last `REFRESH`.

Use it for expensive aggregates that don't need to be up to the second: dashboards, overnight
reports. Never for anything where stale numbers would mislead.

**The trap:** a materialised view that nobody refreshes silently serves last month's numbers
forever, and looks exactly like a working one.

### Roles and permissions

```sql
CREATE ROLE analyst NOLOGIN;
GRANT USAGE ON SCHEMA shop TO analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA shop TO analyst;

CREATE ROLE reporting_app LOGIN PASSWORD 'a-strong-password';
GRANT analyst TO reporting_app;         -- inherits analyst's rights

REVOKE SELECT ON customers FROM analyst;
GRANT  SELECT (customer_id, country, segment) ON customers TO analyst;  -- columns only
```

**The principle of least privilege:** give each role the minimum it needs. A reporting
dashboard needs `SELECT` and nothing else. If it's compromised, `SELECT` is the worst it can
do.

The common failure is one superuser account shared by every application and person, so nothing
can be revoked without breaking everything, and no action can be attributed to anyone.

Note `GRANT SELECT ON ALL TABLES` only affects tables that exist *now*. New tables need
`ALTER DEFAULT PRIVILEGES`.

### Row-level security

Postgres can filter rows per user:

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_own_country ON orders
    FOR SELECT
    USING (ship_country = current_setting('app.user_country', true));
```

A regional manager querying `SELECT * FROM orders` sees only their region — enforced by the
database, not by remembering to add a `WHERE` clause in every application query.

Supabase relies heavily on this. Worth knowing it exists.

> Our practice tables have RLS disabled, which is fine for a private learning database with
> fictional data. On any Supabase project holding real data reachable from a browser, enable
> RLS — without it, the anon key can read every row.

---

## Part 2 — Worked example (~20 min)

**The task:** *Make "revenue" mean one thing.*

### The problem

Three people are asked for last quarter's revenue. One includes cancelled orders. One uses
`products.unit_price` instead of the price at time of sale. One forgets the discount. Three
numbers, three meetings, no trust.

### The fix — define it once

```sql
CREATE OR REPLACE VIEW order_revenue AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       o.status,
       round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS goods_revenue,
       max(o.shipping_fee)                                                     AS shipping,
       round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100))
             + max(o.shipping_fee), 2)                                         AS total_revenue
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.status IN ('completed', 'shipped')      -- the definition, in one place
GROUP  BY o.order_id, o.customer_id, o.order_date, o.status, o.shipping_fee;
```

Every decision from earlier weeks is baked in: cancelled and refunded excluded (week 3),
`oi.unit_price` not `p.unit_price` (week 4), `max()` for the shipping fee to survive fan-out
(week 5).

Now the hard questions are easy and consistent:

```sql
SELECT sum(total_revenue) FROM order_revenue WHERE order_date >= '2025-01-01';

SELECT date_trunc('month', order_date)::date AS month, sum(total_revenue)
FROM   order_revenue GROUP BY 1 ORDER BY 1;
```

### Why this matters more than it looks

The view isn't a convenience. It's **the definition of a business term, written down and
enforced**. When someone later argues that refunds should count, the discussion happens once,
the view changes once, and every report changes with it.

Undocumented definitions scattered across forty saved queries is the normal state of most
companies' analytics, and it's the reason nobody trusts the dashboards.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-12.sql`](../../solutions/week-12.sql).

### Exercise 12.1 — Build a useful view

Create `customer_summary` exposing, for every customer — including those who've never ordered:

customer id, full name, email, country, segment, total orders, total revenue (0.00 if none),
first order date, most recent order date, and days since last order.

Use `LEFT JOIN` so all 40 customers appear. Then query it three ways: top 5 by revenue,
customers with no orders, and customers inactive for over 300 days.

*Expected: 40 rows in the view.*

### Exercise 12.2 — Materialised view and staleness

Create a materialised view of monthly revenue. Query it. Then:

1. Insert a new completed order with line items.
2. Query the materialised view again — has it changed?
3. `REFRESH` it and query again.
4. Write a comment explaining what you observed and what it means for a dashboard built on it.

Do the inserts inside a transaction you roll back afterwards.

### Exercise 12.3 — Least privilege

Design roles for three consumers of this database:

- a **reporting dashboard** — read-only, must not see customer emails
- a **warehouse app** — reads products and orders, updates `stock_qty` only
- a **data engineer** — full access to `shop`, no ability to create roles

Write the `CREATE ROLE` and `GRANT` statements. For each, write one sentence on what damage a
compromise of that role could do.

---

## Part 4 — Capstone (~60+ min)

### The Nimbus executive dashboard

Build one deliverable answering the questions an owner would actually ask. Use everything.

**Requirements — the SQL:**

1. At least **four views**, each with a clear single purpose.
2. Use of **CTEs**, **window functions**, and **aggregate filtering**.
3. A **gap-free monthly time series** (`generate_series` scaffold, week 6).
4. At least one **anti-join** finding something absent.
5. **Data-quality checks** presented alongside the numbers, not hidden.
6. Every revenue figure must exclude cancelled and refunded orders, and must be free of
   fan-out. State how you verified it.

**Requirements — the answers.** Your dashboard must answer:

- What is total revenue, and how has it moved month over month?
- Who are the top 10 customers by lifetime value, and what share of revenue do they represent?
- Which product categories are growing and which are shrinking?
- Which customers were active last year but haven't ordered in the last 6 months?
- Which products have never sold?
- How much revenue is at risk in unpaid or pending orders?

**Requirements — the write-up.** A comment block at the end, maximum 400 words:

- The five findings you'd put in front of a manager.
- Every claim supported by a number your queries produce.
- **At least two caveats** — a place where the data is incomplete, ambiguous, or where a
  number could be misread. You have material: partial first and last months, four customers
  with no country, test accounts in production, percentage changes on tiny bases.
- One thing you'd want to measure but can't with this schema, and what you'd add.

**How this is judged.** Not on query cleverness. On whether someone reading your write-up would
make a *better decision* than they would without it — and whether every number in it is
defensible when challenged.

The caveats are the part that matters most. Anyone can produce numbers. Knowing which of your
own numbers not to trust is the job.

---

## Checklist

- [ ] You can explain when a view beats a materialised view, and the risk of each
- [ ] You understand least privilege and can grant column-level access
- [ ] You know what RLS is and when a Supabase project needs it
- [ ] You've encoded a business definition in a view rather than repeating it
- [ ] Your capstone's revenue figures are fan-out free and you can prove it
- [ ] Your write-up states what you don't trust, not only what you found

---

## After week 12

You now know enough to be useful and enough to know what you don't know. Reasonable next steps:

- **Recursive CTEs** (`WITH RECURSIVE`) — org charts, category trees, graph traversal.
- **Query tuning at scale** — this course's tables are tiny; find a large public dataset.
- **`psql`** — the command-line client, and the environment most DBA work actually happens in.
- **Backup and restore** — `pg_dump`, `pg_restore`, point-in-time recovery. Core DBA material
  this course only mentions.
- **Replication and high availability** — the next real DBA topic.
- **Rebuild this schema from scratch** without looking. If you can design `orders`,
  `order_items` and `payments` with correct keys and constraints from memory, you've got it.

**Tick week 12 in [`PLANNER.md`](../../PLANNER.md) — and that's the course.**
