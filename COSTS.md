# What this costs

**Nothing. Permanently.**

You've asked a few times, so here is the full audit rather than a reassurance — every tool
this course touches, what licence it carries, and where the edge cases actually are.

---

## The complete list

| Thing | Cost | Licence / tier | Card needed? |
|---|---|---|---|
| **PostgreSQL** | Free | PostgreSQL Licence (open source) | No |
| **PGlite** — Postgres in the browser | Free | Apache 2.0 | No |
| **jsDelivr** — CDN serving PGlite | Free | Free public CDN | No |
| **GitHub** — the repo | Free | Free tier, public repos unlimited | No |
| **GitHub Pages** — hosting the app | Free | Free for public repos | No |
| **The course itself** | Free | Markdown and `.sql` files in your repo | No |
| **Docker** *(optional)* | Free | See the note below | No |
| **DBeaver Community** *(optional)* | Free | Apache 2.0 | No |
| **pgAdmin** *(optional)* | Free | PostgreSQL Licence | No |

**Nothing here has a trial that converts to paid, and no card is on file anywhere.**

---

## Verified, not assumed

Checked against the repo directly:

- **The app loads exactly one external file** — PGlite from jsDelivr. That's the entire
  runtime dependency list.
- **There is no `package.json`** in the repo, so there is no npm dependency tree to audit
  and nothing that can pull in a licensed package later.
- **External domains referenced anywhere in the docs:** your own GitHub Pages, `github.com`,
  `dbeaver.io`, `pglite.dev`, `cdn.jsdelivr.net`. That's all of them.

---

## The honest edge cases

Three places where "free" needs a footnote. None affects you, but you should know them rather
than find out later.

### Docker Desktop

**Free for personal use, education, and small businesses.** Docker requires a paid
subscription only for companies with **more than 250 employees or $10M+ annual revenue**.

If that ever mattered, the alternatives are free with no conditions at all:
- **Docker Engine** on Linux — fully open source, no licence tier
- **Podman** — drop-in replacement, no licensing restrictions
- Or skip containers entirely and install PostgreSQL natively

### DBeaver

**DBeaver Community Edition is free and open source.** There is a paid *DBeaver PRO* — you
don't need it, and the Community edition does everything this course requires. Just make sure
you download Community.

### GitHub Pages limits

Free tier: **1 GB site size, 100 GB bandwidth per month, 10 builds per hour.**

Your app is about **180 KB**. You would need roughly half a million visits a month to approach
the bandwidth limit. This will never cost you anything.

---

## What if jsDelivr disappeared?

It's a free public CDN with no account behind it, so there's no bill — but it *is* a third
party, and third parties change.

Two mitigations, both already in place:

1. **Your browser caches PGlite after the first load**, so the app keeps working offline
   regardless.
2. **[LOCAL-SETUP.md](LOCAL-SETUP.md) has instructions to bundle PGlite locally** — one `npm
   install` and a one-line change, and the app has zero external dependencies.

---

## What changed when the subscription ended

Only one thing: **you no longer have an AI tutor on tap.**

Nothing else was ever paid for. Supabase was on the free tier from the first minute — I
checked the cost was $0/month before creating the project, and confirmed it again before
recommending it. It's going away because you don't need it, not because it was costing you.

The course was written to survive exactly this. The explanations live in `solutions/`,
`ERRORS.md`, `GLOSSARY.md`, `SCHEMA-MAP.md` and the app's Learn tab — in the repo, not in a
chat log. The ten templates in `prompts/` work with any AI, including free tiers and local
models.

---

## The one thing that could cost you money

**Nothing in this repo.** But for completeness, since you're learning skills you'll use
elsewhere:

If you later point these techniques at a **cloud database you pay for** — BigQuery, RDS,
Snowflake — then queries cost money, and a careless `SELECT *` over a large table can cost
real amounts. That's not this course; it's worth knowing before your first job.

The habits this course drills — `LIMIT` while exploring, filtering early, checking row counts,
reading `EXPLAIN` before running something expensive — are the same habits that keep those
bills small.
