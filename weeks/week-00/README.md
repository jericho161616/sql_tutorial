# Week 0 — Start here

**Time:** ~45 minutes
**Assumes:** absolutely nothing

If you have never touched a database, this is your starting line. No jargon is used here
before it's explained, and nothing below asks you to memorise anything.

By the end you will have run your first real query and will know what you're looking at.

---

## Part 1 — What is a database, really?

### Start with something you already know: a spreadsheet

Imagine a spreadsheet of customers:

| customer_id | first_name | last_name | country |
|---|---|---|---|
| 1 | Elena | Sarmiento | Philippines |
| 2 | Robert | Ashcroft | United Kingdom |
| 3 | Yuki | Tanaka | Japan |

You already understand this. It has **rows** (each one a customer) and **columns** (each one
a fact about that customer).

**A database table is exactly this.** Same idea, same shape. If you can read a spreadsheet,
you can read a database table.

### So why not just use a spreadsheet?

Three reasons, and they're the reasons databases exist at all:

**1. Size.** A spreadsheet slows to a crawl at a few hundred thousand rows. A database
handles hundreds of millions without complaint.

**2. Many people at once.** If two people edit the same spreadsheet cell simultaneously, one
of them loses their work. A database is built so that thousands of people can read and write
at the same time without destroying each other's changes.

**3. Rules that are actually enforced.** In a spreadsheet, nothing stops you typing "banana"
into the price column. A database can *refuse*. You tell it "price must be a number, and it
must be zero or more," and from then on it is simply not possible to store anything else —
no matter who tries, or from what program.

That third one is the big one. A spreadsheet trusts you. A database checks.

### The vocabulary, all at once

Six words. That's the whole vocabulary for today:

| Word | What it means | In our data |
|---|---|---|
| **Database** | The whole collection of data | Everything Nimbus stores |
| **Table** | One spreadsheet-like grid | `customers` |
| **Row** | One item — one *thing* | One customer, Elena |
| **Column** | One fact about that thing | `first_name` |
| **Schema** | The blueprint — what tables exist and what shape they are | Our schema is called `shop` |
| **Query** | A question you ask the database | "Show me all customers in Japan" |

**"Schema"** is the one that sounds most intimidating and is actually the simplest. It means
*the design*. Which tables exist, what columns each has, what type each column is, and the
rules. That's all. When someone says "look at the schema," they mean "look at how the tables
are laid out."

---

## Part 2 — What is SQL?

**SQL** is the language you use to ask a database questions. It stands for **Structured Query
Language**. Say it "ess-cue-el" or "sequel" — both are common, neither is wrong.

Here's the thing that makes SQL unusual and, honestly, quite pleasant: **it reads like
English.**

```sql
SELECT first_name, last_name
FROM   customers
WHERE  country = 'Japan';
```

Read it out loud: *"Select the first name and last name, from the customers table, where the
country is Japan."*

That's a working query. You just read code.

### The thing that surprises people

In most programming, you tell the computer **how** to do something — step by step, in order.

In SQL, you describe **what you want**, and the database figures out how to get it.

You never write "look at row 1, check the country, if it's Japan then keep it, now look at
row 2…". You just say *"where country is Japan"* and the database works out the rest. It
decides whether to scan everything or take a shortcut. That's its job, not yours.

This is why SQL is learnable by people who don't consider themselves programmers.

---

## Part 3 — Why are there many tables instead of one big one?

This is the question that confuses everyone at the start, so let's do it properly.

Say we kept everything in one giant table:

| order_id | customer_name | customer_email | product | price |
|---|---|---|---|---|
| 1 | Carlos Mendoza | carlos@example.com | Rapid SSD 1TB | 109.00 |
| 2 | Carlos Mendoza | carlos@example.com | UPS 650VA | 129.00 |
| 3 | Carlos Mendoza | carlos@example.com | Cat6 Cable | 34.00 |

Carlos has placed 8 orders in our real data. Look at the problems:

**His email is written 8 times.** If he changes it, you must find and fix all 8. Miss one and
your database now holds two different emails for the same person — and nothing tells you
which is right.

**A customer who hasn't ordered yet cannot exist.** There's no order to put them in. Two of
our 40 customers signed up recently and haven't bought anything. In this design, they simply
wouldn't be in the system.

**You can't record an order with two products** without either repeating the whole order or
adding `product1`, `product2`, `product3` columns — which caps you at three products forever.

### The fix: store each fact once

So instead:

- **`customers`** holds Carlos once. His email lives in exactly one place.
- **`orders`** holds his 8 orders, each one pointing back at him with a small number: `customer_id = 8`.
- **`order_items`** holds the individual products on each order.

That pointer — a column in one table holding an ID from another — is called a **foreign key**.
It's the entire trick. It's just a number that means "this belongs to that."

The price you pay is that answering "what did Carlos buy?" now needs you to **join** the
tables back together. That's what weeks 4 and 5 are about, and it's the single most useful
skill in SQL.

### Keys, in one line each

- **Primary key** — the column that uniquely identifies a row. `customers.customer_id`. No
  two customers share one. It's the row's name badge.
- **Foreign key** — a column pointing at another table's primary key. `orders.customer_id`.
  It's how a row says "I belong to that one."

That's it. Keys are just IDs and pointers.

---

## Part 4 — Your first query, right now

Open the app: **https://jericho161616.github.io/sql_tutorial/app/**

Or the Supabase editor: **https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql**

### Before anything: you cannot break this

Everything in this database is invented. There is no real customer, no real money, no real
order. If you delete every row, you click one button and it comes back exactly as it was.

**So experiment.** Type things that might not work. The people who learn fastest are the ones
who break things on purpose. Being careful is a habit for later, when the data is real.

### Type this

```sql
SELECT * FROM products;
```

Press Run.

Twenty-five rows come back. Let's take it apart:

- **`SELECT`** — "show me"
- **`*`** — "every column" (the asterisk means *all*)
- **`FROM products`** — "from the products table"
- **`;`** — "that's the end of my question"

So: *"Show me every column from the products table."*

### Now narrow it

```sql
SELECT product_name, unit_price
FROM   products
WHERE  category = 'Storage';
```

*"Show me the name and price, from products, where the category is Storage."* Five rows.

Notice:

- **Single quotes around text.** `'Storage'` is a piece of text, so it gets quotes. Numbers
  don't: `unit_price > 100`, never `unit_price > '100'`.
- **Capital letters matter inside the quotes.** `'storage'` finds nothing, because the value
  stored is `'Storage'` with a capital S. This will catch you at least once. When a query
  returns zero rows, check your capitalisation before you assume the data is missing.
- **Capital letters do NOT matter for the SQL words.** `select` and `SELECT` are identical.
  We write them in capitals purely so your eye can separate the commands from the table names.

### One more

```sql
SELECT product_name, unit_price
FROM   products
ORDER  BY unit_price DESC
LIMIT  3;
```

*"Show me name and price, from products, sorted by price highest-first, and just give me the
top 3."*

`DESC` is short for descending — biggest first. `ASC` is ascending, smallest first, and it's
what you get if you don't say.

**You have now written a real SQL query.** That's the hard part done — everything after this
is adding pieces to a shape you already understand.

---

## Part 5 — What is the `shop` thing?

You'll see this line everywhere:

```sql
SET search_path TO shop, public;
```

Here's what it means. Our tables live in a labelled drawer called `shop`. Their full names
are really `shop.products`, `shop.customers`, and so on.

That line says: *"when I mention a table, look in the `shop` drawer first."* It saves you
typing `shop.` before every single table name.

**In the app, this is already done for you.** In the Supabase editor, run it once at the top
of each session. If you forget, you'll see:

```
ERROR: relation "products" does not exist
```

"Relation" is the database's formal word for "table". So that error means *"there's no table
called products"* — because you haven't told it which drawer to look in.

That one error accounts for most of the confusion in week 1, and now you know the fix.

---

## Part 6 — What you're about to learn

Twelve weeks, and here's the honest shape of it:

**Weeks 1–3 — getting data out of one table.** Choosing rows, choosing columns, sorting,
counting, totalling. This is most of everyday SQL.

**Weeks 4–7 — combining tables.** Joins. This is where SQL becomes powerful and where the
interesting mistakes live.

**Week 8 — messy real data.** Dates in five different formats, numbers stored as text,
duplicates. This is what actual jobs involve.

**Weeks 9–12 — building and running databases.** Designing tables, changing data safely,
making queries fast, controlling who can see what. This is the database-administration and
data-engineering half, and it's the part most beginner courses skip.

---

## Before you start week 1

Read [`GLOSSARY.md`](../../GLOSSARY.md) — every term in this course explained in plain
English. You don't need to memorise it; just know it's there when a word stops making sense.

Then [`SCHEMA-MAP.md`](../../SCHEMA-MAP.md) — a picture of the tables and a guide to which
one holds what. When you're stuck on "where do I even get this from?", that's the page.

And bookmark [`ERRORS.md`](../../ERRORS.md) — the errors you'll hit, in plain English, with
the fix. You will need it, and needing it is normal.

---

## Checklist

You're ready for week 1 when you can say, in your own words:

- [ ] What a table, a row and a column are
- [ ] What "schema" means
- [ ] Why customer details aren't stored on every order
- [ ] What a primary key and a foreign key are
- [ ] Why text needs single quotes but numbers don't
- [ ] What `SELECT`, `FROM` and `WHERE` each do

If any of those are fuzzy, re-read that part. Nothing here is difficult, but week 1 assumes
all six.

**On to [week 1](../week-01/).**
