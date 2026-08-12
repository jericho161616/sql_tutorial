-- =============================================================
--  SOLUTIONS - Week 7: Window functions
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 7.1 - Rank products by price within category
-- Expected: 23 rows
-- -------------------------------------------------------------
SELECT product_name,
       category,
       unit_price,
       RANK() OVER (PARTITION BY category ORDER BY unit_price DESC) AS price_rank
FROM   products
WHERE  NOT is_discontinued
ORDER  BY category, price_rank;

--  Cables       Cat6 Cable 3m (10-pack)     34.00   1
--  Cables       HDMI 2.1 Cable 2m           24.00   2
--  Cables       USB-C to USB-C 2m           17.50   3
--  Networking   24-Port Managed Switch     429.00   1
--  Networking   Nimbus Router 2000 Pro     349.00   2
--  ...23 rows in total.

-- ARE THERE ANY TIES?
SELECT category, unit_price, count(*)
FROM   products
WHERE  NOT is_discontinued
GROUP  BY category, unit_price
HAVING count(*) > 1;
--  0 rows. No two live products share a price within the same
--  category.

--  SO WOULD RANK AND ROW_NUMBER DIFFER HERE? No - on this data they
--  produce identical output, because they only diverge on ties and
--  there are none.
--
--  THAT IS EXACTLY WHY THIS QUESTION IS WORTH ASKING. Your query
--  works today by accident. Add one product priced at 89.00 to
--  Peripherals - which already has a Bluetooth Headset at 89.00 -
--  and the two functions immediately disagree:
--
--      ROW_NUMBER  gives them 3 and 4 (arbitrary which is which)
--      RANK        gives them both 3, then skips to 5
--      DENSE_RANK  gives them both 3, then continues at 4
--
--  Choosing between them on the basis of "it worked when I tried it"
--  means the choice was never made. Decide on intent:
--
--      RANK / DENSE_RANK - when equal things should rank equally.
--                          Correct for a published "price rank".
--      ROW_NUMBER        - when you need exactly one row per group
--                          and do not care which. Correct for
--                          "give me each customer's latest order".
--
--  A "top 3" list built with ROW_NUMBER will silently cut one of two
--  tied products and nobody will ever notice.


-- -------------------------------------------------------------
-- Exercise 7.2 - Top 2 products per category
-- Expected: 12 rows
-- -------------------------------------------------------------
WITH ranked AS (
    SELECT product_name,
           category,
           unit_price,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY unit_price DESC) AS rn
    FROM   products
    WHERE  NOT is_discontinued
)
SELECT product_name, category, unit_price, rn
FROM   ranked
WHERE  rn <= 2
ORDER  BY category, rn;

--  12 rows - six categories, two each.

-- WHY THE CTE IS NECESSARY:
--
--      SELECT ..., ROW_NUMBER() OVER (...) AS rn
--      FROM   products
--      WHERE  rn <= 2
--
--      ERROR: column "rn" does not exist
--
--  Window functions are computed AFTER WHERE, for the same reason
--  aggregates are: WHERE decides which rows exist, and a window
--  function needs to know which rows exist before it can number
--  them. So you compute the ranking in one step and filter it in
--  the next. Memorise this two-step shape - "top N per group" is one
--  of the most common real questions in SQL.

-- WHAT IF A CATEGORY HAD ONLY ONE LIVE PRODUCT?
--
--  It would contribute one row, not two, and the report would say
--  nothing about it. Software currently has exactly 2 live products,
--  so it scrapes in; discontinue one and your "top 2" table silently
--  becomes a "top 1" for that category.
--
--  Nothing errors. The table just has 11 rows instead of 12 and
--  looks completely normal. If it matters that every category
--  appears twice, you must check for it - the query will not tell
--  you. This is the same family of problem as week 3's missing
--  months: absence does not announce itself.


-- -------------------------------------------------------------
-- Exercise 7.3 - Each customer's most recent order
-- Expected: 38 rows
-- -------------------------------------------------------------
WITH ranked_orders AS (
    SELECT o.order_id,
           o.customer_id,
           o.order_date,
           o.status,
           ROW_NUMBER() OVER (PARTITION BY o.customer_id
                              ORDER BY o.order_date DESC, o.order_id DESC) AS rn
    FROM   orders o
)
SELECT c.first_name,
       c.last_name,
       r.order_id,
       r.order_date,
       r.status
FROM   ranked_orders r
JOIN   customers c ON c.customer_id = r.customer_id
WHERE  r.rn = 1
ORDER  BY r.order_date DESC;

--  38 rows - one per customer who has ever ordered. Harriet Lockwood
--  and Kwame Mensah are absent because they have no orders to rank;
--  that is correct for "each customer's most recent order".

-- WHY ROW_NUMBER RATHER THAN RANK?
--
--  Because the requirement is EXACTLY ONE ROW PER CUSTOMER.
--
--  If a customer placed two orders on the same date, RANK would give
--  both rank 1 and WHERE rn = 1 would return both - two rows for one
--  customer, quietly breaking the "one row per customer" guarantee
--  that the rest of your report depends on.
--
--  ROW_NUMBER cannot do that. It always produces 1, 2, 3... with no
--  repeats, so rn = 1 returns precisely one row per partition no
--  matter what the data does.
--
--  NOTE THE TIEBREAKER: ORDER BY order_date DESC, order_id DESC.
--  Without the second term, two orders on the same date could be
--  numbered in either order, and re-running the query might return a
--  different one. A deterministic tiebreaker means the same query
--  gives the same answer tomorrow - which matters enormously the
--  first time someone asks why a number changed.


-- =============================================================
--  Mini-project - month-over-month growth report
-- =============================================================

WITH months AS (
    SELECT generate_series(DATE '2024-01-01',
                           DATE '2025-10-01',
                           INTERVAL '1 month')::date AS month
),
monthly_revenue AS (
    SELECT   date_trunc('month', o.order_date)::date AS month,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY 1
),
filled AS (                       -- scaffold + reality, no gaps
    SELECT    m.month,
              COALESCE(r.revenue, 0.00) AS revenue
    FROM      months m
    LEFT JOIN monthly_revenue r ON r.month = m.month
)
SELECT to_char(month, 'YYYY-MM') AS mth,
       revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month,
       round(revenue - LAG(revenue) OVER (ORDER BY month), 2) AS change,
       round(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS pct_change,
       round(SUM(revenue) OVER (ORDER BY month), 2) AS running_total,
       round(AVG(revenue) OVER (ORDER BY month
                                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM   filled
ORDER  BY month;

--  mth      revenue    prev      change     pct      running   mov_avg
--  2024-01    453.00      -          -        -        453.00    453.00
--  2024-02   6828.50    453.00   6375.50  1407.4%     7281.50   3640.75
--  2024-03   4293.95   6828.50  -2534.55   -37.1%    11575.45   3858.48
--  2024-04   4164.50   4293.95   -129.45    -3.0%    15739.95   5095.65
--  2024-05   3350.00   4164.50   -814.50   -19.6%    19089.95   3936.15
--  2024-06   4285.50   3350.00    935.50    27.9%    23375.45   3933.33
--  2024-07  11627.10   4285.50   7341.60   171.3%    35002.55   6420.87
--  2024-08   4268.60  11627.10  -7358.50   -63.3%    39271.15   6727.07
--  2024-09   4333.50   4268.60     64.90     1.5%    43604.65   6743.07
--  ...22 rows in total.

-- NOTE the moving average is computed on `filled`, AFTER the gaps
-- have been zero-filled. Computed on the raw data instead, a missing
-- month would be skipped rather than counted as zero, and a
-- "3-month" average would silently span four calendar months.


-- -------------------------------------------------------------
-- COMMENTARY (five sentences, every claim backed by a number)
-- -------------------------------------------------------------
--
--  1. Revenue runs at roughly $4,300 per month across 2024-2025,
--     with the 3-month moving average sitting between $3,900 and
--     $6,700 for most of the period.
--
--  2. IGNORE FEBRUARY'S +1407.4%: January booked only $453.00 from a
--     single order because the data begins on 17 January, so the
--     percentage is measuring a partial month rather than growth -
--     the absolute change of $6,375.50 is the honest figure, and even
--     that overstates the case.
--
--  3. July 2024's $11,627.10 is the one genuine anomaly, 171.3% above
--     June and nearly triple the run rate; it is worth finding out
--     what drove it.
--
--  4. August's -63.3% is NOT a collapse but a return to baseline -
--     at $4,268.60 it is within $100 of April, May, June and
--     September, and only looks catastrophic because it is being
--     compared against July's spike.
--
--  5. THE FINAL MONTH IS INCOMPLETE: the last order is dated
--     2025-10-18, so October's figure covers 18 days and will read
--     as a sharp decline on any chart - it should be excluded from
--     the trend or clearly marked as partial.
--
--  WHAT MAKES THIS A REPORT RATHER THAN A TABLE:
--
--  Two of the five sentences exist to stop the reader drawing a
--  false conclusion. The +1407% and the -63.3% are both arithmetically
--  correct and both would mislead anyone who read them without the
--  context - one invents growth that never happened, the other
--  invents a crash.
--
--  Handing someone a table containing those numbers without comment
--  is not neutral. It is likely to send them investigating a decline
--  that does not exist, and the fact that every figure in the table
--  was correct will not help when that is discovered.
--
--  A percentage is a ratio, and a ratio with a small or partial
--  denominator says more about the denominator than about the
--  business. Always publish the absolute number beside it so the
--  reader can check.
