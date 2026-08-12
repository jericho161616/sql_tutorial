# Week 8 — Types, dates & cleaning

**Time:** ~2.5 hours
**You'll learn:** casting, date arithmetic, `COALESCE`/`NULLIF`, string functions, regex basics

Every week so far used clean data. This week you meet `raw_signups` — 40 rows of the kind of
filth that actually arrives from a CSV export, a third-party form, or a system somebody built
in a hurry in 2019. Cleaning data is most of a data engineer's job, and it is almost never
taught.

```sql
SET search_path TO shop, public;
```

---

## Part 1 — Concepts (~30 min)

### Types, and why `text` everywhere is a problem

Look at the staging table:

```sql
SELECT * FROM raw_signups LIMIT 5;
```

Every column is `text` — including dates and money. That's normal for a staging table: a raw
load's job is to *accept whatever it's given* and let you sort it out afterwards. Refusing
bad rows at load time means losing them entirely.

But `text` means nothing is guaranteed. `'49.00'`, `'$49.00'`, `'1,299.00'` and `'NULL'` are
all perfectly valid text and none of them is a number.

### Casting

```sql
SELECT '49.00'::numeric;              -- 49.00
SELECT '2024-01-14'::date;            -- 2024-01-14
SELECT CAST('49.00' AS numeric);      -- same thing, standard SQL syntax
```

`::` is Postgres shorthand. `CAST(... AS ...)` is portable. Use `::` here; recognise both.

**A failed cast is an error, not a `NULL`:**

```sql
SELECT '$49.00'::numeric;
-- ERROR: invalid input syntax for type numeric: "$49.00"
```

One bad row aborts the whole statement. That's why you clean *before* you cast.

Postgres 17 offers a safe alternative:

```sql
SELECT '$49.00'::numeric DEFAULT NULL ON CONVERSION ERROR;   -- NULL, no error
```

Useful, but availability varies by version — the portable habit is to validate with a regex
first, then cast only what passes.

### Dates

```sql
SELECT CURRENT_DATE;                            -- today
SELECT order_date + 30 FROM orders LIMIT 1;     -- 30 days later
SELECT AGE(CURRENT_DATE, '2024-01-14'::date);   -- an interval: "1 year 6 mons 28 days"
SELECT date_trunc('month', order_date)::date;   -- first day of that month
SELECT EXTRACT(YEAR FROM order_date);           -- 2024
SELECT EXTRACT(DOW FROM order_date);            -- day of week, 0 = Sunday
```

**Date arithmetic is real arithmetic.** `order_date + 30` is 30 days later, handling month
lengths and leap years for you. This is a genuine advantage of storing a `date` rather than a
string — `'2024-01-14' + 30` on text is an error, not a date.

**Parsing non-standard formats** with `to_date`:

```sql
SELECT to_date('05/04/2024', 'DD/MM/YYYY');     -- 2024-04-05
SELECT to_date('April 19 2024', 'Month DD YYYY'); -- 2024-04-19
SELECT to_date('26-04-2024', 'DD-MM-YYYY');     -- 2024-04-26
```

**The ambiguity that has caused real financial losses:** `05/04/2024` is 5 April in most of
the world and 4 May in the United States. Nothing in the data tells you which. You must find
out from whoever produced the file — and if you can't, you must say so in your write-up
rather than picking one silently.

### NULL handling

```sql
COALESCE(country, 'Unknown')     -- first non-NULL argument
NULLIF(monthly_spend, '')        -- NULL if the two are equal, else the first
NULLIF(denominator, 0)           -- the division-by-zero guard from week 7
```

`NULLIF(x, '')` is the standard way to convert empty strings into proper `NULL`s — and it
matters, because `''` and `NULL` look identical in most result grids while behaving
completely differently.

### String functions

```sql
lower('PRO')                       -- 'pro'
upper('pro')                       -- 'PRO'
btrim('  pro  ')                   -- 'pro'  (trims both ends)
btrim('xxproxx', 'x')              -- 'pro'  (trims any of those characters)
length('pro')                      -- 3
replace('1,299.00', ',', '')       -- '1299.00'
split_part('a@b.com', '@', 2)      -- 'b.com'
substring('hello' FROM 2 FOR 3)    -- 'ell'
'a' || 'b'                         -- 'ab'   (concatenation)
initcap('meera kapoor')            -- 'Meera Kapoor'
```

`lower(btrim(x))` is the workhorse of deduplication. It turns `'MEERA.KAPOOR@example.com'`,
`' meera.kapoor@example.com '` and `'meera.kapoor@example.com'` into one identical value.

### Regex basics

```sql
email ~ '^[^@]+@[^@]+\.[^@]+$'     -- matches (case-sensitive)
email !~ '^[^@]+@'                 -- does not match
regexp_replace('$1,299.00', '[^0-9.]', '', 'g')   -- '1299.00' — strip all non-numeric
```

The `'g'` flag means *global* — replace every occurrence, not just the first. Forget it and
`'1,299,000'` becomes `'1299,000'`.

That `regexp_replace` is the money-cleaning idiom: strip everything that isn't a digit or a
dot, then cast.

**A warning about validating emails with regex:** the pattern above catches obvious rubbish
like `'not-an-email'`, and that is all it should be asked to do. Fully validating an email
address by regex is famously impossible, and the only real test is sending one. Use regex to
catch the obviously broken, not to certify the rest as good.

### Profile before you change anything

**The rule of data cleaning: never write an `UPDATE` before you have counted what you're
about to change.**

```sql
-- What am I about to do?
SELECT count(*) FROM raw_signups WHERE monthly_spend !~ '^-?\d+(\.\d+)?$';

-- What do those values actually look like?
SELECT DISTINCT monthly_spend FROM raw_signups WHERE monthly_spend !~ '^-?\d+(\.\d+)?$';
```

Then clean. Then verify the count changed by exactly the amount you expected.

Cleaning without profiling is how somebody normalises 40 rows and destroys 4 they didn't know
were different.

### Clean into a view, never over the original

```sql
CREATE VIEW clean_signups AS SELECT ... FROM raw_signups WHERE ...;
```

A **view** is a saved query, not a copy of the data. It runs fresh every time you select from
it, so the raw table stays untouched and auditable.

That matters more than it sounds. If you `UPDATE` the raw table and your cleaning rule turns
out to be wrong, the original values are gone — you cannot re-derive them, and you cannot
prove to anyone what was there before. Keeping the raw data immutable and expressing cleaning
as a *transformation* is the foundation of every serious data pipeline.

---

## Part 2 — Worked example (~20 min)

**The task:** *Make the `country` column usable.*

### Step 1: Look before touching

```sql
SELECT country, count(*) AS rows
FROM   raw_signups
GROUP  BY country
ORDER  BY count(*) DESC, country;
```

**34 distinct spellings across 40 rows.** Among them:

```
'USA'  'U.S.A.'  'united states'  '  United States '  'United States'
'UK'   'U.K.'    'britain'        'United Kingdom'
'India'  'india'
'N/A'  'unknown'  'Nowhere'  'Testland'  NULL
```

Five ways of writing the United States. Four for the UK. Any `GROUP BY country` treats all of
them as different countries, so a "sales by country" report would split one market into five
rows and none of them would look important.

### Step 2: Classify the problems

They are not all the same kind of problem, and they need different fixes:

| Problem | Example | Fix |
|---|---|---|
| Whitespace | `'  United States '` | `btrim` |
| Case | `'india'` | `lower` then `initcap` |
| Genuine synonyms | `'USA'`, `'U.S.A.'`, `'britain'` | a lookup mapping |
| Placeholders | `'N/A'`, `'unknown'` | convert to `NULL` |
| Junk | `'Testland'`, `'Nowhere'` | flag the row as non-genuine |

The first two are mechanical. The third needs a decision. The last two are not cleaning
problems at all — they're *detection* problems.

### Step 3: Mechanical fixes first

```sql
SELECT country,
       initcap(btrim(lower(country))) AS tidied
FROM   raw_signups
WHERE  country IS NOT NULL;
```

`'  United States '` and `'united states'` both become `'United States'`. Two of the five US
spellings are now merged, for free, with no decisions required.

### Step 4: Synonyms need a mapping

`'USA'` cannot be turned into `'United States'` by any string function — they share no
characters. This needs a lookup:

```sql
CASE lower(btrim(country))
     WHEN 'usa'    THEN 'United States'
     WHEN 'u.s.a.' THEN 'United States'
     WHEN 'uk'     THEN 'United Kingdom'
     WHEN 'u.k.'   THEN 'United Kingdom'
     WHEN 'britain' THEN 'United Kingdom'
     ELSE initcap(btrim(lower(country)))
END
```

In production this belongs in a **lookup table**, not a `CASE`. A `CASE` requires a code
change and a deployment every time a new spelling appears; a table row can be added by
whoever noticed the problem. Same logic, very different maintenance cost.

### Step 5: Placeholders are not countries

```sql
CASE WHEN lower(btrim(country)) IN ('n/a', 'unknown', 'none', '')
     THEN NULL
     ELSE ...
END
```

`'N/A'` means *we don't know* — which is precisely what `NULL` means. Leaving it as text is
worse than useless: it survives every `IS NULL` check you write, so your data-quality report
says the country is present when it isn't. **A placeholder string is a `NULL` in disguise, and
disguised `NULL`s are more dangerous than honest ones.**

### Step 6: Flag junk, don't silently delete it

`'Testland'` and `'Nowhere'` belong to rows named "Test Test" and "QA Automation". Those are
test accounts.

**Do not delete them in the cleaning step.** Add a flag:

```sql
CASE WHEN lower(email) LIKE '%test%'
       OR lower(email) LIKE 'qa+%'
       OR lower(btrim(country)) IN ('testland', 'nowhere')
     THEN true ELSE false
END AS looks_like_test
```

Deleting rows during cleaning destroys evidence. Flagging them lets a report exclude them
while leaving anyone able to ask "how many test accounts are in production?" — which is a
question somebody should eventually ask.

---

## Part 3 — Exercises (~60 min)

Attempt before opening [`solutions/week-08.sql`](../../solutions/week-08.sql).

### Exercise 8.1 — Profile before cleaning

Write a **single query** producing one row per data-quality problem with a count. Use the
`UNION ALL` pattern from week 5. Profile at least:

- rows with a `NULL` email
- rows whose email doesn't contain `@`
- rows with a blank (`''`) or `NULL` signup date
- rows whose `monthly_spend` won't cast to a number
- how many distinct `plan` spellings exist
- how many distinct `country` spellings exist
- how many email addresses are duplicated after `lower(btrim(...))`

*Expected among others: 40 rows total, 8 plan spellings for 3 real plans, 34 country
spellings, 36 distinct normalised emails.*

Write this **before** writing any cleaning SQL. That ordering is the exercise.

### Exercise 8.2 — Normalise the plan column

`plan` should have exactly three values: `basic`, `pro`, `enterprise`. It currently has eight
spellings.

Write a query showing the raw value, the cleaned value, and the row count for each raw value.
Then prove your cleaning worked by showing the cleaned column has exactly 3 distinct values.

*Expected: 8 raw spellings collapsing to 3.*

### Exercise 8.3 — Parse the dates

`signup_date_text` holds at least five different formats plus a blank and a `NULL`.

Write a query returning `row_id`, the raw text, and a parsed `date` — with `NULL` where it
cannot be parsed rather than an error. Use a `CASE` that tests the format with a regex before
choosing a `to_date` pattern.

Then flag two rows whose dates parse perfectly but are **not plausible**. State what makes
them implausible.

*Hint: one is in the distant past, one in the distant future. A date that parses is not the
same as a date that's true.*

---

## Part 4 — Mini-project (~30 min)

### Build a validated `clean_signups` view

Create a view that any colleague could safely use, leaving `raw_signups` untouched.

```sql
CREATE OR REPLACE VIEW clean_signups AS ...
```

It should expose:

- `row_id`
- `full_name` — trimmed, with internal double spaces collapsed
- `email` — lowercased and trimmed, `NULL` if malformed
- `country` — trimmed, synonyms merged, placeholders as `NULL`
- `signup_date` — a real `date`, `NULL` if unparseable
- `plan` — one of the three valid values, `NULL` otherwise
- `monthly_spend` — a real `numeric`, `NULL` if unparseable or negative
- `is_valid` — boolean: true only if email, date and plan are all present and sane
- `looks_like_test` — boolean flag, not a deletion

**Then write validation queries comparing raw against clean**, and answer in comments:

1. How many rows are `is_valid`?
2. How many distinct real people are in the file, after deduplicating on normalised email?
3. `raw_signups` has 40 rows and 39 non-null emails, but only 36 distinct normalised ones.
   Account for all three missing.
4. One row has `monthly_spend` of 9999999.00. Should the cleaning rule reject it? Argue both
   sides, then decide.

Question 4 has no right answer, which is the point. An outlier can be a data-entry error or
your most important customer, and the same value is either depending on context you don't
have. Say what you'd do and what you'd ask.

---

## Checklist

- [ ] You profile and count before writing any cleaning SQL
- [ ] You clean into a view and never overwrite the raw table
- [ ] You convert placeholder strings like `'N/A'` into real `NULL`s
- [ ] You flag suspicious rows rather than deleting them
- [ ] You validate with a regex before casting, rather than letting a cast throw
- [ ] You know `05/04/2024` is ambiguous and that you must ask rather than guess

**Tick week 8 in [`PLANNER.md`](../../PLANNER.md).**
