# Week 9 — Schema design & DDL

**Time:** ~2.5 hours
**You'll learn:** `CREATE TABLE`, type choice, constraints, keys, `ON DELETE`, normalisation

Weeks 1–8 read data somebody else designed. From here on you design it yourself. This is
where the DBA and data-engineering half of the course begins, and it's the week most beginner
SQL courses skip entirely.

A schema is the only part of a system that's genuinely hard to change later. Application code
can be rewritten in an afternoon. A badly-typed column with three years of data in it is a
migration, a maintenance window, and a risk.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### CREATE TABLE

```sql
CREATE TABLE suppliers (
    supplier_id  integer      PRIMARY KEY,
    name         text         NOT NULL,
    country      text,
    contact_email text        UNIQUE,
    created_at   timestamptz  NOT NULL DEFAULT now()
);
```

Every column is a decision: a name, a type, and a set of rules about what may go in it.

### Choosing types

| Need | Use | Not |
|---|---|---|
| Text of any length | `text` | `varchar(255)` |
| Whole numbers | `integer`, or `bigint` if it may exceed 2.1 billion | |
| **Money** | `numeric(10,2)` | **never `float`/`real`** |
| A date, no time | `date` | |
| A moment in time | `timestamptz` | `timestamp` |
| True/false | `boolean` | `integer` 0/1, `text` 'Y'/'N' |
| Auto-numbering key | `integer GENERATED ALWAYS AS IDENTITY` | |

**Never use floating point for money.** `float` can't represent 0.10 exactly:

```sql
SELECT 0.1::float + 0.2::float = 0.3::float;   -- false
SELECT 0.1::numeric + 0.2::numeric = 0.3::numeric;  -- true
```

`numeric` stores decimal digits exactly. Financial totals computed in `float` drift by cents
that never reconcile, and finding out why costs somebody a week.

**Prefer `text` to `varchar(n)` in Postgres.** They perform identically, and `varchar(255)`
imposes a limit you invented. When a real name turns out to be 260 characters, `text` doesn't
care and `varchar(255)` is a migration. Use a `CHECK` constraint if you genuinely need a
limit.

**Prefer `timestamptz` to `timestamp`.** `timestamptz` records an actual moment and handles
time zones; plain `timestamp` records wall-clock digits with no indication of *where*. The
second one is only correct if you can guarantee everything is in a single time zone forever.

### Constraints — rules the database enforces

```sql
CREATE TABLE returns (
    return_id   integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    integer       NOT NULL REFERENCES orders (order_id),
    reason      text          NOT NULL CHECK (reason IN ('faulty','wrong_item','unwanted')),
    quantity    integer       NOT NULL CHECK (quantity > 0),
    refund      numeric(10,2) NOT NULL DEFAULT 0 CHECK (refund >= 0),
    created_at  timestamptz   NOT NULL DEFAULT now(),
    UNIQUE (order_id, reason)
);
```

- **`PRIMARY KEY`** — unique and never `NULL`. One per table.
- **`NOT NULL`** — a value is required.
- **`UNIQUE`** — no duplicates. Can span several columns.
- **`CHECK`** — an arbitrary rule about the row's own values.
- **`REFERENCES`** — a foreign key; the value must exist in the other table.
- **`DEFAULT`** — used when no value is supplied.

**Why put rules in the database rather than the application?**

Because the database is the last line of defence and the application isn't the only thing that
writes to it. A migration script, an admin running manual SQL at midnight, a second service, a
bug in a code path nobody tested — every one of those bypasses your application's validation.
Nothing bypasses a `CHECK` constraint.

Constraints also *document* intent. Reading `CHECK (quantity > 0)` tells you a zero-quantity
return is meaningless in this business. No comment required.

### ON DELETE — what happens to children

```sql
order_id integer REFERENCES orders (order_id) ON DELETE CASCADE
```

| Option | Effect |
|---|---|
| `NO ACTION` (default) | Refuse the delete while children exist |
| `CASCADE` | Delete the children too |
| `SET NULL` | Keep children, blank their reference |
| `RESTRICT` | Like `NO ACTION`, checked immediately |

`CASCADE` is right for genuinely owned data — an order's line items are meaningless without
the order. It's dangerous everywhere else: deleting one customer could silently remove years of
order history.

**Default to `NO ACTION`.** Being forced to think about the children before deleting a parent
is a feature.

### Normalisation

The rule of thumb: **store each fact exactly once.**

**1NF** — no repeating groups. Not this:

```
order_id | product1 | product2 | product3
```

You can't query it (finding orders containing a product means checking three columns), and it
caps you at three products. That's what `order_items` exists to fix.

**2NF/3NF** — every column depends on the key, the whole key, and nothing but the key.

If `orders` had a `customer_email` column, that email depends on the *customer*, not the
*order*. Storing it on the order means the same email written on all 8 of Carlos's orders,
and 8 rows to update when it changes — with the near-certainty that one gets missed and the
database now disagrees with itself.

**When to break the rules deliberately.** Our `order_items.unit_price` duplicates
`products.unit_price`. That looks like a 3NF violation and isn't: it stores a *different fact*
— the price **at the time of sale**, which must never change when the current price does.

Denormalisation is legitimate when you're capturing a historical value, or when a
measured performance problem justifies it. It is not legitimate because joins feel like
effort.

### ALTER TABLE

```sql
ALTER TABLE suppliers ADD COLUMN rating integer CHECK (rating BETWEEN 1 AND 5);
ALTER TABLE suppliers ALTER COLUMN country SET NOT NULL;
ALTER TABLE suppliers DROP COLUMN rating;
ALTER TABLE suppliers RENAME COLUMN name TO supplier_name;
```

Adding a nullable column is instant and safe. **Adding `NOT NULL` to a column with existing
`NULL`s fails** — you must backfill first, which is exactly the right order of operations.

---

## Part 2 — Worked example (~20 min)

**The task:** *Design a table to record product reviews.*

### Step 1: What is one row?

Answer this before typing anything. **One row = one review, written by one customer, about one
product.**

Getting this sentence wrong is the source of most bad schemas. If you can't say it in one
sentence, you're designing two tables.

### Step 2: What facts belong to a review?

Who wrote it, what it's about, the rating, the text, when it was written. Then ask of each one:
*does this depend on the review, or on something else?*

The customer's email depends on the customer. The product's name depends on the product. So
neither belongs here — store the IDs and join.

### Step 3: Write it, deciding each column

```sql
CREATE TABLE product_reviews (
    review_id    integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id   integer      NOT NULL REFERENCES products (product_id),
    customer_id  integer      NOT NULL REFERENCES customers (customer_id),
    rating       smallint     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title        text,
    body         text,
    is_published boolean      NOT NULL DEFAULT false,
    created_at   timestamptz  NOT NULL DEFAULT now(),

    UNIQUE (product_id, customer_id)
);
```

The reasoning behind each choice:

- **`GENERATED ALWAYS AS IDENTITY`** — the database issues IDs. `ALWAYS` means an application
  cannot override it, which prevents a whole class of collision bug.
- **`smallint` for rating** — 1 to 5 needs two bytes, not four. Minor, but the `CHECK` is the
  real guard.
- **`CHECK (rating BETWEEN 1 AND 5)`** — a 7-star rating is now impossible, permanently,
  regardless of which application writes it.
- **`title`/`body` nullable** — a rating with no words is a legitimate review.
- **`is_published DEFAULT false`** — safe by default. A new review is invisible until approved.
  If the moderation code fails, nothing leaks; the opposite default publishes unmoderated text.
- **`UNIQUE (product_id, customer_id)`** — one review per customer per product. This is a
  *business rule* expressed structurally.

### Step 4: Test the constraints by trying to break them

```sql
-- Should fail: rating out of range
INSERT INTO product_reviews (product_id, customer_id, rating) VALUES (1, 1, 7);
-- ERROR: new row violates check constraint "product_reviews_rating_check"

-- Should fail: no such product
INSERT INTO product_reviews (product_id, customer_id, rating) VALUES (9999, 1, 5);
-- ERROR: violates foreign key constraint

-- Should fail: same customer reviewing the same product twice
INSERT INTO product_reviews (product_id, customer_id, rating) VALUES (1, 1, 5);
INSERT INTO product_reviews (product_id, customer_id, rating) VALUES (1, 1, 4);
-- ERROR: duplicate key value violates unique constraint
```

**A constraint you haven't tried to violate is a constraint you don't know works.** Writing
`CHECK (rating BETWEEN 1 AND 5)` and never testing it is how people discover a typo two years
later, with 40,000 rows of bad data behind it.

### Step 5: What's deliberately missing

There's no `product_name` and no `customer_email`. Both are one join away, and duplicating
them would mean two places to update and eventual disagreement.

There's also no `average_rating` on `products`. That's a *derived* value — computable at any
time with `avg()`. Storing a computed value means keeping it in sync forever, and a cached
average that drifts from its own source data is a genuinely miserable bug to chase. Only cache
it when a measured performance problem forces you to.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-09.sql`](../../solutions/week-09.sql).

### Exercise 9.1 — Critique a bad schema

Here is a table somebody actually wrote. Find **at least seven** problems and explain the
consequence of each:

```sql
CREATE TABLE customer_orders (
    id            varchar(50),
    customer_name varchar(100),
    customer_email varchar(100),
    cust_country  varchar(50),
    product1      varchar(100),
    product2      varchar(100),
    product3      varchar(100),
    order_total   float,
    order_date    varchar(20),
    status        varchar(20),
    is_paid       varchar(5)
);
```

For each problem, say **what breaks** — not just "that's wrong", but what query returns the
wrong answer or what operation becomes impossible.

### Exercise 9.2 — Build a table properly

Design and create a `suppliers` table. Nimbus buys products from suppliers; each product has
exactly one supplier, and a supplier provides many products.

Requirements: a supplier has a name (required), a country, a contact email (unique when
present), a payment-terms value that must be one of `net30`, `net60`, `prepaid`, an
active flag defaulting to true, and a creation timestamp set automatically.

Then `ALTER TABLE products` to add a `supplier_id` foreign key. Explain why it must be
nullable when you add it, even though every product should eventually have one.

### Exercise 9.3 — Test your constraints

Write `INSERT` statements that **deliberately fail** against your `suppliers` table — one per
constraint. For each, show the statement and the exact error.

Then write one that succeeds.

*This exercise is not busywork. Untested constraints are assumptions.*

---

## Part 4 — Mini-project (~30 min)

### Design a returns (RMA) subsystem

Nimbus needs to handle returns. From the business:

> A customer can return items from an order. Each return covers one order and may include
> several products, with a quantity per product. A return has a status: `requested`,
> `approved`, `received`, `refunded`, or `rejected`. Each returned product has a reason:
> `faulty`, `wrong_item`, `unwanted`, or `damaged_in_transit`. We record when the return was
> requested and when it was resolved. The refund amount is per product line. You cannot return
> more of a product than was ordered.

**Design and create the tables.** Then:

1. Write the `CREATE TABLE` statements with full constraints.
2. Explain, in comments, why you chose one table or two.
3. State which `ON DELETE` behaviour you used on each foreign key and why.
4. Identify one rule from the description that **cannot** be enforced by a constraint, and say
   how you'd enforce it instead.
5. Insert one valid return with two product lines.
6. Write three statements that correctly fail, showing the errors.

Point 4 is the one worth thinking hardest about. "You cannot return more of a product than was
ordered" involves comparing against a *different table* — and a `CHECK` constraint can only see
the row it's attached to.

---

## Checklist

- [ ] You can say what one row of a table represents, in one sentence, before creating it
- [ ] You use `numeric` for money and never `float`
- [ ] You use `timestamptz` rather than `timestamp`
- [ ] You put business rules in `CHECK` constraints rather than only in application code
- [ ] You test constraints by trying to violate them
- [ ] You can explain why `order_items.unit_price` is a legitimate duplicate
- [ ] You default to `NO ACTION` on foreign keys and use `CASCADE` deliberately

**Tick week 9 in [`PLANNER.md`](../../PLANNER.md).**
