/* =============================================================================
   13_risk_points_derivation.sql
   Purpose : Derive the risk-score points from the BUILD SET ONLY.
             The view v_risk_points_build is the evidence for every number
             written into the CASE statements in 14_risk_score.sql; check H1 in
             04_validation_checks.sql proves the two match.
   Output  : view v_risk_points_build
   Input   : v_build_test_split (build rows only), customers, accounts,
             activity, age_bands
   Factors (chosen in the data-quality review and analysis - no leakage columns, no gender):
     F1 Age band x activity status  - one factor, because the two interact
                                      (inactive 50-59 is far worse than
                                      "old" + "inactive" added separately)
     F2 Products held (1 / 2 / 3 / 4)
     F3 Country
     F4 Balance (zero vs has a balance)
   Method  - a simple "scorecard":
     1. For each group, take its churn rate in the build set.
     2. Smooth small groups toward average: add 10 imaginary customers who
        churn at the build-set average. A group of 12 cannot claim 0% or
        100% risk; a group of 2,000 is barely affected.
          smoothed_rate = (leavers + 10 * build_rate) / (customers + 10)
     3. Points = 10 x natural log of (smoothed_rate / build_rate), rounded.
        Logs make points ADD UP sensibly: +7 points = about double the risk,
        -7 points = about half.
     4. Shift each factor so its safest group scores 0 (no negative points).
   Assumption: smoothing weight 10 and scale 10 are judgement calls chosen
             for readability; they are not tuned on the test set.
   ============================================================================= */


/* Q13.1 Build-set baseline. */
SELECT
    COUNT(*)                         AS build_customers,
    SUM(act.exited)                  AS build_leavers,
    ROUND(AVG(act.exited * 1.0), 4)  AS build_churn_rate
FROM v_build_test_split AS s
JOIN activity AS act ON act.customer_id = s.customer_id
WHERE s.split_set = 'build';


/* Points for every group of every factor, derived from build data. */
DROP VIEW IF EXISTS v_risk_points_build;

CREATE VIEW v_risk_points_build AS
WITH build AS (
    SELECT
        ab.band_order,
        ab.band_label || ' / '
            || CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS age_activity,
        CAST(ac.num_products AS TEXT)                                     AS products,
        c.country,
        CASE WHEN ac.balance = 0 THEN 'Zero' ELSE 'Has balance' END       AS balance_group,
        act.exited
    FROM v_build_test_split AS s
    JOIN customers AS c   ON c.customer_id   = s.customer_id
    JOIN accounts  AS ac  ON ac.customer_id  = s.customer_id
    JOIN activity  AS act ON act.customer_id = s.customer_id
    JOIN age_bands AS ab  ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
    WHERE s.split_set = 'build'
),
baseline AS (
    SELECT AVG(exited * 1.0) AS build_rate FROM build
),
groups AS (
    SELECT 'F1 Age band x activity' AS factor, age_activity AS factor_group,
           MIN(band_order) AS sort_key, COUNT(*) AS customers, SUM(exited) AS leavers
    FROM build GROUP BY age_activity
    UNION ALL
    SELECT 'F2 Products held', products, MIN(CAST(products AS INTEGER)), COUNT(*), SUM(exited)
    FROM build GROUP BY products
    UNION ALL
    SELECT 'F3 Country', country, 0, COUNT(*), SUM(exited)
    FROM build GROUP BY country
    UNION ALL
    SELECT 'F4 Balance', balance_group, 0, COUNT(*), SUM(exited)
    FROM build GROUP BY balance_group
),
raw_points AS (
    SELECT
        g.factor,
        g.factor_group,
        g.sort_key,
        g.customers,
        g.leavers,
        g.leavers * 1.0 / g.customers                                  AS churn_rate,
        (g.leavers + 10 * b.build_rate) / (g.customers + 10)           AS smoothed_rate,
        10 * LN(((g.leavers + 10 * b.build_rate) / (g.customers + 10)) / b.build_rate)
                                                                       AS log_lift_points
    FROM groups AS g
    CROSS JOIN baseline AS b
)
SELECT
    factor,
    factor_group,
    sort_key,
    customers,
    leavers,
    ROUND(churn_rate, 4)                                         AS build_churn_rate,
    ROUND(smoothed_rate, 4)                                      AS smoothed_rate,
    ROUND(log_lift_points, 2)                                    AS log_lift_points,
    CAST(ROUND(log_lift_points) AS INTEGER)
      - MIN(CAST(ROUND(log_lift_points) AS INTEGER)) OVER (PARTITION BY factor)
                                                                 AS points
FROM raw_points;


/* Q13.2 The points table, readable order. */
SELECT
    factor,
    factor_group,
    customers,
    leavers,
    build_churn_rate,
    smoothed_rate,
    log_lift_points,
    points
FROM v_risk_points_build
ORDER BY factor, sort_key, factor_group;


/* Q13.3 Score range: the lowest and highest score a customer can get. */
SELECT
    SUM(min_points) AS min_possible_score,
    SUM(max_points) AS max_possible_score
FROM (
    SELECT factor, MIN(points) AS min_points, MAX(points) AS max_points
    FROM v_risk_points_build
    GROUP BY factor
) AS per_factor;


/* Q13.4 What smoothing changed. Compares log-lift points BEFORE the
         shift-to-zero step (shifting moves every group in a factor by the
         same amount, so it would blur the comparison). Large groups barely
         move; small groups are pulled toward 0 (= average risk).            */
WITH baseline AS (
    SELECT SUM(leavers) * 1.0 / SUM(customers) AS build_rate
    FROM v_risk_points_build
    WHERE factor = 'F3 Country'          -- any one factor covers every build customer
)
SELECT
    p.factor,
    p.factor_group,
    p.customers,
    ROUND(10 * LN((p.leavers * 1.0 / p.customers) / b.build_rate), 2) AS unsmoothed_log_lift,
    ROUND(p.log_lift_points, 2)                                       AS smoothed_log_lift,
    ROUND(p.log_lift_points
          - 10 * LN((p.leavers * 1.0 / p.customers) / b.build_rate), 2) AS change_from_smoothing
FROM v_risk_points_build AS p
CROSS JOIN baseline AS b
ORDER BY ABS(p.log_lift_points
             - 10 * LN((p.leavers * 1.0 / p.customers) / b.build_rate)) DESC
LIMIT 5;
