-- =============================================================
--  Nimbus Supply Co. - practice database
--  File 3 of 3: the messy table
--
--  This is what real data actually looks like when it arrives from
--  a CSV export, a third-party form, or a system somebody built in
--  a hurry in 2019.
--
--  Every column is `text`, because that is how raw loads arrive:
--  nothing has been validated or converted yet. This table is the
--  raw material for week 8 (data cleaning).
--
--  The dirt in here is deliberate. Do not "fix" this file -
--  the whole exercise is learning to clean it with SQL while
--  leaving the original rows untouched.
-- =============================================================

SET search_path TO shop, public;

DROP TABLE IF EXISTS raw_signups;

-- No primary key, no constraints, no types. A staging table's job is
-- to accept whatever it is given and let you sort it out afterwards.
CREATE TABLE raw_signups (
    row_id           integer,
    full_name        text,
    email            text,
    country          text,
    signup_date_text text,
    plan             text,
    monthly_spend    text
);

COMMENT ON TABLE raw_signups IS
  'Raw marketing signup export. Unvalidated on purpose - clean it in week 8.';

INSERT INTO raw_signups (row_id, full_name, email, country, signup_date_text, plan, monthly_spend) VALUES
 -- ---- reasonably clean rows -------------------------------------
 ( 1, 'Elena Sarmiento',   'elena.sarmiento@example.com', 'Philippines',    '2024-01-14', 'pro',        '49.00'),
 ( 2, 'Robert Ashcroft',   'r.ashcroft@example.com',      'United Kingdom', '2024-01-22', 'enterprise', '299.00'),
 ( 3, 'Yuki Tanaka',       'yuki.tanaka@example.com',     'Japan',          '2024-02-03', 'basic',      '19.00'),

 -- ---- inconsistent country spellings ----------------------------
 ( 4, 'Nathan Cole',       'nathan.cole@example.com',     'USA',            '2024-02-11', 'pro',        '49.00'),
 ( 5, 'Marie Fontaine',    'marie.fontaine@example.com',  'U.S.A.',         '2024-02-18', 'pro',        '49.00'),
 ( 6, 'Derek Lowell',      'derek.lowell@example.com',    'united states',  '2024-02-25', 'basic',      '19.00'),
 ( 7, 'Paula Nkemdirim',   'paula.n@example.com',         '  United States ','2024-03-02', 'pro',       '49.00'),
 ( 8, 'Ian Hargreaves',    'ian.hargreaves@example.com',  'UK',             '2024-03-09', 'basic',      '19.00'),
 ( 9, 'Fiona Bell',        'fiona.bell@example.com',      'U.K.',           '2024-03-16', 'pro',        '49.00'),
 (10, 'Callum Reid',       'callum.reid@example.com',     'britain',        '2024-03-23', 'basic',      '19.00'),

 -- ---- date formats that disagree with each other -----------------
 (11, 'Sofia Petrova',     'sofia.petrova@example.com',   'Bulgaria',       '05/04/2024',   'pro',       '49.00'),
 (12, 'Jonas Bergmann',    'jonas.bergmann@example.com',  'Germany',        '2024-4-12',    'enterprise','299.00'),
 (13, 'Aisha Rahman',      'aisha.rahman@example.com',    'Bangladesh',     'April 19 2024','basic',     '19.00'),
 (14, 'Wei Zhang',         'wei.zhang@example.com',       'Singapore',      '26-04-2024',   'pro',       '49.00'),
 (15, 'Camila Rojas',      'camila.rojas@example.com',    'Chile',          '2024/05/03',   'basic',     '19.00'),

 -- ---- missing values, in three different disguises ---------------
 (16, 'Hugo Almeida',      'hugo.almeida@example.com',    'Portugal',        NULL,          'pro',       '49.00'),
 (17, 'Leila Haddad',      'leila.haddad@example.com',    'Lebanon',        '',             'basic',     '19.00'),
 (18, 'Tariq Hassan',      'tariq.hassan@example.com',    'N/A',            '2024-05-24',   'pro',       '49.00'),
 (19, 'Emma Lindgren',     'emma.lindgren@example.com',    NULL,            '2024-05-31',   'basic',     ''),
 (20, 'Andres Guzman',     'andres.guzman@example.com',   'unknown',        '2024-06-07',   'pro',       'NULL'),

 -- ---- duplicates: same person, different formatting --------------
 (21, 'Meera Kapoor',      'meera.kapoor@example.com',    'India',          '2024-06-14',   'pro',       '49.00'),
 (22, 'meera kapoor',      'MEERA.KAPOOR@example.com',    'India',          '2024-06-14',   'pro',       '49.00'),
 (23, 'Meera  Kapoor ',    ' meera.kapoor@example.com ',  'india',          '2024-06-14',   'Pro',       '49.00'),
 (24, 'Carlos Mendoza',    'carlos.mendoza@example.com',  'Mexico',         '2024-06-21',   'basic',     '19.00'),
 (25, 'Carlos Mendoza',    'carlos.mendoza@example.com',  'Mexico',         '2024-06-21',   'basic',     '19.00'),

 -- ---- plan values that will not GROUP BY cleanly -----------------
 (26, 'Ryan Mitchell',     'ryan.mitchell@example.com',   'Australia',      '2024-06-28',   'PRO',       '49.00'),
 (27, 'Sinead Kavanagh',   'sinead.k@example.com',        'Ireland',        '2024-07-05',   'Basic',     '19.00'),
 (28, 'Victor Ivanov',     'victor.ivanov@example.com',   'Estonia',        '2024-07-12',   ' pro ',     '49.00'),
 (29, 'Zainab Osei',       'zainab.osei@example.com',     'Ghana',          '2024-07-19',   'ENTERPRISE','299.00'),
 (30, 'Thomas Bergeron',   'thomas.bergeron@example.com', 'Canada',         '2024-07-26',   'enterprise','299.00'),

 -- ---- money stored as text, with symbols and separators ----------
 (31, 'Nadia Iqbal',       'nadia.iqbal@example.com',     'Pakistan',       '2024-08-02',   'pro',       '$49.00'),
 (32, 'Grace Okonkwo',     'grace.okonkwo@example.com',   'Nigeria',        '2024-08-09',   'enterprise','1,299.00'),
 (33, 'Ahmed Al-Rashid',   'ahmed.rashid@example.com',    'UAE',            '2024-08-16',   'enterprise','299'),
 (34, 'Ingrid Halvorsen',  'ingrid.h@example.com',        'Norway',         '2024-08-23',   'pro',       '49.0'),

 -- ---- outliers and impossible values -----------------------------
 (35, 'Test Test',         'test@test.com',               'Testland',       '2024-08-30',   'basic',     '-19.00'),
 (36, 'QA Automation',     'qa+bot@example.com',          'Nowhere',        '1900-01-01',   'basic',     '0.00'),
 (37, 'Big Spender Corp',  'ap@bigspender.example.com',   'United States',  '2024-09-06',   'enterprise','9999999.00'),
 (38, 'Future Person',     'future@example.com',          'Canada',         '2099-12-31',   'pro',       '49.00'),

 -- ---- malformed email addresses ----------------------------------
 (39, 'Broken Email',      'not-an-email',                'Ireland',        '2024-09-13',   'basic',     '19.00'),
 (40, 'No Email At All',    NULL,                         'Ghana',          '2024-09-20',   'pro',       '49.00');
