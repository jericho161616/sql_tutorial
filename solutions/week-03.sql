-- =============================================================
--  SOLUTIONS - Week 3: Aggregation
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 3.1 - Products per category (including discontinued)
-- Expected: 6 rows, totalling 25
-- -------------------------------------------------------------
SELECT   category,
         count(*) AS products
FROM     products
GROUP BY category
ORDER BY products DESC, category;

--  Networking    6
--  Peripherals   6
--  Cables        3
--  Power         3
--  Storage       5
--  Software      2
--
--  ...sorted by count descending, so actually:
--  Networking 6, Peripherals 6, Storage 5, Cables 3, Power 3, Software 2
--
--  Note the tie: Networking and Peripherals both have 6. Without a
--  tiebreaker the database may return them in either order, which is
--  why `ORDER BY products DESC, category` is better than
--  `ORDER BY products DESC` alone. Ties are everywhere in grouped
--  results and unstable output is confusing when you re-run a report
--  and the rows have shuffled.

-- Always verify the total:
SELECT sum(products) FROM (SELECT count(*) AS products FROM products GROUP BY category) x;
--  25  - matches the row count of `products`. Nothing was lost.


-- -------------------------------------------------------------
-- Exercise 3.2 - Orders by status
-- Expected: 5 rows summing to 120
-- -------------------------------------------------------------
SELECT   status,
         count(*) AS orders
FROM     orders
GROUP BY status
ORDER BY orders DESC;

--  completed   78
--  shipped     20
--  pending     10
--  cancelled    7
--  refunded     5
--             ----
--             120

-- The check, done properly rather than by eye:
SELECT count(*) AS total_orders FROM orders;   -- 120

--  78 + 20 + 10 + 7 + 5 = 120. Every order is in exactly one group.
--
--  This check is worth doing every single time you GROUP BY. If the
--  parts don't sum to the whole, either a WHERE clause dropped rows
--  you forgot about, or the grouping column contains NULLs (which
--  form their own group, easily overlooked), or you are grouping the
--  wrong thing entirely.
--
--  Note for later: 'cancelled' and 'refunded' together are 12 orders,
--  10% of the table. Any revenue query that forgets to exclude them
--  will overstate income by roughly that much. Remember this in
--  week 5.


-- -------------------------------------------------------------
-- Exercise 3.3 - WHERE and HAVING in one query
-- Expected: 5 rows
-- -------------------------------------------------------------
SELECT   category,
         count(*)                  AS products,
         round(avg(unit_price), 2) AS avg_price
FROM     products
WHERE    NOT is_discontinued       -- per-ROW test: runs BEFORE grouping
GROUP BY category
HAVING   count(*) >= 3             -- per-GROUP test: runs AFTER grouping
ORDER BY avg_price DESC;

--  Networking    5   241.10
--  Storage       5   197.80
--  Peripherals   5   137.00
--  Power         3   126.67
--  Cables        3    25.17
--
--  FIVE rows, not six. Software is missing: it has only 2 live
--  products, so HAVING count(*) >= 3 removed the whole group.
--  Notice that Software's average price (174.00) would have placed
--  it third - a group can be excluded for being small even when its
--  numbers look attractive. That is exactly what the HAVING is for.

-- WHY THEY CANNOT BE SWAPPED:
--
--  `WHERE NOT is_discontinued` asks a question about ONE ROW: is this
--  particular product discontinued? That can be answered while the
--  database is still reading individual rows, before any grouping.
--  It cannot go in HAVING... well, technically Postgres would accept
--  it, but it would then run after grouping, which is wasted work:
--  you would build the Networking group out of 6 products and only
--  then discard the dead one, changing the count you already computed.
--
--  `HAVING count(*) >= 3` asks a question about a WHOLE GROUP: how
--  many products ended up in this pile? That is unanswerable until
--  the piles exist. Putting it in WHERE is a hard error:
--
--      WHERE count(*) >= 3
--      ERROR: aggregate functions are not allowed in WHERE
--
--  The rule in one line: WHERE is about rows, HAVING is about groups.
--  When you could use either, use WHERE - filtering early means
--  fewer rows to group, which is less work.


-- =============================================================
--  Mini-project - monthly order summary
-- =============================================================

SELECT   to_char(order_date, 'YYYY-MM')                 AS month,
         count(*)                                       AS orders,
         count(*) FILTER (WHERE status = 'completed')   AS completed,
         count(*) FILTER (WHERE status = 'cancelled')   AS cancelled,
         sum(shipping_fee)                              AS shipping_collected
FROM     orders
GROUP BY to_char(order_date, 'YYYY-MM')
ORDER BY month;

--  month     orders  completed  cancelled  shipping
--  2024-01        1          1          0      6.50
--  2024-02        4          4          0     33.00
--  2024-03        6          3          0     50.50
--  2024-04        6          4          1     48.50
--  2024-05        6          4          0     46.00
--  2024-06        6          2          0     50.00
--  2024-07        7          7          0     53.50
--  2024-08        6          3          1     62.50
--  2024-09        5          2          0     41.00
--  2024-10        6          4          1     38.00
--  2024-11        7          7          0     50.50
--  2024-12        6          1          0     55.00
--  2025-01        6          4          1     57.50
--  2025-02        6          5          0     58.00
--  2025-03        7          4          1     44.50
--  2025-04        5          3          0     28.50
--  2025-05        6          4          0     64.50
--  2025-06        6          3          0     50.00
--  2025-07        7          6          1     65.50
--  2025-08        6          3          1     52.00
--  2025-09        3          2          0      9.50
--  2025-10        2          2          0     11.50

-- Note: you can also write `GROUP BY 1` to group by the first
-- SELECT column. It is shorter and common in practice, but it breaks
-- silently if someone reorders your SELECT list. Fine for a scratch
-- query, risky in anything saved.


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. Which month had the most orders?
--
--    Four months tie at 7: 2024-07, 2024-11, 2025-03 and 2025-07.
--
--    A tie is a real answer, not a failure. Had you written
--    `ORDER BY orders DESC LIMIT 1` you would have got exactly one of
--    those four - chosen arbitrarily by the database - and reported
--    it as "the busiest month", which would be wrong three-quarters
--    of the time. LIMIT 1 on a tied ordering is a quiet way to
--    manufacture a false fact.

-- 2. Do the monthly totals sum to 120?
SELECT sum(orders) AS total
FROM  (SELECT count(*) AS orders FROM orders GROUP BY to_char(order_date,'YYYY-MM')) x;
--  120  - correct, nothing was dropped.

-- 3. Are any months missing from the output?
--
--    No. The result runs from 2024-01 to 2025-10 with all 22
--    consecutive months present.
--
--    But here is the point of the question: YOU CANNOT TELL THAT
--    FROM THE OUTPUT ITSELF without checking the dates by eye. A
--    month with zero orders would simply not appear - there would be
--    no row at all, not a row containing 0. GROUP BY can only make
--    groups out of rows that exist, and a month with no orders has
--    no rows to group.
--
--    So a missing month and a zero month look identical in this
--    output: both are just absent. If you fed this straight into a
--    line chart, the chart would draw a line from the month before
--    the gap to the month after it, and the gap would vanish
--    completely. Your chart would show a smooth trend across a
--    period when the business sold nothing.
--
--    The fix is to generate a complete list of months and LEFT JOIN
--    the orders onto it, so empty months survive as genuine zeros.
--    That needs generate_series and a join - you will have both by
--    the end of week 6.
--
--    ALSO WORTH NOTICING: 2025-09 has 3 orders and 2025-10 has 2,
--    against a run rate of about 6. That is not a business collapse,
--    it is the data simply stopping - the last order is dated
--    2025-10-18. Trailing partial periods look exactly like a crash
--    on a chart, and reading them as a downturn is one of the most
--    common mistakes in reporting. Always check whether your final
--    period is complete before you interpret its shape.
