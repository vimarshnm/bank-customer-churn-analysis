/* =============================================================================
   04_validation_checks.sql
   Purpose : Automated health checks to re-run on every month's data.
   Rule    : EVERY query returns ZERO rows when the data is healthy.
             Any row returned is a failure, and says what failed and where:
               check_name  - which rule broke
               customer_id - the offending customer (NULL for table-level checks)
               detail      - the bad value or the numbers that disagree
   Run     : ./scripts/run_checks.sh   (exits with an error if any row returns)
   Notes   : Sections A-B check the raw staging copy, so problems are found
             BEFORE type conversion can hide them (CAST('abc' AS INTEGER) = 0).
             Sections C-F check the typed tables; G checks the reference
             bands (07_reference_bands.sql); H checks the risk score
             (13_risk_points_derivation.sql vs 14_risk_score.sql). Some C-E rules repeat the
             schema CHECK constraints on purpose: constraints can be dropped
             or bypassed when data arrives another way, and these queries also
             run unchanged on databases that do not enforce CHECKs.
             Hard rules only - soft warnings (e.g. salary < 1,000) live in
             03_data_quality.sql so a healthy month is not reported as failed.
   ============================================================================= */


/* =============================================================================
   A. STAGING: COMPLETENESS AND UNIQUENESS
   ============================================================================= */

-- A1. Every raw field must be filled in (no NULLs or blanks).
SELECT
    'A1_missing_value' AS check_name,
    "CustomerId"       AS customer_id,
    'blank field in raw row ' || COALESCE("RowNumber", '?') AS detail
FROM stg_churn_raw
WHERE COALESCE(TRIM("CustomerId"), '')         = ''
   OR COALESCE(TRIM("Surname"), '')            = ''
   OR COALESCE(TRIM("CreditScore"), '')        = ''
   OR COALESCE(TRIM("Geography"), '')          = ''
   OR COALESCE(TRIM("Gender"), '')             = ''
   OR COALESCE(TRIM("Age"), '')                = ''
   OR COALESCE(TRIM("Tenure"), '')             = ''
   OR COALESCE(TRIM("Balance"), '')            = ''
   OR COALESCE(TRIM("NumOfProducts"), '')      = ''
   OR COALESCE(TRIM("HasCrCard"), '')          = ''
   OR COALESCE(TRIM("IsActiveMember"), '')     = ''
   OR COALESCE(TRIM("EstimatedSalary"), '')    = ''
   OR COALESCE(TRIM("Exited"), '')             = ''
   OR COALESCE(TRIM("Complain"), '')           = ''
   OR COALESCE(TRIM("Satisfaction Score"), '') = ''
   OR COALESCE(TRIM("Card Type"), '')          = ''
   OR COALESCE(TRIM("Point Earned"), '')       = '';

-- A2. Each customer appears once in the raw file.
SELECT
    'A2_duplicate_customer_id' AS check_name,
    "CustomerId"               AS customer_id,
    'appears ' || COUNT(*) || ' times' AS detail
FROM stg_churn_raw
GROUP BY "CustomerId"
HAVING COUNT(*) > 1;


/* =============================================================================
   B. STAGING: NUMBERS LOOK LIKE NUMBERS
   GLOB is SQLite's pattern match (PostgreSQL equivalent: !~ '^[0-9]+$').
   ============================================================================= */

-- B1. Whole-number columns contain only digits.
SELECT
    'B1_non_integer_value' AS check_name,
    "CustomerId"           AS customer_id,
    'CustomerId=' || "CustomerId" || ' CreditScore=' || "CreditScore"
        || ' Age=' || "Age" || ' Tenure=' || "Tenure"
        || ' NumOfProducts=' || "NumOfProducts"
        || ' Point Earned=' || "Point Earned" AS detail
FROM stg_churn_raw
WHERE TRIM("CustomerId")         GLOB '*[^0-9]*'
   OR TRIM("CreditScore")        GLOB '*[^0-9]*'
   OR TRIM("Age")                GLOB '*[^0-9]*'
   OR TRIM("Tenure")             GLOB '*[^0-9]*'
   OR TRIM("NumOfProducts")      GLOB '*[^0-9]*'
   OR TRIM("HasCrCard")          GLOB '*[^0-9]*'
   OR TRIM("IsActiveMember")     GLOB '*[^0-9]*'
   OR TRIM("Exited")             GLOB '*[^0-9]*'
   OR TRIM("Complain")           GLOB '*[^0-9]*'
   OR TRIM("Satisfaction Score") GLOB '*[^0-9]*'
   OR TRIM("Point Earned")       GLOB '*[^0-9]*';

-- B2. Money columns contain only digits and at most one decimal point.
SELECT
    'B2_non_decimal_value' AS check_name,
    "CustomerId"           AS customer_id,
    'Balance=' || "Balance" || ' EstimatedSalary=' || "EstimatedSalary" AS detail
FROM stg_churn_raw
WHERE TRIM("Balance")         GLOB '*[^0-9.]*'
   OR TRIM("Balance")         GLOB '*.*.*'
   OR TRIM("EstimatedSalary") GLOB '*[^0-9.]*'
   OR TRIM("EstimatedSalary") GLOB '*.*.*';


/* =============================================================================
   C. TYPED TABLES: VALID FLAGS AND CATEGORIES
   ============================================================================= */

-- C1. Yes/no flags are strictly 0 or 1.
SELECT 'C1_invalid_flag' AS check_name, customer_id,
       'has_credit_card=' || has_credit_card AS detail
FROM accounts
WHERE has_credit_card NOT IN (0, 1)
UNION ALL
SELECT 'C1_invalid_flag', customer_id, 'is_active_member=' || is_active_member
FROM activity
WHERE is_active_member NOT IN (0, 1)
UNION ALL
SELECT 'C1_invalid_flag', customer_id, 'complained=' || complained
FROM activity
WHERE complained NOT IN (0, 1)
UNION ALL
SELECT 'C1_invalid_flag', customer_id, 'exited=' || exited
FROM activity
WHERE exited NOT IN (0, 1);

-- C2. Text categories use only the agreed codes.
SELECT 'C2_invalid_category' AS check_name, customer_id,
       'gender=' || gender AS detail
FROM customers
WHERE gender NOT IN ('Female', 'Male')
UNION ALL
SELECT 'C2_invalid_category', customer_id, 'country=' || country
FROM customers
WHERE country NOT IN ('France', 'Germany', 'Spain')
UNION ALL
SELECT 'C2_invalid_category', customer_id, 'card_type=' || card_type
FROM accounts
WHERE card_type NOT IN ('SILVER', 'GOLD', 'PLATINUM', 'DIAMOND');


/* =============================================================================
   D. TYPED TABLES: VALUES IN RANGE
   Assumption: ranges match the business rules in 01_schema.sql.
   ============================================================================= */

-- D1. Numeric values fall inside their allowed business ranges.
SELECT 'D1_out_of_range' AS check_name, customer_id, 'age=' || age AS detail
FROM customers
WHERE age NOT BETWEEN 18 AND 100
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'credit_score=' || credit_score
FROM accounts
WHERE credit_score NOT BETWEEN 300 AND 900
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'tenure_years=' || tenure_years
FROM accounts
WHERE tenure_years NOT BETWEEN 0 AND 10
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'balance=' || balance
FROM accounts
WHERE balance < 0
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'num_products=' || num_products
FROM accounts
WHERE num_products NOT BETWEEN 1 AND 4
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'estimated_salary=' || estimated_salary
FROM accounts
WHERE estimated_salary <= 0
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'satisfaction_score=' || satisfaction_score
FROM activity
WHERE satisfaction_score NOT BETWEEN 1 AND 5
UNION ALL
SELECT 'D1_out_of_range', customer_id, 'points_earned=' || points_earned
FROM activity
WHERE points_earned < 0;


/* =============================================================================
   E. TYPED TABLES: RELATIONSHIPS (ORPHANS AND GAPS)
   Every customer must have exactly one accounts row and one activity row.
   ============================================================================= */

-- E1. Orphans: child rows pointing at a customer that does not exist.
SELECT 'E1_orphan_account' AS check_name, ac.customer_id, 'no matching customers row' AS detail
FROM accounts AS ac
LEFT JOIN customers AS c ON c.customer_id = ac.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'E1_orphan_activity', act.customer_id, 'no matching customers row'
FROM activity AS act
LEFT JOIN customers AS c ON c.customer_id = act.customer_id
WHERE c.customer_id IS NULL;

-- E2. Gaps: customers missing their accounts or activity row.
SELECT 'E2_customer_without_account' AS check_name, c.customer_id, 'no accounts row' AS detail
FROM customers AS c
LEFT JOIN accounts AS ac ON ac.customer_id = c.customer_id
WHERE ac.customer_id IS NULL
UNION ALL
SELECT 'E2_customer_without_activity', c.customer_id, 'no activity row'
FROM customers AS c
LEFT JOIN activity AS act ON act.customer_id = c.customer_id
WHERE act.customer_id IS NULL;


/* =============================================================================
   F. RECONCILIATION: NOTHING LOST OR ALTERED BETWEEN STAGING AND TYPED TABLES
   ============================================================================= */

-- F0. The load actually brought data in. Without this, empty tables would
--     PASS every other check (0 rows = 0 rows, and no rows to be invalid).
--     Assumption: a real monthly file has at least 1,000 customers.
SELECT
    'F0_too_few_rows' AS check_name,
    NULL              AS customer_id,
    'customers=' || COUNT(*) || ' (expected >= 1000)' AS detail
FROM customers
HAVING COUNT(*) < 1000;

-- F1. Row counts agree across staging and all typed tables.
WITH counts AS (
    SELECT
        (SELECT COUNT(*) FROM stg_churn_raw) AS staging_rows,
        (SELECT COUNT(*) FROM customers)     AS customers_rows,
        (SELECT COUNT(*) FROM accounts)      AS accounts_rows,
        (SELECT COUNT(*) FROM activity)      AS activity_rows
)
SELECT
    'F1_row_count_mismatch' AS check_name,
    NULL                    AS customer_id,
    'staging=' || staging_rows || ' customers=' || customers_rows
        || ' accounts=' || accounts_rows || ' activity=' || activity_rows AS detail
FROM counts
WHERE customers_rows <> staging_rows
   OR accounts_rows  <> staging_rows
   OR activity_rows  <> staging_rows;

-- F2. Control totals agree: total balance and number of leavers.
--     Balance compared to the cent to allow for floating-point rounding.
WITH totals AS (
    SELECT
        (SELECT ROUND(SUM(CAST("Balance" AS REAL)), 2) FROM stg_churn_raw) AS staging_balance,
        (SELECT ROUND(SUM(balance), 2)                 FROM accounts)      AS typed_balance,
        (SELECT SUM(CAST("Exited" AS INTEGER))         FROM stg_churn_raw) AS staging_leavers,
        (SELECT SUM(exited)                            FROM activity)      AS typed_leavers
)
SELECT
    'F2_control_total_mismatch' AS check_name,
    NULL                        AS customer_id,
    'balance ' || staging_balance || ' vs ' || typed_balance
        || '; leavers ' || staging_leavers || ' vs ' || typed_leavers AS detail
FROM totals
WHERE staging_balance <> typed_balance
   OR staging_leavers <> typed_leavers;

-- F3. Churn rate is within a believable band for a monthly snapshot.
--     A sudden jump usually means a broken extract, not a real event.
--     Assumption: 5%-40% band; this month is 20.38%. Adjust as history builds.
SELECT
    'F3_churn_rate_out_of_band' AS check_name,
    NULL                        AS customer_id,
    'churn_rate=' || ROUND(AVG(exited * 1.0), 4) AS detail
FROM activity
HAVING AVG(exited * 1.0) NOT BETWEEN 0.05 AND 0.40;


/* =============================================================================
   G. REFERENCE BANDS: NO GAPS, NO OVERLAPS
   ============================================================================= */

-- G1. Every customer falls into exactly one band of each type.
--     0 matches = a gap in the band edges; 2+ = overlapping bands.
WITH band_matches AS (
    SELECT 'age_bands' AS band_table, c.customer_id, COUNT(b.band_order) AS matches
    FROM customers AS c
    LEFT JOIN age_bands AS b
           ON c.age >= b.lower_bound AND c.age < b.upper_bound
    GROUP BY c.customer_id
    UNION ALL
    SELECT 'balance_bands', ac.customer_id, COUNT(b.band_order)
    FROM accounts AS ac
    LEFT JOIN balance_bands AS b
           ON ac.balance >= b.lower_bound AND ac.balance < b.upper_bound
    GROUP BY ac.customer_id
    UNION ALL
    SELECT 'tenure_bands', ac.customer_id, COUNT(b.band_order)
    FROM accounts AS ac
    LEFT JOIN tenure_bands AS b
           ON ac.tenure_years >= b.lower_bound AND ac.tenure_years < b.upper_bound
    GROUP BY ac.customer_id
    UNION ALL
    SELECT 'credit_score_bands', ac.customer_id, COUNT(b.band_order)
    FROM accounts AS ac
    LEFT JOIN credit_score_bands AS b
           ON ac.credit_score >= b.lower_bound AND ac.credit_score < b.upper_bound
    GROUP BY ac.customer_id
)
SELECT
    'G1_band_gap_or_overlap' AS check_name,
    customer_id,
    band_table || ' matches=' || matches AS detail
FROM band_matches
WHERE matches <> 1;


/* =============================================================================
   H. RISK SCORE: CASE POINTS MATCH THE BUILD-SET DERIVATION
   ============================================================================= */

-- H1. Every point awarded in v_customer_risk (14_risk_score.sql) equals the
--     points derived from the build set in v_risk_points_build (13_...sql).
--     A row here means someone edited the CASE logic, or the build data
--     changed and the points need re-deriving.
WITH awarded AS (
    SELECT customer_id, 'F1 Age band x activity' AS factor,
           age_band || ' / ' || activity_status AS factor_group,
           pts_age_activity AS points
    FROM v_customer_risk
    UNION ALL
    SELECT customer_id, 'F2 Products held', CAST(num_products AS TEXT), pts_products
    FROM v_customer_risk
    UNION ALL
    SELECT customer_id, 'F3 Country', country, pts_country
    FROM v_customer_risk
    UNION ALL
    SELECT customer_id, 'F4 Balance',
           CASE WHEN balance = 0 THEN 'Zero' ELSE 'Has balance' END, pts_balance
    FROM v_customer_risk
)
SELECT
    'H1_points_mismatch' AS check_name,
    a.customer_id,
    a.factor || ' [' || a.factor_group || '] awarded=' || COALESCE(a.points, 'NULL')
        || ' derived=' || COALESCE(d.points, 'none') AS detail
FROM awarded AS a
LEFT JOIN v_risk_points_build AS d
       ON d.factor = a.factor
      AND d.factor_group = a.factor_group
WHERE d.points IS NULL
   OR a.points IS NULL
   OR a.points <> d.points;
