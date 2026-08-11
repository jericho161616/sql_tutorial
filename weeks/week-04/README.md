# Week 4 — Joins I

**Time:** ~2.5 hours
**You'll learn:** primary and foreign keys, `INNER JOIN`, `LEFT JOIN`, table aliases

Everything so far used one table. Real questions almost never fit in one table, because
real databases deliberately split data across several. This week you learn to put them back
together.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Why the data is split up in the first place

Our `orders` table stores `customer_id`, not the customer's name and email. That looks like
extra work — why not just put the name in the order?

Because a customer places many orders. Storing "Elena Sarmiento, elena.sarmiento@example.com"
on all fourteen of her orders means:

- The same text is written fourteen times, wasting space.
- When she changes her email, you must find and update fourteen rows, and if you miss one
  the database now disagrees with itself about her email.
- A customer who has never ordered can't exist at all, because there's no order to put her
  in.

So the data is stored **once**, in `customers`, and orders point at it with a small number.
That pointer is a **foreign key**, and this splitting-up is called *normalisation* — the
subject of week 9.

The cost is that answering "who ordered what" now requires putting the tables back together.
That's a join.

### Keys

- A **primary key** uniquely identifies a row. `customers.customer_id` — no two customers
  share one, and it's never `NULL`.
- A **foreign key** points at another table's primary key. `orders.customer_id` holds a
  value that must exist in `customers.customer_id`.

The foreign key is enforced. Try to insert an order for customer 9999 and Postgres refuses:
that customer doesn't exist. This is **referential integrity**, and it's one of the main
reasons to keep data in a database rather than a pile of spreadsheets.

### INNER JOIN — rows that match on both sides

```sql
SELECT o.order_id,
       o.order_date,
       c.first_name,
       c.last_name
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
ORDER  BY o.order_id;
```

Read `ON c.customer_id = o.customer_id` as the instruction: *for each order, find the
customer row whose `customer_id` matches this order's `customer_id`, and stick them
together side by side.*

`JOIN` on its own means `INNER JOIN` — the words are interchangeable. Writing `INNER` is
clearer when a query mixes join types.

### Table aliases

`orders o` and `customers c` give each table a short name. Then `o.order_date` and
`c.first_name` say unambiguously which table each column came from.

Aliases aren't decoration. Both tables have a `customer_id` column, so writing bare
`customer_id` is ambiguous and Postgres will reject it:

```
ERROR: column reference "customer_id" is ambiguous
```

**Qualify every column with its table alias once you have more than one table.** It costs
two characters and makes the query readable by someone who doesn't know the schema — again,
often you in six months.

Pick meaningful aliases. `o` and `c` are fine. `a` and `b` are not.

### LEFT JOIN — keep everything on the left, matched or not

This is the important one.

```sql
SELECT c.first_name,
       c.last_name,
       o.order_id
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id;
```

`LEFT JOIN` keeps **every row from the left table** (`customers`), whether or not a match
exists on the right. Where nothing matches, the right table's columns come back as `NULL`.

Harriet Lockwood and Kwame Mensah have never ordered. With `INNER JOIN` they vanish from
the result entirely. With `LEFT JOIN` they appear, with `NULL` in `order_id`.

**Which is correct depends entirely on the question:**

| Question | Join |
|---|---|
| "List our orders with customer names" | `INNER` — an order without a customer is impossible |
| "How many orders has each customer placed?" | `LEFT` — otherwise customers with zero silently disappear |
| "Which customers have never ordered?" | `LEFT`, then filter for `NULL` |

That middle row is where people get hurt. `INNER JOIN` doesn't error when it drops rows.
It just quietly returns a shorter list, and "we have 38 customers" goes in the report when
the answer is 40.

### Finding the missing rows: the anti-join

```sql
SELECT c.first_name, c.last_name
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE     o.order_id IS NULL;        -- keep ONLY the non-matches
```

`LEFT JOIN` plus `WHERE ... IS NULL` means "everything on the left that has nothing on the
right". It's the standard way to ask *what's missing* — customers who never bought,
products never sold, orders never paid.

Note it must be `o.order_id IS NULL`, testing a column from the **right** table. Testing a
left-table column would filter out real customers instead.

### RIGHT and FULL joins

`RIGHT JOIN` is `LEFT JOIN` with the tables the other way round. It's rare — most people
find it easier to swap the table order and use `LEFT`. `FULL OUTER JOIN` keeps unmatched
rows from both sides; you'll meet it occasionally when comparing two datasets.

Learn `INNER` and `LEFT` properly. They cover almost everything.

### Where the join condition goes

```sql
-- Correct: keeps all customers, but only counts their 2025 orders
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
                  AND o.order_date >= '2025-01-01';

-- Different! Silently turns the LEFT JOIN back into an INNER JOIN
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE     o.order_date >= '2025-01-01';
```

In the second version, customers with no orders have `NULL` in `o.order_date`, and
`NULL >= '2025-01-01'` is not true — so `WHERE` drops them. You wrote `LEFT JOIN` and got
`INNER JOIN` behaviour.

**Conditions on the right-hand table of a `LEFT JOIN` belong in `ON`, not `WHERE`.** This is
a genuinely common bug and it's worth reading that pair of queries twice.

---

## Part 2 — Worked example (~20 min)

**The question:** *How many orders has each customer placed?*

### Attempt 1 — the obvious join

```sql
SELECT   c.first_name,
         c.last_name,
         count(*) AS orders
FROM     customers c
JOIN     orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY orders DESC;
```

**38 rows.** Carlos Mendoza tops it with 8.

Note the `GROUP BY c.customer_id, c.first_name, c.last_name` — grouping by the ID as well as
the names is deliberate. Two different customers could share a first and last name; grouping
by the primary key guarantees they stay separate.

### Attempt 2 — check the total

We have 40 customers. This returned **38**. Two are missing.

```sql
SELECT count(*) FROM customers;   -- 40
```

The `INNER JOIN` dropped Harriet Lockwood and Kwame Mensah, because they have no matching
rows in `orders`. If this were a customer report, two people would simply not exist.

Both signed up in late 2025 — they're our newest customers, and arguably the most
interesting ones to a sales team. The `INNER JOIN` silently deleted precisely the people
someone should be calling.

### Attempt 3 — LEFT JOIN

```sql
SELECT    c.first_name,
          c.last_name,
          count(*) AS orders
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name
ORDER BY  orders;
```

**40 rows.** But look at the bottom: Harriet and Kwame show **1 order each**.

They have zero. Where did the 1 come from?

### The `count(*)` trap

`count(*)` counts **rows**, and after a `LEFT JOIN` Harriet still occupies one row — a row
made of her details plus a set of `NULL`s where the order should be. `count(*)` doesn't care
that the row is half empty. It counts it.

The fix is to count a column from the **right** table, because `count(column)` skips `NULL`s:

```sql
SELECT    c.first_name,
          c.last_name,
          count(o.order_id) AS orders     -- count order IDs, not rows
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name
ORDER BY  orders DESC, c.last_name;
```

**40 rows, and Harriet and Kwame now correctly show 0.**

### What to take from this

The wrong answers here were 38 and "1 order for a customer with none". Neither raised an
error. Both looked entirely reasonable.

Two habits catch this permanently:

1. **After any join, check the row count against what you expected.** 38 when you have 40
   customers is a question worth asking.
2. **After a `LEFT JOIN`, use `count(right_table_column)`, never `count(*)`.**

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-04.sql`](../../solutions/week-04.sql).

### Exercise 4.1 — Your first join

List every order with the customer's first name, last name and country. Show `order_id`,
`order_date`, `status`, and the three customer columns. Sort by `order_id`.

*Expected: 120 rows — the same as the number of orders. If you get more, something is
wrong; if fewer, an order has lost its customer.*

### Exercise 4.2 — LEFT JOIN and the count trap

List **every** customer with the number of orders they've placed, including those who've
placed none. Show first name, last name, and `orders`, most orders first.

*Expected: 40 rows, with exactly two customers showing 0. If your zeros show as 1, you've hit
the `count(*)` trap from the worked example.*

### Exercise 4.3 — Joining on a different key

List every order line with its product name and category. Show `order_id`, `product_name`,
`category`, `quantity` and the line's `unit_price`. Sort by `order_id`, then `product_name`.

*Expected: 300 rows. Note you're joining `order_items` to `products` — the `unit_price` you
want is the one stored on `order_items` (the price at time of sale), not the product's
current price. Both columns are called `unit_price`, so you must qualify it.*

---

## Part 4 — Mini-project (~30 min)

### An order detail report

Support needs to look up a single order and see everything about it.

Write **one query** that returns, for **order 42** only, one row per line item, showing:

- `order_id`, `order_date`, `status`
- customer full name (combine first and last with `||`, aliased `customer`)
- customer email
- `product_name` and `category`
- `quantity`
- the line's `unit_price`
- a calculated `line_total` — quantity × unit price, with the discount applied

For the line total, remember `discount_pct` is a percentage: `quantity * unit_price * (1 - discount_pct / 100)`.

You'll need to join **three tables**: `orders` → `order_items` → `products`, plus
`customers`. Build it up one join at a time and check the row count after each — that's how
you find the step that breaks.

**Then answer, in comments:**

1. How many line items does order 42 have?
2. What's the order total (the sum of your `line_total` column, plus the shipping fee)?
3. Order 42's customer details repeat on every row. Why is that unavoidable in a single
   flat result, and what would you do differently if you were building a screen for support
   staff rather than returning a table?

Question 3 is about the difference between a *result set* and a *view of data a human
reads*. SQL returns rectangles; a support screen is not a rectangle.

---

## Checklist

- [ ] You can explain why `orders` stores `customer_id` instead of the customer's name
- [ ] You qualify every column with a table alias in a multi-table query
- [ ] You can state when `INNER` is right and when `LEFT` is right
- [ ] You know why `count(*)` gives 1 instead of 0 after a `LEFT JOIN`
- [ ] You know why a `WHERE` condition on the right table breaks a `LEFT JOIN`
- [ ] You check the row count after every join

**Tick week 4 in [`PLANNER.md`](../../PLANNER.md).**
