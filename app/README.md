# The SQL Study Console

A single-file web app covering **all 12 weeks** of the course, plus six incident challenges, with real PostgreSQL running
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

- **72 exercises** — six per week across all 12 weeks, each with the real question and expected row count
- **6 incidents** — case-based challenges written as support tickets, where you diagnose a real bug this database can produce
- **Answer checking** by running the reference solution against your result and comparing —
  it tells you *how* you're wrong (row count, column count, wrong order, wrong values), not
  just that you are
- **Progressive hints**, revealed one at a time — light at first, nearly the answer by the last
- **The solution stays locked until you've run a query** — even a wrong one
- **A scratchpad** for free-form SQL against the same database
- Progress, drafts and revealed hints saved in `localStorage`, surviving reloads

## Incidents

Six case-based challenges, separate from the weeks. Each opens as a ticket from a colleague or
client — *"revenue is overstated by 18%"*, *"your app gets slower as we grow"* — and you work
out what is wrong.

Every one is a genuine bug this database produces, drawn from the traps deliberately seeded
into it. Some are answered by picking the right diagnosis from four options, where every
option explains itself, including the wrong ones. Others require writing the query that proves
the cause. All end in a debrief describing what to carry forward.

The week 12 capstone stays in the repo rather than the app — its value is the written
analysis, which is not something a checker should grade.

## Three kinds of checking

Weeks 1–8 are read-only. Your result is compared against the reference solution's result, and
mismatches are reported by kind — wrong row count, wrong column count, right rows in the wrong
order, or wrong values.

Weeks 9–12 **write** to the database, so there is no result to compare. Instead the app runs a
check query against the database *afterwards* and grades the outcome — inspecting
`information_schema` to confirm your `CREATE TABLE` carries the constraints asked for,
checking `pg_indexes` for an index you created, or counting rows to confirm an `UPDATE` did
what it should. Extra columns and different names are fine; only the stated requirements are
checked.

Some questions have no query to grade at all — reading an `EXPLAIN` plan, or judging what a
stale materialised view shows a user. Those are multiple choice, and each option carries its
own explanation, so a wrong pick teaches as much as a right one.

Those exercises are marked with a warning, and the check query's output is shown so you can
see exactly what was measured. All of them are safe to re-run.

## A note on the first load

PGlite is about 13 MB of WebAssembly. The first visit downloads it; after that the browser
caches it and startup is roughly a second. If it stalls on "Starting PostgreSQL", the usual
causes are a private-browsing window (which often blocks IndexedDB) or a network that blocks
`cdn.jsdelivr.net`.
