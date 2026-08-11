-- =============================================================
--  SOLUTIONS - Week 1: Reading data
--
--  STOP. Have you actually attempted these?
--
--  Reading a correct query feels like learning and is not. If you
--  have not written a broken version of each of these and fixed it,
--  close this file and go back to the exercises. Fifteen minutes of
--  being stuck is worth more than an hour of reading solutions.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 1.1 - Storage products, name and price, dearest first
-- Expected: 5 rows
-- -------------------------------------------------------------
SELECT product_name,
       unit_price
FROM   products
WHERE  category = 'Storage'
ORDER  BY unit_price DESC;

--  Vault NAS 4-Bay    529.00
--  Rapid SSD 2TB      198.00
--  Rapid SSD 1TB      109.00
--  Archive HDD 4TB     89.00
--  Rapid SSD 500GB     64.00
--
--  Note: 'Storage' is capitalised. 'storage' returns zero rows,
--  because text comparison in Postgres is case-sensitive. Zero rows
--  is not an error message - it looks exactly like "no such data",
--  which is why it is such a good way to fool yourself.


-- -------------------------------------------------------------
-- Exercise 1.2 - Live products, sorted by category then price
-- Expected: 23 rows
-- -------------------------------------------------------------
SELECT product_name,
       category,
       unit_price
FROM   products
WHERE  NOT is_discontinued
ORDER  BY category ASC,        -- outer sort: groups the output
          unit_price DESC;     -- inner sort: applies within each group

--  All of these are equivalent, pick whichever reads best to you:
--      WHERE NOT is_discontinued
--      WHERE is_discontinued = false
--      WHERE is_discontinued IS FALSE
--
--  `NOT is_discontinued` is the most idiomatic. A boolean column is
--  already a true/false value - comparing it to `true` adds a step
--  that does nothing.
--
--  The two-level sort is the point of this exercise. Categories come
--  out alphabetically (Cables, Networking, Peripherals, Power,
--  Software, Storage) and within each one the prices descend. Swap
--  the two ORDER BY terms around and run it again to see how
--  differently the same 23 rows read.


-- -------------------------------------------------------------
-- Exercise 1.3 - Margin, aliased, filtered
-- Expected: 6 rows
-- -------------------------------------------------------------

-- FIRST, the version you probably wrote:
--
--     SELECT product_name, unit_price, cost_price,
--            unit_price - cost_price AS margin
--     FROM   products
--     WHERE  margin > 100
--     ORDER  BY margin DESC;
--
--     ERROR:  column "margin" does not exist
--
-- WHY: the database evaluates WHERE *before* SELECT. When WHERE runs,
-- the alias `margin` has not been created yet - SELECT is what creates
-- it, and SELECT hasn't happened. The alias simply does not exist at
-- the moment WHERE needs it.
--
-- Curiously, ORDER BY margin DESC on the last line is FINE, because
-- ORDER BY runs *after* SELECT. Same query, same alias, one clause
-- can see it and the other cannot. That asymmetry is not intuitive;
-- it just follows from the evaluation order.

-- THE FIX: repeat the expression in WHERE.
SELECT product_name,
       unit_price,
       cost_price,
       unit_price - cost_price AS margin
FROM   products
WHERE  unit_price - cost_price > 100     -- the expression, not the alias
ORDER  BY margin DESC;                   -- alias is fine here

--  Vault NAS 4-Bay          529.00  322.00  207.00
--  24-Port Managed Switch   429.00  256.00  173.00
--  Nimbus Monitor 1-Year    199.00   40.00  159.00
--  Nimbus Router 2000 Pro   349.00  198.00  151.00
--  Nimbus Backup 1-Year     149.00   30.00  119.00
--  27" QHD Monitor          289.00  176.00  113.00
--
--  Repeating the expression feels redundant, and it is. Two ways to
--  avoid it, both of which you will learn properly later:
--      week 6  - wrap the query in a CTE and filter the CTE
--      week 12 - store it as a view
--  For now, repeating it is the correct and normal thing to do.


-- =============================================================
--  Mini-project - Nimbus product catalogue report
-- =============================================================

-- Catalogue of all products currently for sale.
-- Grouped by category, best-margin items first within each.
SELECT sku,
       product_name,
       category,
       unit_price              AS price,
       unit_price - cost_price AS margin,
       stock_qty               AS in_stock
FROM   products
WHERE  NOT is_discontinued
ORDER  BY category ASC,
          unit_price - cost_price DESC;


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. Which category has the highest-margin product overall?
--
--    Storage - the Vault NAS 4-Bay, at 207.00 margin.
--
--    Worth noticing: it is also the most expensive product we sell.
--    Highest margin and highest price often travel together, but not
--    always - Nimbus Monitor 1-Year is second on margin (159.00) at a
--    price of only 199.00, because software costs almost nothing to
--    reproduce. In week 3 you'll be able to ask which *category* has
--    the best average margin, which is the more useful question.

-- 2. Two products show in_stock = 0 but are not discontinued. Why
--    might that be correct rather than a data error?
--
--    They are Nimbus Backup 1-Year and Nimbus Monitor 1-Year - both
--    software subscriptions. Software has no physical stock. You can
--    sell an unlimited number of licences without a warehouse.
--
--    So stock_qty = 0 here means "not applicable", not "sold out".
--    The schema has no way to express that difference, which means
--    any "out of stock" report built on this column will wrongly flag
--    both products forever.
--
--    That is a real modelling flaw, and it is the kind of thing you
--    are being trained to notice. A stricter design would add an
--    `is_physical` boolean, or make stock_qty NULL for non-physical
--    goods - NULL meaning "not applicable" rather than "zero". You'll
--    meet exactly that distinction in week 2.

-- 3. What column would you need to answer "which products should we
--    reorder?" that this schema does not have?
--
--    A reorder threshold - the stock level at which we should buy
--    more. Something like `reorder_point integer`.
--
--    Without it, "low stock" has no definition. Is 22 units of the
--    Vault NAS low? It is 22 units of a 529.00 item that sells slowly;
--    it might be a year of supply. Meanwhile 88 units of a cable that
--    sells 50 a week is nearly an emergency. Stock quantity alone
--    cannot tell you, because low is relative to how fast the thing
--    sells.
--
--    Good answers also include: supplier lead time, minimum order
--    quantity, or a sales-velocity figure. Any of those show you
--    spotted the real gap - the schema records a *state* (how many we
--    have) but nothing about the *rate* (how fast they go), and
--    reordering is a question about rate.
