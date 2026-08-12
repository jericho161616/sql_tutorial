# Schema map — what's in the database and where

The page to open when you're stuck on *"where do I even get this from?"*

---

## The picture

```
                          ┌──────────────────┐
                          │    customers     │   40 rows
                          │──────────────────│   the people who buy
                          │ customer_id  PK  │◀────────────┐
                          │ first_name       │             │
                          │ last_name        │             │
                          │ email            │             │
                          │ country   (NULL) │             │
                          │ city      (NULL) │             │
                          │ signup_date      │             │
                          │ segment          │             │
                          │ is_active        │             │
                          └──────────────────┘             │
                                                           │ "who placed it"
                                                           │
                          ┌──────────────────┐             │
                          │      orders      │   120 rows  │
                          │──────────────────│             │
                          │ order_id     PK  │◀──┐         │
                          │ customer_id  FK  │───┼─────────┘
                          │ order_date       │   │
                          │ status           │   │  ⚠ filter this
                          │ ship_country     │   │
                          │ shipping_fee     │   │
                          │ discount_code    │   │
                          └──────────────────┘   │
                                                 │
                    ┌────────────────────────────┴──────┐
                    │ "what was on it"       "what was paid"
                    │                                   │
        ┌──────────────────────┐          ┌──────────────────────┐
        │     order_items      │ 300 rows │       payments       │ 128 rows
        │──────────────────────│          │──────────────────────│
        │ order_item_id    PK  │          │ payment_id       PK  │
        │ order_id         FK  │          │ order_id         FK  │
        │ product_id       FK  │───┐      │ paid_on              │
        │ quantity             │   │      │ amount               │
        │ unit_price ⚠ at sale │   │      │ method               │
        │ discount_pct         │   │      │ status               │
        └──────────────────────┘   │      └──────────────────────┘
                                   │
                                   │ "which product"
                                   ▼
                          ┌──────────────────┐
                          │     products     │   25 rows
                          │──────────────────│
                          │ product_id   PK  │
                          │ sku              │
                          │ product_name     │
                          │ category         │
                          │ unit_price ⚠ now │
                          │ cost_price       │
                          │ stock_qty        │
                          │ is_discontinued  │
                          └──────────────────┘


        ┌──────────────────────┐          ┌──────────────────────┐
        │      employees       │ 12 rows  │     raw_signups      │ 40 rows
        │──────────────────────│          │──────────────────────│
        │ employee_id      PK  │◀─┐       │ every column is TEXT │
        │ full_name            │  │       │ deliberately filthy  │
        │ job_title            │  │       │ used in week 8 only  │
        │ department           │  │       └──────────────────────┘
        │ manager_id       FK ─┼──┘
        │ hired_on             │  points at ITSELF
        │ annual_salary        │  (the CEO's is NULL)
        └──────────────────────┘
```

**`PK`** = primary key, the row's unique ID.
**`FK`** = foreign key, a pointer to another table's PK.

---

## Read it in plain English

- A **customer** places many **orders**. Each order belongs to exactly one customer.
- An **order** contains many **order_items** — one row per product on that order.
- Each **order_item** points at one **product**.
- **Orders and products are never connected directly.** Always through `order_items`. This
  catches everyone once.
- An **order** can have **zero, one, or several payments** — zero if never paid, several if
  paid in instalments or retried after a card failure.
- **employees** points at itself: `manager_id` holds another employee's `employee_id`.

---

## "I want to know X — where do I look?"

| I want… | Start at | Go through | Land on |
|---|---|---|---|
| Customer names, emails, countries | `customers` | — | — |
| A list of products and prices | `products` | — | — |
| When orders were placed | `orders` | — | — |
| **Who placed an order** | `orders` | — | `customers` |
| **What products were on an order** | `orders` | `order_items` | `products` |
| **What a customer bought** | `customers` | `orders` → `order_items` | `products` |
| **How much an order was worth** | `orders` | `order_items` | — |
| **Whether an order was paid** | `orders` | — | `payments` |
| **Which products sell best** | `order_items` | — | `products` |
| **Revenue by country** | `orders` | `order_items` | `customers` |
| Who reports to whom | `employees` | `employees` again | — |
| Messy data to clean | `raw_signups` | — | — |

**The pattern:** to get from customers to products, you always pass through `orders` and
`order_items`. There's no shortcut, and looking for one is a common early frustration.

---

## What one row means in each table

Getting this right prevents most wrong answers.

| Table | One row = |
|---|---|
| `customers` | one person |
| `products` | one item we sell |
| `orders` | one order (the *header* — who, when, what status) |
| `order_items` | **one product on one order** |
| `payments` | **one payment attempt** |
| `employees` | one member of staff |

**Why this matters:** `orders` has 120 rows but `order_items` has 300. Join them and you get
**300 rows**, not 120 — because one row now means *one product on one order*, not *one order*.

Anything order-level you total after that (like `shipping_fee`) gets counted **once per
product**. That's fan-out, and it's week 5.

---

## Sample rows — what the data actually looks like

### `customers`

| customer_id | first_name | last_name | country | segment | is_active |
|---|---|---|---|---|---|
| 1 | Elena | Sarmiento | Philippines | consumer | true |
| 7 | Anonymous | User | *NULL* | consumer | true |
| 8 | Carlos | Mendoza | Mexico | business | true |
| 39 | Harriet | Lockwood | United Kingdom | consumer | true |

### `products`

| product_id | product_name | category | unit_price | cost_price | is_discontinued |
|---|---|---|---|---|---|
| 3 | 8-Port Gigabit Switch | Networking | 79.50 | 41.00 | false |
| 9 | Vault NAS 4-Bay | Storage | 529.00 | 322.00 | false |
| 24 | Nimbus Router 500 (EOL) | Networking | 99.00 | 61.00 | **true** |

### `orders`

| order_id | customer_id | order_date | status | shipping_fee |
|---|---|---|---|---|
| 42 | 3 | 2024-07-29 | completed | 14.00 |
| 9 | 25 | 2024-03-08 | completed | 5.00 |

### `order_items` — note order 42 has three rows

| order_item_id | order_id | product_id | quantity | unit_price | discount_pct |
|---|---|---|---|---|---|
| … | 42 | 3 | 5 | 79.50 | 0.00 |
| … | 42 | 10 | 1 | 89.00 | **10.00** |
| … | 42 | 19 | 4 | 129.00 | 0.00 |

### `payments` — note order 9 has two rows

| payment_id | order_id | paid_on | amount | status |
|---|---|---|---|---|
| … | 9 | 2024-03-09 | 187.20 | captured |
| … | 9 | 2024-04-08 | 124.80 | captured |

---

## Three traps built into this schema on purpose

### 1. `status` — not every order is real revenue

```
completed  78    ← real
shipped    20    ← real
pending    10    ← not paid yet
cancelled   7    ← NOT revenue
refunded    5    ← NOT revenue
```

**12 of 120 orders are cancelled or refunded.** Forget to exclude them and you overstate
income by about 10%. Nearly every revenue query needs:

```sql
WHERE status IN ('completed', 'shipped')
```

### 2. Two columns called `unit_price`, and they mean different things

- **`order_items.unit_price`** — what the customer *actually paid*, frozen at the moment of
  sale. **Use this for revenue.**
- **`products.unit_price`** — what we charge *today*.

Use the wrong one and last year's revenue changes every time somebody edits a price.

When you join both tables, writing bare `unit_price` gives
`column reference "unit_price" is ambiguous` — the database refusing to guess.

### 3. Gaps that are supposed to be there

| What | How many | Bites you in |
|---|---|---|
| Customers with `NULL` country | 4 | Week 2 — `<> 'X'` silently drops them |
| Customers who never ordered | 2 | Week 4 — `INNER JOIN` deletes them |
| Products never sold | 2 | Week 4 |
| Orders with **no** payment | 17 | Week 5 |
| Orders with **2+** payments | 25 | Week 5 — inflates revenue |

If a number ever looks suspiciously round or suspiciously large, one of these is usually why.

---

## The joins you'll write most

**Order with its customer**
```sql
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
```

**Order with its products**
```sql
FROM orders o
JOIN order_items oi ON oi.order_id  = o.order_id
JOIN products    p  ON p.product_id = oi.product_id
```

**Every customer, including those with no orders**
```sql
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
```

**What an order was worth**
```sql
SELECT o.order_id,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS goods,
       MAX(o.shipping_fee) AS shipping        -- MAX, not SUM. See fan-out.
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.status IN ('completed','shipped')
GROUP  BY o.order_id;
```

---

## Look at the data yourself

The fastest way to understand a table is to open it:

```sql
SELECT * FROM customers LIMIT 5;
SELECT * FROM orders    LIMIT 5;
```

**Do this before writing any query.** Thirty seconds of looking saves ten minutes of guessing
at column names — and it's how you learn that the value is `'Storage'` and not `'storage'`.

You can also click through the tables visually in the
[Supabase Table Editor](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/editor),
or see an auto-drawn diagram in the
[Schema Visualiser](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/database/schemas).

---

## Two commands to inspect any table

**What columns does this table have?**
```sql
SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'shop' AND table_name = 'orders'
ORDER  BY ordinal_position;
```

**What tables exist?**
```sql
SELECT table_name
FROM   information_schema.tables
WHERE  table_schema = 'shop'
ORDER  BY table_name;
```

These work on *any* PostgreSQL database, not just this one — genuinely useful the first day of
a job, when nobody has documented the schema.
