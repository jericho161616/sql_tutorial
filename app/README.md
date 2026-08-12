# The SQL Study Console

A single-file web app covering **weeks 1–7** of the course, with real PostgreSQL running
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

- Twenty-one exercises across weeks 1–7, each with the real question and expected row count
- **Answer checking** by running the reference solution against your result and comparing —
  it tells you *how* you're wrong (row count, column count, wrong order, wrong values), not
  just that you are
- **Progressive hints**, three per exercise, revealed one at a time
- **The solution stays locked until you've run a query** — even a wrong one
- **A scratchpad** for free-form SQL against the same database
- Progress, drafts and revealed hints saved in `localStorage`, surviving reloads

## What it doesn't do

Weeks 8–12 are complete in the repo as markdown but aren't in the app yet. Work those in the
[Supabase SQL editor](https://supabase.com/dashboard/project/qfbublnaognbrxdqqsor/sql)
alongside the week folders.

Weeks 9–12 write data — `CREATE TABLE`, `INSERT`, `UPDATE`, indexes, views. Those work fine
against Supabase, and would work here too, but the app's answer-checking is built around
`SELECT` results, so it isn't the right tool for them yet.

## A note on the first load

PGlite is about 13 MB of WebAssembly. The first visit downloads it; after that the browser
caches it and startup is roughly a second. If it stalls on "Starting PostgreSQL", the usual
causes are a private-browsing window (which often blocks IndexedDB) or a network that blocks
`cdn.jsdelivr.net`.
