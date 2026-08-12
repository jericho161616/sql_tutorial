# SQL Tutorial — a 12-week self-study course

A free, self-paced SQL course built around one practice database you can break as
often as you like. No paid tools, no subscriptions, no trial that expires.

**Track:** database administration / data engineering, with app-development crossover
**Pace:** about 2.5 hours per week, for 12 weeks
**Dialect:** PostgreSQL 17

---

## Start here

### 1. Open your database

Your practice database is already built and waiting:

**https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql**

That link opens the SQL editor. Type a query, press **Run**, see results. Nothing to
install — it works from any browser, on the free tier, indefinitely.

Try this to confirm it works:

```sql
SET search_path TO shop, public;
SELECT * FROM products LIMIT 5;
```

You should get five rows back. If you do, you're set up. That's the whole setup step.

> **One gotcha.** The `SET search_path TO shop, public;` line tells Postgres to look in
> our `shop` schema. Run it once at the top of each editor session, or write
> `shop.products` instead of `products` every time. Forgetting it produces
> `relation "products" does not exist` — which is the single most common confusion in
> week 1, and now you know the fix.

### 2. Open the planner

[`PLANNER.md`](PLANNER.md) is your course map and progress tracker. Twelve weeks, each
with a checkbox. Tick them as you go — it's a real file in git, so your progress is
saved and you can see how far you've come.

### 3. Do week 1

Go to [`weeks/week-01/`](weeks/week-01/) and work through it. Every week has the same
four parts, in this order:

| Part | Time | What it is |
|---|---|---|
| **Concepts** | ~30 min | The ideas, in plain English. Read it. |
| **Worked example** | ~20 min | One query, built up line by line, with its real output. |
| **Exercises** | ~60 min | Three questions, getting harder. You write the SQL. |
| **Mini-project** | ~30 min | One realistic task combining the week's skills. |

---

## The rule about answers

**Solutions live in [`solutions/`](solutions/), in a separate folder, on purpose.**

Do not open the solution file until you have genuinely attempted the exercise —
including getting it wrong, getting an error, and trying again. Reading a correct query
feels like learning and is not. Writing a broken one and fixing it is where the learning
actually happens.

A useful standard: open the solution when you're stuck for **15 minutes**, not 15 seconds.
And when you do open it, compare it to your attempt rather than just reading it — the
difference between your query and the solution is the actual lesson.

Every solution file explains *why*, not just *what*. Several of them show a wrong version
first, because the wrong version is usually the more instructive one.

---

## The practice database

**Nimbus Supply Co.** is a fictional online retailer selling networking and computer
hardware. Six tables in the `shop` schema, plus one deliberately filthy staging table.

```
  customers                orders                 order_items            products
  ┌──────────────┐         ┌──────────────┐       ┌───────────────┐      ┌───────────────┐
  │ customer_id  │────┐    │ order_id     │───┐   │ order_item_id │  ┌───│ product_id    │
  │ first_name   │    │    │ customer_id  │◀──┘   │ order_id      │◀─┘   │ sku           │
  │ last_name    │    └───▶│ order_date   │   └──▶│ product_id    │──┐   │ product_name  │
  │ email        │         │ status       │       │ quantity      │  └──▶│ category      │
  │ country      │         │ ship_country │       │ unit_price    │      │ unit_price    │
  │ city         │         │ shipping_fee │       │ discount_pct  │      │ cost_price    │
  │ signup_date  │         │ discount_code│       └───────────────┘      │ stock_qty     │
  │ segment      │         └──────────────┘                             │ is_discontinued│
  │ is_active    │                │                                     │ created_at    │
  └──────────────┘                │                                     └───────────────┘
                                  │
                                  │        payments                employees
                                  │        ┌──────────────┐        ┌───────────────┐
                                  └───────▶│ payment_id   │        │ employee_id   │◀─┐
                                           │ order_id     │        │ full_name     │  │
                                           │ paid_on      │        │ job_title     │  │
                                           │ amount       │        │ department    │  │
                                           │ method       │        │ manager_id    │──┘
                                           │ status       │        │ hired_on      │
                                           └──────────────┘        │ annual_salary │
                                                                   └───────────────┘
```

**In plain English:**

- A **customer** places many **orders**. Each order belongs to exactly one customer.
- An **order** contains many **order_items** — one row per product on that order.
- Each **order_item** points at one **product**. This is how orders and products connect:
  never directly, always through `order_items`.
- An **order** can have **zero, one, or several payments**. Zero if it was never paid.
  Several if it was paid in instalments, refunded, or retried after a card failure.
- **employees** points at itself: `manager_id` is another employee's `employee_id`.
  Ana Villaruel is CEO and has `NULL` there, because she reports to nobody.

### The traps are deliberate

This data was built with specific problems baked in, because you cannot learn to spot
them in clean data:

| What's in there | Why | Bites you in |
|---|---|---|
| 2 customers with no orders at all | `INNER JOIN` silently drops them | Week 4 |
| 4 customers with `NULL` country | `WHERE country != 'Ireland'` won't return them | Week 2 |
| 2 products nobody ever ordered | Same trap, from the other side | Week 4 |
| 17 orders with no payment row | `LEFT JOIN` vs `INNER JOIN` matters | Week 5 |
| 25 orders with **2+ payment rows** | Joining inflates your revenue total | Week 5 |
| `cancelled` and `refunded` orders | Counting them as revenue is *the* classic error | Week 3 |
| No indexes on any foreign key | So you can add them and watch `EXPLAIN` change | Week 11 |
| `raw_signups`, 40 rows of filth | 8 spellings of 3 plan names, 5 date formats | Week 8 |

If a query of yours ever returns a suspiciously round or suspiciously large number,
one of the rows above is usually why.

---

## Rebuilding the database

You will eventually run an `UPDATE` without a `WHERE` clause and wreck something. Everyone
does. That's what a practice database is for — and it's why the reset takes 30 seconds.

Open the SQL editor and run these three files in order:

1. [`db/01_schema.sql`](db/01_schema.sql) — tables, keys, constraints
2. [`db/02_seed.sql`](db/02_seed.sql) — the data
3. [`db/03_messy_data.sql`](db/03_messy_data.sql) — the `raw_signups` table

File 1 begins with `DROP SCHEMA IF EXISTS shop CASCADE`, so it wipes and rebuilds from
scratch. The seed data is generated with plain arithmetic rather than random numbers,
so you get **byte-identical data every time** — which means the answers in `solutions/`
stay correct no matter how many times you reset.

---

## Repository layout

```
README.md            you are here
HOW-TO-STUDY.md      the operating manual — read this before week 1
PLANNER.md           the 12-week map + your progress checkboxes
db/                  schema, seed data, and the messy table
weeks/week-01..12/   concepts, worked example, exercises, mini-project
my-answers/          where YOUR work goes — one template per week
solutions/           answers — stay out until you've attempted
prompts/             the 10 AI-tutor prompts, filled in with your details
```

**[`HOW-TO-STUDY.md`](HOW-TO-STUDY.md) is the one to read first.** It covers what teaches what,
where you write queries versus where you save answers, the 15-minute rule for getting unstuck,
and what to do when you fall behind.

---

## Using AI as your tutor

[`prompts/`](prompts/) holds ten reusable prompts adapted from the guide you found,
with the blanks already filled in with your actual schema, dialect and goals. Use them
when you're stuck — `prompts/05-fix-my-broken-query.md` in particular is worth reaching
for the moment an error message stops making sense.

They're written to make the AI *teach* rather than *answer*: several of them explicitly
instruct it not to reveal the solution until you've made an attempt. That constraint is
the difference between using AI to learn SQL and using AI to avoid learning SQL.

---

## Honest expectations

After 12 weeks at this pace you will be able to read and write real queries against a
real schema, design a sane table, understand what an index does, and reason about why a
query is slow. That is a genuine, employable foundation.

You will not be an expert. Nobody is after 30 hours. What you will have is the thing that
makes the next 300 hours productive.
