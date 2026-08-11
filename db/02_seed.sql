-- =============================================================
--  Nimbus Supply Co. - practice database
--  File 2 of 3: seed data
--
--  Reference tables (employees, customers, products) are written out
--  by hand so you can read them. Transaction tables (orders,
--  order_items, payments) are GENERATED with plain arithmetic -
--  no randomness - so the data is identical every time anyone runs
--  this file. Same script, same rows, same answers.
-- =============================================================

SET search_path TO shop, public;


-- -------------------------------------------------------------
-- employees (12) - note Ana has no manager; she is the CEO
-- -------------------------------------------------------------
INSERT INTO employees (employee_id, full_name, job_title, department, manager_id, hired_on, annual_salary) VALUES
 (1,  'Ana Villaruel',    'Chief Executive Officer', 'Executive',  NULL, '2019-02-01',  185000.00),
 (2,  'Marcus Oyelaran',  'VP Engineering',          'Engineering',   1, '2019-06-15',  152000.00),
 (3,  'Priya Raghunathan','VP Operations',           'Operations',    1, '2020-01-20',  148000.00),
 (4,  'Tomas Lindqvist',  'Senior Engineer',         'Engineering',   2, '2020-09-01',  118000.00),
 (5,  'Hannah Boateng',   'Database Administrator',  'Engineering',   2, '2021-03-11',  112000.00),
 (6,  'Kenji Nakamura',   'Data Engineer',           'Engineering',   2, '2022-07-05',   99000.00),
 (7,  'Sofia Marchetti',  'Warehouse Manager',       'Operations',    3, '2020-11-30',   87000.00),
 (8,  'Diego Fuentes',    'Logistics Coordinator',   'Operations',    7, '2022-02-14',   61000.00),
 (9,  'Amara Nwosu',      'Support Lead',            'Support',       3, '2021-08-23',   72000.00),
 (10, 'Lukas Weber',      'Support Specialist',      'Support',       9, '2023-04-03',   54000.00),
 (11, 'Rosa Delgado',     'Support Specialist',      'Support',       9, '2024-01-08',   52000.00),
 (12, 'Ibrahim Chaudhry', 'Junior Engineer',         'Engineering',   4, '2024-06-17',   71000.00);


-- -------------------------------------------------------------
-- customers (40)
--
--  Deliberate quirks you will need later:
--   * customers 7, 19, 28, 33 have NULL country
--   * customers 39 and 40 have never placed an order
--   * a handful are marked inactive
-- -------------------------------------------------------------
INSERT INTO customers (customer_id, first_name, last_name, email, country, city, signup_date, segment, is_active) VALUES
 (1,  'Elena',   'Sarmiento', 'elena.sarmiento@example.com',  'Philippines',   'Manila',       '2023-01-14', 'consumer',  true),
 (2,  'Robert',  'Ashcroft',  'r.ashcroft@example.com',       'United Kingdom','Manchester',   '2023-01-22', 'business',  true),
 (3,  'Yuki',    'Tanaka',    'yuki.tanaka@example.com',      'Japan',         'Osaka',        '2023-02-03', 'consumer',  true),
 (4,  'Grace',   'Okonkwo',   'grace.okonkwo@example.com',    'Nigeria',       'Lagos',        '2023-02-19', 'business',  true),
 (5,  'Daniel',  'Brennan',   'dan.brennan@example.com',      'Ireland',       'Cork',         '2023-03-01', 'consumer',  true),
 (6,  'Meera',   'Kapoor',    'meera.kapoor@example.com',     'India',         'Pune',         '2023-03-17', 'education', true),
 (7,  'Anonymous','User',     'anon.user7@example.com',        NULL,            NULL,          '2023-03-28', 'consumer',  true),
 (8,  'Carlos',  'Mendoza',   'carlos.mendoza@example.com',   'Mexico',        'Guadalajara',  '2023-04-09', 'business',  true),
 (9,  'Ingrid',  'Halvorsen', 'ingrid.h@example.com',         'Norway',        'Bergen',       '2023-04-21', 'consumer',  true),
 (10, 'Samuel',  'Adeyemi',   'samuel.adeyemi@example.com',   'Nigeria',       'Abuja',        '2023-05-05', 'business',  false),
 (11, 'Chloe',   'Dubois',    'chloe.dubois@example.com',     'France',        'Lyon',         '2023-05-18', 'consumer',  true),
 (12, 'Ahmed',   'Al-Rashid', 'ahmed.rashid@example.com',     'UAE',           'Dubai',        '2023-06-02', 'business',  true),
 (13, 'Beatriz', 'Ferreira',  'bea.ferreira@example.com',     'Brazil',        'Recife',       '2023-06-24', 'consumer',  true),
 (14, 'Nathan',  'Cole',      'nathan.cole@example.com',      'United States', 'Denver',       '2023-07-07', 'consumer',  true),
 (15, 'Wei',     'Zhang',     'wei.zhang@example.com',        'Singapore',     'Singapore',    '2023-07-19', 'business',  true),
 (16, 'Fatima',  'Bennani',   'fatima.bennani@example.com',   'Morocco',       'Casablanca',   '2023-08-02', 'education', true),
 (17, 'Oliver',  'Whitfield', 'oliver.w@example.com',         'United Kingdom','Bristol',      '2023-08-15', 'consumer',  true),
 (18, 'Camila',  'Rojas',     'camila.rojas@example.com',     'Chile',         'Santiago',     '2023-09-01', 'consumer',  true),
 (19, 'Test',    'Account',   'test.account19@example.com',    NULL,            NULL,          '2023-09-12', 'consumer',  false),
 (20, 'Jonas',   'Bergmann',  'jonas.bergmann@example.com',   'Germany',       'Leipzig',      '2023-09-26', 'business',  true),
 (21, 'Aisha',   'Rahman',    'aisha.rahman@example.com',     'Bangladesh',    'Dhaka',        '2023-10-10', 'education', true),
 (22, 'Liam',    'O''Sullivan','liam.osullivan@example.com',  'Ireland',       'Galway',       '2023-10-23', 'consumer',  true),
 (23, 'Sofia',   'Petrova',   'sofia.petrova@example.com',    'Bulgaria',      'Sofia',        '2023-11-06', 'consumer',  true),
 (24, 'Marcus',  'Johansson', 'marcus.j@example.com',         'Sweden',        'Malmo',        '2023-11-20', 'business',  true),
 (25, 'Ngozi',   'Eze',       'ngozi.eze@example.com',        'Nigeria',       'Enugu',        '2023-12-04', 'consumer',  true),
 (26, 'Ryan',    'Mitchell',  'ryan.mitchell@example.com',    'Australia',     'Perth',        '2023-12-18', 'business',  true),
 (27, 'Leila',   'Haddad',    'leila.haddad@example.com',     'Lebanon',       'Beirut',       '2024-01-08', 'consumer',  true),
 (28, 'Pat',     'Nolastname', 'pat.n28@example.com',          NULL,           'Unknown',      '2024-01-22', 'consumer',  true),
 (29, 'Hugo',    'Almeida',   'hugo.almeida@example.com',     'Portugal',      'Porto',        '2024-02-05', 'consumer',  true),
 (30, 'Sinead',  'Kavanagh',  'sinead.k@example.com',         'Ireland',       'Dublin',       '2024-02-19', 'business',  true),
 (31, 'Tariq',   'Hassan',    'tariq.hassan@example.com',     'Egypt',         'Cairo',        '2024-03-04', 'education', true),
 (32, 'Emma',    'Lindgren',  'emma.lindgren@example.com',    'Sweden',        'Uppsala',      '2024-03-18', 'consumer',  true),
 (33, 'Jane',    'Doe',       'jane.doe33@example.com',        NULL,            NULL,          '2024-04-01', 'consumer',  false),
 (34, 'Andres',  'Guzman',    'andres.guzman@example.com',    'Colombia',      'Medellin',     '2024-04-15', 'business',  true),
 (35, 'Nadia',   'Iqbal',     'nadia.iqbal@example.com',      'Pakistan',      'Lahore',       '2024-05-06', 'consumer',  true),
 (36, 'Thomas',  'Bergeron',  'thomas.bergeron@example.com',  'Canada',        'Quebec City',  '2024-05-20', 'consumer',  true),
 (37, 'Zainab',  'Osei',      'zainab.osei@example.com',      'Ghana',         'Accra',        '2024-06-03', 'education', true),
 (38, 'Victor',  'Ivanov',    'victor.ivanov@example.com',    'Estonia',       'Tallinn',      '2024-06-17', 'business',  true),
 (39, 'Harriet', 'Lockwood',  'harriet.lockwood@example.com', 'United Kingdom','Leeds',        '2025-11-24', 'consumer',  true),
 (40, 'Kwame',   'Mensah',    'kwame.mensah@example.com',     'Ghana',         'Kumasi',       '2025-12-02', 'consumer',  true);


-- -------------------------------------------------------------
-- products (25)
--   Products 24 and 25 have never been ordered by anyone.
-- -------------------------------------------------------------
INSERT INTO products (product_id, sku, product_name, category, unit_price, cost_price, stock_qty, is_discontinued, created_at) VALUES
 (1,  'NW-RTR-1000', 'Nimbus Router 1000',        'Networking',  189.00,  102.50, 120, false, '2022-11-01'),
 (2,  'NW-RTR-2000', 'Nimbus Router 2000 Pro',    'Networking',  349.00,  198.00,  64, false, '2023-04-12'),
 (3,  'NW-SWT-8',    '8-Port Gigabit Switch',     'Networking',   79.50,   41.00, 210, false, '2022-11-01'),
 (4,  'NW-SWT-24',   '24-Port Managed Switch',    'Networking',  429.00,  256.00,  33, false, '2023-01-18'),
 (5,  'NW-APT-300',  'Ceiling Access Point 300',  'Networking',  159.00,   88.00,  95, false, '2023-06-02'),
 (6,  'ST-SSD-500',  'Rapid SSD 500GB',           'Storage',      64.00,   35.50, 340, false, '2022-11-01'),
 (7,  'ST-SSD-1TB',  'Rapid SSD 1TB',             'Storage',     109.00,   61.00, 285, false, '2022-11-01'),
 (8,  'ST-SSD-2TB',  'Rapid SSD 2TB',             'Storage',     198.00,  118.00, 140, false, '2023-02-20'),
 (9,  'ST-NAS-4B',   'Vault NAS 4-Bay',           'Storage',     529.00,  322.00,  22, false, '2023-05-09'),
 (10, 'ST-HDD-4TB',  'Archive HDD 4TB',           'Storage',      89.00,   52.00, 175, false, '2022-11-01'),
 (11, 'PR-KBD-MEC',  'Mechanical Keyboard MK2',   'Peripherals',  119.00,   58.00, 260, false, '2023-03-15'),
 (12, 'PR-MSE-ERG',  'Ergonomic Mouse E1',        'Peripherals',   49.00,   21.00, 410, false, '2022-11-01'),
 (13, 'PR-MON-27',   '27" QHD Monitor',           'Peripherals',  289.00,  176.00,  58, false, '2023-07-21'),
 (14, 'PR-DOK-USB',  'USB-C Dock 11-in-1',        'Peripherals',  139.00,   74.00, 130, false, '2023-08-30'),
 (15, 'PR-HDS-BT',   'Bluetooth Headset H5',      'Peripherals',   89.00,   43.00, 190, false, '2023-09-14'),
 (16, 'CB-ETH-C6',   'Cat6 Cable 3m (10-pack)',   'Cables',       34.00,   14.00, 520, false, '2022-11-01'),
 (17, 'CB-USB-C2',   'USB-C to USB-C 2m',         'Cables',       17.50,    6.20, 780, false, '2022-11-01'),
 (18, 'CB-HDM-21',   'HDMI 2.1 Cable 2m',         'Cables',       24.00,    9.50, 445, false, '2023-02-02'),
 (19, 'PW-UPS-650',  'UPS 650VA',                 'Power',       129.00,   77.00,  88, false, '2023-04-27'),
 (20, 'PW-PDU-8',    'Rack PDU 8-Outlet',         'Power',       219.00,  131.00,  41, false, '2023-10-05'),
 (21, 'PW-SRG-6',    'Surge Protector 6-Way',     'Power',        32.00,   13.00, 300, false, '2022-11-01'),
 (22, 'SW-BAK-1Y',   'Nimbus Backup 1-Year',      'Software',    149.00,   30.00,   0, false, '2023-01-05'),
 (23, 'SW-MON-1Y',   'Nimbus Monitor 1-Year',     'Software',    199.00,   40.00,   0, false, '2023-01-05'),
 (24, 'NW-RTR-500',  'Nimbus Router 500 (EOL)',   'Networking',   99.00,   61.00,   6, true,  '2021-05-10'),
 (25, 'PR-WBC-720',  'Webcam 720p (EOL)',         'Peripherals',  39.00,   24.00,  14, true,  '2021-08-22');


-- =============================================================
--  Generated transaction data
--  Everything below is arithmetic on a row number. No randomness.
-- =============================================================

-- -------------------------------------------------------------
-- orders (120), spread across 2024-2025
-- -------------------------------------------------------------
INSERT INTO orders (order_id, customer_id, order_date, status, ship_country, shipping_fee, discount_code)
SELECT
    n                                                             AS order_id,
    -- Most orders spread evenly across customers 1-38, but every third
    -- order goes to one of the first 8. That gives a realistic skew:
    -- a few repeat buyers, a long tail of occasional ones, and customers
    -- 39 and 40 (who only signed up recently) with no orders at all.
    CASE WHEN n % 3 = 0 THEN 1 + (n % 8)
         ELSE 1 + ((n * 7) % 38)
    END                                                           AS customer_id,
    DATE '2024-01-01' + ((n * 5 + (n % 7) * 11) % 700)            AS order_date,
    CASE
        WHEN n % 17 = 0 THEN 'cancelled'
        WHEN n % 23 = 0 THEN 'refunded'
        WHEN n % 11 = 0 THEN 'pending'
        WHEN n %  5 = 0 THEN 'shipped'
        ELSE                 'completed'
    END                                                           AS status,
    NULL                                                          AS ship_country,  -- backfilled below
    CASE WHEN n % 4 = 0 THEN 0.00
         ELSE ROUND((5 + (n % 9) * 1.5)::numeric, 2)
    END                                                           AS shipping_fee,
    CASE WHEN n %  6 = 0 THEN 'SAVE10'
         WHEN n % 13 = 0 THEN 'WELCOME'
         WHEN n % 19 = 0 THEN 'FREESHIP'
         ELSE NULL
    END                                                           AS discount_code
FROM generate_series(1, 120) AS n;

-- Ship to wherever the customer lives. Customers with a NULL country
-- leave a NULL here too - which is exactly the sort of gap you will
-- learn to detect rather than ignore.
UPDATE orders o
SET    ship_country = c.country
FROM   customers c
WHERE  c.customer_id = o.customer_id;


-- -------------------------------------------------------------
-- order_items - between 1 and 4 lines per order
-- -------------------------------------------------------------
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount_pct)
SELECT
    ROW_NUMBER() OVER (ORDER BY o.order_id, i)          AS order_item_id,
    o.order_id,
    p.product_id,
    1 + ((o.order_id + i) % 5)                          AS quantity,
    p.unit_price,
    CASE WHEN (o.order_id + i) %  9 = 0 THEN 10.00
         WHEN (o.order_id + i) % 17 = 0 THEN 25.00
         ELSE 0.00
    END                                                 AS discount_pct
FROM        orders o
CROSS JOIN  LATERAL generate_series(1, 1 + (o.order_id % 4)) AS i
JOIN        products p
       ON   p.product_id = 1 + ((o.order_id * 3 + i * 7) % 23);


-- -------------------------------------------------------------
-- payments
--
--  The rules below create the situations you need to learn from:
--    * cancelled and pending orders get NO payment row
--    * every 9th paid order is settled in TWO instalments
--      -> joining orders to payments will double-count it
--    * refunded orders carry a capture AND a refund row
--    * every 14th order has a failed attempt before it succeeded
-- -------------------------------------------------------------
WITH order_totals AS (
    SELECT o.order_id,
           o.order_date,
           o.status,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100))
                 + MAX(o.shipping_fee), 2) AS total
    FROM   orders o
    JOIN   order_items oi ON oi.order_id = o.order_id
    GROUP  BY o.order_id, o.order_date, o.status, o.shipping_fee
),
rules AS (
    -- Rule 1: single full payment for paid orders that are not instalments
    SELECT order_id, order_date + 1 AS paid_on, total AS amount,
           'captured' AS status, 1 AS seq
    FROM   order_totals
    WHERE  status IN ('completed','shipped','refunded')
      AND  order_id % 9 <> 0

    UNION ALL
    -- Rule 2: instalment orders pay 60% now...
    SELECT order_id, order_date + 1, ROUND(total * 0.60, 2), 'captured', 1
    FROM   order_totals
    WHERE  status IN ('completed','shipped','refunded')
      AND  order_id % 9 = 0

    UNION ALL
    -- ...and the remaining 40% a month later
    SELECT order_id, order_date + 31, ROUND(total * 0.40, 2), 'captured', 2
    FROM   order_totals
    WHERE  status IN ('completed','shipped','refunded')
      AND  order_id % 9 = 0

    UNION ALL
    -- Rule 3: refunded orders also carry a refund row
    SELECT order_id, order_date + 21, total, 'refunded', 3
    FROM   order_totals
    WHERE  status = 'refunded'

    UNION ALL
    -- Rule 4: a failed attempt that was retried successfully
    SELECT order_id, order_date, total, 'failed', 0
    FROM   order_totals
    WHERE  status IN ('completed','shipped')
      AND  order_id % 14 = 0
)
INSERT INTO payments (payment_id, order_id, paid_on, amount, method, status)
SELECT ROW_NUMBER() OVER (ORDER BY order_id, seq) AS payment_id,
       order_id,
       paid_on,
       amount,
       CASE (order_id + seq) % 4
            WHEN 0 THEN 'card'
            WHEN 1 THEN 'paypal'
            WHEN 2 THEN 'card'
            ELSE        'bank_transfer'
       END,
       status
FROM   rules;
