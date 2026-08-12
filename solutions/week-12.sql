-- =============================================================
--  SOLUTIONS - Week 12: Views, security & capstone
--
--  The capstone has no single right answer. What follows is one
--  worked version. Yours will differ; judge it on whether every
--  number is defensible and every caveat is stated.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 12.1 - customer_summary view
-- Expected: 40 rows
-- -------------------------------------------------------------
CREATE OR REPLACE VIEW customer_summary AS
WITH order_totals AS (
    SELECT   o.order_id,
             o.customer_id,
             o.order_date,
             round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS order_value
    FROM     orders o
    JOIN     order_items oi ON oi.order_id = o.order_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY o.order_id, o.customer_id, o.order_date
),
per_customer AS (
    SELECT   customer_id,
             count(*)              AS total_orders,
             round(sum(order_value), 2) AS total_revenue,
             min(order_date)       AS first_order_date,
             max(order_date)       AS last_order_date
    FROM     order_totals
    GROUP BY customer_id
)
SELECT c.customer_id,
       c.first_name || ' ' || c.last_name        AS full_name,
       c.email,
       c.country,
       c.segment,
       COALESCE(p.total_orders, 0)               AS total_orders,
       COALESCE(p.total_revenue, 0.00)           AS total_revenue,
       p.first_order_date,
       p.last_order_date,
       CASE WHEN p.last_order_date IS NULL THEN NULL
            ELSE (CURRENT_DATE - p.last_order_date)
       END                                        AS days_since_last_order
FROM      customers c
LEFT JOIN per_customer p ON p.customer_id = c.customer_id;

--  40 rows - every customer, including the two who never ordered.
--
--  NOTE THE TWO-CTE STRUCTURE. order_totals collapses order_items to
--  one row per order; per_customer then rolls those up. Doing both in
--  one step would make count(*) count line items and call them
--  orders. Aggregate in the order the grain changes.
--
--  days_since_last_order stays NULL rather than becoming 0 for
--  customers who never ordered. Zero would mean "ordered today",
--  which is the opposite of the truth. NULL means "not applicable",
--  and that is exactly what it should say.

-- Top 5 by revenue
SELECT full_name, country, total_orders, total_revenue
FROM   customer_summary
ORDER  BY total_revenue DESC
LIMIT  5;

-- Customers who have never ordered
SELECT full_name, email, country, signup_date
FROM   customer_summary cs
JOIN   customers c USING (customer_id)
WHERE  cs.total_orders = 0;
--  2 rows: Harriet Lockwood, Kwame Mensah - both signed up late 2025.

-- Dormant: no order in over 300 days
SELECT full_name, country, total_revenue, last_order_date, days_since_last_order
FROM   customer_summary
WHERE  days_since_last_order > 300
ORDER  BY total_revenue DESC;
--
--  Note this correctly EXCLUDES the never-ordered customers, because
--  their days_since_last_order is NULL and NULL > 300 is not true
--  (week 2). Whether that is what you want is a real question: a
--  "reach out to dormant customers" list arguably should include
--  people who never started. Decide deliberately rather than
--  inheriting whatever NULL comparison happens to do.


-- -------------------------------------------------------------
-- Exercise 12.2 - Materialised view and staleness
-- -------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS monthly_revenue_mv AS
SELECT   date_trunc('month', o.order_date)::date AS month,
         count(DISTINCT o.order_id)              AS orders,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS revenue
FROM     orders o
JOIN     order_items oi ON oi.order_id = o.order_id
WHERE    o.status IN ('completed','shipped')
GROUP BY 1;

SELECT * FROM monthly_revenue_mv ORDER BY month DESC LIMIT 3;

BEGIN;

INSERT INTO orders (order_id, customer_id, order_date, status, shipping_fee)
VALUES (9001, 1, CURRENT_DATE, 'completed', 10.00);

INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
VALUES (9001, 9001, 9, 2, 529.00);

-- 2. Query again WITHOUT refreshing
SELECT * FROM monthly_revenue_mv ORDER BY month DESC LIMIT 3;
--  UNCHANGED. The new $1,058 order is invisible.

-- 3. Refresh, then query
REFRESH MATERIALIZED VIEW monthly_revenue_mv;
SELECT * FROM monthly_revenue_mv ORDER BY month DESC LIMIT 3;
--  Now the current month appears with the new order included.

ROLLBACK;
REFRESH MATERIALIZED VIEW monthly_revenue_mv;   -- undo the refresh too

-- 4. WHAT THIS MEANS FOR A DASHBOARD:
--
--  A materialised view is a PHOTOGRAPH, not a window. Between
--  refreshes it serves the state of the world at the moment of the
--  last REFRESH, with total confidence and no indication of age.
--
--  THE DANGEROUS PART IS THAT IT LOOKS IDENTICAL TO A WORKING ONE.
--  A refresh job that silently fails produces a dashboard that keeps
--  loading instantly and showing plausible numbers - last week's.
--  Nobody notices until a figure is challenged, and by then several
--  decisions have been made on stale data.
--
--  IF YOU USE ONE, DISPLAY ITS AGE. Store the refresh time and put it
--  on the dashboard:
--
--      CREATE TABLE mv_refresh_log (
--          view_name    text        PRIMARY KEY,
--          refreshed_at timestamptz NOT NULL
--      );
--
--  Then show "as at 04:00 today" beside the numbers. A stale figure
--  labelled with its age is useful. A stale figure labelled as
--  current is a lie the system tells on your behalf.
--
--  Use a plain VIEW unless you have measured that the query is too
--  slow. Correct-and-slower beats fast-and-possibly-wrong for
--  anything a decision rests on.


-- -------------------------------------------------------------
-- Exercise 12.3 - Least privilege
-- -------------------------------------------------------------

-- 1. Reporting dashboard - read-only, must not see emails
CREATE ROLE reporting_dashboard NOLOGIN;
GRANT USAGE ON SCHEMA shop TO reporting_dashboard;
GRANT SELECT ON orders, order_items, products, payments TO reporting_dashboard;
GRANT SELECT (customer_id, first_name, last_name, country, city, segment,
              signup_date, is_active)
      ON customers TO reporting_dashboard;      -- email deliberately omitted
GRANT SELECT ON customer_summary TO reporting_dashboard;

--  DAMAGE IF COMPROMISED: an attacker can read sales figures and
--  customer names, but gets no email addresses - so no phishing list,
--  and no ability to change or delete anything. Commercially
--  embarrassing, not operationally serious.
--
--  NOTE THE LEAK: customer_summary SELECTS c.email, so granting
--  access to the view hands over the very column the table grant
--  withheld. Views run with their OWNER's privileges by default.
--  Either build a separate view without email, or declare it
--  WITH (security_invoker = true) so it runs as the caller and the
--  column grant applies. This is an easy and common mistake - a
--  careful table grant undone by a view nobody re-checked.

-- 2. Warehouse app - reads products and orders, updates stock only
CREATE ROLE warehouse_app LOGIN PASSWORD 'change-me-to-something-strong';
GRANT USAGE ON SCHEMA shop TO warehouse_app;
GRANT SELECT ON products, orders, order_items TO warehouse_app;
GRANT UPDATE (stock_qty) ON products TO warehouse_app;
GRANT INSERT, SELECT ON stock_adjustments TO warehouse_app;
-- deliberately NOT granted: UPDATE or DELETE on stock_adjustments

--  DAMAGE IF COMPROMISED: stock levels can be corrupted, which is
--  disruptive and recoverable - every change is in the append-only
--  audit log, so the real values can be reconstructed. Prices,
--  customers and payments cannot be touched. The column-level UPDATE
--  grant means even a total compromise of this app cannot alter a
--  product's price.

-- 3. Data engineer - full access to shop, cannot create roles
CREATE ROLE data_engineer LOGIN PASSWORD 'change-me-too';
GRANT USAGE, CREATE ON SCHEMA shop TO data_engineer;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA shop TO data_engineer;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA shop TO data_engineer;
ALTER DEFAULT PRIVILEGES IN SCHEMA shop
      GRANT ALL PRIVILEGES ON TABLES TO data_engineer;
-- NOT granted: SUPERUSER, CREATEROLE, CREATEDB

--  DAMAGE IF COMPROMISED: severe - all data in `shop` can be read,
--  altered or dropped. But the blast radius stops at this schema:
--  no new roles can be minted, no other database touched, no
--  privileges escalated. That containment is the entire point of not
--  handing out superuser.
--
--  ALTER DEFAULT PRIVILEGES matters: GRANT ... ON ALL TABLES only
--  covers tables that exist RIGHT NOW. Without the default-privileges
--  line, every table created next month is invisible to this role,
--  and somebody "fixes" it by granting superuser.


-- =============================================================
--  CAPSTONE - the Nimbus executive dashboard
--  (one worked version)
-- =============================================================

-- ---------- View 1: the single definition of revenue ----------
CREATE OR REPLACE VIEW v_order_revenue AS
SELECT   o.order_id,
         o.customer_id,
         o.order_date,
         o.status,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100)), 2) AS goods,
         max(o.shipping_fee)                                                     AS shipping,
         round(sum(oi.quantity * oi.unit_price * (1 - oi.discount_pct/100))
               + max(o.shipping_fee), 2)                                         AS total
FROM     orders o
JOIN     order_items oi ON oi.order_id = o.order_id
WHERE    o.status IN ('completed','shipped')
GROUP BY o.order_id, o.customer_id, o.order_date, o.status, o.shipping_fee;

--  FAN-OUT VERIFICATION - how I know this is right:
--      SELECT count(*) FROM v_order_revenue;        -- 98
--      SELECT count(*) FROM orders
--       WHERE status IN ('completed','shipped');    -- 98
--  Equal, so exactly one row per qualifying order. max(shipping_fee)
--  rather than sum() means the fee is counted once, not once per
--  line. Confirm against the unjoined truth:
--      SELECT sum(shipping_fee) FROM orders WHERE status IN (...);

-- ---------- View 2: gap-free monthly series ----------
CREATE OR REPLACE VIEW v_monthly AS
WITH months AS (
    SELECT generate_series(
             (SELECT date_trunc('month', min(order_date)) FROM orders),
             (SELECT date_trunc('month', max(order_date)) FROM orders),
             INTERVAL '1 month')::date AS month
),
m AS (
    SELECT   date_trunc('month', order_date)::date AS month,
             count(*)                              AS orders,
             count(DISTINCT customer_id)           AS customers,
             round(sum(total), 2)                  AS revenue
    FROM     v_order_revenue
    GROUP BY 1
)
SELECT    mo.month,
          COALESCE(m.orders, 0)      AS orders,
          COALESCE(m.customers, 0)   AS customers,
          COALESCE(m.revenue, 0.00)  AS revenue
FROM      months mo
LEFT JOIN m ON m.month = mo.month;

--  Bounds derived from the data, not hard-coded - so the report
--  cannot silently stop counting when new data arrives.

-- ---------- View 3: customer lifetime value ----------
CREATE OR REPLACE VIEW v_customer_ltv AS
SELECT    c.customer_id,
          c.first_name || ' ' || c.last_name AS full_name,
          c.country,
          c.segment,
          COALESCE(count(r.order_id), 0)     AS orders,
          COALESCE(round(sum(r.total), 2), 0.00) AS lifetime_value,
          max(r.order_date)                  AS last_order_date
FROM      customers c
LEFT JOIN v_order_revenue r ON r.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name, c.country, c.segment;

-- ---------- View 4: data-quality checks, shown not hidden ----------
CREATE OR REPLACE VIEW v_data_quality AS
SELECT 'customers with no country'    AS check_name,
       count(*) AS n FROM customers WHERE country IS NULL
UNION ALL SELECT 'customers who never ordered', count(*)
  FROM customers c WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id=c.customer_id)
UNION ALL SELECT 'products never sold', count(*)
  FROM products p WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id=p.product_id)
UNION ALL SELECT 'orders with no payment', count(*)
  FROM orders o WHERE NOT EXISTS (SELECT 1 FROM payments p WHERE p.order_id=o.order_id)
UNION ALL SELECT 'likely test accounts', count(*)
  FROM customers WHERE first_name ILIKE ANY (ARRAY['test','anonymous']) OR email ILIKE '%test%';


-- ---------- The dashboard questions ----------

-- Q1: revenue and month-over-month movement
SELECT to_char(month,'YYYY-MM') AS mth, orders, revenue,
       round(revenue - lag(revenue) OVER (ORDER BY month), 2) AS change,
       round(100.0*(revenue - lag(revenue) OVER (ORDER BY month))
             / NULLIF(lag(revenue) OVER (ORDER BY month),0), 1) AS pct,
       round(sum(revenue) OVER (ORDER BY month), 2) AS running_total
FROM   v_monthly ORDER BY month;

-- Q2: top 10 customers and their share of revenue
WITH total AS (SELECT sum(lifetime_value) AS all_revenue FROM v_customer_ltv)
SELECT   l.full_name, l.country, l.orders, l.lifetime_value,
         round(100.0 * l.lifetime_value / t.all_revenue, 1) AS pct_of_revenue,
         round(100.0 * sum(l.lifetime_value) OVER (ORDER BY l.lifetime_value DESC)
               / t.all_revenue, 1) AS cumulative_pct
FROM     v_customer_ltv l CROSS JOIN total t
ORDER BY l.lifetime_value DESC
LIMIT    10;

-- Q3: category growth, first half vs second half
WITH cat AS (
    SELECT   p.category,
             sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100))
               FILTER (WHERE o.order_date < DATE '2025-01-01') AS y2024,
             sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100))
               FILTER (WHERE o.order_date >= DATE '2025-01-01') AS y2025
    FROM     orders o
    JOIN     order_items oi ON oi.order_id=o.order_id
    JOIN     products p ON p.product_id=oi.product_id
    WHERE    o.status IN ('completed','shipped')
    GROUP BY p.category
)
SELECT category, round(y2024,2) AS y2024, round(y2025,2) AS y2025,
       round(100.0*(y2025-y2024)/NULLIF(y2024,0), 1) AS pct_change
FROM   cat ORDER BY pct_change DESC NULLS LAST;

-- Q4: lapsed customers - bought in 2024, silent for 6 months
SELECT full_name, country, orders, lifetime_value, last_order_date
FROM   v_customer_ltv
WHERE  last_order_date < (SELECT max(order_date) FROM orders) - INTERVAL '6 months'
ORDER  BY lifetime_value DESC;
--  Measured against the latest date IN THE DATA, not CURRENT_DATE.
--  Against today's date every customer looks lapsed, because the
--  dataset ends in October 2025 - an artefact of the data, not a
--  business fact.

-- Q5: products never sold  (anti-join)
SELECT p.product_id, p.sku, p.product_name, p.category, p.stock_qty, p.is_discontinued
FROM   products p
WHERE  NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id);

-- Q6: revenue at risk in unpaid / pending orders
SELECT   o.status,
         count(DISTINCT o.order_id) AS orders,
         round(sum(oi.quantity*oi.unit_price*(1-oi.discount_pct/100)), 2) AS value_at_risk
FROM     orders o
JOIN     order_items oi ON oi.order_id = o.order_id
WHERE    o.status = 'pending'
   OR    NOT EXISTS (SELECT 1 FROM payments p
                     WHERE p.order_id = o.order_id AND p.status = 'captured')
GROUP BY o.status;

SELECT * FROM v_data_quality;


-- =============================================================
--  WRITE-UP  (under 400 words)
-- =============================================================
--
--  FINDINGS
--
--  1. Revenue totals roughly $107,600 across 98 completed and shipped
--     orders, running at about $4,300 a month. Growth is flat, not
--     rising: the running total climbs steadily because time passes,
--     not because monthly revenue is increasing.
--
--  2. Revenue is concentrated. The top 10 of 38 buying customers
--     account for a large share of lifetime value, led by Carlos
--     Mendoza at $8,930.55 - roughly four times the median customer's
--     $2,380.50. Losing two or three accounts would be material.
--
--  3. Networking is the largest category at $37,358.85, followed by
--     Storage at $27,086.10. Cables contribute $2,468.63 - under 3% -
--     despite carrying three active products.
--
--  4. Two products have never sold a single unit. Both are flagged
--     discontinued, so this is expected rather than a problem, but
--     they still hold stock: 6 and 14 units respectively.
--
--  5. Ten pending orders carry unpaid value. All 17 orders without a
--     payment record are either pending or cancelled, and no
--     completed or shipped order is unpaid - so the collections
--     position is clean and the exposure is only the pending queue.
--
--  CAVEATS - read before acting on any figure above
--
--  a) THE FIRST AND LAST MONTHS ARE PARTIAL. Data starts 17 January
--     2024 and ends 18 October 2025. January shows $453 from one
--     order, which makes February look like 1,407% growth - it is
--     not, it is a partial month. October will likewise look like a
--     collapse on any chart. Exclude both from trend readings.
--
--  b) FOUR CUSTOMERS HAVE NO COUNTRY, affecting 13 orders. Every
--     country-level breakdown above is missing those, and a naive
--     `WHERE country <> 'X'` filter would silently drop them from
--     both sides of any comparison. Publish a "country unknown" line
--     rather than letting totals quietly fail to reconcile.
--
--  c) AT LEAST TWO ACCOUNTS ARE TEST DATA sitting in the production
--     customer table, and one more has the literal string 'Unknown'
--     in its city field. Customer counts are overstated by a small
--     amount and the placeholder text will survive every NULL check.
--
--  WHAT I CANNOT MEASURE WITH THIS SCHEMA
--
--  Acquisition channel. There is no way to tell how a customer found
--  Nimbus, so "which channel produces the highest-value customers" -
--  the question that would actually direct the marketing budget - is
--  unanswerable. I would add a `source` column to `customers`,
--  populated at signup, and a `channel` on `orders` for attribution.
--  Until then, any claim about what drives acquisition is a guess.
