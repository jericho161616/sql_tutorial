-- =============================================================
--  SOLUTIONS - Week 5: Joins II and fan-out
--
--  If you read this before attempting 5.1, you will lose the only
--  chance the course gives you to be genuinely fooled by a wrong
--  number. Being fooled once, safely, is what stops it happening
--  later on something that matters.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 5.1 - Demonstrate fan-out to yourself
-- -------------------------------------------------------------

-- (a) The truth
SELECT sum(shipping_fee) AS shipping_correct FROM orders;
--  976.50

-- (b) The same figure, destroyed by a join
SELECT sum(o.shipping_fee) AS shipping_inflated
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id;
--  2938.50

-- THE RATIO
SELECT round(2938.50 / 976.50, 3) AS inflation_factor;   -- 3.009

--  Both queries are valid SQL. Neither raises a warning. One is
--  wrong by a factor of three.
--
--  WHY: the join produces one row per ORDER LINE, not per order.
--  Order 42's fee of 14.00 lands on all three of its lines, so the
--  sum adds 14.00 three times.
--
--  THE OBVIOUS GUESS ABOUT THE RATIO IS WRONG. You would expect the
--  factor to equal the average number of line items per order:
SELECT round(count(*)::numeric / (SELECT count(*) FROM orders), 3) AS avg_lines
FROM   order_items;
--  2.500
--
--  But the inflation factor is 3.009, not 2.500. The difference
--  matters: the factor is the line count WEIGHTED BY SHIPPING FEE.
--  Orders that happen to carry a bigger fee also happen to have more
--  lines, so the expensive fees get over-counted more often than the
--  cheap ones, dragging the ratio above the plain average.
--
--  The lesson is not the arithmetic. It is that you cannot estimate
--  the size of a fan-out error from summary statistics. You have to
--  measure it - which means running the correct query alongside the
--  suspect one and comparing, exactly as above.

-- The detection technique, in two lines:
SELECT count(*) FROM orders;                                          -- 120
SELECT count(*) FROM orders o JOIN order_items oi USING (order_id);    -- 300
--
--  120 -> 300. Before the join, a row was an order. After it, a row
--  is a line item. Any order-level column summed after that point is
--  counted 2.5 times on average.
--
--  (USING (order_id) is shorthand for ON oi.order_id = o.order_id,
--  usable when both columns share a name. It also merges them into
--  one output column.)


-- -------------------------------------------------------------
-- Exercise 5.2 - Self-join: employees and their managers
-- Expected: 12 rows
-- -------------------------------------------------------------

-- WRONG: INNER JOIN silently drops the CEO
--
--     SELECT e.full_name, e.job_title, m.full_name AS manager
--     FROM   employees e
--     JOIN   employees m ON m.employee_id = e.manager_id;
--
--     11 rows. Ana Villaruel is missing, because her manager_id is
--     NULL and NULL matches nothing.

-- CORRECT
SELECT    e.full_name                    AS employee,
          e.job_title,
          COALESCE(m.full_name, '(none)') AS manager
FROM      employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER  BY m.full_name NULLS FIRST, e.full_name;

--  Ana Villaruel        Chief Executive Officer  (none)
--  Priya Raghunathan    VP Operations            Ana Villaruel
--  Marcus Oyelaran      VP Engineering           Ana Villaruel
--  Amara Nwosu          Support Lead             Priya Raghunathan
--  Sofia Marchetti      Warehouse Manager        Priya Raghunathan
--  ...and so on, 12 rows total.
--
--  HOW A SELF-JOIN WORKS: `employees e` and `employees m` are the
--  same physical table opened twice under two names. The aliases are
--  not optional decoration - without them the query cannot say which
--  copy a column belongs to.
--
--  Read the ON clause as: "for this employee row e, find the
--  employee row m whose employee_id equals e's manager_id."
--
--  The COALESCE turns the NULL manager into readable text. Without
--  it Ana's manager column is blank, which a reader can easily
--  misread as missing data rather than "correct - she is the boss".
--
--  Note this only goes ONE level up. Showing a full reporting chain
--  of arbitrary depth needs a RECURSIVE CTE, which is beyond this
--  course but worth knowing exists - look up WITH RECURSIVE when you
--  meet an org chart or a category tree in real work.


-- -------------------------------------------------------------
-- Exercise 5.3 - Anti-join: orders with no payment
-- Expected: 17 rows
-- -------------------------------------------------------------
SELECT o.order_id,
       o.order_date,
       o.status,
       c.first_name || ' ' || c.last_name AS customer
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
WHERE  NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)
ORDER  BY o.order_id;

--  17 rows.

-- The LEFT JOIN form, equivalent:
SELECT    o.order_id, o.order_date, o.status
FROM      orders o
LEFT JOIN payments p ON p.order_id = o.order_id
WHERE     p.payment_id IS NULL
ORDER  BY o.order_id;

--  Prefer NOT EXISTS. It says what it means, it cannot accidentally
--  fan out (a LEFT JOIN to a table with several matches would
--  multiply rows before the IS NULL filter runs), and unlike NOT IN
--  it is safe when NULLs are present.

-- IS THIS A DATA-QUALITY PROBLEM?
SELECT   o.status, count(*) AS unpaid
FROM     orders o
WHERE    NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)
GROUP BY o.status;
--  cancelled   7
--  pending    10

--  NO. It is exactly what you should expect, and the query above is
--  what proves it.
--
--  All 17 unpaid orders are either `cancelled` (7) or `pending` (10).
--  A cancelled order should never have been paid. A pending one has
--  not been paid YET. Both are correct states, not gaps.
--
--  The check that would actually indicate a problem is the narrower
--  one - an order marked completed or shipped with no payment, i.e.
--  goods that left the warehouse without money arriving:
SELECT count(*) AS shipped_but_unpaid
FROM   orders o
WHERE  o.status IN ('completed','shipped')
  AND  NOT EXISTS (SELECT 1 FROM payments p
                   WHERE p.order_id = o.order_id AND p.status = 'captured');
--  0
--
--  Zero. The pipeline is sound.
--
--  THIS IS THE POINT OF THE EXERCISE. "17 orders have no payment"
--  sounds alarming and is completely fine. Reporting it as a defect
--  would send someone off to investigate nothing.
--
--  A count on its own is not a finding. A count you have broken down
--  and explained is. Always ask what the failing rows have in common
--  before you escalate a number.


-- =============================================================
--  Mini-project - integrity checks on the order pipeline
-- =============================================================

WITH order_goods AS (      -- collapse order_items to ONE row per order
    SELECT order_id,
           ROUND(SUM(quantity * unit_price * (1 - discount_pct / 100)), 2) AS goods
    FROM   order_items
    GROUP  BY order_id
),
order_paid AS (            -- collapse payments to ONE row per order
    SELECT order_id,
           ROUND(SUM(amount), 2) AS paid
    FROM   payments
    WHERE  status = 'captured'
    GROUP  BY order_id
)
SELECT '1. orders with no line items' AS check_name,
       count(*) AS failures
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)

UNION ALL
SELECT '2. orders with no payment record', count(*)
FROM   orders o
WHERE  NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id = o.order_id)

UNION ALL
SELECT '3. completed/shipped with no captured payment', count(*)
FROM   orders o
WHERE  o.status IN ('completed','shipped')
  AND  NOT EXISTS (SELECT 1 FROM payments p
                   WHERE p.order_id = o.order_id AND p.status = 'captured')

UNION ALL
SELECT '4. customers who never ordered', count(*)
FROM   customers c
WHERE  NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id)

UNION ALL
SELECT '5. products never ordered', count(*)
FROM   products p
WHERE  NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id)

UNION ALL
SELECT '6. captured payments <> order total', count(*)
FROM   orders o
JOIN   order_goods g ON g.order_id = o.order_id
LEFT   JOIN order_paid pd ON pd.order_id = o.order_id
WHERE  o.status IN ('completed','shipped')
  AND  COALESCE(pd.paid, 0) <> ROUND(g.goods + o.shipping_fee, 2)

UNION ALL
SELECT '7. orders with NULL ship_country', count(*)
FROM   orders o
WHERE  o.ship_country IS NULL

ORDER  BY check_name;

--  1. orders with no line items                      0
--  2. orders with no payment record                 17
--  3. completed/shipped with no captured payment     0
--  4. customers who never ordered                    2
--  5. products never ordered                         2
--  6. captured payments <> order total               0
--  7. orders with NULL ship_country                 13

-- CHECK 6 IS THE ONE THAT TEACHES THE WEEK'S LESSON.
--
--  It compares two aggregates - the goods total from order_items and
--  the captured total from payments - for the same order. That is
--  precisely the two-sibling-child-tables trap.
--
--  Written naively:
--
--      FROM  orders o
--      JOIN  order_items oi ON oi.order_id = o.order_id
--      JOIN  payments    p  ON p.order_id  = o.order_id
--      GROUP BY o.order_id
--
--  ...an order with 2 lines and 2 payments produces 4 rows. BOTH
--  sums are then wrong - the goods double-counted by the payments,
--  the payments double-counted by the goods. The comparison would
--  report failures that do not exist.
--
--  The CTEs at the top are the fix. Each collapses its table to one
--  row per order BEFORE anything is joined, so the join is
--  one-to-one and nothing multiplies. Aggregate first, join second.
--
--  Note also the LEFT JOIN to order_paid plus COALESCE(pd.paid, 0):
--  an order with no payments at all must still be evaluated, not
--  silently dropped. An INNER JOIN there would hide exactly the
--  orders the check exists to find.


-- -------------------------------------------------------------
-- THE VERDICT
-- -------------------------------------------------------------
--
--  Four checks return non-zero. NONE of them is a bug.
--
--  Check 2 - 17 orders with no payment. All are cancelled (7) or
--  pending (10). Correct behaviour: you do not pay for an order you
--  cancelled, and a pending order has not been paid yet.
--
--  Check 4 - 2 customers who never ordered. Harriet Lockwood and
--  Kwame Mensah, who signed up in November and December 2025 and
--  have not bought anything yet. Normal, and arguably a sales
--  opportunity rather than a defect.
--
--  Check 5 - 2 products never ordered. Both are end-of-life items
--  (Nimbus Router 500, Webcam 720p) carrying is_discontinued = true.
--  Discontinued products not selling is the expected outcome.
--
--  Check 7 - 13 orders with NULL ship_country. These belong to the
--  four customers who never supplied a country. The gap is real and
--  worth fixing at the signup form, but it is an INPUT problem, not
--  a corruption of the order pipeline.
--
--  Worth pausing on the arithmetic here: 4 customers produced 13
--  affected orders. One missing field on one signup form propagated
--  into thirteen unusable rows downstream, and it will keep
--  propagating with every order those customers place. That ratio is
--  the argument for fixing data quality at the point of entry rather
--  than patching it in reports forever.
--
--  The three checks that would signal genuine breakage - 1, 3 and 6 -
--  are all zero. An order always has line items, nothing shipped
--  without payment, and every payment total reconciles exactly
--  against its order.
--
--  VERDICT: the pipeline is sound. Report the country gap to whoever
--  owns the signup form; report nothing else as a defect.
--
--  Note what the write-up does: every non-zero number is explained
--  rather than escalated. Handing someone a list of seven counts and
--  letting them panic about the four that are not zero is not
--  analysis - it is forwarding. The value you add is knowing which
--  numbers mean something.
