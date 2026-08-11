# Week 5 — Joins II, and the fan-out bug

**Time:** ~2.5 hours
**You'll learn:** three-table joins, self-joins, anti-joins, and **fan-out**

This is the most important week in the first half of the course. Fan-out is the bug that
makes a query report 17% more revenue than the company earned, without raising a single
error. Experienced people ship it. Do not skip this week.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Fan-out: what actually happens when you join

Here is order 42. It has one shipping fee and three line items.

```
orders                          order_items
order_id | shipping_fee         order_id | product           | qty
   42    |    14.00                42    | 8-Port Switch     |  5
                                   42    | Archive HDD 4TB   |  1
                                   42    | UPS 650VA         |  4
```

Join them:

```sql
SELECT o.order_id, o.shipping_fee, p.product_name
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
JOIN   products p ON p.product_id = oi.product_id
WHERE  o.order_id = 42;
```

```
order_id | shipping_fee | product_name
   42    |    14.00     | 8-Port Gigabit Switch
   42    |    14.00     | Archive HDD 4TB
   42    |    14.00     | UPS 650VA
```

**The shipping fee is now on three rows.** It was charged once. The join copied it onto
every line item, because that's what a join does: for each order row, it produces one output
row per matching item.

So this is wrong:

```sql
SELECT sum(o.shipping_fee)      -- 42.00. The real answer is 14.00.
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_id = 42;
```

Across the whole table it's worse. Real shipping revenue is **$976.50**. After joining to
`order_items`, `sum(o.shipping_fee)` reports **$2,938.50** — almost exactly three times too
much.

Note that orders average **2.5** line items, not 3, yet the inflation factor is 3.009. The
ratio isn't the average item count — it's the *item count weighted by shipping fee*. Orders
carrying a larger fee happen to have more lines, so they're over-counted more heavily. You
can't predict the damage from the average alone, which is another reason to measure the
error rather than estimate it.

**This is fan-out.** Joining a parent (`orders`) to its children (`order_items`) multiplies
the parent's rows by the number of children. Any parent-level value you then aggregate gets
counted once per child.

### Why it's so dangerous

Compare it to a `NULL` bug, which makes numbers too *small* and often obviously so. Fan-out
makes numbers too *big*, and a bigger revenue figure is exactly what nobody questions.

- No error is raised.
- The query looks correct.
- $103,487 instead of $88,572 doesn't look wrong. It looks like a good year.

### Spotting it

**Count your rows.** That's it. That's the whole technique.

```sql
SELECT count(*) FROM orders;                                   -- 120
SELECT count(*) FROM orders o JOIN order_items oi
       ON oi.order_id = o.order_id;                            -- 300
```

Your row count went from 120 to 300. Every order-level value in that result is now
duplicated 2.5× on average. If you know that before you aggregate, you won't be fooled.

**The rule: after every join, ask what one row now represents.** Before the join, one row was
one order. After it, one row is one *line item*. Those are different things, and summing an
order-level column across line-item rows is a category error.

### Three ways to fix it

**Fix 1 — aggregate at the right level.** If you only need order-level totals, don't join to
the children at all:

```sql
SELECT sum(shipping_fee) FROM orders;      -- 976.50. Correct.
```

**Fix 2 — use `MAX` (or `MIN`) to de-duplicate within a group.** When you must join but need
the parent value once per group:

```sql
SELECT o.order_id,
       sum(oi.quantity * oi.unit_price) AS goods,
       max(o.shipping_fee)              AS shipping   -- once, not once per line
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
GROUP  BY o.order_id;
```

Every row in the group has the same `shipping_fee`, so `max()` returns that value exactly
once. This is a standard, legitimate technique — not a hack.

**Fix 3 — aggregate first, then join.** Collapse the children to one row before joining.
This is the cleanest approach and it's what week 6's CTEs make readable:

```sql
SELECT o.order_id,
       o.shipping_fee,          -- safe: still one row per order
       i.goods
FROM   orders o
JOIN  (SELECT order_id, sum(quantity * unit_price) AS goods
       FROM   order_items
       GROUP  BY order_id) i ON i.order_id = o.order_id;
```

The subquery reduces `order_items` to one row per order, so joining it doesn't multiply
anything.

### The worst case: joining two child tables at once

```sql
FROM  orders o
JOIN  order_items oi ON oi.order_id = o.order_id
JOIN  payments    p  ON p.order_id  = o.order_id
```

Order 9 has **2 line items** and **2 payments** (it was paid in instalments — 187.20 then
124.80). This join produces **2 × 2 = 4 rows** for that one order. Every line item is
duplicated by every payment.

Now `sum(oi.quantity * oi.unit_price)` counts the goods twice. That's how completed-order
revenue goes from $88,572 to **$103,487**.

**Never join two sibling child tables directly.** Aggregate each one separately first, then
join the summaries.

### Self-joins — a table joined to itself

`employees.manager_id` points at `employees.employee_id`. To show each person alongside their
manager, join the table to itself with two different aliases:

```sql
SELECT    e.full_name AS employee,
          e.job_title,
          m.full_name AS manager
FROM      employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY  m.full_name NULLS FIRST, e.full_name;
```

The aliases `e` and `m` are what make this work — they let you treat one physical table as
two logical ones.

`LEFT JOIN` is deliberate: Ana Villaruel is CEO and has `NULL` in `manager_id`. `INNER JOIN`
returns 11 employees; `LEFT JOIN` returns all 12. Losing the CEO from the staff list is a
small, funny bug that is exactly the same shape as losing $15,000 of revenue.

### Anti-joins — finding what's missing

Two ways to ask "which rows have no match?":

```sql
-- LEFT JOIN + IS NULL
SELECT p.product_name
FROM      products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE     oi.order_item_id IS NULL;

-- NOT EXISTS - usually clearer, and safe with NULLs
SELECT p.product_name
FROM   products p
WHERE  NOT EXISTS (SELECT 1 FROM order_items oi
                   WHERE oi.product_id = p.product_id);
```

Both return the two products nobody has ever ordered. Prefer `NOT EXISTS`: it states the
intent directly, and unlike `NOT IN` it behaves correctly when `NULL`s are involved
(remember week 2).

---

## Part 2 — Worked example (~20 min)

**The question:** *What is our total revenue by product category?*

### Attempt 1 — the natural query

Revenue involves orders, their line items, and the products those items refer to. So join
all three:

```sql
SELECT   p.category,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
FROM     orders o
JOIN     order_items oi ON oi.order_id  = o.order_id
JOIN     products    p  ON p.product_id = oi.product_id
JOIN     payments    pay ON pay.order_id = o.order_id   -- "only count orders we got paid for"
WHERE    o.status IN ('completed', 'shipped')
GROUP BY p.category
ORDER BY revenue DESC;
```

That last join looks like careful thinking: *only count revenue we were actually paid for.*
It is the mistake.

### Attempt 2 — count the rows before trusting the total

```sql
SELECT count(*) FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status IN ('completed','shipped');
-- 240 rows

SELECT count(*) FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN payments pay ON pay.order_id = o.order_id
WHERE o.status IN ('completed','shipped');
-- 284 rows
```

Adding the `payments` join **increased the row count from 240 to 284 without adding a single
piece of information**. Every order paid in two instalments had all of its line items
duplicated, and those orders now contribute their goods value twice.

The damage: revenue reports **$126,995.83** instead of the true **$107,629.93**. That's
$19,366 of pure arithmetic error — an 18% overstatement produced by a join that looked like
diligence.

### Attempt 3 — the correct query

Drop the payments join entirely. The line items already tell you what was sold; `status`
already tells you the order is real.

```sql
SELECT   p.category,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
FROM     orders o
JOIN     order_items oi ON oi.order_id  = o.order_id
JOIN     products    p  ON p.product_id = oi.product_id
WHERE    o.status IN ('completed', 'shipped')
GROUP BY p.category
ORDER BY revenue DESC;
```

| category | revenue |
|---|---|
| Networking | 37,358.85 |
| Storage | 27,086.10 |
| Peripherals | 19,639.40 |
| Power | 11,535.00 |
| Software | 9,541.95 |
| Cables | 2,468.63 |

Total: **$107,629.93**.

### What if you genuinely need payment data too?

Aggregate it separately, then join the summary:

```sql
SELECT   p.category,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
FROM     orders o
JOIN     order_items oi ON oi.order_id = o.order_id
JOIN     products p ON p.product_id = oi.product_id
WHERE    o.status IN ('completed','shipped')
  AND    EXISTS (SELECT 1 FROM payments pay
                 WHERE pay.order_id = o.order_id AND pay.status = 'captured')
GROUP BY p.category;
```

`EXISTS` **tests** for a payment without **joining** to it. It answers "is there at least
one?" and stops looking — so it can never multiply your rows. Whenever a join exists only to
check that something is there, `EXISTS` is the right tool.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-05.sql`](../../solutions/week-05.sql).

### Exercise 5.1 — Demonstrate the bug to yourself

Write two queries and compare them:

- **(a)** `sum(shipping_fee)` from `orders` alone
- **(b)** `sum(o.shipping_fee)` from `orders` joined to `order_items`

Report both numbers and write a comment explaining the ratio between them.

*Expected: (a) 976.50, (b) 2,938.50. Then work out what number would make that ratio make
sense, and check it.*

### Exercise 5.2 — Self-join

Show every employee with their job title and their manager's name. Include Ana Villaruel,
who has no manager — show her manager as `(none)`.

*Expected: 12 rows. `INNER JOIN` gives 11; if you get 11, you've lost the CEO.*

### Exercise 5.3 — Anti-join

Find every order that has **no payment record at all**. Show `order_id`, `order_date`,
`status` and the customer's name. Sort by `order_id`.

*Expected: 17 rows. Then look at the `status` column and answer: is this a data-quality
problem, or is it exactly what you'd expect? Justify your answer.*

---

## Part 4 — Mini-project (~30 min)

### Find every gap in the order pipeline

You're the data engineer. Someone asks whether the order data can be trusted. Produce a
**single result** listing each integrity check and how many rows fail it.

Use `UNION ALL` to stack one row per check:

```sql
SELECT 'orders with no line items' AS check_name, count(*) AS failures
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
UNION ALL
SELECT 'next check', count(*) FROM ...
```

Write checks for at least these:

1. Orders with no line items
2. Orders with no payment record
3. Orders marked `completed` or `shipped` but with no captured payment
4. Customers who have never placed an order
5. Products never ordered
6. Orders where the sum of captured payments **doesn't equal** the order total
7. Orders with a `NULL` `ship_country`

Check 6 is the hard one and the most valuable. Watch out for fan-out — you're comparing an
aggregate of `order_items` against an aggregate of `payments` for the same order, which is
exactly the two-child-tables trap. Aggregate each side separately.

**Then write a short verdict** as a comment: which failures are real bugs, and which are
normal business reality? Not every non-zero number is a problem — an order with no payment
might simply be pending. Distinguishing "broken" from "expected" is the actual skill here.

---

## Checklist

- [ ] You can explain why joining `orders` to `order_items` triples the shipping total
- [ ] You count rows before and after every join
- [ ] You can state what one row represents at each stage of a query
- [ ] You know three ways to fix fan-out and when each applies
- [ ] You use `EXISTS` instead of a join when you only need to test existence
- [ ] You never join two sibling child tables directly

**Tick week 5 in [`PLANNER.md`](../../PLANNER.md).**
