-- =============================================================
--  Nimbus Supply Co. - practice database
--  File 1 of 3: schema (tables, keys, constraints)
--
--  Run order:  01_schema.sql -> 02_seed.sql -> 03_messy_data.sql
--  Dialect:    PostgreSQL 17
--
--  Nimbus is a fictional online retailer. Nothing here is real
--  data, so you can break, drop and rebuild it as often as you like.
-- =============================================================

-- Everything lives in its own schema so it never collides with
-- anything else in the project. `shop` is our namespace.
DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;

-- This makes `customers` mean `shop.customers` for the rest of the session,
-- so you don't have to type the schema name every single time.
SET search_path TO shop, public;


-- -------------------------------------------------------------
-- employees
--   Self-referencing: manager_id points back at this same table.
--   That's what makes a "self-join" possible (you'll meet it in week 5).
-- -------------------------------------------------------------
CREATE TABLE employees (
    employee_id   integer      PRIMARY KEY,
    full_name     text         NOT NULL,
    job_title     text         NOT NULL,
    department    text         NOT NULL,
    manager_id    integer      REFERENCES employees (employee_id),
    hired_on      date         NOT NULL,
    annual_salary numeric(10,2) NOT NULL CHECK (annual_salary > 0)
);

COMMENT ON TABLE  employees            IS 'Nimbus staff. manager_id is a self-reference.';
COMMENT ON COLUMN employees.manager_id IS 'NULL for the CEO, who reports to nobody.';


-- -------------------------------------------------------------
-- customers
--   Note: country is deliberately nullable. Some customers never
--   filled it in. This is your playground for NULL logic (week 2).
-- -------------------------------------------------------------
CREATE TABLE customers (
    customer_id integer     PRIMARY KEY,
    first_name  text        NOT NULL,
    last_name   text        NOT NULL,
    email       text        NOT NULL UNIQUE,
    country     text,                       -- nullable on purpose
    city        text,
    signup_date date        NOT NULL,
    segment     text        NOT NULL DEFAULT 'consumer'
                            CHECK (segment IN ('consumer', 'business', 'education')),
    is_active   boolean     NOT NULL DEFAULT true
);

COMMENT ON COLUMN customers.country IS 'Nullable: not every customer supplied one.';


-- -------------------------------------------------------------
-- products
-- -------------------------------------------------------------
CREATE TABLE products (
    product_id     integer       PRIMARY KEY,
    sku            text          NOT NULL UNIQUE,
    product_name   text          NOT NULL,
    category       text          NOT NULL,
    unit_price     numeric(10,2) NOT NULL CHECK (unit_price >= 0),
    cost_price     numeric(10,2) NOT NULL CHECK (cost_price >= 0),
    stock_qty      integer       NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    is_discontinued boolean      NOT NULL DEFAULT false,
    created_at     date          NOT NULL
);

COMMENT ON COLUMN products.cost_price IS 'What Nimbus paid. unit_price - cost_price = margin.';


-- -------------------------------------------------------------
-- orders
--   status matters a lot. A 'cancelled' order is still a row in
--   this table - forgetting to filter it out is the single most
--   common beginner mistake in revenue reporting.
-- -------------------------------------------------------------
CREATE TABLE orders (
    order_id      integer       PRIMARY KEY,
    customer_id   integer       NOT NULL REFERENCES customers (customer_id),
    order_date    date          NOT NULL,
    status        text          NOT NULL
                                CHECK (status IN ('completed','shipped','pending','cancelled','refunded')),
    ship_country  text,
    shipping_fee  numeric(10,2) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
    discount_code text                        -- nullable: most orders have none
);

COMMENT ON COLUMN orders.status        IS 'Filter this. cancelled/refunded orders are not revenue.';
COMMENT ON COLUMN orders.discount_code IS 'Nullable: NULL means no code was used.';


-- -------------------------------------------------------------
-- order_items
--   The line items of an order. One order has many items, which is
--   why joining orders -> order_items multiplies your rows.
--   Understanding that multiplication is the whole of week 5.
--
--   unit_price is stored again here on purpose: it captures the
--   price *at the time of sale*. If products.unit_price changes
--   next year, historical orders must not silently change value.
--   That is a real data-modelling decision, not a redundancy bug.
-- -------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id integer       PRIMARY KEY,
    order_id      integer       NOT NULL REFERENCES orders (order_id) ON DELETE CASCADE,
    product_id    integer       NOT NULL REFERENCES products (product_id),
    quantity      integer       NOT NULL CHECK (quantity > 0),
    unit_price    numeric(10,2) NOT NULL CHECK (unit_price >= 0),
    discount_pct  numeric(5,2)  NOT NULL DEFAULT 0
                                CHECK (discount_pct >= 0 AND discount_pct <= 100),

    -- The same product should not appear twice on one order;
    -- bump the quantity instead. This is a composite unique constraint.
    UNIQUE (order_id, product_id)
);

COMMENT ON COLUMN order_items.unit_price IS 'Price at time of sale, deliberately copied from products.';


-- -------------------------------------------------------------
-- payments
--   An order can have ZERO payments (never paid) or MORE THAN ONE
--   (paid in instalments, or a retry after a failure).
--   That one-to-many relationship is a trap that inflates totals.
--   You will fall into it in week 5, on purpose, and then learn the fix.
-- -------------------------------------------------------------
CREATE TABLE payments (
    payment_id   integer       PRIMARY KEY,
    order_id     integer       NOT NULL REFERENCES orders (order_id) ON DELETE CASCADE,
    paid_on      date          NOT NULL,
    amount       numeric(10,2) NOT NULL CHECK (amount > 0),
    method       text          NOT NULL
                               CHECK (method IN ('card','paypal','bank_transfer','voucher')),
    status       text          NOT NULL DEFAULT 'captured'
                               CHECK (status IN ('captured','failed','refunded'))
);

COMMENT ON TABLE payments IS 'One order may have 0, 1 or many payment rows.';


-- -------------------------------------------------------------
-- Deliberately NOT indexed (yet).
--
-- Postgres automatically indexes every PRIMARY KEY and UNIQUE
-- constraint above, but the foreign key columns - orders.customer_id,
-- order_items.order_id, payments.order_id - have no index at all.
--
-- That is not an oversight. In week 11 you will run EXPLAIN, see
-- the sequential scans, add the indexes yourself, and watch the
-- plan change. Leave them alone until then.
-- -------------------------------------------------------------
