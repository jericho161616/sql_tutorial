-- =============================================================
--  SOLUTIONS - Week 4: Joins I
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 4.1 - Orders with customer details
-- Expected: 120 rows
-- -------------------------------------------------------------
SELECT o.order_id,
       o.order_date,
       o.status,
       c.first_name,
       c.last_name,
       c.country
FROM   orders o
JOIN   customers c ON c.customer_id = o.customer_id
ORDER  BY o.order_id;

--  120 rows - exactly the number of orders.
--
--  THAT COUNT IS THE POINT. An INNER JOIN from orders to customers
--  returns one row per order only because every order has exactly
--  one matching customer, guaranteed by the foreign key constraint.
--
--  If this had returned FEWER than 120, an order would have a
--  customer_id pointing at a customer that doesn't exist - which the
--  foreign key makes impossible here, but which happens constantly
--  in databases built without constraints.
--
--  If it returned MORE than 120, customers would contain duplicate
--  customer_id values - impossible here because it's the primary key.
--
--  Both those guarantees come from the schema, not from luck. This is
--  what constraints buy you, and it is why week 9 matters.
--
--  Note some rows show NULL in country. Those are the four customers
--  who never supplied one. The join worked perfectly; the underlying
--  data is simply incomplete. A join returning NULLs from the right
--  table is not the same as a join failing.


-- -------------------------------------------------------------
-- Exercise 4.2 - Every customer with their order count
-- Expected: 40 rows, two of them zero
-- -------------------------------------------------------------

-- WRONG VERSION 1 - INNER JOIN loses the customers you care about
--
--     SELECT c.first_name, c.last_name, count(*) AS orders
--     FROM   customers c
--     JOIN   orders o ON o.customer_id = c.customer_id
--     GROUP  BY c.customer_id, c.first_name, c.last_name;
--
--     38 rows. Harriet Lockwood and Kwame Mensah are gone, because
--     they have no rows in `orders` to match against. No error.

-- WRONG VERSION 2 - LEFT JOIN, but count(*) counts the empty row
--
--     SELECT c.first_name, c.last_name, count(*) AS orders
--     FROM      customers c
--     LEFT JOIN orders o ON o.customer_id = c.customer_id
--     GROUP  BY c.customer_id, c.first_name, c.last_name;
--
--     40 rows - but Harriet and Kwame show 1 order each.
--     They have zero. count(*) counts ROWS, and after a LEFT JOIN
--     Harriet still occupies one row: her details plus NULLs where
--     the order should be. count(*) counts it anyway.

-- CORRECT
SELECT    c.first_name,
          c.last_name,
          count(o.order_id) AS orders    -- count a RIGHT-table column
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name
ORDER BY  orders DESC, c.last_name;

--  40 rows. Carlos Mendoza leads with 8. Harriet Lockwood and
--  Kwame Mensah correctly show 0.
--
--  WHY IT WORKS: count(column) skips NULLs, count(*) does not.
--  Harriet's single row has NULL in o.order_id, so count(o.order_id)
--  sees nothing to count and returns 0.
--
--  RULE: after a LEFT JOIN, never count(*). Count a column from the
--  right-hand table. The same applies to sum() and avg() - always
--  aggregate the column you actually mean.
--
--  Note also GROUP BY c.customer_id, c.first_name, c.last_name.
--  Grouping by the primary key as well as the names means two
--  different customers who happen to share a name stay separate.
--  Group by names alone and you would silently merge them.


-- -------------------------------------------------------------
-- Exercise 4.3 - Order lines with product details
-- Expected: 300 rows
-- -------------------------------------------------------------
SELECT oi.order_id,
       p.product_name,
       p.category,
       oi.quantity,
       oi.unit_price          -- the price AT TIME OF SALE
FROM   order_items oi
JOIN   products p ON p.product_id = oi.product_id
ORDER  BY oi.order_id, p.product_name;

--  300 rows - one per order line, which is the row count of
--  order_items. Joining a child table to its parent does not change
--  the child's row count, because each child has exactly one parent.
--  (Joining a PARENT to its CHILDREN is what multiplies rows - that
--  is week 5.)
--
--  THE QUALIFICATION MATTERS HERE. Both tables have a column called
--  unit_price. Writing bare `unit_price` gets you:
--
--      ERROR: column reference "unit_price" is ambiguous
--
--  and you must choose:
--
--      oi.unit_price  - what the customer actually paid, frozen at
--                       the moment of sale. Use this for revenue.
--      p.unit_price   - what we charge for it TODAY.
--
--  Using p.unit_price to calculate historical revenue means last
--  year's totals change every time someone edits a price. That is a
--  genuinely serious bug, and the ambiguity error is the database
--  making you decide on purpose.


-- =============================================================
--  Mini-project - order detail report for order 42
-- =============================================================

SELECT o.order_id,
       o.order_date,
       o.status,
       c.first_name || ' ' || c.last_name AS customer,
       c.email,
       p.product_name,
       p.category,
       oi.quantity,
       oi.unit_price,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100), 2) AS line_total
FROM   orders      o
JOIN   customers   c  ON c.customer_id = o.customer_id
JOIN   order_items oi ON oi.order_id   = o.order_id
JOIN   products    p  ON p.product_id  = oi.product_id
WHERE  o.order_id = 42
ORDER  BY p.product_name;

--  order_date  status     customer     product                 qty  price  line_total
--  2024-07-29  completed  Yuki Tanaka  8-Port Gigabit Switch     5  79.50      397.50
--  2024-07-29  completed  Yuki Tanaka  Archive HDD 4TB           1  89.00       80.10
--  2024-07-29  completed  Yuki Tanaka  UPS 650VA                 4 129.00      516.00
--
--  Build this up one join at a time and check the row count after
--  each step. orders alone: 1 row. Plus customers: still 1. Plus
--  order_items: 3. Plus products: still 3. The step that changes the
--  count is the step that multiplies - and knowing WHICH step did it
--  is how you debug a join that has gone wrong.
--
--  Note the Archive HDD line: 1 x 89.00 would be 89.00, but it has
--  discount_pct = 10, so 89.00 * 0.90 = 80.10. If your third line
--  reads 89.00, you forgot the discount.


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. How many line items does order 42 have?
--
--    3.

-- 2. What is the order total?
SELECT ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100)), 2) AS goods,
       MAX(o.shipping_fee)                                                      AS shipping,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100))
             + MAX(o.shipping_fee), 2)                                          AS order_total
FROM   orders o
JOIN   order_items oi ON oi.order_id = o.order_id
WHERE  o.order_id = 42;
--  goods 993.60 + shipping 14.00 = 1007.60
--
--  Watch the MAX(o.shipping_fee). The shipping fee lives on the ORDER,
--  but this query has one row per LINE, so the fee of 14.00 appears
--  three times. SUM(o.shipping_fee) would give 42.00 - the fee
--  charged three times over.
--
--  MAX() picks it up exactly once. That is not a trick; it is the
--  standard way to carry a parent-level value through a query that
--  has been multiplied by its children. You have just met join
--  fan-out, which is the entire subject of week 5.

-- 3. Why do the customer details repeat on every row?
--
--    Because SQL returns a rectangle. Every row must have a value in
--    every column, so a query joining one order to three line items
--    produces three rows, and the order-level facts - date, status,
--    customer name, email - are copied onto each one.
--
--    There is no way to express "this value belongs to the group, not
--    the row" in a flat result set. The repetition is not redundancy
--    in the data; it is an artefact of flattening a hierarchy
--    (one order, containing several lines) into a grid.
--
--    WHAT I WOULD DO INSTEAD for a support screen:
--
--    Run two queries. One returns the order header - a single row
--    with the order, customer and totals. The other returns the
--    lines. The application shows the header once at the top and the
--    lines in a table beneath it, which is how the data is actually
--    shaped and how a human expects to read it.
--
--    That is the normal pattern in real applications, and it is worth
--    internalising early: the shape that is convenient for SQL is
--    frequently not the shape a person should be shown. A single
--    query returning everything looks efficient and produces a
--    screen where the customer's email is printed three times.
--
--    A third option, once you reach week 7: aggregate the lines into
--    a JSON array with json_agg() so one row carries the header and
--    a nested list of items. That returns the hierarchy intact in a
--    single round trip, which is why APIs tend to do it that way.
