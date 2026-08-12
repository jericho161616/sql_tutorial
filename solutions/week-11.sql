-- =============================================================
--  SOLUTIONS - Week 11: Indexes & performance
--
--  Your exact numbers will differ - plans depend on statistics,
--  Postgres version and what else the server is doing. The SHAPE of
--  the plan and the reasoning are what matter, not the milliseconds.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- Exercise 11.1 - Read a plan
-- -------------------------------------------------------------
EXPLAIN ANALYZE
SELECT c.first_name, c.last_name, count(o.order_id) AS orders
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name;

--  REAL OUTPUT from this database:
--
--  HashAggregate  (cost=23.14..26.64 rows=350 width=76)
--                 (actual time=0.182..0.191 rows=40 loops=1)
--    Group Key: c.customer_id
--    Batches: 1  Memory Usage: 37kB
--    ->  Hash Right Join  (cost=17.88..21.39 rows=350 width=72)
--                         (actual time=0.114..0.157 rows=122 loops=1)
--          Hash Cond: (o.customer_id = c.customer_id)
--          ->  Seq Scan on orders o  (cost=0.00..3.20 rows=120 width=8)
--                                    (actual time=0.027..0.038 rows=120 loops=1)
--          ->  Hash  (cost=13.50..13.50 rows=350 width=68)
--                    (actual time=0.063..0.064 rows=40 loops=1)
--                Buckets: 1024  Batches: 1  Memory Usage: 11kB
--                ->  Seq Scan on customers c  (cost=0.00..13.50 rows=350 width=68)
--                                             (actual time=0.046..0.050 rows=40 loops=1)
--  Planning Time: 2.083 ms
--  Execution Time: 0.375 ms

-- HOW TO READ IT: plans are trees, and you read them INSIDE OUT and
-- BOTTOM UP. The most indented nodes run first.
--
--  1. Seq Scan on customers  - read all 40 customers
--  2. Hash                   - build a hash table from them (11kB)
--  3. Seq Scan on orders     - read all 120 orders
--  4. Hash Right Join        - probe the hash table with each order
--  5. HashAggregate          - group the results and count
--
-- SCAN TYPES: two sequential scans, no index scans. Expected - there
-- are no indexes on these columns yet, and both tables are tiny.
--
-- JOIN ALGORITHM: Hash Join. Postgres chose it because both inputs
-- are small and the join is on equality. The alternatives are Nested
-- Loop (good when one side is tiny and the other is indexed) and
-- Merge Join (good when both inputs are already sorted).
--
-- NOTE IT SAYS "Hash RIGHT Join" THOUGH WE WROTE "LEFT JOIN".
-- The planner swapped the table order - it scans orders and probes a
-- hash built from customers, which is cheaper than the reverse. A
-- RIGHT JOIN with the operands flipped is logically identical to our
-- LEFT JOIN. The planner is free to do this; the result is unchanged.
--
-- ROW COUNTS - THE MOST IMPORTANT LINE:
--
--      estimated rows=350   actual rows=40
--
-- The planner expected 350 customers and found 40. That is nearly a
-- 9x overestimate, and it is why the whole plan carries rows=350.
-- The cause is stale statistics: nothing has run ANALYZE since the
-- data was loaded, so Postgres is working from defaults rather than
-- measurements.
--
-- On a 40-row table this costs nothing. On a real table a 9x
-- misestimate is how you get a Nested Loop chosen for ten million
-- rows and a query that should take 200ms taking forty minutes.
--
-- THE FIX IS ONE COMMAND:
ANALYZE customers;
ANALYZE orders;
ANALYZE order_items;
ANALYZE payments;
ANALYZE products;
-- Re-run the EXPLAIN and the estimate should now be close to 40.
--
-- WHENEVER A PLAN LOOKS INSANE, CHECK THE ESTIMATE AGAINST THE ACTUAL
-- FIRST. Stale statistics are the single most common cause of a
-- catastrophically bad plan, and ANALYZE is free.
--
-- THE JOIN PRODUCED 122 ROWS from 120 orders. Those two extra rows
-- are Harriet Lockwood and Kwame Mensah - the customers with no
-- orders, preserved by the LEFT JOIN exactly as week 4 described.
-- The plan is quietly confirming the join type is doing its job.
--
-- PLANNING 2.083ms vs EXECUTION 0.375ms:
-- Postgres spent five times longer DECIDING how to run this query
-- than running it. That single fact explains the whole of exercise
-- 11.2 before you run it.


-- -------------------------------------------------------------
-- Exercise 11.2 - Index every foreign key
-- -------------------------------------------------------------
CREATE INDEX idx_orders_customer_id      ON orders      (customer_id);
CREATE INDEX idx_order_items_order_id    ON order_items (order_id);
CREATE INDEX idx_order_items_product_id  ON order_items (product_id);
CREATE INDEX idx_payments_order_id       ON payments    (order_id);

ANALYZE orders;
ANALYZE order_items;
ANALYZE payments;

-- Naming convention: idx_<table>_<column(s)>. Boring and predictable
-- beats clever. When a plan mentions an index you should know what it
-- covers without going to look it up.

-- Re-run exercise 11.1's query:
EXPLAIN ANALYZE
SELECT c.first_name, c.last_name, count(o.order_id) AS orders
FROM      customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY  c.customer_id, c.first_name, c.last_name;

-- DID THE PLAN CHANGE? Almost certainly not - still two Seq Scans and
-- a Hash Join.
--
-- IS THAT WHAT I EXPECTED? YES, and here is why.
--
-- This query reads EVERY row of both tables. There is no WHERE clause.
-- An index helps you FIND A FEW ROWS AMONG MANY; it cannot help when
-- the answer requires all of them. Using an index here would mean
-- reading the index AND then the whole table - strictly more work
-- than reading the table once.
--
-- Second reason: both tables fit in a single 8kB page. A sequential
-- scan is one disk read. Nothing can beat one disk read.
--
-- THE PLANNER IS NOT IGNORING YOUR INDEX. It priced both options and
-- picked the cheaper one, and it was right. An index that goes unused
-- on 120 rows is not a wasted index - it is an index whose table has
-- not grown up yet.
--
-- SO WHY CREATE THEM AT ALL? Three reasons, none about today's
-- SELECT speed:
--
--   1. The tables will grow. Adding an index to a large, busy table
--      is disruptive; creating it now costs nothing.
--   2. ON DELETE CASCADE must find child rows. Without an index on
--      order_items.order_id, deleting one order scans all 300 line
--      items - and deleting 1,000 orders scans them 1,000 times.
--   3. Foreign key checks take locks. Unindexed FKs are a well-known
--      source of lock contention under concurrent writes.
--
-- Indexing foreign keys is a DEFAULT, not an optimisation.


-- -------------------------------------------------------------
-- Exercise 11.3 - Make an index that actually gets used
-- -------------------------------------------------------------

-- To get an index scan you need HIGH SELECTIVITY - returning very few
-- rows from the largest available table. order_items has 300 rows.

EXPLAIN ANALYZE
SELECT * FROM order_items WHERE order_id = 42;

--  With idx_order_items_order_id in place you may see:
--
--  Index Scan using idx_order_items_order_id on order_items
--    (cost=0.15..8.17 rows=3 width=26) (actual time=0.018..0.020 rows=3 loops=1)
--    Index Cond: (order_id = 42)
--
--  3 rows out of 300 - selective enough that the index wins.
--
--  If you still get a Seq Scan, the table is simply too small for it
--  to matter, and that is a legitimate answer. Prove the index works
--  by forcing it:

SET enable_seqscan = off;
EXPLAIN ANALYZE SELECT * FROM order_items WHERE order_id = 42;
SET enable_seqscan = on;          -- ALWAYS put it back

--  Compare the two costs. If the forced index plan costs MORE than
--  the sequential scan, you have just demonstrated the planner was
--  right, which is a better outcome than beating it.
--
--  NEVER leave enable_seqscan = off outside an experiment. It is a
--  diagnostic switch, not a tuning setting. It does not make queries
--  faster; it removes an option the planner needs.

-- An INDEX ONLY SCAN - the best possible outcome - happens when every
-- column you ask for lives in the index, so the table is never read:
EXPLAIN ANALYZE
SELECT order_id FROM order_items WHERE order_id = 42;
--  Index Only Scan using idx_order_items_order_id on order_items
--    Heap Fetches: 0
--
--  `Heap Fetches: 0` means the table was not touched at all. This is
--  what "covering index" means, and it is why adding a column to an
--  index sometimes helps far more than expected.


-- =============================================================
--  Mini-project - index the database and measure it
-- =============================================================

-- ---- Step 2: the extra indexes ----
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
CREATE INDEX idx_orders_pending       ON orders (order_date) WHERE status = 'pending';
ANALYZE orders;

--  COMPOSITE (customer_id, order_date): serves queries filtering on
--  customer_id alone, or on both. It does NOT serve a query filtering
--  only on order_date - like a phone book sorted by surname then
--  first name, useless for finding everyone called James.
--
--  PARTIAL (WHERE status = 'pending'): indexes 10 rows instead of
--  120. Smaller, faster to maintain, and only useful for queries that
--  also filter on status = 'pending'.


-- ---- Step 4: which indexes are actually used? ----
SELECT relname       AS table_name,
       indexrelname  AS index_name,
       idx_scan      AS times_used,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM   pg_stat_user_indexes
WHERE  schemaname = 'shop'
ORDER  BY idx_scan, indexrelname;

--  Most will show idx_scan = 0. That is honest and expected.
--
--  On a real system this query is genuinely valuable: any index with
--  idx_scan = 0 after weeks of production traffic is costing you
--  write performance and disk for nothing, and is a candidate to
--  drop. Do check it has been running long enough to be fair - an
--  index used only by a quarterly report will look dead in April.


-- -------------------------------------------------------------
-- Step 5: the honest conclusion
-- -------------------------------------------------------------
--
--  Almost none of these indexes changed a plan or a measurable time.
--  On 120 orders and 300 line items, sequential scans win because the
--  data fits in a handful of pages, and PLANNING the query already
--  costs five times more than executing it (2.083ms vs 0.375ms).
--
--  SO WHEN SHOULD YOU ADD AN INDEX?
--
--  Not "when the query is slow" - by then you are debugging an
--  incident under pressure, and adding an index to a large hot table
--  can lock it or take hours.
--
--  Not "just in case", either. Every index slows every INSERT,
--  UPDATE and DELETE on that table, consumes disk, and adds a
--  possibility for the planner to weigh. A table with fifteen
--  speculative indexes has genuinely slow writes and a planner
--  spending real time choosing between them.
--
--  A DEFENSIBLE POLICY:
--
--   1. INDEX EVERY FOREIGN KEY, ALWAYS, from day one. The cost is
--      near zero, and the reasons go beyond query speed - cascade
--      deletes and FK lock contention both need it. This is the one
--      case where "it might help later" IS good enough, because the
--      cost of being wrong is negligible and the cost of being late
--      is not.
--
--   2. INDEX WHAT YOU MEASURE. Add an index in response to a real
--      query plan on realistic data volumes, not a guess.
--
--   3. REVIEW WITH pg_stat_user_indexes. Drop what nothing uses.
--
--  "It might help later" is a good reason for foreign keys and a poor
--  reason for anything else. The difference is that foreign key
--  indexes have a predictable, universal payoff, while speculative
--  indexes on arbitrary columns are a bet on a query nobody has
--  written yet - and you pay the write cost whether or not that
--  query ever appears.
