# Running everything locally, forever, for free

This course was built to outlive any subscription. Nothing in it depends on a paid service,
and this page is how you cut the last ties.

---

## First: you are not losing anything

**Your database is code, not data.**

There is nothing to export from Supabase. The three files in [`db/`](db/) rebuild it exactly:

```
db/01_schema.sql      the tables, keys and constraints
db/02_seed.sql        the data
db/03_messy_data.sql  the deliberately filthy staging table
```

The seed is generated with **arithmetic, not random numbers**, which is why the same script
always produces the same 40 customers, 120 orders, 300 line items and 128 payments — on any
PostgreSQL, on any machine, in any year.

That was a deliberate choice made on day one, precisely so every answer in `solutions/` stays
correct no matter where you run it.

| What | Where it lives | Survives? |
|---|---|---|
| The database | `db/*.sql` in git | ✅ Yes |
| The course | Markdown in git | ✅ Yes |
| The app | One HTML file in git | ✅ Yes |
| Your answers | `my-answers/*.sql` in git | ✅ Yes |
| **App progress** | **Your browser's storage** | ⚠️ **Export it — see below** |
| Supabase project | Their servers | ❌ Goes away — and doesn't matter |

---

## Step 1 — Export your app progress (2 minutes)

This is the only thing genuinely at risk, because it lives in your browser rather than in git.

1. Open the app
2. Click **Export progress** in the top bar
3. A file downloads: `sql-progress-YYYY-MM-DD.json`
4. **Commit it to the repo** so it is backed up like everything else:

```bash
mkdir -p progress
mv ~/Downloads/sql-progress-*.json progress/
git add progress/ && git commit -m "Back up study progress" && git push
```

To restore it later — new laptop, cleared browser, different machine — click **Import** and
choose the file. It *merges*, so importing never wipes work you've done since.

---

## Step 2 — How you run SQL

> ### ✅ Decided: Option A — the app
>
> This is the chosen path. For weeks 1–8 the app is not merely easier than a local
> PostgreSQL, it is **better**: those weeks are pure `SELECT`, and the app adds grading,
> progressive hints and progress tracking that a bare `psql` prompt cannot.
>
> **Revisit this page at week 9.** That is where you start creating tables, managing indexes
> and granting roles — and where a real server starts teaching you things the browser cannot:
> `pg_dump` backups, roles that actually log in, connection strings, config files. When you
> get there, use **Option B (Docker)**.
>
> Nothing below needs doing today.

All three options cost nothing. **You may well not need Postgres at all.**

### Option A — Just use the app *(chosen — zero setup)*

The Study Console already runs **real PostgreSQL inside your browser** via PGlite (WebAssembly).
It has never talked to Supabase. It works offline. It is already everything you need for all 72
exercises and the 6 incidents.

Open it from GitHub Pages, or straight off your disk:

```bash
git clone https://github.com/jericho161616/sql_tutorial.git
cd sql_tutorial/app
python3 -m http.server 8000
# then open http://localhost:8000
```

**One caveat:** the app fetches PGlite from a CDN on first load. If you want it working with
no internet at all, see [Fully offline](#fully-offline) below.

### Option B — Real PostgreSQL via Docker *(for week 9 onward)*

Closest to a production environment, and nothing to uninstall afterwards.

```bash
# start a Postgres container
docker run --name nimbus-sql \
  -e POSTGRES_PASSWORD=practice \
  -e POSTGRES_DB=nimbus \
  -p 5432:5432 \
  -d postgres:17

# load the course database
cd sql_tutorial
docker cp db/01_schema.sql      nimbus-sql:/tmp/
docker cp db/02_seed.sql        nimbus-sql:/tmp/
docker cp db/03_messy_data.sql  nimbus-sql:/tmp/

docker exec -u postgres nimbus-sql psql -d nimbus -f /tmp/01_schema.sql
docker exec -u postgres nimbus-sql psql -d nimbus -f /tmp/02_seed.sql
docker exec -u postgres nimbus-sql psql -d nimbus -f /tmp/03_messy_data.sql

# open a SQL prompt
docker exec -it -u postgres nimbus-sql psql -d nimbus
```

Then at the `nimbus=#` prompt:

```sql
SET search_path TO shop, public;
SELECT count(*) FROM orders;     -- 120
```

Useful container commands:

```bash
docker stop nimbus-sql      # stop it (data is kept)
docker start nimbus-sql     # start it again
docker rm -f nimbus-sql     # delete it entirely
```

### Option C — PostgreSQL installed natively

```bash
# macOS
brew install postgresql@17 && brew services start postgresql@17
createdb nimbus

# Ubuntu / Debian
sudo apt install postgresql
sudo -u postgres createdb nimbus

# Windows — download the installer from postgresql.org, then use pgAdmin or psql
```

Load the course database:

```bash
cd sql_tutorial
psql -d nimbus -f db/01_schema.sql
psql -d nimbus -f db/02_seed.sql
psql -d nimbus -f db/03_messy_data.sql
psql -d nimbus
```

---

## Step 3 — Verify it loaded correctly

Run this against whichever option you chose. **Every number should match**, because the seed
is deterministic:

```sql
SET search_path TO shop, public;

SELECT 'customers'   AS t, count(*) FROM customers
UNION ALL SELECT 'products',    count(*) FROM products
UNION ALL SELECT 'orders',      count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'payments',    count(*) FROM payments
UNION ALL SELECT 'employees',   count(*) FROM employees
UNION ALL SELECT 'raw_signups', count(*) FROM raw_signups;
```

Expected:

| table | rows |
|---|---|
| customers | 40 |
| products | 25 |
| orders | 120 |
| order_items | 300 |
| payments | 128 |
| employees | 12 |
| raw_signups | 40 |

And the two checks that prove the teaching traps survived the move:

```sql
SELECT count(*) FROM customers WHERE country <> 'Nigeria';   -- 33, NOT 37
SELECT sum(shipping_fee) FROM orders;                        -- 976.50
```

If those two match, everything in `solutions/` is still correct for your copy.

---

## Step 4 — A free GUI, if you want one

The `psql` command line is genuinely fine, and it is what the job actually uses. But if you
prefer clicking:

- **[DBeaver Community](https://dbeaver.io)** — free, open source, works with every database
- **pgAdmin** — free, ships with most Postgres installs
- **VS Code** + the PostgreSQL extension — free

Connection details for Options B and C:

```
Host:     localhost
Port:     5432
Database: nimbus
User:     postgres
Password: practice      (Docker) — or blank/your OS user for a native install
```

---

## Step 5 — Close the Supabase project cleanly

Once you have verified a local copy works:

1. **Pause** it first rather than deleting — Supabase free projects pause automatically after
   inactivity anyway, and pausing is reversible.
2. When you are sure, delete it: Project Settings → General → **Delete project**.

**There is nothing to back up.** Anything you created inside it during weeks 9–12 —
`suppliers`, `returns`, `promotions`, the views — is reproducible from the exercises
themselves.

---

## Fully offline

The app pulls PGlite from a CDN on first load. Your browser caches it, so it keeps working
offline afterwards. To remove the dependency completely:

```bash
cd sql_tutorial/app
npm install @electric-sql/pglite@0.2.17
```

Then change one line near the top of the `<script type="module">` block in `app/index.html`:

```js
// from
import { PGlite } from 'https://cdn.jsdelivr.net/npm/@electric-sql/pglite@0.2.17/dist/index.js';
// to
import { PGlite } from './node_modules/@electric-sql/pglite/dist/index.js';
```

Serve it with `python3 -m http.server 8000` and it now works with no internet at all.

*(Don't commit `node_modules` — it is about 13 MB of WebAssembly.)*

---

## Studying without an AI tutor

Worth saying plainly, since this is the other thing that changes.

The course was written so the explanation lives **in the repo**, not in a chat log. That was
deliberate:

- **`solutions/`** explains *why*, not just what — several show the wrong version first,
  because the wrong version is usually more instructive
- **`ERRORS.md`** decodes the errors you will actually hit
- **`GLOSSARY.md`** defines every term in plain English
- **`SCHEMA-MAP.md`** answers "where do I even get this from?"
- **`CHEATSHEET.md`** is the syntax you need mid-query
- The app's **Learn** tab carries the same material beside your work

For the times you do want a second opinion, `prompts/` holds ten prompt templates with your
schema already filled in. They work with any AI — a free tier of anything, or a local model.
The prompts do the work, not the subscription.

**And the honest version:** you do not need a tutor to finish this. You need the exercises, the
solutions, and the willingness to be stuck for fifteen minutes before opening one. All three
are in this repo and none of them expire.
