/* =============================================================================
   01_schema.sql
   Purpose : Create the three typed analysis tables, linked 1:1 by customer_id.
               customers  - who the customer is (demographics)
               accounts   - what they hold (financial details and products)
               activity   - how they engage, and whether they left (churn)
   Output  : customers, accounts, activity
   Design  : One row per customer in every table (vertical partitioning by
             subject area). accounts and activity reference customers via a
             FOREIGN KEY, so every analysis that combines subjects needs a JOIN.
   Notes   : CHECK ranges are business rules, set a little wider than
             the values seen in this month's file so that a valid new month is
             not rejected. Each one is marked assumption for review.
   ============================================================================= */

PRAGMA foreign_keys = ON;

-- Drop children before the parent so foreign keys never block a rebuild.
DROP TABLE IF EXISTS activity;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;

-- -----------------------------------------------------------------------------
-- customers: demographics (parent table)
-- -----------------------------------------------------------------------------
CREATE TABLE customers (
    customer_id  INTEGER PRIMARY KEY,                     -- bank's customer number (CSV: CustomerId)
    surname      TEXT    NOT NULL,                        -- PII: used only for the retention call list
    gender       TEXT    NOT NULL
                 CHECK (gender IN ('Female', 'Male')),
    age          INTEGER NOT NULL
                 CHECK (age BETWEEN 18 AND 100),          -- Assumption: adult customers, max 100
    country      TEXT    NOT NULL
                 CHECK (country IN ('France', 'Germany', 'Spain'))  -- CSV: Geography
);

-- -----------------------------------------------------------------------------
-- accounts: financial details and products held
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    customer_id       INTEGER PRIMARY KEY
                      REFERENCES customers (customer_id),
    credit_score      INTEGER NOT NULL
                      CHECK (credit_score BETWEEN 300 AND 900),   -- Assumption: common bureau scale; data is 350-850
    tenure_years      INTEGER NOT NULL
                      CHECK (tenure_years BETWEEN 0 AND 10),      -- Assumption: source caps tenure at 10
    balance           REAL    NOT NULL
                      CHECK (balance >= 0),                       -- deposit balance; 0 = empty account
    num_products      INTEGER NOT NULL
                      CHECK (num_products BETWEEN 1 AND 4),       -- Assumption: bank offers max 4 products
    has_credit_card   INTEGER NOT NULL
                      CHECK (has_credit_card IN (0, 1)),
    card_type         TEXT    NOT NULL
                      CHECK (card_type IN ('SILVER', 'GOLD', 'PLATINUM', 'DIAMOND')),
    estimated_salary  REAL    NOT NULL
                      CHECK (estimated_salary > 0)                -- bank's estimate, not verified income
);

-- -----------------------------------------------------------------------------
-- activity: engagement, feedback and churn outcome
-- -----------------------------------------------------------------------------
CREATE TABLE activity (
    customer_id         INTEGER PRIMARY KEY
                        REFERENCES customers (customer_id),
    is_active_member    INTEGER NOT NULL
                        CHECK (is_active_member IN (0, 1)),
    complained          INTEGER NOT NULL
                        CHECK (complained IN (0, 1)),             -- LEAKAGE RISK: reviewed in 03_data_quality.sql
    satisfaction_score  INTEGER NOT NULL
                        CHECK (satisfaction_score BETWEEN 1 AND 5),
    points_earned       INTEGER NOT NULL
                        CHECK (points_earned >= 0),               -- loyalty points
    exited              INTEGER NOT NULL
                        CHECK (exited IN (0, 1))                  -- TARGET: 1 = customer left the bank
);
