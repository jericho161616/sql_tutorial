# Glossary

Every term in this course, in plain English. Nothing here assumes you've read anything else.

**How to use it:** don't read it front to back. Come here when a word stops making sense.
Use `Ctrl+F` / `Cmd+F` to jump to a term.

Terms are grouped by what they're *for*, because that's how you'll look for them.

---

## The absolute basics

**Database**
The whole collection of stored data, plus the software that manages it. Think of it as a
filing cabinet that can answer questions about its own contents.

**Table**
One grid of data, like a single spreadsheet tab. `customers` is a table. It has rows and
columns. Everything in a database lives in tables.

**Row** *(also called a record)*
One item in a table. One customer. One order. One product. If a table is a spreadsheet, a row
is a line in it.

**Column** *(also called a field)*
One fact about the item. `first_name` is a column. Every row in the table has a value for
every column — even if that value is "unknown".

**Schema**
The blueprint: what tables exist, what columns they have, what type each column is, and the
rules. It's the *design* of the database, not the data itself.
It's also a named container — our tables live in a schema called `shop`, so their full names
are `shop.customers`, `shop.orders`, and so on.

**Query**
A question you ask the database. Every `SELECT` you write is a query.

**SQL**
Structured Query Language. The language you write queries in. Say it "ess-cue-el" or
"sequel"; both are fine.

**PostgreSQL** *(often just "Postgres")*
The specific database software this course uses. Free, open source, and one of the most
widely used databases in the world. Other databases (MySQL, SQL Server, Oracle) speak *almost*
the same SQL, with small differences.

**Dialect**
A database's particular flavour of SQL. Most of what you learn transfers; a few things don't.
When a tutorial doesn't work, a dialect difference is a common cause.

**Relation**
Postgres's formal word for a table. It only shows up in error messages, which is why
`relation "products" does not exist` really just means *"there's no table called products"*.

---

## The commands you'll use constantly

**`SELECT`**
"Show me these columns." The start of nearly every query.
`SELECT product_name, unit_price`

**`FROM`**
"…from this table."
`FROM products`

**`WHERE`**
"…but only the rows that pass this test." Filters rows.
`WHERE category = 'Storage'`

**`ORDER BY`**
"…and sort the result like this." `ASC` = smallest first (the default), `DESC` = biggest first.
`ORDER BY unit_price DESC`

**`LIMIT`**
"…and only give me this many rows."
`LIMIT 10`

**`AS`** *(alias)*
Renames a column in the output only. The table itself is unchanged. Essential once you start
calculating things, because a calculated column otherwise gets a useless name.
`SELECT unit_price - cost_price AS margin`

**`DISTINCT`**
"Remove duplicates from the result."
`SELECT DISTINCT country FROM customers`

**`*`**
"Every column." Fine while exploring, a bad habit in saved queries — if someone adds a column,
your query silently starts returning it.

**`;`**
Ends a statement. Get in the habit; it stops being optional the moment you run two statements
together.

**`--`**
A comment. Everything after it on that line is ignored by the database and is there for humans.

---

## Filtering and comparing

**Operator**
A symbol that compares or calculates. `=`, `<>`, `>`, `<`, `>=`, `<=`, `+`, `-`, `*`, `/`.

**`=` vs `<>`**
Equal to, and not equal to. `!=` also means not-equal and works identically.
Note SQL uses ONE equals sign for comparison, not two.

**`AND` / `OR` / `NOT`**
Combine conditions. `AND` = both must be true. `OR` = either will do. `NOT` = flip it.
**Important:** `AND` is evaluated before `OR`, like `×` before `+` in maths. Use brackets when
you mix them, or you'll get a wrong answer with no error.

**`IN`**
A tidier way to write several `OR`s on the same column.
`WHERE country IN ('Ireland', 'Japan', 'Ghana')`

**`BETWEEN`**
A range, **including both ends**. `BETWEEN 50 AND 150` means 50 and 150 are both included.

**`LIKE`**
Pattern matching on text. `%` matches any number of characters, `_` matches exactly one.
`WHERE product_name LIKE 'Nimbus%'` finds anything starting with "Nimbus".
`ILIKE` is the same but ignores capital letters (Postgres only).

**`IS NULL` / `IS NOT NULL`**
The **only** way to test for missing values. `= NULL` never works — see NULL below.

---

## NULL — the one that trips everyone up

**`NULL`**
Means **unknown**, not zero and not empty text. Four of our customers have `NULL` in their
country column because they never filled it in — we genuinely don't know where they live.

**Why NULL behaves strangely**
Because "unknown" can't be compared to anything. Ask SQL whether an unknown country is
different from `'Nigeria'` and the honest answer is *"I can't tell"* — so it returns neither
true nor false, and `WHERE` drops the row.

That's why this returns 33 and not 37, even though only 3 of our 40 customers are Nigerian:

```sql
SELECT count(*) FROM customers WHERE country <> 'Nigeria';   -- 33
```

The four customers with unknown countries silently vanish. **No error, no warning.**

**`IS DISTINCT FROM`**
Postgres shorthand for "different, and treat unknown as different too". This returns 37:
`WHERE country IS DISTINCT FROM 'Nigeria'`

**`COALESCE`**
Returns the first value that isn't `NULL`. Useful for display.
`COALESCE(country, 'Unknown')` shows "Unknown" instead of a blank.

**`NULLIF`**
The reverse — returns `NULL` if two values are equal. `NULLIF(x, 0)` is the standard trick to
avoid a divide-by-zero error.

**The habit that catches NULL bugs**
When you split a table into two groups, the two sizes should add up to the total. If they
don't, `NULL` is involved.

---

## Counting and grouping

**Aggregate function**
A function that squashes many rows into one number.

**`count(*)`**
Counts **rows**.

**`count(column)`**
Counts rows where that column **isn't NULL**. Different from `count(*)`, and the gap between
the two is exactly your missing-data count.

**`sum`, `avg`, `min`, `max`**
Total, average, smallest, largest. All of them **ignore NULLs**.

**`GROUP BY`**
"Sort rows into piles, then run the aggregate once per pile."
`GROUP BY category` gives you one row per category.

**The GROUP BY rule**
Every column in your `SELECT` must either appear in the `GROUP BY` or be inside an aggregate
function. If you ask for one row per category but also ask for `product_name`, the database
doesn't know which of the five product names to show — so it refuses.

**`HAVING`**
Like `WHERE`, but it filters **groups** after aggregating, not rows before.
`WHERE` = about one row. `HAVING` = about a whole group.
You can't put `count(*)` in `WHERE`, because the counting hasn't happened yet.

**`FILTER`**
A Postgres feature for counting subsets side by side in one pass.
`count(*) FILTER (WHERE status = 'completed')`

**Median vs average**
The average is the total divided by the count. The median is the middle value. When a few
large values pull the average up, the median describes a *typical* case far better. Our
customers average $2,908 in spend but the median is $2,380 — a 22% gap.

---

## Joining tables

**Join**
Sticking two tables side by side, matching rows using a shared value. This is how you answer
"which customer placed this order" when the name and the order live in different tables.

**Primary key** *(PK)*
The column that uniquely identifies a row. `customers.customer_id`. Never duplicated, never
`NULL`. Think of it as the row's ID badge.

**Foreign key** *(FK)*
A column pointing at another table's primary key. `orders.customer_id` holds the ID of the
customer who placed it. It's how a row says "I belong to that one."

**Referential integrity**
The guarantee that a foreign key always points at something real. The database will refuse an
order for customer 9999 if no such customer exists.

**`INNER JOIN`** *(or just `JOIN`)*
Keeps only rows that **match on both sides**. Customers with no orders disappear entirely —
with no warning.

**`LEFT JOIN`**
Keeps **everything from the left table**, matched or not. Where there's no match, the right
table's columns come back as `NULL`. Use this when "none" is a valid answer you need to see.

**`ON`**
Where you write the join condition.
`ON c.customer_id = o.customer_id`

**Alias** *(table alias)*
A short nickname for a table so you can say which one a column came from.
`FROM orders o JOIN customers c ON …` — then `o.order_date` and `c.first_name`.
Once you have two tables, you must qualify columns that exist in both, or you'll get
`column reference is ambiguous`.

**Anti-join**
Finding rows with **no** match — customers who never ordered, products never sold. Written as
a `LEFT JOIN` plus `WHERE … IS NULL`, or more clearly with `NOT EXISTS`.

**Self-join**
Joining a table to itself, using two different aliases. Used when a table points at itself —
our `employees.manager_id` holds another employee's ID.

**Fan-out** ⚠️
**The most important term in this glossary.**
When you join a table to another that has several matching rows, the first table's rows get
**duplicated** — and anything you then total up gets counted multiple times.

Order 42 has one shipping fee of $14.00 and three line items. Join them and the $14.00 appears
on three rows, so `SUM` reports $42.00. Across our data, shipping revenue reads **$2,938.50**
when the truth is **$976.50**.

**No error is raised.** The number is just wrong, and wrong in the direction nobody questions.

**How to spot it:** count your rows before and after every join. If the count grew, ask what
one row now represents.

---

## Building on what you know

**Subquery**
A query inside another query. Lets you use the result of one question inside another.

**CTE** *(Common Table Expression, the `WITH` clause)*
A named, reusable step at the top of your query. Turns one impossible query into three easy
ones stacked together, and lets you run each step on its own to find where a wrong answer came
from.

**`EXISTS` / `NOT EXISTS`**
Tests whether a matching row exists, without joining to it. Because it only answers yes/no, it
**cannot cause fan-out** — which makes it safer than a join when you only need to check.

**Window function**
Calculates across a set of rows **while keeping every row**. `GROUP BY` collapses 23 products
into 6 category rows; a window function gives you all 23 products each carrying its category's
average alongside.

**`OVER` / `PARTITION BY`**
`OVER` is what makes a function a window function. `PARTITION BY` splits rows into groups
without collapsing them.

**`ROW_NUMBER` / `RANK` / `DENSE_RANK`**
Numbering functions. They differ only on ties: `ROW_NUMBER` always gives different numbers,
`RANK` gives ties the same number then skips, `DENSE_RANK` gives ties the same number and
doesn't skip.

**`LAG` / `LEAD`**
Look at the previous or next row. This is how you calculate "change since last month" without
joining a table to itself.

**Running total**
A cumulative sum. `SUM(x) OVER (ORDER BY month)` — the `ORDER BY` inside `OVER` is what turns
a grand total into a running one.

---

## Data types

**Data type**
What kind of value a column holds. The database enforces it — you cannot put text in a number
column.

**`integer`**
A whole number. `bigint` for very large ones.

**`numeric(10,2)`**
An exact decimal — 10 digits total, 2 after the point. **Always use this for money.**

**`float` / `real`** ⚠️
Approximate decimals. Fast, and **wrong for money** — `float` can't store 0.10 exactly, so
totals drift by fractions of a cent that never reconcile.

**`text`**
Text of any length. In Postgres, prefer this over `varchar(255)` — same speed, no arbitrary
limit you invented.

**`boolean`**
True or false. Better than storing `'Y'`/`'N'` text, which eventually becomes `'y'`, `'yes'`,
`'1'` and `''`.

**`date`**
A calendar date, no time. Supports real arithmetic: `order_date + 30` is 30 days later.

**`timestamptz`**
A precise moment including time zone. Prefer it over plain `timestamp`, which records
wall-clock digits with no indication of *where*.

**Cast**
Converting a value from one type to another. `'49.00'::numeric` turns text into a number.
A failed cast is an **error**, not a `NULL` — which is why you validate before casting.

---

## Designing and changing data

**DDL** *(Data Definition Language)*
Commands that change the *structure*: `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`.

**DML** *(Data Manipulation Language)*
Commands that change the *data*: `INSERT`, `UPDATE`, `DELETE`.

**Constraint**
A rule the database enforces. Nothing can bypass it — not your app, not a script, not someone
typing SQL at midnight.

- **`NOT NULL`** — a value is required
- **`UNIQUE`** — no duplicates
- **`CHECK`** — any rule you like, e.g. `CHECK (quantity > 0)`
- **`DEFAULT`** — the value used when none is given

**Normalisation**
Organising tables so each fact is stored **exactly once**. It's why customer emails live in
`customers` and not on every order.

**`ON DELETE CASCADE`**
"If the parent row is deleted, delete the children too." Right for genuinely owned data (an
order's line items). Dangerous elsewhere — it can silently remove years of history.

**Transaction**
A group of statements that **all succeed or all fail**. Started with `BEGIN`, finished with
`COMMIT` (keep it) or `ROLLBACK` (undo it).
It's also your undo button: run something risky, look at the result, `ROLLBACK` if it's wrong.

**ACID**
The four guarantees a transactional database gives:
**A**tomicity (all or nothing), **C**onsistency (rules always hold), **I**solation (concurrent
work doesn't interfere), **D**urability (once committed, it survives a power cut).

**Upsert**
Insert a row, or update it if it already exists. `INSERT … ON CONFLICT … DO UPDATE`. Essential
for anything that reloads the same data repeatedly.

**Soft delete**
Marking a row inactive instead of removing it. Keeps history, keeps foreign keys valid, and is
reversible. Our `customers.is_active` column does this.

---

## Speed and structure

**Index**
A separate sorted structure that lets the database find rows without reading the whole table —
like the index at the back of a book.
**The trade-off:** faster reads, **slower writes**, and it uses disk. An index nobody uses is
pure cost.

**Sequential scan** *(Seq Scan)*
Reading every row. Fine on small tables — genuinely faster than an index when the table fits
in one page.

**Index scan**
Using an index to jump to the rows you want. What you want on large tables.

**`EXPLAIN`**
Shows the plan the database *would* use, without running the query.

**`EXPLAIN ANALYZE`**
Actually runs it and shows real times and row counts. ⚠️ On an `UPDATE` or `DELETE` this
really does change data — wrap it in `BEGIN … ROLLBACK`.

**Query planner**
The part of the database that decides *how* to run your query. When it ignores an index you
just created, it usually has good reason.

**`ANALYZE`**
Refreshes the statistics the planner uses. Stale statistics are the most common cause of a
catastrophically bad plan, and this is free to run.

**View**
A saved query that behaves like a table. Stores no data — it runs fresh each time. Good for
hiding complexity and for making sure "revenue" means one thing to everyone.

**Materialised view**
A view whose results **are** stored. Fast, but only as current as the last `REFRESH`. A
refresh job that quietly fails serves stale numbers that look perfectly current.

**Role / `GRANT`**
Users and permissions. `GRANT SELECT` gives read access. **Least privilege** means giving each
role the minimum it needs, so a compromise does the least damage.

**RLS** *(Row-Level Security)*
Rules that filter which *rows* a given user can see, enforced by the database rather than by
remembering to add a `WHERE` clause everywhere.

---

## Words that sound scarier than they are

| Term | It just means |
|---|---|
| Schema | The design / layout |
| Relation | Table |
| Tuple | Row |
| Attribute | Column |
| Cardinality | How many |
| Predicate | A test that's true or false |
| Idempotent | Safe to run more than once |
| Grain | What one row represents |
| Referential integrity | Pointers always point at something real |
| Normalisation | Don't store the same fact twice |
| Denormalisation | Deliberately storing it twice, for a reason |

---

## Still stuck on a word?

If a term isn't here, ask me — and tell me which one, so I can add it. A glossary that's
missing the word you needed isn't finished.
