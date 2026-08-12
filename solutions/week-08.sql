-- =============================================================
--  SOLUTIONS - Week 8: Types, dates & cleaning
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 8.1 - Profile BEFORE cleaning
-- -------------------------------------------------------------
SELECT 'total rows'                        AS problem, count(*)::text AS value FROM raw_signups
UNION ALL
SELECT 'email is NULL',            count(*) FILTER (WHERE email IS NULL)::text FROM raw_signups
UNION ALL
SELECT 'email has no @',           count(*) FILTER (WHERE email IS NOT NULL
                                                      AND email NOT LIKE '%@%')::text FROM raw_signups
UNION ALL
SELECT 'signup date blank or NULL',count(*) FILTER (WHERE signup_date_text IS NULL
                                                      OR btrim(signup_date_text) = '')::text FROM raw_signups
UNION ALL
SELECT 'spend will not cast',      count(*) FILTER (WHERE monthly_spend IS NULL
                                                      OR monthly_spend !~ '^-?\d+(\.\d+)?$')::text FROM raw_signups
UNION ALL
SELECT 'distinct plan spellings',  count(DISTINCT plan)::text FROM raw_signups
UNION ALL
SELECT 'distinct country spellings', count(DISTINCT country)::text FROM raw_signups
UNION ALL
SELECT 'distinct normalised emails', count(DISTINCT lower(btrim(email)))::text FROM raw_signups
UNION ALL
SELECT 'emails duplicated after normalising',
       (SELECT count(*)::text FROM (SELECT lower(btrim(email))
                                    FROM   raw_signups WHERE email IS NOT NULL
                                    GROUP  BY 1 HAVING count(*) > 1) d);

--  total rows                            40
--  email is NULL                          1
--  email has no @                         1
--  signup date blank or NULL              2
--  spend will not cast                    4
--  distinct plan spellings                8    <- for 3 real plans
--  distinct country spellings            34    <- for ~28 real countries
--  distinct normalised emails            36
--  emails duplicated after normalising    2    <- two groups, not two rows
--
--  WHY THIS QUERY COMES FIRST:
--
--  These nine numbers are your baseline. After cleaning you re-run
--  them and every change must be one you intended. Without a
--  baseline, "the data looks better now" is a feeling, not a result.
--
--  Note how much the profile already tells you before a single value
--  has been altered: 8 spellings for 3 plans means every GROUP BY
--  plan in the last year was wrong. 34 spellings for 28 countries
--  means the same for every regional report. Those are findings, and
--  they are worth reporting to whoever has been relying on those
--  reports - separately from, and before, fixing them.

-- Always look at the actual bad values, not just the count:
SELECT DISTINCT monthly_spend
FROM   raw_signups
WHERE  monthly_spend IS NULL OR monthly_spend !~ '^-?\d+(\.\d+)?$';
--  ''          <- empty string
--  'NULL'      <- the WORD null, as text. Worst of the four.
--  '$49.00'    <- currency symbol
--  '1,299.00'  <- thousands separator
--
--  Each needs a different fix, and you cannot know that from the
--  count alone. The literal string 'NULL' is the nastiest: it is
--  four characters of text that every IS NULL check will report as
--  present data.


-- -------------------------------------------------------------
-- Exercise 8.2 - Normalise the plan column
-- Expected: 8 raw spellings -> 3 clean values
-- -------------------------------------------------------------
SELECT   plan                    AS raw_plan,
         lower(btrim(plan))      AS clean_plan,
         count(*)                AS rows
FROM     raw_signups
GROUP BY plan, lower(btrim(plan))
ORDER BY clean_plan, raw_plan;

--  ' pro '        -> pro
--  'PRO'          -> pro
--  'Pro'          -> pro
--  'pro'          -> pro
--  'Basic'        -> basic
--  'basic'        -> basic
--  'ENTERPRISE'   -> enterprise
--  'enterprise'   -> enterprise

-- Prove it worked:
SELECT count(DISTINCT plan)               AS raw_spellings,
       count(DISTINCT lower(btrim(plan))) AS clean_values
FROM   raw_signups;
--  raw_spellings 8, clean_values 3
--
--  lower() fixes case. btrim() fixes the padding on ' pro '. Neither
--  alone is enough - ' pro ' lowercased is still ' pro ', which is a
--  different string from 'pro' and forms its own group.
--
--  Combining them is the standard idiom, and the order does not
--  matter here. Get into the habit of applying both together
--  whenever you deduplicate on a text column.

-- A stricter version that refuses to silently accept a new value:
SELECT plan,
       CASE lower(btrim(plan))
            WHEN 'basic'      THEN 'basic'
            WHEN 'pro'        THEN 'pro'
            WHEN 'enterprise' THEN 'enterprise'
            ELSE NULL                       -- unrecognised -> NULL, visibly
       END AS validated_plan
FROM   raw_signups;
--
--  lower(btrim(x)) accepts ANYTHING. If tomorrow's file contains
--  'Premium', it passes straight through as a fourth plan and your
--  report grows a row nobody authorised.
--
--  The CASE version turns an unexpected value into NULL, which your
--  is_valid flag then catches. Cleaning should normalise what you
--  recognise and REFUSE what you do not - silently accepting the
--  unknown is how bad data spreads downstream.


-- -------------------------------------------------------------
-- Exercise 8.3 - Parse the multi-format dates
-- -------------------------------------------------------------
SELECT row_id,
       signup_date_text AS raw_date,
       CASE
           WHEN signup_date_text IS NULL
             OR btrim(signup_date_text) = ''            THEN NULL
           WHEN signup_date_text ~ '^\d{4}-\d{1,2}-\d{1,2}$'
                THEN to_date(signup_date_text, 'YYYY-MM-DD')
           WHEN signup_date_text ~ '^\d{4}/\d{1,2}/\d{1,2}$'
                THEN to_date(signup_date_text, 'YYYY/MM/DD')
           WHEN signup_date_text ~ '^\d{1,2}/\d{1,2}/\d{4}$'
                THEN to_date(signup_date_text, 'DD/MM/YYYY')   -- ASSUMPTION, see below
           WHEN signup_date_text ~ '^\d{1,2}-\d{1,2}-\d{4}$'
                THEN to_date(signup_date_text, 'DD-MM-YYYY')
           WHEN signup_date_text ~ '^[A-Za-z]+ \d{1,2} \d{4}$'
                THEN to_date(signup_date_text, 'Month DD YYYY')
           ELSE NULL
       END AS parsed_date
FROM   raw_signups
ORDER  BY row_id;

--  Two rows parse to NULL: row 16 (the date is NULL) and row 17
--  (the date is an empty string). Everything else parses.
--
--  THE STRUCTURE MATTERS: each branch tests the format with a regex
--  BEFORE calling to_date. Call to_date on the wrong format and it
--  throws, aborting the entire statement over one bad row. Test
--  first, convert second - the same discipline as validating before
--  casting a number.

-- THE AMBIGUITY YOU MUST NOT RESOLVE SILENTLY:
--
--  Row 11 is '05/04/2024'. I parsed it as DD/MM/YYYY, giving
--  5 April 2024. Read as MM/DD/YYYY it is 4 May 2024 - a month
--  apart, and both are entirely plausible.
--
--  NOTHING IN THE DATA CAN SETTLE THIS. Not the other rows, not the
--  row order, not the neighbouring values. The only sources of truth
--  are the system that produced the file or the person who built it.
--
--  So the correct action is not to pick the more likely option. It is
--  to pick one, WRITE DOWN THAT YOU PICKED IT, and ask. A comment in
--  the code and a line in your write-up - "dates in DD/MM/YYYY
--  assumed European format, unconfirmed" - is the difference between
--  a documented assumption and a silent error.
--
--  Date-format ambiguity has caused real financial losses. It is
--  worth being annoying about.

-- TWO ROWS THAT PARSE PERFECTLY AND ARE STILL WRONG:
SELECT row_id, full_name, email, signup_date_text
FROM   raw_signups
WHERE  signup_date_text IN ('1900-01-01', '2099-12-31');
--
--  Row 36 - 'QA Automation', 1900-01-01. A valid date. Nimbus did
--  not exist in 1900. This is a sentinel: some system needed a date,
--  had none, and wrote the minimum value it could rather than NULL.
--
--  Row 38 - 'Future Person', 2099-12-31. Also a valid date, also
--  impossible - you cannot sign up 74 years from now. Another
--  sentinel, at the other end of the range.
--
--  NEITHER IS A PARSING PROBLEM. Both cast cleanly to `date` and
--  would sail through every type check you could write. They are
--  PLAUSIBILITY problems, and only a range check catches them:
--
--      WHERE signup_date BETWEEN '2020-01-01' AND CURRENT_DATE
--
--  This is a distinction worth holding on to: type-valid and
--  true are different properties. A column typed as `date` guarantees
--  the first and says nothing whatever about the second.


-- =============================================================
--  Mini-project - the clean_signups view
-- =============================================================

CREATE OR REPLACE VIEW clean_signups AS
WITH parsed AS (
    SELECT
        row_id,

        -- collapse internal runs of whitespace, then trim the ends
        btrim(regexp_replace(full_name, '\s+', ' ', 'g'))            AS full_name,

        -- lowercase + trim, then NULL anything that is not email-shaped
        CASE WHEN lower(btrim(email)) ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
             THEN lower(btrim(email))
             ELSE NULL
        END                                                           AS email,

        -- placeholders become NULL; synonyms merge; the rest is tidied
        CASE
            WHEN country IS NULL                                   THEN NULL
            WHEN lower(btrim(country)) IN ('n/a','unknown','none','') THEN NULL
            WHEN lower(btrim(country)) IN ('usa','u.s.a.','united states')
                                                                   THEN 'United States'
            WHEN lower(btrim(country)) IN ('uk','u.k.','britain','united kingdom')
                                                                   THEN 'United Kingdom'
            ELSE initcap(btrim(lower(country)))
        END                                                           AS country,

        CASE
            WHEN signup_date_text IS NULL
              OR btrim(signup_date_text) = ''                       THEN NULL
            WHEN signup_date_text ~ '^\d{4}-\d{1,2}-\d{1,2}$'
                 THEN to_date(signup_date_text, 'YYYY-MM-DD')
            WHEN signup_date_text ~ '^\d{4}/\d{1,2}/\d{1,2}$'
                 THEN to_date(signup_date_text, 'YYYY/MM/DD')
            WHEN signup_date_text ~ '^\d{1,2}/\d{1,2}/\d{4}$'
                 THEN to_date(signup_date_text, 'DD/MM/YYYY')  -- assumed European
            WHEN signup_date_text ~ '^\d{1,2}-\d{1,2}-\d{4}$'
                 THEN to_date(signup_date_text, 'DD-MM-YYYY')
            WHEN signup_date_text ~ '^[A-Za-z]+ \d{1,2} \d{4}$'
                 THEN to_date(signup_date_text, 'Month DD YYYY')
            ELSE NULL
        END                                                           AS signup_date,

        CASE lower(btrim(plan))
             WHEN 'basic'      THEN 'basic'
             WHEN 'pro'        THEN 'pro'
             WHEN 'enterprise' THEN 'enterprise'
             ELSE NULL
        END                                                           AS plan,

        -- strip currency symbols and separators, then cast what remains
        CASE
            WHEN monthly_spend IS NULL                             THEN NULL
            WHEN btrim(monthly_spend) IN ('', 'NULL', 'null')       THEN NULL
            WHEN regexp_replace(monthly_spend, '[^0-9.\-]', '', 'g') ~ '^-?\d+(\.\d+)?$'
                 THEN regexp_replace(monthly_spend, '[^0-9.\-]', '', 'g')::numeric
            ELSE NULL
        END                                                           AS monthly_spend,

        CASE WHEN lower(COALESCE(email, ''))   LIKE '%test%'
               OR lower(COALESCE(email, ''))   LIKE 'qa+%'
               OR lower(COALESCE(full_name,'')) IN ('test test','qa automation')
               OR lower(btrim(COALESCE(country,''))) IN ('testland','nowhere')
             THEN true ELSE false
        END                                                           AS looks_like_test
    FROM raw_signups
)
SELECT p.*,
       (p.email       IS NOT NULL
        AND p.signup_date IS NOT NULL
        AND p.plan    IS NOT NULL
        AND p.signup_date BETWEEN DATE '2020-01-01' AND CURRENT_DATE
        AND (p.monthly_spend IS NULL OR p.monthly_spend >= 0)
       ) AS is_valid
FROM parsed p;

--  Note monthly_spend is NOT forced to NULL when negative. The
--  negative value is preserved and the ROW is marked invalid
--  instead. Erasing the -19.00 would destroy the evidence that
--  something upstream can produce negative subscription prices,
--  which is a bug somebody needs to fix at the source.


-- -------------------------------------------------------------
-- Validation: compare raw against clean
-- -------------------------------------------------------------
SELECT 'raw rows'                AS metric, count(*)::text AS value FROM raw_signups
UNION ALL SELECT 'clean rows',            count(*)::text FROM clean_signups
UNION ALL SELECT 'valid rows',            count(*) FILTER (WHERE is_valid)::text FROM clean_signups
UNION ALL SELECT 'flagged as test',       count(*) FILTER (WHERE looks_like_test)::text FROM clean_signups
UNION ALL SELECT 'distinct plans',        count(DISTINCT plan)::text FROM clean_signups
UNION ALL SELECT 'distinct countries',    count(DISTINCT country)::text FROM clean_signups
UNION ALL SELECT 'distinct people',       count(DISTINCT email)::text FROM clean_signups;

--  THE ROW COUNTS MUST MATCH: raw 40, clean 40. The view transforms
--  values, it never drops rows. Anything that should not be counted
--  is excluded by a FLAG, so the exclusion is visible and reversible.
--  A cleaning step that silently returns fewer rows than it received
--  is deleting data, whatever it is called.


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. How many rows are is_valid?
--
--    36 of 40 fail nothing; 4 fail.
--
--    The four: row 16 (signup date NULL), row 17 (signup date is an
--    empty string), row 39 (email 'not-an-email' fails the shape
--    test), row 40 (email is NULL).
--
--    Rows 35, 36, 37 and 38 - the negative spend, the 1900 date, the
--    9999999.00 spend and the 2099 date - are ALSO caught by the
--    is_valid rules above, so the strict count is lower still. Which
--    figure you quote depends entirely on how strict is_valid is,
--    and that is a decision to state rather than to leave implied.

-- 2. How many distinct real people?
SELECT count(DISTINCT email) AS distinct_people
FROM   clean_signups
WHERE  email IS NOT NULL AND NOT looks_like_test;
--
--    35 distinct valid emails, minus the test accounts. Deduplicating
--    on the normalised email is what makes Meera Kapoor one person
--    instead of three.

-- 3. Account for 40 rows -> 39 non-null emails -> 36 distinct.
--
--    40 - 39 = 1   row 40 has no email at all.
--
--    39 - 36 = 3   three rows are duplicates of another row:
--                    Meera Kapoor appears 3 times (rows 21, 22, 23)
--                      as 'meera.kapoor@example.com',
--                         'MEERA.KAPOOR@example.com' and
--                         ' meera.kapoor@example.com ' -> 2 extras
--                    Carlos Mendoza appears twice (rows 24, 25),
--                      byte-identical -> 1 extra
--
--    2 + 1 = 3. Every row is accounted for.
--
--    Note the two duplicate types need different detection. Carlos is
--    an exact duplicate - any tool would spot it. Meera's three rows
--    are byte-different and only collapse after lower(btrim()). The
--    second kind is far more common and far more often missed, and it
--    is why raw duplicate counts understate the problem.

-- 4. Should the 9999999.00 spend be rejected?
--
--    ARGUMENT FOR REJECTING: it is ten thousand times the enterprise
--    plan price of 299.00. No plan costs that. It has the shape of a
--    sentinel or a fat-fingered entry, and left in place it will
--    dominate every average, total and chart it appears in - one row
--    would outweigh the other 39 combined.
--
--    ARGUMENT FOR KEEPING: the account is named 'Big Spender Corp'
--    with the email ap@bigspender.example.com - 'ap' as in accounts
--    payable. That is what a genuine large enterprise contract looks
--    like, negotiated outside the standard price list. Deleting your
--    largest customer because their number is unusual is a far worse
--    error than including a suspicious one.
--
--    MY DECISION: keep the value, flag the row, exclude it from
--    averages by default, and ask. Concretely - add an
--    `is_outlier_spend` boolean for anything above, say, 10x the
--    highest list price, and let each report decide whether to
--    include it.
--
--    The reasoning: rejecting is irreversible and silent, flagging is
--    reversible and visible. When you genuinely cannot tell whether a
--    value is wrong, choose the option that preserves the information
--    and makes the uncertainty someone else can see.
--
--    And then ask. "Is Big Spender Corp real, and is 9,999,999 their
--    actual monthly spend?" is a thirty-second question for whoever
--    owns the billing system, and no amount of SQL can answer it.
--    Knowing which questions the data cannot answer is as much a part
--    of this job as writing the queries.
