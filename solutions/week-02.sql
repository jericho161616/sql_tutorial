-- =============================================================
--  SOLUTIONS - Week 2: Filtering properly
--
--  Attempt first. Exercise 2.3 in particular is worthless if you
--  read the answer - the entire point is getting 33 when you
--  expected 37 and having to work out where four people went.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 2.1 - Core European market customers
-- Expected: 7 rows
-- -------------------------------------------------------------
SELECT first_name,
       last_name,
       country,
       city
FROM   customers
WHERE  country IN ('Ireland', 'United Kingdom', 'Germany')
ORDER  BY country, last_name;

--  Germany         Leipzig      Jonas   Bergmann
--  Ireland         Cork         Daniel  Brennan
--  Ireland         Dublin       Sinead  Kavanagh
--  Ireland         Galway       Liam    O'Sullivan
--  United Kingdom  Manchester   Robert  Ashcroft
--  United Kingdom  Leeds        Harriet Lockwood
--  United Kingdom  Bristol      Oliver  Whitfield
--
--  Written out with OR this would be three repetitions of
--  `country = ...`. IN is the same logic, a third of the length,
--  and much easier to extend when a fourth market is added.


-- -------------------------------------------------------------
-- Exercise 2.2 - Mid-priced live products
-- Expected: 9 rows
-- -------------------------------------------------------------
SELECT product_name,
       category,
       unit_price
FROM   products
WHERE  unit_price BETWEEN 50 AND 150
  AND  NOT is_discontinued
ORDER  BY unit_price;

--  Rapid SSD 500GB           Storage       64.00
--  8-Port Gigabit Switch     Networking    79.50
--  Bluetooth Headset H5      Peripherals   89.00
--  Archive HDD 4TB           Storage       89.00
--  Rapid SSD 1TB             Storage      109.00
--  Mechanical Keyboard MK2   Peripherals  119.00
--  UPS 650VA                 Power        129.00
--  USB-C Dock 11-in-1        Peripherals  139.00
--  Nimbus Backup 1-Year      Software     149.00
--
--  Two products deserve a look for NOT being here:
--
--    Ergonomic Mouse E1, 49.00 - excluded, because BETWEEN 50 AND 150
--    means >= 50, and 49 is below it. One dollar outside the net.
--
--    Nimbus Router 500 (EOL), 99.00 - comfortably inside the price
--    range, excluded only by `AND NOT is_discontinued`. Drop that
--    condition and you get 10 rows instead of 9. The extra row is a
--    product you cannot sell. Same trap as week 1.
--
--  BETWEEN is inclusive at BOTH ends: a product priced at exactly
--  50.00 or exactly 150.00 would be included. Nothing in this data
--  sits precisely on either boundary, so use the 64.00 item as your
--  sanity check - it is comfortably inside, and if it is missing
--  from your output something else has gone wrong.
--
--  Note also that the two 89.00 products can come out in either
--  order. ORDER BY unit_price alone does not say which of two equal
--  prices comes first, so the database is free to choose. If you
--  need a stable order, add a tiebreaker: ORDER BY unit_price,
--  product_name.
--
--  Drop the `AND NOT is_discontinued` and you get 10 rows. The extra
--  one is Nimbus Router 500 (EOL) at 99.00 - a product that is in the
--  price range and that we cannot sell. Same trap as week 1.


-- -------------------------------------------------------------
-- Exercise 2.3 - THE NULL TRAP
-- -------------------------------------------------------------

-- (a) The naive version
SELECT count(*) AS not_nigeria_naive
FROM   customers
WHERE  country <> 'Nigeria';
--  33

-- (b) The version that accounts for unknown countries
SELECT count(*) AS not_nigeria_including_unknown
FROM   customers
WHERE  country <> 'Nigeria'
   OR  country IS NULL;
--  37

-- Postgres shorthand for exactly the same thing as (b):
SELECT count(*) FROM customers WHERE country IS DISTINCT FROM 'Nigeria';
--  37

-- THE EXPLANATION:
--
--  40 customers. 3 are in Nigeria. So 37 are not in Nigeria.
--
--  Version (a) returns 33. The four missing customers are the ones
--  with country IS NULL - Anonymous User, Test Account, Pat
--  Nolastname and Jane Doe.
--
--  For each of them SQL evaluated `NULL <> 'Nigeria'`. NULL means
--  "unknown". Is an unknown country different from Nigeria? Nobody
--  can say - it might BE Nigeria. So the comparison returns NULL,
--  not true, and WHERE only keeps rows where the test came out true.
--  The four rows were dropped.
--
--  Nothing failed. No error, no warning, no hint. Just a number that
--  is 4 too small and looks entirely plausible.
--
--  THE CHECK THAT CATCHES THIS EVERY TIME:
--      in-group + out-group should equal the total.
--      3 + 33 = 36, not 40.  <- four people are in neither group
--      3 + 37 = 40.          <- correct
--
--  Run that arithmetic any time you split a table in two. It takes
--  ten seconds and it catches this entire class of bug permanently.


-- =============================================================
--  Mini-project - data-quality audit of `customers`
-- =============================================================

-- 1. Total customers
SELECT count(*) AS total_customers FROM customers;
--  40

-- 2. Customers with no country recorded
SELECT count(*) AS null_country FROM customers WHERE country IS NULL;
--  4

SELECT customer_id, first_name, last_name, email, city, signup_date
FROM   customers
WHERE  country IS NULL
ORDER  BY customer_id;
--   7  Anonymous User  anon.user7@example.com       (no city)   2023-03-28
--  19  Test Account    test.account19@example.com   (no city)   2023-09-12
--  28  Pat Nolastname  pat.n28@example.com          Unknown     2024-01-22
--  33  Jane Doe        jane.doe33@example.com       (no city)   2024-04-01

-- 3. Customers with no city recorded
SELECT count(*) AS null_city FROM customers WHERE city IS NULL;
--  3

-- 4. Distinct countries - and does DISTINCT count NULL?
SELECT count(DISTINCT country) AS distinct_countries FROM customers;
--  28

--  Verify rather than assume. There are 40 customers, 4 with NULL
--  country, so 36 rows carry an actual country value, and those 36
--  values cover 28 distinct countries.
--
--  count(DISTINCT country) = 28 tells you NULL was NOT counted as a
--  value. Confirm it directly:
SELECT count(*) AS distinct_incl_null
FROM  (SELECT DISTINCT country FROM customers) x;
--  29   <- one MORE than 28
--
--  SELECT DISTINCT returns 29 rows: 28 countries plus one NULL row.
--  But count(DISTINCT country) returns 28, because aggregate
--  functions skip NULLs. Same data, two different answers, depending
--  on which tool you reach for. This is exactly the sort of
--  off-by-one that turns into an argument in a meeting.

-- 5. Accounts that do not look like real people
SELECT customer_id, first_name, last_name, email
FROM   customers
WHERE  first_name ILIKE 'test'
    OR first_name ILIKE 'anonymous'
    OR email      ILIKE '%test%'
    OR (first_name ILIKE 'jane' AND last_name ILIKE 'doe')
ORDER  BY customer_id;
--   7  Anonymous User
--  19  Test Account
--  33  Jane Doe
--
--  Unmistakably fake: Test Account (19) and Anonymous User (7).
--  Nobody is named those things.
--
--  Arguable: Jane Doe (33) is the English-language placeholder name
--  for an unidentified person - but it is also a real name that real
--  people genuinely have. Pat Nolastname (28) is stranger still: the
--  surname is literally "Nolastname", which reads like a form
--  rejecting an empty field and substituting a placeholder, and the
--  city is the string 'Unknown' rather than a NULL.
--
--  THAT is the interesting finding, and it is worth more than the
--  two obvious ones: somebody's signup form has been writing the
--  words 'Unknown' and 'Nolastname' into columns instead of leaving
--  them NULL. Those strings will survive every NULL check you write.
--  `WHERE city IS NULL` will never find customer 28, because 'Unknown'
--  is a perfectly good non-null string.
--
--  Fake data that announces itself as NULL is easy. Fake data
--  disguised as real data is the problem.

-- 6. Inactive customers
SELECT count(*) AS inactive FROM customers WHERE NOT is_active;
--  3   (customers 10, 19 and 33)

-- 7. Country/city NULL asymmetry
SELECT count(*) FILTER (WHERE country IS NULL AND city IS NOT NULL) AS country_null_city_set,
       count(*) FILTER (WHERE city IS NULL AND country IS NOT NULL) AS city_null_country_set
FROM   customers;
--  country_null_city_set = 1     (customer 28, city 'Unknown')
--  city_null_country_set = 0
--
--  Every customer missing a city is also missing a country, but not
--  the reverse. That asymmetry is a clue about collection: it
--  suggests city and country were captured together in one step that
--  either succeeded or failed as a unit - except for customer 28,
--  where something wrote a placeholder instead of failing cleanly.


-- -------------------------------------------------------------
-- THE VERDICT
-- -------------------------------------------------------------
--
--  Can this table be trusted for a country-level sales report?
--
--  Qualified yes - with the gap stated in the report, not hidden.
--
--  The numbers: 36 of 40 customers (90%) have a usable country. The
--  4 that don't are a small enough share not to distort national
--  totals much. But three of those four look like non-customers
--  anyway (test, anonymous, placeholder), so the real coverage of
--  genuine customers is better than 90%.
--
--  What I would tell whoever asked:
--
--  "Yes, with two caveats. First, four customers have no country and
--  will be missing from any country breakdown - so publish a
--  'Country unknown' line rather than letting the totals silently
--  fail to add up. Second, at least two of the 40 accounts are test
--  data sitting in the production table, and one more has 'Unknown'
--  written into the city field as literal text. Before this becomes
--  a recurring report, those should be flagged or removed, and the
--  signup form should be storing NULL instead of placeholder words."
--
--  Note what makes that a good answer: every claim in it is a number
--  produced above. "Can we trust it?" is not answered with a feeling.
