# The SQL Study Console

A single-file web app covering **weeks 1–10** of the course, with real PostgreSQL running
inside your browser tab.

## How it works

`index.html` loads [PGlite](https://pglite.dev) — PostgreSQL compiled to WebAssembly — from a
CDN, then builds the Nimbus practice database in your browser's IndexedDB storage using the
same schema and seed script as [`db/`](../db).

That means:

- **Your queries really execute.** Errors are genuine PostgreSQL errors, not simulated ones.
- **Nothing leaves your machine.** The database is local to your browser. Your Supabase
  project is never contacted.
- **It works offline** after the first load.
- **Resetting is instant** — one button drops and rebuilds the schema.

The data is byte-identical to the Supabase copy, because the seed is generated with
arithmetic rather than random numbers. Every answer in [`solutions/`](../solutions) is correct
in both.

## Running it locally

It's one static file with no build step:

```bash
cd app
python3 -m http.server 8000
# open http://localhost:8000
```

## What it does

- Thirty exercises across weeks 1–10, each with the real question and expected row count
- **Answer checking** by running the reference solution against your result and comparing —
  it tells you *how* you're wrong (row count, column count, wrong order, wrong values), not
  just that you are
- **Progressive hints**, three per exercise, revealed one at a time
- **The solution stays locked until you've run a query** — even a wrong one
- **A scratchpad** for free-form SQL against the same database
- Progress, drafts and revealed hints saved in `localStorage`, surviving reloads

## What it doesn't do

Weeks 11–12 aren't in the app. Week 11 is about indexes and `EXPLAIN` — those change how
*fast* a query runs, never what it returns, so there is nothing for a result-checker to grade.
Week 12 ends in a capstone whose value is the written analysis. Both are better done in the
[Supabase SQL editor](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql)
alongside the week folders.

## Two kinds of checking

Weeks 1–8 are read-only. Your result is compared against the reference solution's result, and
mismatches are reported by kind — wrong row count, wrong column count, right rows in the wrong
order, or wrong values.

Weeks 9–10 **write** to the database, so there is no result to compare. Instead the app runs a
check query against the database *afterwards* and grades the outcome — inspecting
`information_schema` to confirm your `CREATE TABLE` actually carries the constraints asked
for, or counting rows to confirm an `UPDATE` did what it should. Extra columns and different
names are fine; only the stated requirements are checked.

Those exercises are marked with a warning, and the check query's output is shown so you can
see exactly what was measured. All of them are safe to re-run.

## A note on the first load

PGlite is about 13 MB of WebAssembly. The first visit downloads it; after that the browser
caches it and startup is roughly a second. If it stalls on "Starting PostgreSQL", the usual
causes are a private-browsing window (which often blocks IndexedDB) or a network that blocks
`cdn.jsdelivr.net`.
