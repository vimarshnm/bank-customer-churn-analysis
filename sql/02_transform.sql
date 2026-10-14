/* =============================================================================
   02_transform.sql
   Purpose : Convert staging TEXT columns to proper types and split the single
             raw table into customers, accounts and activity.
   Input   : stg_churn_raw
   Output  : customers, accounts, activity (populated)
   Notes   : TRIM guards against stray whitespace in future files. If any value
             breaks a CHECK constraint the INSERT fails loudly - by design, bad
             data must be fixed at source, not silently loaded.
             RowNumber is not carried forward: it is only a file row index.
   ============================================================================= */

PRAGMA foreign_keys = ON;

BEGIN TRANSACTION;

-- Parent first: demographics.
INSERT INTO customers (customer_id, surname, gender, age, country)
SELECT
    CAST(TRIM("CustomerId") AS INTEGER),
    TRIM("Surname"),
    TRIM("Gender"),
    CAST(TRIM("Age") AS INTEGER),
    TRIM("Geography")
FROM stg_churn_raw;

-- Financial details and products.
INSERT INTO accounts (
    customer_id, credit_score, tenure_years, balance,
    num_products, has_credit_card, card_type, estimated_salary
)
SELECT
    CAST(TRIM("CustomerId") AS INTEGER),
    CAST(TRIM("CreditScore") AS INTEGER),
    CAST(TRIM("Tenure") AS INTEGER),
    CAST(TRIM("Balance") AS REAL),
    CAST(TRIM("NumOfProducts") AS INTEGER),
    CAST(TRIM("HasCrCard") AS INTEGER),
    UPPER(TRIM("Card Type")),
    CAST(TRIM("EstimatedSalary") AS REAL)
FROM stg_churn_raw;

-- Engagement, feedback and churn outcome.
INSERT INTO activity (
    customer_id, is_active_member, complained,
    satisfaction_score, points_earned, exited
)
SELECT
    CAST(TRIM("CustomerId") AS INTEGER),
    CAST(TRIM("IsActiveMember") AS INTEGER),
    CAST(TRIM("Complain") AS INTEGER),
    CAST(TRIM("Satisfaction Score") AS INTEGER),
    CAST(TRIM("Point Earned") AS INTEGER),
    CAST(TRIM("Exited") AS INTEGER)
FROM stg_churn_raw;

COMMIT;
