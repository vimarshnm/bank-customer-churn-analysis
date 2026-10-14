/* =============================================================================
   07_reference_bands.sql
   Purpose : Lookup (dimension) tables that turn continuous values into bands,
             so SQL, Excel and Tableau all use IDENTICAL boundaries.
   Output  : age_bands, balance_bands, tenure_bands, credit_score_bands
   Rule    : lower_bound is INCLUSIVE, upper_bound is EXCLUSIVE:
               value >= lower_bound AND value < upper_bound
             The top band uses a large upper_bound so no value falls through.
             04_validation_checks.sql (G1) proves every customer lands in
             exactly one band of each type.
   Usage   : JOIN age_bands AS ab
                 ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
             (a "range join" - matches on a range instead of an equal key)
   Assumption: band edges chosen for readability and to follow the churn
             pattern seen in profiling (churn peaks in the 50s); adjust here
             only, and every downstream query and extract follows.
   ============================================================================= */

DROP TABLE IF EXISTS age_bands;
DROP TABLE IF EXISTS balance_bands;
DROP TABLE IF EXISTS tenure_bands;
DROP TABLE IF EXISTS credit_score_bands;

-- -----------------------------------------------------------------------------
-- Age bands (years)
-- -----------------------------------------------------------------------------
CREATE TABLE age_bands (
    band_order   INTEGER PRIMARY KEY,
    band_label   TEXT    NOT NULL UNIQUE,
    lower_bound  INTEGER NOT NULL,
    upper_bound  INTEGER NOT NULL,
    CHECK (lower_bound < upper_bound)
);

INSERT INTO age_bands (band_order, band_label, lower_bound, upper_bound) VALUES
    (1, '18-29', 18,  30),
    (2, '30-39', 30,  40),
    (3, '40-49', 40,  50),
    (4, '50-59', 50,  60),
    (5, '60-69', 60,  70),
    (6, '70+',   70, 999);

-- -----------------------------------------------------------------------------
-- Balance bands (deposit balance)
-- -----------------------------------------------------------------------------
CREATE TABLE balance_bands (
    band_order   INTEGER PRIMARY KEY,
    band_label   TEXT    NOT NULL UNIQUE,
    lower_bound  REAL    NOT NULL,
    upper_bound  REAL    NOT NULL,
    CHECK (lower_bound < upper_bound)
);

INSERT INTO balance_bands (band_order, band_label, lower_bound, upper_bound) VALUES
    (1, 'Zero',          0.00,       0.01),
    (2, 'Under 50k',     0.01,   50000.00),
    (3, '50k-100k',  50000.00,  100000.00),
    (4, '100k-150k', 100000.00, 150000.00),
    (5, '150k+',     150000.00, 999999999.00);

-- -----------------------------------------------------------------------------
-- Tenure bands (years with the bank)
-- -----------------------------------------------------------------------------
CREATE TABLE tenure_bands (
    band_order   INTEGER PRIMARY KEY,
    band_label   TEXT    NOT NULL UNIQUE,
    lower_bound  INTEGER NOT NULL,
    upper_bound  INTEGER NOT NULL,
    CHECK (lower_bound < upper_bound)
);

INSERT INTO tenure_bands (band_order, band_label, lower_bound, upper_bound) VALUES
    (1, '0-2 yrs',  0,  3),
    (2, '3-5 yrs',  3,  6),
    (3, '6-8 yrs',  6,  9),
    (4, '9-10 yrs', 9, 99);

-- -----------------------------------------------------------------------------
-- Credit score bands
-- -----------------------------------------------------------------------------
CREATE TABLE credit_score_bands (
    band_order   INTEGER PRIMARY KEY,
    band_label   TEXT    NOT NULL UNIQUE,
    lower_bound  INTEGER NOT NULL,
    upper_bound  INTEGER NOT NULL,
    CHECK (lower_bound < upper_bound)
);

INSERT INTO credit_score_bands (band_order, band_label, lower_bound, upper_bound) VALUES
    (1, 'Under 500',   0, 500),
    (2, '500-599',   500, 600),
    (3, '600-699',   600, 700),
    (4, '700-799',   700, 800),
    (5, '800+',      800, 9999);
