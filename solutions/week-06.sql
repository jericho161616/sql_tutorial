-- =============================================================
--  SOLUTIONS - Week 6: Subqueries & CTEs
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 6.1 - Products above the average price
-- Expected: 8 rows, average 160.13
-- -------------------------------------------------------------
SELECT product_name,
       category,
       unit_price,
       (SELECT round(avg(unit_price), 2)
        FROM   products
        WHERE  NOT is_discontinued) AS avg_price
FROM   products
WHERE  NOT is_discontinued
  AND  unit_price > (SELECT avg(unit_price)
                     FROM   products
                     WHERE  NOT is_discontinued)
ORDER  BY unit_price DESC;

--  Vault NAS 4-Bay           Storage      529.00  160.13
--  24-Port Managed Switch    Networking   429.00  160.13
--  Nimbus Router 2000 Pro    Networking   349.00  160.13
--  27" QHD Monitor           Peripherals  289.00  160.13
--  Rack PDU 8-Outlet         Power        219.00  160.13
--  Nimbus Monitor 1-Year     Software     199.00  160.13
--  Rapid SSD 2TB             Storage      198.00  160.13
--  Nimbus Router 1000        Networking   189.00  160.13
--
--  8 rows out of 23 live products. Only about a third of products
--  are priced above the average price - the same skew you will meet
--  again in the worked example, for the same reason: a few expensive
--  items pull the mean above the middle of the pack.
--
--  THE FILTER MUST BE REPEATED INSIDE THE SUBQUERY. Leave off
--  `WHERE NOT is_discontinued` in the inner query and the average
--  becomes 157.58 instead of 160.13, because the two end-of-life
--  products drag it down. A subquery does NOT inherit the outer
--  query's WHERE clause - it is a separate query that happens to be
--  written inside another one.
--
--  Small difference here. On a table where 30% of rows are inactive,
--  the same mistake shifts every threshold in your report.
--
--  Note the average is computed twice - once for display, once for
--  the comparison. That is wasteful and repetitive. A CTE fixes it:

WITH live AS (
    SELECT * FROM products WHERE NOT is_discontinued
),
avg_price AS (
    SELECT round(avg(unit_price), 2) AS avg_price FROM live
)
SELECT l.product_name, l.category, l.unit_price, a.avg_price
FROM   live l
CROSS  JOIN avg_price a          -- one row, so this cannot fan out
WHERE  l.unit_price > a.avg_price
ORDER  BY l.unit_price DESC;

--  CROSS JOIN against a single-row CTE is the standard way to make a
--  scalar available to every row. Because avg_price has exactly one
--  row, multiplying by it changes nothing - 8 rows in, 8 rows out.


-- -------------------------------------------------------------
-- Exercise 6.2 - Customers who bought Storage products
-- Expected: 29 rows
-- -------------------------------------------------------------
SELECT c.first_name,
       c.last_name,
       c.country
FROM   customers c
WHERE  EXISTS (SELECT 1
               FROM   orders      o
               JOIN   order_items oi ON oi.order_id   = o.order_id
               JOIN   products    p  ON p.product_id  = oi.product_id
               WHERE  o.customer_id = c.customer_id      -- the correlation
                 AND  p.category = 'Storage')
ORDER  BY c.last_name;

--  29 rows.

-- WHAT GOES WRONG WITH A PLAIN JOIN:
--
--     SELECT c.first_name, c.last_name, c.country
--     FROM   customers c
--     JOIN   orders o       ON o.customer_id = c.customer_id
--     JOIN   order_items oi ON oi.order_id   = o.order_id
--     JOIN   products p     ON p.product_id  = oi.product_id
--     WHERE  p.category = 'Storage';
--
--  This returns ONE ROW PER MATCHING ORDER LINE, not one row per
--  customer. A customer who bought Storage items on four separate
--  orders appears four times. The list is no longer a list of
--  customers - it is a list of purchases wearing customer names.
--
--  You could patch it with SELECT DISTINCT, and people do. But
--  DISTINCT is a blunt instrument: it silently removes duplicates
--  without you ever knowing how many there were, and it would also
--  merge two genuinely different customers who happened to share
--  every selected column.
--
--  EXISTS is better because it never creates the duplicates in the
--  first place. It asks "is there at least one?", gets an answer,
--  and stops looking. One customer, one row, guaranteed by
--  construction rather than cleaned up afterwards.
--
--  THE RULE: if you need COLUMNS from the other table, JOIN.
--  If you only need to know a match EXISTS, use EXISTS.


-- -------------------------------------------------------------
-- Exercise 6.3 - Rewrite as a CTE, then extend it
-- Expected: 12 rows
-- -------------------------------------------------------------

-- PART A - the same query, readable
WITH customer_totals AS (
    SELECT   o.customer_id,
             count(DISTINCT o.order_id)                 AS orders,
             round(sum(oi.quantity * oi.unit_price), 2) AS total
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY o.customer_id
)
SELECT   c.first_name,
         c.last_name,
         t.orders,
         t.total
FROM     customer_totals t
JOIN     customers c ON c.customer_id = t.customer_id
WHERE    t.total > 3000
ORDER BY t.total DESC;

--  12 rows. Carlos Mendoza leads.
--
--  Identical output to the nested version, but it reads downwards:
--  "work out each customer's totals, then attach names, then filter."
--  The nested original made you read inside-out.
--
--  Note count(DISTINCT o.order_id), not count(*). After joining to
--  order_items there is one row per LINE, so count(*) would count
--  line items and call them orders. DISTINCT on the order_id undoes
--  the fan-out for that column. (sum() is unaffected - we genuinely
--  do want every line added up.)

-- PART B - add each customer's most recent order date
WITH customer_totals AS (
    SELECT   o.customer_id,
             count(DISTINCT o.order_id)                 AS orders,
             round(sum(oi.quantity * oi.unit_price), 2) AS total
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY o.customer_id
),
last_order AS (                      -- built from `orders` ALONE
    SELECT   customer_id,
             max(order_date) AS last_order_date
    FROM     orders
    WHERE    status IN ('completed','shipped')
    GROUP BY customer_id
)
SELECT   c.first_name,
         c.last_name,
         t.orders,
         t.total,
         l.last_order_date
FROM     customer_totals t
JOIN     customers  c ON c.customer_id = t.customer_id
JOIN     last_order l ON l.customer_id = t.customer_id
WHERE    t.total > 3000
ORDER BY t.total DESC;

--  Still 12 rows - and that is the thing to check.
--
--  WHY last_order IS BUILT FROM `orders` ALONE: it needs nothing from
--  order_items. Adding another join to order_items inside it would
--  produce one row per line item, and although max(order_date) would
--  survive that unharmed, the habit will not. The moment you add a
--  sum() to a CTE that has been silently multiplied, you have a
--  fan-out bug.
--
--  BUILD EACH CTE FROM THE SMALLEST SET OF TABLES THAT ANSWERS ITS
--  OWN QUESTION. Then join the summaries. Both CTEs here produce
--  exactly one row per customer, so joining them is one-to-one and
--  the row count cannot change.
--
--  DEBUGGING TIP: run each CTE alone before combining them.
--
--      WITH last_order AS ( ... )
--      SELECT * FROM last_order ORDER BY customer_id;
--
--  If a five-CTE query gives a wrong answer, this narrows it to one
--  step in about a minute.


-- =============================================================
--  Mini-project - the monthly report with no missing months
-- =============================================================

WITH months AS (
    SELECT generate_series(DATE '2024-01-01',
                           DATE '2025-10-01',
                           INTERVAL '1 month')::date AS month
),
monthly_orders AS (
    SELECT   date_trunc('month', o.order_date)::date        AS month,
             count(*)                                        AS orders,
             count(*) FILTER (WHERE o.status = 'completed')  AS completed,
             count(DISTINCT o.customer_id)                   AS customers
    FROM     orders o
    GROUP BY date_trunc('month', o.order_date)::date
),
monthly_revenue AS (
    SELECT   date_trunc('month', o.order_date)::date AS month,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY date_trunc('month', o.order_date)::date
)
SELECT    m.month,
          COALESCE(mo.orders,    0)    AS orders,
          COALESCE(mo.completed, 0)    AS completed,
          COALESCE(mr.revenue,   0.00) AS revenue,
          COALESCE(mo.customers, 0)    AS customers
FROM      months m
LEFT JOIN monthly_orders  mo ON mo.month = m.month
LEFT JOIN monthly_revenue mr ON mr.month = m.month
ORDER BY  m.month;

--  22 rows, 2024-01 through 2025-10.
--
--  THE THREE THINGS THAT MAKE THIS CORRECT:
--
--  1. `months` is the driving table. Every LEFT JOIN hangs off it,
--     so the output has exactly as many rows as the scaffold - 22 -
--     regardless of what the data contains.
--
--  2. Orders and revenue are computed in SEPARATE CTEs. Revenue
--     needs order_items; the order count does not. Computing both in
--     one CTE joined to order_items would make `count(*)` count line
--     items instead of orders. Two questions, two CTEs.
--
--  3. COALESCE turns the NULLs a LEFT JOIN produces into 0. Without
--     it an empty month shows NULL, which charts and spreadsheets
--     treat inconsistently - some plot nothing, some plot zero, some
--     break the line. Say what you mean.


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. Exactly 22 rows?
--
--    Yes. From 2024-01-01 to 2025-10-01 inclusive at one-month steps
--    is 22 values. generate_series includes both endpoints.

-- 2. Do the order counts sum to 120?
--
--    Yes, 120 - because the seed data happens to span exactly this
--    range, with the first order on 2024-01-17 and the last on
--    2025-10-18.
--
--    BUT DO NOT TREAT THAT AS A GUARANTEE. The scaffold is
--    hard-coded to those dates. If an order existed in December 2025,
--    it would fall OUTSIDE the scaffold and be silently dropped by
--    the LEFT JOIN - the total would read less than 120 and no error
--    would appear.
--
--    That is the weakness of a hard-coded range, and it is a real
--    production bug: a report that quietly stops counting anything
--    after the date somebody typed in two years ago. Derive the
--    bounds from the data instead:
--
--        SELECT generate_series(
--                 (SELECT date_trunc('month', min(order_date)) FROM orders),
--                 (SELECT date_trunc('month', max(order_date)) FROM orders),
--                 INTERVAL '1 month')::date AS month
--
--    Now the scaffold grows with the data and nothing can fall off
--    the end.

-- 3. Delete March 2024 and re-run - does March survive?
--
--    YES. Add this to the monthly_orders and monthly_revenue CTEs:
--
--        WHERE o.order_date NOT BETWEEN '2024-03-01' AND '2024-03-31'
--
--    The output still has 22 rows and 2024-03-01 still appears, now
--    showing orders 0, completed 0, revenue 0.00, customers 0.
--
--    That is the entire point of the exercise. The month exists in
--    the report because it exists in the SCAFFOLD, not because it
--    exists in the data. Week 3's version would have dropped the row
--    entirely and drawn a smooth line straight across a month in
--    which the business sold nothing.
--
--    If March vanished when you tried it, your joins are the wrong
--    way round - you have real data on the left and the scaffold on
--    the right, which makes the scaffold pointless.
--
--    PROVE IT RATHER THAN ASSUMING IT. A gap-handling query that has
--    never been tested against an actual gap is not known to work.
--    This applies to far more than dates: any code path that only
--    runs on unusual input needs unusual input pointed at it
--    deliberately, or you will find out it is broken when the
--    unusual input arrives on its own.
