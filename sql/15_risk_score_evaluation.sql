/* =============================================================================
   15_risk_score_evaluation.sql
   Business question: If the retention team calls the riskiest 10% each month,
                      how many real leavers would they reach - and does the
                      score work on customers it was NOT built from?
   Input   : v_customer_risk
   Method  : Customers are ranked into deciles WITHIN their own set
             (build or test), so each set is judged on its own: the test set
             is ranked as if it were a fresh month of customers.
             Same tie-break as the final score: score, then balance, then id.
   Metrics :
     top-10% churn rate  - share of the call list who actually left
     lift                - top-10% churn rate / that set's overall churn rate
     capture @ 10/20/30% - share of ALL the set's leavers found by calling
                           the top 10% / 20% / 30%
     bottom-10% churn    - churn in the lowest-risk decile (should be low)
     max capture @ 10%   - the best ANY list could do: a top-10% list holds
                           only 10% of customers, so it can hold at most
                           that many leavers
     margin (95%)        - normal sampling noise on a test-set rate:
                           1.96 x sqrt(rate x (1 - rate) / n)
   ============================================================================= */


/* Q15.1 Headline metrics, build vs test side by side. */
WITH ranked AS (
    SELECT
        split_set,
        exited,
        NTILE(10) OVER (
            PARTITION BY split_set
            ORDER BY risk_score DESC, balance DESC, customer_id
        ) AS set_decile
    FROM v_customer_risk
),
per_set AS (
    SELECT
        split_set,
        COUNT(*)                                                         AS customers,
        SUM(exited)                                                      AS leavers,
        AVG(exited * 1.0)                                                AS churn_rate,
        AVG(CASE WHEN set_decile = 1  THEN exited * 1.0 END)             AS top10_churn_rate,
        AVG(CASE WHEN set_decile = 10 THEN exited * 1.0 END)             AS bottom10_churn_rate,
        SUM(CASE WHEN set_decile <= 1 THEN exited ELSE 0 END) * 1.0 / SUM(exited) AS capture_top10,
        SUM(CASE WHEN set_decile <= 2 THEN exited ELSE 0 END) * 1.0 / SUM(exited) AS capture_top20,
        SUM(CASE WHEN set_decile <= 3 THEN exited ELSE 0 END) * 1.0 / SUM(exited) AS capture_top30
    FROM ranked
    GROUP BY split_set
)
SELECT
    split_set,
    customers,
    leavers,
    ROUND(churn_rate, 4)                     AS overall_churn_rate,
    ROUND(top10_churn_rate, 4)               AS top10_churn_rate,
    ROUND(top10_churn_rate / churn_rate, 2)  AS top10_lift,
    ROUND(capture_top10, 4)                  AS capture_top10,
    ROUND(capture_top20, 4)                  AS capture_top20,
    ROUND(capture_top30, 4)                  AS capture_top30,
    ROUND(bottom10_churn_rate, 4)            AS bottom10_churn_rate,
    ROUND(CASE WHEN customers / 10.0 < leavers THEN customers / 10.0 ELSE leavers END
          / leavers, 4)                      AS max_possible_capture_top10
FROM per_set
ORDER BY split_set;


/* Q15.2 Full gains table for the TEST set: every decile, with cumulative
         capture (running total of leavers found).                          */
WITH ranked AS (
    SELECT
        exited,
        risk_score,
        NTILE(10) OVER (ORDER BY risk_score DESC, balance DESC, customer_id) AS set_decile
    FROM v_customer_risk
    WHERE split_set = 'test'
),
by_decile AS (
    SELECT
        set_decile,
        COUNT(*)         AS customers,
        MIN(risk_score)  AS min_score,
        MAX(risk_score)  AS max_score,
        SUM(exited)      AS leavers
    FROM ranked
    GROUP BY set_decile
)
SELECT
    set_decile,
    customers,
    min_score,
    max_score,
    leavers,
    ROUND(leavers * 1.0 / customers, 4)                                AS churn_rate,
    ROUND((leavers * 1.0 / customers)
          / (SUM(leavers) OVER () * 1.0 / SUM(customers) OVER ()), 2)  AS lift,
    SUM(leavers) OVER (ORDER BY set_decile)                            AS cumulative_leavers,
    ROUND(SUM(leavers) OVER (ORDER BY set_decile) * 1.0
          / SUM(leavers) OVER (), 4)                                   AS cumulative_capture
FROM by_decile
ORDER BY set_decile;


/* Q15.3 Same gains table for the BUILD set, for comparison. */
WITH ranked AS (
    SELECT
        exited,
        risk_score,
        NTILE(10) OVER (ORDER BY risk_score DESC, balance DESC, customer_id) AS set_decile
    FROM v_customer_risk
    WHERE split_set = 'build'
),
by_decile AS (
    SELECT
        set_decile,
        COUNT(*)         AS customers,
        MIN(risk_score)  AS min_score,
        MAX(risk_score)  AS max_score,
        SUM(exited)      AS leavers
    FROM ranked
    GROUP BY set_decile
)
SELECT
    set_decile,
    customers,
    min_score,
    max_score,
    leavers,
    ROUND(leavers * 1.0 / customers, 4)                                AS churn_rate,
    ROUND((leavers * 1.0 / customers)
          / (SUM(leavers) OVER () * 1.0 / SUM(customers) OVER ()), 2)  AS lift,
    SUM(leavers) OVER (ORDER BY set_decile)                            AS cumulative_leavers,
    ROUND(SUM(leavers) OVER (ORDER BY set_decile) * 1.0
          / SUM(leavers) OVER (), 4)                                   AS cumulative_capture
FROM by_decile
ORDER BY set_decile;


/* Q15.4 Each factor's churn rate in BUILD vs TEST - where does the drop
         (if any) come from? Groups whose test rate differs a lot from the
         build rate are the ones the score "over-learned".                  */
WITH long_form AS (
    SELECT split_set, 'F1 Age band x activity' AS factor,
           age_band || ' / ' || activity_status AS factor_group, exited
    FROM v_customer_risk
    UNION ALL
    SELECT split_set, 'F2 Products held', CAST(num_products AS TEXT), exited
    FROM v_customer_risk
    UNION ALL
    SELECT split_set, 'F3 Country', country, exited
    FROM v_customer_risk
    UNION ALL
    SELECT split_set, 'F4 Balance',
           CASE WHEN balance = 0 THEN 'Zero' ELSE 'Has balance' END, exited
    FROM v_customer_risk
)
SELECT
    factor,
    factor_group,
    SUM(CASE WHEN split_set = 'build' THEN 1 ELSE 0 END)                   AS build_customers,
    ROUND(AVG(CASE WHEN split_set = 'build' THEN exited * 1.0 END), 4)     AS build_churn_rate,
    SUM(CASE WHEN split_set = 'test' THEN 1 ELSE 0 END)                    AS test_customers,
    ROUND(AVG(CASE WHEN split_set = 'test' THEN exited * 1.0 END), 4)      AS test_churn_rate,
    ROUND(AVG(CASE WHEN split_set = 'test'  THEN exited * 1.0 END)
        - AVG(CASE WHEN split_set = 'build' THEN exited * 1.0 END), 4)     AS test_minus_build
FROM long_form
GROUP BY factor, factor_group
ORDER BY ABS(AVG(CASE WHEN split_set = 'test'  THEN exited * 1.0 END)
           - AVG(CASE WHEN split_set = 'build' THEN exited * 1.0 END)) DESC
LIMIT 8;


/* Q15.5 Is the build-to-test change bigger than normal sampling noise?
         For each capture rate: test minus build, and the 95% margin of the
         test figure (n = test-set leavers). If |change| < margin, the drop
         is consistent with chance rather than a broken score.              */
WITH ranked AS (
    SELECT
        split_set,
        exited,
        NTILE(10) OVER (
            PARTITION BY split_set
            ORDER BY risk_score DESC, balance DESC, customer_id
        ) AS set_decile
    FROM v_customer_risk
),
capture AS (
    SELECT 'Top 10%' AS call_list, 1 AS deciles UNION ALL
    SELECT 'Top 20%', 2 UNION ALL
    SELECT 'Top 30%', 3
),
rates AS (
    SELECT
        cp.call_list,
        r.split_set,
        SUM(CASE WHEN r.set_decile <= cp.deciles THEN r.exited ELSE 0 END) * 1.0
            / SUM(r.exited)  AS capture_rate,
        SUM(r.exited)        AS leavers
    FROM ranked AS r
    CROSS JOIN capture AS cp
    GROUP BY cp.call_list, r.split_set
)
SELECT
    b.call_list,
    ROUND(b.capture_rate, 4)                                         AS build_capture,
    ROUND(t.capture_rate, 4)                                         AS test_capture,
    ROUND(t.capture_rate - b.capture_rate, 4)                        AS test_minus_build,
    ROUND(1.96 * SQRT(t.capture_rate * (1 - t.capture_rate) / t.leavers), 4) AS margin_95,
    CASE
        WHEN ABS(t.capture_rate - b.capture_rate)
             < 1.96 * SQRT(t.capture_rate * (1 - t.capture_rate) / t.leavers)
        THEN 'within noise'
        ELSE 'real change'
    END                                                              AS verdict
FROM rates AS b
JOIN rates AS t
  ON t.call_list = b.call_list
 AND t.split_set = 'test'
WHERE b.split_set = 'build'
ORDER BY b.call_list;
