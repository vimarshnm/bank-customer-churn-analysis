/* =============================================================================
   14_risk_score.sql
   Purpose : The final churn risk score for every customer.
   Output  : view v_customer_risk - one row per customer with each factor's
             points, the total score, risk decile, risk tier and call priority.
   Points  : copied from v_risk_points_build (13_risk_points_derivation.sql),
             which used the BUILD SET ONLY. Check H1 in 04_validation_checks.sql
             fails if these CASE points ever drift from the derivation.
   Score   : 0 (lowest risk) to 65 (highest). +7 points ~ double the risk.

   Ranking : NTILE(10) over ALL customers, highest score first.
             Ties on score are broken by balance (bigger depositor first -
             more money at stake), then customer_id so the order is stable.
   Tiers   - Assumption: tier boundaries are business choices, adjustable:
     risk_tier      decile 1 = 'Very high', 2-3 = 'High', 4-6 = 'Medium',
                    7-10 = 'Low'
     call_priority  only for decile 1 (the retention team's top 10% list):
                    'P1 High value'  balance >= 100,000  (call first)
                    'P2 Mid value'   balance 0.01-99,999
                    'P3 No balance'  balance = 0         (call if capacity)
                    everyone else = 'Not targeted'
   ============================================================================= */

DROP VIEW IF EXISTS v_customer_risk;

CREATE VIEW v_customer_risk AS
WITH factors AS (
    SELECT
        c.customer_id,
        s.split_set,
        c.surname,
        c.country,
        c.gender,
        c.age,
        ab.band_label                                                    AS age_band,
        CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS activity_status,
        ac.num_products,
        ac.balance,
        act.exited,

        -- F1 Age band x activity status ------------------------------------
        CASE
            WHEN ab.band_label = '18-29' AND act.is_active_member = 1 THEN  0
            WHEN ab.band_label = '18-29' AND act.is_active_member = 0 THEN  6
            WHEN ab.band_label = '30-39' AND act.is_active_member = 1 THEN  4
            WHEN ab.band_label = '30-39' AND act.is_active_member = 0 THEN  9
            WHEN ab.band_label = '40-49' AND act.is_active_member = 1 THEN 14
            WHEN ab.band_label = '40-49' AND act.is_active_member = 0 THEN 19
            WHEN ab.band_label = '50-59' AND act.is_active_member = 1 THEN 19
            WHEN ab.band_label = '50-59' AND act.is_active_member = 0 THEN 26
            WHEN ab.band_label = '60-69' AND act.is_active_member = 1 THEN 10
            WHEN ab.band_label = '60-69' AND act.is_active_member = 0 THEN 27
            WHEN ab.band_label = '70+'   AND act.is_active_member = 1 THEN  0
            WHEN ab.band_label = '70+'   AND act.is_active_member = 0 THEN 21
        END                                                              AS pts_age_activity,

        -- F2 Products held --------------------------------------------------
        CASE ac.num_products
            WHEN 1 THEN 13
            WHEN 2 THEN  0
            WHEN 3 THEN 24
            WHEN 4 THEN 24
        END                                                              AS pts_products,

        -- F3 Country --------------------------------------------------------
        CASE c.country
            WHEN 'France'  THEN 0
            WHEN 'Germany' THEN 8
            WHEN 'Spain'   THEN 1
        END                                                              AS pts_country,

        -- F4 Balance --------------------------------------------------------
        CASE WHEN ac.balance = 0 THEN 0 ELSE 6 END                       AS pts_balance

    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands AS ab  ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
    JOIN v_build_test_split AS s ON s.customer_id = c.customer_id
),
scored AS (
    SELECT
        factors.*,
        pts_age_activity + pts_products + pts_country + pts_balance AS risk_score
    FROM factors
),
ranked AS (
    SELECT
        scored.*,
        NTILE(10) OVER (ORDER BY risk_score DESC, balance DESC, customer_id) AS risk_decile,
        ROW_NUMBER() OVER (ORDER BY risk_score DESC, balance DESC, customer_id) AS risk_rank
    FROM scored
)
SELECT
    customer_id,
    split_set,
    surname,
    country,
    gender,
    age,
    age_band,
    activity_status,
    num_products,
    balance,
    pts_age_activity,
    pts_products,
    pts_country,
    pts_balance,
    risk_score,
    risk_rank,
    risk_decile,
    CASE
        WHEN risk_decile = 1             THEN 'Very high'
        WHEN risk_decile IN (2, 3)       THEN 'High'
        WHEN risk_decile BETWEEN 4 AND 6 THEN 'Medium'
        ELSE 'Low'
    END                                  AS risk_tier,
    CASE
        WHEN risk_decile <> 1   THEN 'Not targeted'
        WHEN balance >= 100000  THEN 'P1 High value'
        WHEN balance > 0        THEN 'P2 Mid value'
        ELSE 'P3 No balance'
    END                                  AS call_priority,
    exited
FROM ranked;


/* Q14.1 Summary by risk tier (all customers). */
SELECT
    risk_tier,
    MIN(risk_decile)                 AS first_decile,
    COUNT(*)                         AS customers,
    MIN(risk_score)                  AS min_score,
    MAX(risk_score)                  AS max_score,
    SUM(exited)                      AS leavers,
    ROUND(AVG(exited * 1.0), 4)      AS churn_rate
FROM v_customer_risk
GROUP BY risk_tier
ORDER BY first_decile;


/* Q14.2 Call priority within the top 10%. */
SELECT
    call_priority,
    COUNT(*)                         AS customers,
    SUM(exited)                      AS leavers,
    ROUND(AVG(exited * 1.0), 4)      AS churn_rate,
    ROUND(SUM(balance), 2)           AS total_balance
FROM v_customer_risk
WHERE risk_decile = 1
GROUP BY call_priority
ORDER BY call_priority;


/* Q14.3 Worked example: the 5 highest-ranked customers and how their score
         was built - this is what a retention agent would see.             */
SELECT
    risk_rank,
    customer_id,
    age_band || ', ' || activity_status || ', ' || num_products || ' products, '
        || country || ', balance ' || ROUND(balance, 0)  AS profile,
    pts_age_activity || ' + ' || pts_products || ' + ' || pts_country
        || ' + ' || pts_balance || ' = ' || risk_score     AS score_breakdown,
    call_priority
FROM v_customer_risk
ORDER BY risk_rank
LIMIT 5;
