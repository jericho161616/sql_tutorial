# The 12-Week Plan

**Target:** ~2.5 hours per week. **Total:** ~30 hours.

Tick the boxes as you go. Change `[ ]` to `[x]` and commit — this file is your progress
record, and seeing eight ticked weeks in a row is worth more motivation than any streak
counter.

Weeks are sized to be *finishable*. If a week takes you four hours instead of two and a
half, that is normal and fine. If you miss a week entirely, pick up where you left off —
this plan has no expiry date and nothing here is a deadline.

---

## How the weeks fit together

```
  FOUNDATION            Weeks 1-3    Get data out of one table
  ├─ 1  Reading data                 SELECT, WHERE, ORDER BY
  ├─ 2  Filtering properly           NULL logic, IN, BETWEEN, LIKE
  └─ 3  Aggregation                  GROUP BY, HAVING, COUNT/SUM/AVG

  COMBINING             Weeks 4-7    Get data out of several tables
  ├─ 4  Joins I                      INNER, LEFT, and what keys are for
  ├─ 5  Joins II                     Multi-table, self, anti-joins, fan-out
  ├─ 6  Subqueries & CTEs            Breaking hard queries into steps
  └─ 7  Window functions             Ranking and running totals

  REAL DATA             Week 8       Data that fights back
  └─ 8  Types & cleaning             Dates, casting, strings, the messy table

  BUILDING              Weeks 9-12   Your track: DBA / data engineering / app dev
  ├─ 9  Schema design & DDL          CREATE TABLE, constraints, normalisation
  ├─ 10 Writing data                 INSERT/UPDATE/DELETE, transactions, upsert
  ├─ 11 Indexes & performance        EXPLAIN, index types, why queries crawl
  └─ 12 Views, security & capstone   Views, roles, and the final project
```

Weeks 1–8 are the SQL everyone needs. Weeks 9–12 are where the course leans into your
actual goal — the parts a DBA or data engineer is paid for, which most beginner SQL
courses skip entirely.

---

## Progress

### Before you start

- [ ] **Week 0 — Start here** · [folder](weeks/week-00/) · *~45 min, assumes nothing*
  What a database, table, row and column are. Why data is split across tables. What keys are.
  Your first query.
  **Skip this only if you already know what a primary key is.**

### Foundation

- [ ] **Week 1 — Reading data** · [folder](weeks/week-01/)
  `SELECT`, `FROM`, `WHERE`, `ORDER BY`, `LIMIT`, column aliases, comments.
  *Mini-project: a product catalogue report.*

- [ ] **Week 2 — Filtering properly** · [folder](weeks/week-02/)
  `AND`/`OR`/`NOT`, operator precedence, `IN`, `BETWEEN`, `LIKE`, `IS NULL`, `DISTINCT`.
  **The week where `NULL` stops being intuitive and starts being understood.**
  *Mini-project: a data-quality audit of the customer table.*

- [ ] **Week 3 — Aggregation** · [folder](weeks/week-03/)
  `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `GROUP BY`, `HAVING`, and why `WHERE` and `HAVING`
  are not the same thing.
  *Mini-project: a monthly sales summary.*

### Combining tables

- [ ] **Week 4 — Joins I** · [folder](weeks/week-04/)
  Primary and foreign keys, `INNER JOIN`, `LEFT JOIN`, table aliases, join conditions.
  *Mini-project: an order detail report.*

- [ ] **Week 5 — Joins II** · [folder](weeks/week-05/)
  Three-table joins, self-joins, anti-joins, and **fan-out** — the bug where joining a
  one-to-many table silently doubles your revenue figures.
  *Mini-project: find every data gap in the order pipeline.*

- [ ] **Week 6 — Subqueries & CTEs** · [folder](weeks/week-06/)
  Scalar subqueries, `IN`/`EXISTS`, derived tables, and `WITH` clauses. How to solve a
  hard question by writing four easy queries instead of one impossible one.
  *Mini-project: rebuild week 5's mini-project readably.*

- [ ] **Week 7 — Window functions** · [folder](weeks/week-07/)
  `OVER`, `PARTITION BY`, `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, running totals.
  **The single biggest jump in what you can do.**
  *Mini-project: a month-over-month growth report.*

### Real data

- [ ] **Week 8 — Types, dates & cleaning** · [folder](weeks/week-08/)
  Casting, `date`/`timestamp` arithmetic, `COALESCE`, string functions, regex basics.
  Then: profile and clean the `raw_signups` table without destroying the original.
  *Mini-project: build a validated `clean_signups` view.*

### Building

- [ ] **Week 9 — Schema design & DDL** · [folder](weeks/week-09/)
  `CREATE TABLE`, data type choice, `NOT NULL`, `CHECK`, `UNIQUE`, primary and foreign
  keys, `ON DELETE` behaviour, and normalisation to 3NF.
  *Mini-project: design a returns/RMA subsystem from scratch.*

- [ ] **Week 10 — Writing data safely** · [folder](weeks/week-10/)
  `INSERT`, `UPDATE`, `DELETE`, `RETURNING`, transactions, `BEGIN`/`COMMIT`/`ROLLBACK`,
  ACID, and `INSERT ... ON CONFLICT` (upsert).
  **Includes the habit that prevents the career-defining mistake.**
  *Mini-project: a safe, transactional stock-adjustment procedure.*

- [ ] **Week 11 — Indexes & performance** · [folder](weeks/week-11/)
  `EXPLAIN` and `EXPLAIN ANALYZE`, seq scan vs index scan, B-tree indexes, composite
  indexes, and the costs an index imposes on writes.
  *Mini-project: index the foreign keys and measure the before/after.*

- [ ] **Week 12 — Views, security & capstone** · [folder](weeks/week-12/)
  Views, materialised views, roles and `GRANT`, plus a capstone that uses everything.
  *Capstone: an executive dashboard, built and defended.*

---

## Weekly rhythm

The plan assumes roughly 2.5 hours. Split however suits you — one sitting, or four
40-minute evenings. A suggested split:

| Session | Time | Do |
|---|---|---|
| 1 | 30 min | Read the concepts. Run every example as you read. Don't take notes; run queries. |
| 2 | 20 min | Work through the worked example. Change something and predict the result before running it. |
| 3 | 60 min | The three exercises. Stuck 15 minutes? Then open the solution. |
| 4 | 30 min | The mini-project. |

**Run every query you read.** Reading SQL and running SQL are different activities, and
only one of them teaches you anything. The database is free and unbreakable — there is no
reason not to.

---

## If you fall behind

Skip the mini-project, not the exercises. The exercises are where the learning is
concentrated; the mini-project is consolidation, and consolidation can wait.

Do not skip weeks 2, 5 or 9. Week 2 is `NULL`, week 5 is fan-out, week 9 is schema
design. Every one of those is a topic where the gap between "I sort of know this" and
"I actually know this" shows up in production, on a real system, at an inconvenient hour.

---

## A note on the pace

Twelve weeks is longer than the four-week plan in the guide that started this. That is
deliberate. Four weeks at under three hours a week is about ten hours total — enough for
`SELECT`, `WHERE` and a first `JOIN`, and not enough for anything else.

You said under three hours a week. This plan believes you, and stretches the calendar
instead of pretending the material is smaller than it is.
