# Prompt library

Ten reusable prompts for using an AI as your SQL tutor, adapted from the guide that
started this course. The originals were full of `[blanks]`. These have your actual details
already filled in: PostgreSQL 17, the Nimbus schema, and a database-administration /
data-engineering goal.

**How to use one:** open the file, copy the prompt, paste it into a chat with Claude,
and replace anything in `«guillemets»` with your specifics.

| # | Prompt | Reach for it when |
|---|---|---|
| 1 | [Adjust my learning plan](01-adjust-my-learning-plan.md) | The pace is wrong, or your goal shifts |
| 2 | [Build another practice database](02-build-another-practice-db.md) | You want a second domain to practise on |
| 3 | [Teach me this query](03-teach-me-this-query.md) | You want to *understand*, not be handed an answer |
| 4 | [Turn plain English into SQL](04-plain-english-to-sql.md) | You know what you want, not how to write it |
| 5 | [Fix my broken query](05-fix-my-broken-query.md) | **Most used.** An error or a wrong result |
| 6 | [Help me master joins](06-master-joins.md) | Week 4–5, or any time row counts look wrong |
| 7 | [Clean a messy dataset](07-clean-messy-data.md) | Week 8, and every real job afterwards |
| 8 | [Exploratory data analysis](08-exploratory-analysis.md) | Facing an unfamiliar table |
| 9 | [Analyse a business KPI](09-analyse-a-kpi.md) | Someone asks "how's revenue doing?" |
| 10 | [Turn results into insights](10-results-into-insights.md) | You have numbers and need a conclusion |

---

## The one thing that makes these work

Several of these prompts contain an instruction like *"do not show me the answer until I've
attempted it."*

**Leave that line in.** It is the difference between using AI to learn SQL and using AI to
avoid learning SQL. Both feel productive. Only one of them ends with you able to write a
query.

If you delete that line because you're in a hurry, you'll get a correct query and learn
nothing from it — which is fine occasionally when you need an answer, and corrosive as a
habit.

---

## Your schema, ready to paste

Most of these prompts need your schema. Copy this block into any prompt that asks for it:

```
PostgreSQL 17. All tables are in the `shop` schema.

customers(customer_id PK, first_name, last_name, email UNIQUE, country NULLABLE,
          city NULLABLE, signup_date, segment CHECK IN ('consumer','business','education'),
          is_active boolean)

products(product_id PK, sku UNIQUE, product_name, category, unit_price numeric(10,2),
         cost_price numeric(10,2), stock_qty, is_discontinued boolean, created_at date)

orders(order_id PK, customer_id FK -> customers, order_date date,
       status CHECK IN ('completed','shipped','pending','cancelled','refunded'),
       ship_country NULLABLE, shipping_fee numeric(10,2), discount_code NULLABLE)

order_items(order_item_id PK, order_id FK -> orders, product_id FK -> products,
            quantity, unit_price numeric(10,2), discount_pct numeric(5,2),
            UNIQUE(order_id, product_id))

payments(payment_id PK, order_id FK -> orders, paid_on date, amount numeric(10,2),
         method CHECK IN ('card','paypal','bank_transfer','voucher'),
         status CHECK IN ('captured','failed','refunded'))

employees(employee_id PK, full_name, job_title, department,
          manager_id FK -> employees SELF-REFERENCING NULLABLE, hired_on, annual_salary)

raw_signups(row_id, full_name, email, country, signup_date_text, plan, monthly_spend)
  -- staging table, every column is text, deliberately unclean

Known characteristics that matter:
 - 40 customers; 4 have NULL country; 2 have never placed an order
 - 120 orders; 12 are cancelled or refunded and must be excluded from revenue
 - 300 order_items; an order has 1-4 of them
 - 128 payments; 17 orders have NO payment row; 25 orders have TWO OR MORE
 - order_items.unit_price is the price at time of sale, not the current product price
 - no indexes exist on any foreign key column
```

---

## Context worth including

When you ask for help, these are worth stating up front:

- **Dialect:** PostgreSQL 17 (via Supabase)
- **Level:** beginner working through a structured course
- **Goal:** database administration / data engineering, with some application development
- **Time:** under 3 hours a week — so prefer depth on one thing over a survey of five

That last point matters more than it looks. Without it you get comprehensive answers
covering six approaches, which is exactly wrong for someone with 40 minutes.
