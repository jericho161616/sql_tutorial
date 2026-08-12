-- =============================================================
--  SOLUTIONS - Week 10: Writing data safely
--
--  Every destructive statement below is wrapped in BEGIN/ROLLBACK
--  so you can run this file repeatedly without changing anything.
--  That is not a tutorial convenience - it is the working habit.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 10.1 - Insert with RETURNING
-- -------------------------------------------------------------
BEGIN;

INSERT INTO suppliers (name, country, contact_email, payment_terms)
VALUES ('Pacific Components Pte Ltd', 'Singapore', 'orders@pacificcomp.example.com', 'net60'),
       ('Nordic Power Systems',       'Norway',    'sales@nordicpower.example.com',  'prepaid')
RETURNING supplier_id, name, payment_terms;

--  supplier_id | name                       | payment_terms
--            2 | Pacific Components Pte Ltd | net60
--            3 | Nordic Power Systems       | prepaid
--
--  RETURNING hands back the generated IDs immediately. Without it you
--  would need a follow-up SELECT, and that SELECT has to guess which
--  rows were yours - genuinely awkward under concurrency, where
--  another session may have inserted between your two statements.

-- The one that fails:
INSERT INTO suppliers (name, payment_terms)
VALUES ('Dodgy Terms Inc', 'net90');
--  ERROR: new row for relation "suppliers" violates check constraint
--         "suppliers_payment_terms_check"
--  DETAIL: Failing row contains (4, Dodgy Terms Inc, null, null, net90, t, ...)
--
--  Note the whole statement is rejected and NOTHING is written. Note
--  also that supplier_id 4 was consumed - identity sequences do not
--  roll back, by design, because two sessions must never be handed
--  the same number. Gaps in an ID sequence are normal and mean
--  nothing. Do not try to "fix" them.

ROLLBACK;


-- -------------------------------------------------------------
-- Exercise 10.2 - A safe, verified UPDATE
-- -------------------------------------------------------------

-- STEP 1: add the column (nullable, so it is instant and safe)
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_physical boolean;

-- STEP 2: LOOK FIRST. What am I about to change?
SELECT product_id, product_name, category, stock_qty
FROM   products
WHERE  category = 'Software';
--  2 rows: Nimbus Backup 1-Year, Nimbus Monitor 1-Year.
--  Two is what I expected. If this had returned 25, my WHERE clause
--  is wrong and I have just found out for free.

BEGIN;

-- STEP 3: the change, with RETURNING so I can see it
UPDATE products
SET    is_physical = false
WHERE  category = 'Software'
RETURNING product_id, product_name, is_physical;
--  2 rows returned. Correct.

UPDATE products
SET    is_physical = true
WHERE  category <> 'Software'
RETURNING product_id, category, is_physical;
--  23 rows returned. 2 + 23 = 25 = every product. Nothing missed.

-- STEP 4: VERIFY before committing
SELECT is_physical, count(*)
FROM   products
GROUP  BY is_physical;
--  false  2
--  true  23
--  No NULLs left, and the counts add to 25.

COMMIT;

-- STEP 5: now that no NULLs remain, the column can be made required
ALTER TABLE products ALTER COLUMN is_physical SET NOT NULL;

--  WATCH THE SECOND UPDATE'S WHERE CLAUSE.
--
--  `WHERE category <> 'Software'` works here only because category is
--  NOT NULL. Had it been nullable, the four-rows-vanish problem from
--  week 2 would apply: rows with a NULL category would match neither
--  UPDATE and would silently keep is_physical = NULL, and then the
--  SET NOT NULL in step 5 would fail.
--
--  The GROUP BY in step 4 is what catches that. The counts must add
--  up to the table total - the same arithmetic check as week 2.


-- -------------------------------------------------------------
-- Exercise 10.3 - Transaction and rollback
-- -------------------------------------------------------------
BEGIN;

-- 1. before
SELECT product_id, product_name, stock_qty
FROM   products WHERE product_id IN (6, 7);
--  6  Rapid SSD 500GB  340
--  7  Rapid SSD 1TB    285
--  total 625

-- 2. the transfer
UPDATE products SET stock_qty = stock_qty - 10 WHERE product_id = 6;
UPDATE products SET stock_qty = stock_qty + 10 WHERE product_id = 7;

-- 3. verify the total is unchanged
SELECT sum(stock_qty) AS total_after
FROM   products WHERE product_id IN (6, 7);
--  625. Conserved - stock moved, none created or destroyed.

-- 4. undo
ROLLBACK;

SELECT product_id, stock_qty FROM products WHERE product_id IN (6, 7);
--  340 and 285 again. The rollback restored both.

--  WHAT BREAKS WITHOUT THE TRANSACTION:
--
--  If the two UPDATEs run as separate statements and the connection
--  drops - server restart, network blip, laptop lid closed - between
--  them, the first has committed and the second never runs.
--
--  Ten units have been REMOVED FROM THE UNIVERSE. Stock says 330 and
--  285: 615 total, ten short. No error was raised anywhere; the first
--  statement succeeded exactly as instructed.
--
--  Nothing in the database records that a transfer was in progress,
--  so nobody can tell whether 330 is correct or the residue of a
--  half-finished operation. You find out weeks later during a stock
--  count, with no way to reconstruct what happened.
--
--  This is ATOMICITY, the A in ACID, and it is the entire reason
--  transactions exist. Any operation that must change two things is
--  one transaction, always.

-- THE VERSION THAT CORRECTLY FAILS:
BEGIN;
UPDATE products SET stock_qty = stock_qty - 10000 WHERE product_id = 6;
--  ERROR: new row for relation "products" violates check constraint
--         "products_stock_qty_check"
--  DETAIL: Failing row contains (6, ST-SSD-500, ..., -9660, ...)
ROLLBACK;
--
--  Caught by CHECK (stock_qty >= 0) from the original schema. The
--  database refused to enter an impossible state - negative physical
--  stock - without any application code being involved.
--
--  This is week 9's argument made concrete. The constraint was
--  written once, a year ago, and it just stopped a bug in code that
--  did not exist when it was written.


-- =============================================================
--  Mini-project - safe stock adjustments
-- =============================================================

CREATE TABLE IF NOT EXISTS stock_adjustments (
    adjustment_id integer     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id    integer     NOT NULL REFERENCES products (product_id),
    qty_before    integer     NOT NULL,
    qty_change    integer     NOT NULL CHECK (qty_change <> 0),
    qty_after     integer     NOT NULL CHECK (qty_after >= 0),
    reason        text        NOT NULL CHECK (reason IN ('damage','recount','delivery','theft')),
    adjusted_by   text        NOT NULL,
    adjusted_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT arithmetic_holds CHECK (qty_after = qty_before + qty_change)
);

CREATE INDEX IF NOT EXISTS idx_stock_adj_product ON stock_adjustments (product_id, adjusted_at);


-- -------------------------------------------------------------
-- An adjustment: 12 units of product 1 damaged
-- -------------------------------------------------------------
BEGIN;

WITH before AS (
    SELECT stock_qty FROM products WHERE product_id = 1 FOR UPDATE
),
updated AS (
    UPDATE products
    SET    stock_qty = stock_qty - 12
    WHERE  product_id = 1
    RETURNING stock_qty AS qty_after
)
INSERT INTO stock_adjustments (product_id, qty_before, qty_change, qty_after,
                               reason, adjusted_by)
SELECT 1, b.stock_qty, -12, u.qty_after, 'damage', 'hannah.boateng'
FROM   before b CROSS JOIN updated u
RETURNING adjustment_id, product_id, qty_before, qty_change, qty_after;

--  adjustment_id | product_id | qty_before | qty_change | qty_after
--              1 |          1 |        120 |        -12 |       108

SELECT stock_qty FROM products WHERE product_id = 1;   -- 108

COMMIT;

--  `FOR UPDATE` locks the product row for the duration of the
--  transaction, so two warehouse staff adjusting the same product at
--  the same moment cannot both read 120 and both write 108, losing
--  one of the two adjustments. That failure has a name - a lost
--  update - and it is the most common concurrency bug in
--  read-modify-write code.


-- -------------------------------------------------------------
-- Proving it fails safely
-- -------------------------------------------------------------
BEGIN;

UPDATE products SET stock_qty = stock_qty - 9999 WHERE product_id = 1;
--  ERROR: violates check constraint "products_stock_qty_check"

ROLLBACK;

SELECT (SELECT stock_qty FROM products WHERE product_id = 1)      AS stock,
       (SELECT count(*) FROM stock_adjustments WHERE product_id = 1) AS audit_rows;
--  Stock unchanged, and NO audit row was written.
--
--  That is the property that matters. The audit log and the stock
--  level cannot disagree, because a failure rolls back both. An
--  audit row describing an adjustment that never happened is worse
--  than no audit log at all - it is a confident record of a lie.


-- -------------------------------------------------------------
-- Mini-project questions
-- -------------------------------------------------------------

-- 1. Why record qty_before AND qty_after when qty_change implies them?
--
--    Three reasons, and the third is the real one.
--
--    a) It makes the log self-verifying. The CHECK constraint
--       `qty_after = qty_before + qty_change` means a row that does
--       not add up cannot be written. With only qty_change, no such
--       check is possible.
--
--    b) It survives history. Reconstructing stock at a past date from
--       change deltas alone requires replaying every adjustment from
--       the beginning, and one missing row corrupts everything after
--       it. Absolute values let you read any single row and know the
--       state at that moment.
--
--    c) IT DETECTS CHANGES MADE OUTSIDE THIS PROCESS. If adjustment
--       10 ends at qty_after 108 and adjustment 11 starts at
--       qty_before 95, something modified the stock without logging
--       it. Deltas alone can never reveal that gap - the numbers
--       would simply be wrong, consistently and invisibly.
--
--    Storing both is technically redundant. It is the good kind of
--    redundancy: it exists to make errors detectable, which is a
--    different purpose from storing a fact twice.

-- 2. Why must both statements be in one transaction?
--
--    Because otherwise a failure between them leaves stock and audit
--    log permanently contradicting each other.
--
--    If the UPDATE commits and the INSERT fails, stock has moved with
--    no record of why - the exact situation the audit log exists to
--    prevent. If the INSERT commits and the UPDATE fails, the log
--    claims an adjustment that never happened, and anyone
--    reconciling the two finds a discrepancy they cannot explain.
--
--    Either way you now have two sources of truth that disagree, and
--    no way to determine which is right. The transaction makes the
--    pair a single indivisible fact.

-- 3. What is wrong with adjusted_by being text?
--
--    It is an unvalidated string. 'hannah.boateng', 'Hannah Boateng',
--    'hboateng', 'hannah' and 'admin' will all appear, and they are
--    the same person. Grouping adjustments by who made them becomes
--    guesswork, and a departed employee's name lives on with no link
--    to a real identity.
--
--    IN A REAL SYSTEM: a foreign key to employees.employee_id, or to
--    a proper users table. That gives referential integrity, a single
--    canonical name, and the ability to join to role and department.
--
--    Worth noting the tension, though: a foreign key to employees
--    means an employee row can never be deleted while their
--    adjustments exist (correctly - NO ACTION), and audit records
--    should outlive employment. The usual resolution is to keep the
--    FK and soft-delete employees rather than removing them.

-- 4. Should stock_adjustments rows ever be updated or deleted?
--
--    NO. It is an append-only audit log, and that is the whole point.
--
--    An audit log answers one question: "what actually happened?" A
--    log that can be edited answers a different and useless question:
--    "what does someone currently want me to believe happened?" The
--    moment rows can be changed, the log stops being evidence.
--
--    Corrections are made by APPENDING a compensating adjustment, not
--    by editing the mistake. If 12 units were logged as damaged and
--    it was really 10, you add a +2 'recount' row. Both rows survive,
--    the sequence is intact, and the error itself remains visible -
--    which is often the more useful piece of information.
--
--    ENFORCING IT: revoke UPDATE and DELETE on the table from every
--    role that writes to it.
--
--        REVOKE UPDATE, DELETE ON stock_adjustments FROM warehouse_app;
--        GRANT  INSERT, SELECT ON stock_adjustments TO warehouse_app;
--
--    An append-only policy that depends on everyone remembering not
--    to run DELETE is not a policy. Permissions make it real - which
--    is week 12.
