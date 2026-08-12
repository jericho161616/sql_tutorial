-- =============================================================
--  SOLUTIONS - Week 9: Schema design & DDL
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 9.1 - Critique the bad schema
-- -------------------------------------------------------------
--
--  CREATE TABLE customer_orders (
--      id            varchar(50),
--      customer_name varchar(100),
--      customer_email varchar(100),
--      cust_country  varchar(50),
--      product1      varchar(100),
--      product2      varchar(100),
--      product3      varchar(100),
--      order_total   float,
--      order_date    varchar(20),
--      status        varchar(20),
--      is_paid       varchar(5)
--  );
--
--  1. NO PRIMARY KEY.
--     Nothing stops the same order being inserted twice. You cannot
--     reliably update or delete a single row, and no other table can
--     reference this one. Every count you produce is suspect because
--     duplicates are undetectable.
--
--  2. `id` IS varchar(50).
--     An identifier stored as text sorts wrongly ('10' before '9'),
--     wastes space, and permits ' 42', '42 ' and '042' to coexist as
--     three different orders. Use integer or bigint.
--
--  3. product1 / product2 / product3 - REPEATING GROUPS (breaks 1NF).
--     The worst problem here. "Which orders contain a Rapid SSD?"
--     needs three OR'd conditions. "Total units sold per product" is
--     effectively impossible. And a fourth product cannot be
--     recorded at all - the schema caps the business at three items
--     per order. This is what a child table exists to fix.
--
--  4. NO QUANTITY OR PRICE PER PRODUCT.
--     Even with only three products, you cannot say how many of each
--     were bought or what each cost. order_total is unverifiable -
--     there is nothing to add up and check it against.
--
--  5. order_total IS float.
--     Floating point cannot represent 0.10 exactly. Money totals
--     drift by fractions of a cent, and a report that sums a million
--     rows will not reconcile against one that sums them in a
--     different order. Use numeric(10,2).
--
--  6. order_date IS varchar(20).
--     No date arithmetic without casting, no ordering that respects
--     chronology ('2024-1-5' sorts after '2024-10-05' as text), and
--     '31/02/2024' can be stored happily. The database cannot reject
--     a date that does not exist.
--
--  7. CUSTOMER DATA DUPLICATED ON EVERY ORDER (breaks 3NF).
--     customer_name, customer_email and cust_country depend on the
--     CUSTOMER, not the order. A customer with 8 orders has their
--     email stored 8 times; change it and you must update 8 rows.
--     Miss one and the database now holds two contradictory emails
--     for the same person, with no way to tell which is right.
--
--  8. is_paid IS varchar(5).
--     Accepts 'true', 'TRUE', 'yes', 'Y', '1', 'no', 'nope', ''. You
--     will eventually find all of them. Every query needs a defensive
--     IN list. Use boolean.
--
--  9. NO NOT NULL ANYWHERE.
--     Every column is optional. An order with no date, no customer
--     and no total is a valid row.
--
--  10. NO CHECK CONSTRAINTS.
--      status accepts any string. Expect 'compelted' in production.
--
--  11. INCONSISTENT NAMING.
--      customer_name and customer_email, but cust_country. Small,
--      but it guarantees somebody writes the wrong column name.
--
--  12. varchar(n) LIMITS INVENTED FOR NO REASON.
--      A 105-character product name now fails to insert. In Postgres,
--      text has no performance penalty and no arbitrary ceiling.


-- -------------------------------------------------------------
-- Exercise 9.2 - Build the suppliers table properly
-- -------------------------------------------------------------
CREATE TABLE suppliers (
    supplier_id   integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          text        NOT NULL,
    country       text,
    contact_email text        UNIQUE,
    payment_terms text        NOT NULL DEFAULT 'net30'
                              CHECK (payment_terms IN ('net30','net60','prepaid')),
    is_active     boolean     NOT NULL DEFAULT true,
    created_at    timestamptz NOT NULL DEFAULT now()
);

--  UNIQUE on a nullable column: several suppliers may have NULL
--  contact_email, because in SQL two NULLs are not equal - the
--  uniqueness rule simply does not apply to them. That gives exactly
--  the behaviour asked for: "unique when present".
--
--  timestamptz + DEFAULT now(): the database stamps the row. An
--  application-supplied timestamp is whatever that machine's clock
--  said, which on a second server is a different answer.

ALTER TABLE products ADD COLUMN supplier_id integer REFERENCES suppliers (supplier_id);

--  WHY IT MUST BE NULLABLE WHEN ADDED:
--
--  products already holds 25 rows. Adding a NOT NULL column with no
--  default asks Postgres to invent a value for all 25, which it
--  refuses to do:
--
--      ERROR: column "supplier_id" contains null values
--
--  The correct sequence is three steps, and it is the standard
--  pattern for adding a required column to a populated table:
--
--      1. ADD COLUMN, nullable            -- instant, no lock trouble
--      2. UPDATE to backfill every row    -- can be batched if large
--      3. ALTER COLUMN ... SET NOT NULL   -- only once no NULLs remain
--
--  Trying to do it in one step on a live table is how migrations end
--  up locking a production database in the middle of the day.


-- -------------------------------------------------------------
-- Exercise 9.3 - Test the constraints
-- -------------------------------------------------------------

-- FAIL: name is NOT NULL
INSERT INTO suppliers (name, country) VALUES (NULL, 'Germany');
--  ERROR: null value in column "name" of relation "suppliers"
--         violates not-null constraint

-- FAIL: payment_terms not in the allowed set
INSERT INTO suppliers (name, payment_terms) VALUES ('Bad Terms Ltd', 'net90');
--  ERROR: new row for relation "suppliers" violates check constraint
--         "suppliers_payment_terms_check"

-- FAIL: duplicate contact_email
INSERT INTO suppliers (name, contact_email) VALUES ('First',  'dup@example.com');
INSERT INTO suppliers (name, contact_email) VALUES ('Second', 'dup@example.com');
--  ERROR: duplicate key value violates unique constraint
--         "suppliers_contact_email_key"

-- FAIL: cannot supply an IDENTITY ALWAYS value
INSERT INTO suppliers (supplier_id, name) VALUES (99, 'Override Attempt');
--  ERROR: cannot insert a non-DEFAULT value into column "supplier_id"
--  (GENERATED ALWAYS means the database owns this column absolutely.
--   Use GENERATED BY DEFAULT if applications must be able to set it.)

-- SUCCEEDS
INSERT INTO suppliers (name, country, contact_email, payment_terms)
VALUES ('Cablewerks GmbH', 'Germany', 'sales@cablewerks.example.com', 'net60')
RETURNING supplier_id, name, payment_terms, created_at;

--  WHY THIS EXERCISE IS NOT BUSYWORK:
--
--  A constraint you have never tried to violate is an assumption.
--  Typos in CHECK lists are common and completely silent - write
--  CHECK (status IN ('active','inactve')) and everything works
--  perfectly until somebody types the correctly-spelled word.
--
--  Four failed inserts take two minutes and convert "I think this is
--  protected" into "I know this is protected".


-- =============================================================
--  Mini-project - the returns (RMA) subsystem
-- =============================================================

CREATE TABLE returns (
    return_id     integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      integer     NOT NULL REFERENCES orders (order_id),
    status        text        NOT NULL DEFAULT 'requested'
                              CHECK (status IN ('requested','approved','received',
                                                'refunded','rejected')),
    requested_at  timestamptz NOT NULL DEFAULT now(),
    resolved_at   timestamptz,

    -- a resolved return must have a resolution date, and vice versa
    CONSTRAINT resolved_dates_agree CHECK (
        (status IN ('refunded','rejected') AND resolved_at IS NOT NULL)
     OR (status NOT IN ('refunded','rejected') AND resolved_at IS NULL)
    ),
    CONSTRAINT resolved_after_requested CHECK (
        resolved_at IS NULL OR resolved_at >= requested_at
    )
);

CREATE TABLE return_items (
    return_item_id integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    return_id      integer       NOT NULL REFERENCES returns (return_id) ON DELETE CASCADE,
    product_id     integer       NOT NULL REFERENCES products (product_id),
    quantity       integer       NOT NULL CHECK (quantity > 0),
    reason         text          NOT NULL
                                 CHECK (reason IN ('faulty','wrong_item',
                                                   'unwanted','damaged_in_transit')),
    refund_amount  numeric(10,2) NOT NULL DEFAULT 0 CHECK (refund_amount >= 0),

    UNIQUE (return_id, product_id)
);

CREATE INDEX idx_returns_order_id       ON returns (order_id);
CREATE INDEX idx_return_items_return_id ON return_items (return_id);
CREATE INDEX idx_return_items_product   ON return_items (product_id);


-- -------------------------------------------------------------
-- 2. WHY TWO TABLES AND NOT ONE
-- -------------------------------------------------------------
--
--  Because a return covers ONE ORDER but MANY PRODUCTS, and those are
--  facts at two different levels.
--
--  Order-level facts - which order, the status, when it was requested
--  and resolved - occur exactly once per return.
--  Product-level facts - which product, how many, why, how much was
--  refunded - occur once per returned product.
--
--  Forcing both into one table means either repeating the status and
--  dates on every product line (so a status change means updating
--  several rows, which can partially fail and leave one return in two
--  states at once), or falling back to product1/product2/product3 -
--  exercise 9.1's worst problem.
--
--  THE TEST: say out loud what one row represents. "One return" and
--  "one product within a return" are two different sentences, so
--  they are two tables.


-- -------------------------------------------------------------
-- 3. ON DELETE CHOICES
-- -------------------------------------------------------------
--
--  returns.order_id -> orders          : NO ACTION (the default)
--
--      Deleting an order that has returns against it should FAIL. A
--      return is a financial record; losing it because somebody
--      tidied up an order is unacceptable. Forcing the delete to be
--      refused makes a human decide what should really happen.
--
--  return_items.return_id -> returns   : CASCADE
--
--      A return line has no meaning without its return - it is owned
--      by it. Deleting the parent should take the children with it,
--      otherwise you leave orphan rows referencing nothing.
--
--  return_items.product_id -> products : NO ACTION
--
--      Deleting a product that appears in a return must fail. The
--      historical record must keep pointing at what was returned.
--      (In practice you would soft-delete the product with
--      is_discontinued rather than removing the row at all.)
--
--  THE PRINCIPLE: CASCADE only where the child is genuinely PART OF
--  the parent. Everywhere else, refuse and make a person choose.


-- -------------------------------------------------------------
-- 4. THE RULE A CONSTRAINT CANNOT ENFORCE
-- -------------------------------------------------------------
--
--  "You cannot return more of a product than was ordered."
--
--  A CHECK constraint can only see the columns of the row it is
--  attached to. This rule requires looking at ANOTHER TABLE -
--  comparing return_items.quantity against the matching
--  order_items.quantity for the same order and product. CHECK cannot
--  do that, and Postgres will reject a subquery inside one.
--
--  FOUR WAYS TO ENFORCE IT, worst to best:
--
--  a) In application code only.
--     Works until a second application, a migration script or a
--     manual fix bypasses it. This is what the week 9 concepts
--     section warned about.
--
--  b) A BEFORE INSERT OR UPDATE trigger on return_items that looks up
--     the ordered quantity and raises an exception. Enforced by the
--     database, so nothing can bypass it. The cost is that triggers
--     are invisible - somebody debugging a failed insert has to know
--     to go looking for one.
--
--  c) A CHECK on a redundant column: copy the ordered quantity onto
--     return_items at insert time and CHECK (quantity <= qty_ordered).
--     Cheap and declarative, but the copy can go stale.
--
--  d) BEST IN PRACTICE: a trigger (b) for hard enforcement, PLUS a
--     scheduled data-quality query that reports violations - because
--     a rule enforced only at write time says nothing about rows
--     written before the rule existed.
--
--  THE GENERAL LESSON: constraints handle rules about a single row.
--  Rules spanning tables need triggers, application logic, or
--  periodic checking - and knowing which category a rule falls into
--  is the design skill.


-- -------------------------------------------------------------
-- 5. A VALID RETURN WITH TWO LINES
-- -------------------------------------------------------------
BEGIN;

INSERT INTO returns (order_id, status)
VALUES (42, 'requested')
RETURNING return_id;                       -- assume it returns 1

INSERT INTO return_items (return_id, product_id, quantity, reason, refund_amount)
VALUES (1, 3,  2, 'faulty',             159.00),
       (1, 10, 1, 'damaged_in_transit',  89.00);

SELECT r.return_id, r.order_id, r.status,
       ri.product_id, ri.quantity, ri.reason, ri.refund_amount
FROM   returns r
JOIN   return_items ri ON ri.return_id = r.return_id;

COMMIT;

--  Order 42 contains the 8-Port Gigabit Switch (product 3, qty 5) and
--  the Archive HDD 4TB (product 10, qty 1), so returning 2 of one and
--  1 of the other is legitimate.


-- -------------------------------------------------------------
-- 6. THREE STATEMENTS THAT CORRECTLY FAIL
-- -------------------------------------------------------------

-- FAIL: order does not exist
INSERT INTO returns (order_id) VALUES (99999);
--  ERROR: insert or update on table "returns" violates foreign key
--         constraint "returns_order_id_fkey"

-- FAIL: quantity must be positive
INSERT INTO return_items (return_id, product_id, quantity, reason)
VALUES (1, 3, 0, 'faulty');
--  ERROR: new row for relation "return_items" violates check
--         constraint "return_items_quantity_check"

-- FAIL: same product twice on one return
INSERT INTO return_items (return_id, product_id, quantity, reason)
VALUES (1, 3, 1, 'unwanted');
--  ERROR: duplicate key value violates unique constraint
--         "return_items_return_id_product_id_key"

-- FAIL: refunded status with no resolution date
INSERT INTO returns (order_id, status) VALUES (42, 'refunded');
--  ERROR: new row for relation "returns" violates check constraint
--         "resolved_dates_agree"
--
--  That last one is the most interesting constraint in the design.
--  It enforces a relationship BETWEEN TWO COLUMNS of the same row,
--  which CHECK handles perfectly well - the limitation is only on
--  reaching into other tables. Table-level CHECKs like this are
--  underused, and they catch a whole family of "impossible state"
--  bugs that would otherwise need application code.
