/* =============================================================================
   03_data_quality.sql
   Purpose : One-off data quality profile of the loaded data, plus a leakage
             review to decide which columns may be used in the risk score.
   Input   : stg_churn_raw, customers, accounts, activity
   Output  : Result sets only (no tables changed). Findings are written up in
             reports/data_quality.md.
   Sections: 1 Row counts          5 Class balance (churn rate)
             2 NULL / blank checks 6 Leakage review
             3 Duplicates          7 Logical consistency and oddities
             4 Value ranges
   ============================================================================= */


/* -----------------------------------------------------------------------------
   1. ROW COUNTS
   Q1.1 Did every raw row make it into every typed table?
        Expect the same count in all four tables.
   ----------------------------------------------------------------------------- */
SELECT 'stg_churn_raw' AS table_name, COUNT(*) AS row_count FROM stg_churn_raw
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL
SELECT 'activity', COUNT(*) FROM activity;


/* -----------------------------------------------------------------------------
   2. NULL / BLANK CHECKS
   Q2.1 Are any raw values missing? Checked in staging, where everything is
        TEXT, so both NULLs and empty strings are caught before CAST could
        hide them (CAST('' AS INTEGER) silently becomes 0).
        Expect 0 in every column.
   ----------------------------------------------------------------------------- */
SELECT
    SUM(CASE WHEN COALESCE(TRIM("RowNumber"), '')          = '' THEN 1 ELSE 0 END) AS row_number_missing,
    SUM(CASE WHEN COALESCE(TRIM("CustomerId"), '')         = '' THEN 1 ELSE 0 END) AS customer_id_missing,
    SUM(CASE WHEN COALESCE(TRIM("Surname"), '')            = '' THEN 1 ELSE 0 END) AS surname_missing,
    SUM(CASE WHEN COALESCE(TRIM("CreditScore"), '')        = '' THEN 1 ELSE 0 END) AS credit_score_missing,
    SUM(CASE WHEN COALESCE(TRIM("Geography"), '')          = '' THEN 1 ELSE 0 END) AS geography_missing,
    SUM(CASE WHEN COALESCE(TRIM("Gender"), '')             = '' THEN 1 ELSE 0 END) AS gender_missing,
    SUM(CASE WHEN COALESCE(TRIM("Age"), '')                = '' THEN 1 ELSE 0 END) AS age_missing,
    SUM(CASE WHEN COALESCE(TRIM("Tenure"), '')             = '' THEN 1 ELSE 0 END) AS tenure_missing,
    SUM(CASE WHEN COALESCE(TRIM("Balance"), '')            = '' THEN 1 ELSE 0 END) AS balance_missing,
    SUM(CASE WHEN COALESCE(TRIM("NumOfProducts"), '')      = '' THEN 1 ELSE 0 END) AS num_products_missing,
    SUM(CASE WHEN COALESCE(TRIM("HasCrCard"), '')          = '' THEN 1 ELSE 0 END) AS has_cr_card_missing,
    SUM(CASE WHEN COALESCE(TRIM("IsActiveMember"), '')     = '' THEN 1 ELSE 0 END) AS is_active_missing,
    SUM(CASE WHEN COALESCE(TRIM("EstimatedSalary"), '')    = '' THEN 1 ELSE 0 END) AS salary_missing,
    SUM(CASE WHEN COALESCE(TRIM("Exited"), '')             = '' THEN 1 ELSE 0 END) AS exited_missing,
    SUM(CASE WHEN COALESCE(TRIM("Complain"), '')           = '' THEN 1 ELSE 0 END) AS complain_missing,
    SUM(CASE WHEN COALESCE(TRIM("Satisfaction Score"), '') = '' THEN 1 ELSE 0 END) AS satisfaction_missing,
    SUM(CASE WHEN COALESCE(TRIM("Card Type"), '')          = '' THEN 1 ELSE 0 END) AS card_type_missing,
    SUM(CASE WHEN COALESCE(TRIM("Point Earned"), '')       = '' THEN 1 ELSE 0 END) AS points_missing
FROM stg_churn_raw;


/* -----------------------------------------------------------------------------
   3. DUPLICATES
   Q3.1 Is CustomerId unique in the raw file? (The primary key would reject a
        duplicate during the load, but this shows WHICH ids clash.)
        Expect no rows.
   ----------------------------------------------------------------------------- */
SELECT
    "CustomerId" AS customer_id,
    COUNT(*)     AS times_seen
FROM stg_churn_raw
GROUP BY "CustomerId"
HAVING COUNT(*) > 1;

/* Q3.2 Are there fully duplicated customers - same person entered twice
        under different ids? Compare every attribute except the id and row
        number. Expect no rows.                                                */
SELECT
    "Surname", "Geography", "Gender", "Age", "CreditScore",
    "Balance", "EstimatedSalary",
    COUNT(*) AS times_seen
FROM stg_churn_raw
GROUP BY
    "Surname", "Geography", "Gender", "Age", "CreditScore",
    "Balance", "EstimatedSalary"
HAVING COUNT(*) > 1;

/* Q3.3 How unique are surnames? Context only: repeated surnames are normal
        and are NOT duplicates, which is why surname is never used as a key. */
SELECT
    COUNT(*)                AS customers,
    COUNT(DISTINCT surname) AS distinct_surnames
FROM customers;


/* -----------------------------------------------------------------------------
   4. VALUE RANGES
   Q4.1 Min / average / max of every numeric column, after typing.
   ----------------------------------------------------------------------------- */
SELECT 'age' AS column_name, MIN(age) AS min_value, ROUND(AVG(age), 2) AS avg_value, MAX(age) AS max_value
FROM customers
UNION ALL
SELECT 'credit_score', MIN(credit_score), ROUND(AVG(credit_score), 2), MAX(credit_score)
FROM accounts
UNION ALL
SELECT 'tenure_years', MIN(tenure_years), ROUND(AVG(tenure_years), 2), MAX(tenure_years)
FROM accounts
UNION ALL
SELECT 'balance', MIN(balance), ROUND(AVG(balance), 2), MAX(balance)
FROM accounts
UNION ALL
SELECT 'num_products', MIN(num_products), ROUND(AVG(num_products), 2), MAX(num_products)
FROM accounts
UNION ALL
SELECT 'estimated_salary', MIN(estimated_salary), ROUND(AVG(estimated_salary), 2), MAX(estimated_salary)
FROM accounts
UNION ALL
SELECT 'satisfaction_score', MIN(satisfaction_score), ROUND(AVG(satisfaction_score), 2), MAX(satisfaction_score)
FROM activity
UNION ALL
SELECT 'points_earned', MIN(points_earned), ROUND(AVG(points_earned), 2), MAX(points_earned)
FROM activity;

/* Q4.2 Distinct values of every categorical / flag column, with counts.
        Confirms there are no misspellings or unexpected codes.              */
SELECT 'country' AS column_name, country AS value, COUNT(*) AS customers
FROM customers GROUP BY country
UNION ALL
SELECT 'gender', gender, COUNT(*) FROM customers GROUP BY gender
UNION ALL
SELECT 'card_type', card_type, COUNT(*) FROM accounts GROUP BY card_type
UNION ALL
SELECT 'has_credit_card', CAST(has_credit_card AS TEXT), COUNT(*) FROM accounts GROUP BY has_credit_card
UNION ALL
SELECT 'is_active_member', CAST(is_active_member AS TEXT), COUNT(*) FROM activity GROUP BY is_active_member
UNION ALL
SELECT 'complained', CAST(complained AS TEXT), COUNT(*) FROM activity GROUP BY complained
UNION ALL
SELECT 'exited', CAST(exited AS TEXT), COUNT(*) FROM activity GROUP BY exited
ORDER BY column_name, value;

/* Q4.3 Values that pass the hard rules but look implausible (soft warnings).
        Assumption: an annual salary under 1,000 is implausible; a credit
        score of exactly 850 is the scale maximum (a pile-up = capped data).  */
SELECT 'estimated_salary < 1,000' AS warning, COUNT(*) AS customers
FROM accounts WHERE estimated_salary < 1000
UNION ALL
SELECT 'credit_score = 850 (scale cap)', COUNT(*)
FROM accounts WHERE credit_score = 850
UNION ALL
SELECT 'age >= 80', COUNT(*)
FROM customers WHERE age >= 80
UNION ALL
SELECT 'balance = 0', COUNT(*)
FROM accounts WHERE balance = 0;


/* -----------------------------------------------------------------------------
   5. CLASS BALANCE
   Q5.1 Overall churn rate - the baseline every segment and the risk score
        will be compared against.
   ----------------------------------------------------------------------------- */
SELECT
    COUNT(*)                           AS customers,
    SUM(exited)                        AS leavers,
    COUNT(*) - SUM(exited)             AS stayers,
    ROUND(AVG(exited * 1.0), 4)        AS churn_rate
FROM activity;


/* -----------------------------------------------------------------------------
   6. LEAKAGE REVIEW
   A column "leaks" if it would only be known after (or because) the customer
   left. A leaking column makes a score look brilliant in testing and useless
   in real life, because the information is not available in time to act.

   Q6.1 How closely does each 0/1 flag track exited?
        churn_rate_gap = churn when flag is 1 minus churn when flag is 0.
        0 = no relationship; close to +1 or -1 = the flag almost IS the
        outcome, which is suspicious. agreement_with_exited (share of rows
        where flag = exited) is shown too, but read it with care: with 20%
        churn, an unrelated flag can still score well away from 0.50.
   ----------------------------------------------------------------------------- */
WITH flags AS (
    SELECT 'complained' AS column_name, complained AS flag, exited
    FROM activity
    UNION ALL
    SELECT 'is_active_member', is_active_member, exited
    FROM activity
    UNION ALL
    SELECT 'has_credit_card', ac.has_credit_card, act.exited
    FROM accounts AS ac
    JOIN activity AS act ON act.customer_id = ac.customer_id
)
SELECT
    column_name,
    ROUND(AVG(CASE WHEN flag = exited THEN 1.0 ELSE 0.0 END), 4)        AS agreement_with_exited,
    ROUND(AVG(CASE WHEN flag = 1 THEN exited * 1.0 END), 4)             AS churn_rate_when_1,
    ROUND(AVG(CASE WHEN flag = 0 THEN exited * 1.0 END), 4)             AS churn_rate_when_0,
    ROUND(AVG(CASE WHEN flag = 1 THEN exited * 1.0 END)
          - AVG(CASE WHEN flag = 0 THEN exited * 1.0 END), 4)           AS churn_rate_gap,
    ROUND(SUM(CASE WHEN flag = 1 AND exited = 1 THEN 1.0 ELSE 0 END)
          / SUM(exited), 4)                                             AS share_of_leavers_flagged
FROM flags
GROUP BY column_name
ORDER BY ABS(AVG(CASE WHEN flag = 1 THEN exited * 1.0 END)
             - AVG(CASE WHEN flag = 0 THEN exited * 1.0 END)) DESC;

/* Q6.2 Complaint vs churn cross-tab: the detail behind the top Q6.1 result. */
SELECT
    complained,
    SUM(CASE WHEN exited = 1 THEN 1 ELSE 0 END) AS leavers,
    SUM(CASE WHEN exited = 0 THEN 1 ELSE 0 END) AS stayers
FROM activity
GROUP BY complained;

/* Q6.3 Churn rate by every value of each categorical / banded column.
        A value with churn of exactly 0% or 100% is "suspiciously close".     */
WITH by_value AS (
    SELECT 'satisfaction_score' AS column_name, CAST(satisfaction_score AS TEXT) AS value,
           COUNT(*) AS customers, AVG(exited * 1.0) AS churn_rate
    FROM activity
    GROUP BY satisfaction_score
    UNION ALL
    SELECT 'card_type', ac.card_type, COUNT(*), AVG(act.exited * 1.0)
    FROM accounts AS ac
    JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.card_type
    UNION ALL
    SELECT 'num_products', CAST(ac.num_products AS TEXT), COUNT(*), AVG(act.exited * 1.0)
    FROM accounts AS ac
    JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.num_products
    UNION ALL
    SELECT 'tenure_years', CAST(ac.tenure_years AS TEXT), COUNT(*), AVG(act.exited * 1.0)
    FROM accounts AS ac
    JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.tenure_years
)
SELECT
    column_name,
    value,
    customers,
    ROUND(churn_rate, 4) AS churn_rate,
    CASE WHEN churn_rate IN (0, 1) THEN 'CHECK: perfect separation' END AS flag
FROM by_value
ORDER BY column_name, value;

/* Q6.4 Spread of churn rate across each column's values (max - min).
        Near-zero spread = the column carries no churn signal at all.        */
WITH by_value AS (
    SELECT 'satisfaction_score' AS column_name, AVG(exited * 1.0) AS churn_rate
    FROM activity GROUP BY satisfaction_score
    UNION ALL
    SELECT 'card_type', AVG(act.exited * 1.0)
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.card_type
    UNION ALL
    SELECT 'num_products', AVG(act.exited * 1.0)
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.num_products
    UNION ALL
    SELECT 'tenure_years', AVG(act.exited * 1.0)
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
    GROUP BY ac.tenure_years
    UNION ALL
    SELECT 'country', AVG(act.exited * 1.0)
    FROM customers AS c JOIN activity AS act ON act.customer_id = c.customer_id
    GROUP BY c.country
    UNION ALL
    SELECT 'gender', AVG(act.exited * 1.0)
    FROM customers AS c JOIN activity AS act ON act.customer_id = c.customer_id
    GROUP BY c.gender
)
SELECT
    column_name,
    ROUND(MIN(churn_rate), 4)                   AS lowest_churn_rate,
    ROUND(MAX(churn_rate), 4)                   AS highest_churn_rate,
    ROUND(MAX(churn_rate) - MIN(churn_rate), 4) AS spread
FROM by_value
GROUP BY column_name
ORDER BY spread DESC;

/* Q6.5 Leavers vs stayers on each numeric column, as a standardised
        difference: (mean of leavers - mean of stayers) / overall std dev.
        Rule of thumb: |0.2| small, |0.5| medium, |0.8| large. A value far
        above 1 would be suspicious.                                          */
WITH base AS (
    SELECT
        act.exited,
        c.age, ac.credit_score, ac.tenure_years, ac.balance,
        ac.estimated_salary, act.points_earned, act.satisfaction_score
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
),
long_form AS (
    SELECT 'age'                AS column_name, exited, age                AS x FROM base UNION ALL
    SELECT 'credit_score',                      exited, credit_score            FROM base UNION ALL
    SELECT 'tenure_years',                      exited, tenure_years            FROM base UNION ALL
    SELECT 'balance',                           exited, balance                 FROM base UNION ALL
    SELECT 'estimated_salary',                  exited, estimated_salary        FROM base UNION ALL
    SELECT 'points_earned',                     exited, points_earned           FROM base UNION ALL
    SELECT 'satisfaction_score',                exited, satisfaction_score      FROM base
)
SELECT
    column_name,
    ROUND(AVG(CASE WHEN exited = 1 THEN x END), 2)               AS avg_leavers,
    ROUND(AVG(CASE WHEN exited = 0 THEN x END), 2)               AS avg_stayers,
    ROUND(
        (AVG(CASE WHEN exited = 1 THEN x END) - AVG(CASE WHEN exited = 0 THEN x END))
        / SQRT(AVG(x * x) - AVG(x) * AVG(x)),                    -- population std dev
    3)                                                           AS standardised_diff
FROM long_form
GROUP BY column_name
ORDER BY ABS(
    (AVG(CASE WHEN exited = 1 THEN x END) - AVG(CASE WHEN exited = 0 THEN x END))
    / SQRT(AVG(x * x) - AVG(x) * AVG(x))
) DESC;


/* -----------------------------------------------------------------------------
   7. LOGICAL CONSISTENCY AND ODDITIES
   Q7.1 Customers with no credit card but a card_type recorded. If card_type
        were the credit card's tier this should be 0, so card_type is more
        likely a membership / debit-card tier.
   ----------------------------------------------------------------------------- */
SELECT
    has_credit_card,
    card_type,
    COUNT(*) AS customers
FROM accounts
GROUP BY has_credit_card, card_type
ORDER BY has_credit_card, card_type;

/* Q7.2 Zero-balance accounts by country. A country with no zero balances at
        all while others have ~half suggests a difference in how the data was
        collected, which matters when comparing balances across countries.   */
SELECT
    c.country,
    COUNT(*)                                          AS customers,
    SUM(CASE WHEN ac.balance = 0 THEN 1 ELSE 0 END)   AS zero_balance_customers,
    ROUND(AVG(CASE WHEN ac.balance = 0 THEN 1.0 ELSE 0 END), 4) AS zero_balance_share
FROM customers AS c
JOIN accounts  AS ac ON ac.customer_id = c.customer_id
GROUP BY c.country
ORDER BY c.country;

/* Q7.3 Lowest credit scores: every customer below 405 left (found while
        banding scores for the analysis). Same "perfect separation" warning as
        4 products in Q6.3 - too small (21 customers) to build a rule on,
        and possibly a data artefact (e.g. score recorded after default).   */
SELECT
    CASE WHEN ac.credit_score < 405 THEN 'Under 405' ELSE '405 and over' END AS credit_score_group,
    COUNT(*)                    AS customers,
    SUM(act.exited)             AS leavers,
    ROUND(AVG(act.exited * 1.0), 4) AS churn_rate
FROM accounts AS ac
JOIN activity AS act ON act.customer_id = ac.customer_id
GROUP BY CASE WHEN ac.credit_score < 405 THEN 'Under 405' ELSE '405 and over' END
ORDER BY credit_score_group DESC;
