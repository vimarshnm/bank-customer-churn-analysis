/* =============================================================================
   10_financial_comparison.sql
   Business question: Are leavers financially different from stayers, and how
                      much money left the bank with them?
   Input   : customers, accounts, activity
   Output  : Averages and medians for leavers vs stayers; deposits lost
             overall, by country and by balance band.
   Notes   : "Deposits lost" = sum of the balances held by customers who left
             (exited = 1) as at this snapshot.
             Assumption: the balance shown for a leaver is the balance they
             took with them (the data has no closing-balance field).
   ============================================================================= */


/* Q10.1 Leavers vs stayers: average balance, credit score and salary. */
SELECT
    CASE act.exited WHEN 1 THEN 'Leavers' ELSE 'Stayers' END AS customer_group,
    COUNT(*)                                AS customers,
    ROUND(AVG(ac.balance), 2)               AS avg_balance,
    ROUND(AVG(CASE WHEN ac.balance > 0 THEN ac.balance END), 2) AS avg_balance_excl_zero,
    ROUND(AVG(ac.credit_score), 1)          AS avg_credit_score,
    ROUND(AVG(ac.estimated_salary), 2)      AS avg_salary,
    ROUND(AVG(CASE WHEN ac.balance = 0 THEN 1.0 ELSE 0 END), 4) AS zero_balance_share
FROM accounts AS ac
JOIN activity AS act ON act.customer_id = ac.customer_id
GROUP BY act.exited
ORDER BY act.exited DESC;


/* Q10.2 Medians, which are not distorted by extreme values.
         SQLite has no MEDIAN(), so it is built with window functions:
         number each group's values in order, then average the middle one
         (odd count) or middle two (even count).                           */
WITH long_form AS (
    SELECT act.exited, 'balance' AS measure, ac.balance AS value
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
    UNION ALL
    SELECT act.exited, 'credit_score', ac.credit_score
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
    UNION ALL
    SELECT act.exited, 'estimated_salary', ac.estimated_salary
    FROM accounts AS ac JOIN activity AS act ON act.customer_id = ac.customer_id
),
numbered AS (
    SELECT
        exited,
        measure,
        value,
        ROW_NUMBER() OVER (PARTITION BY exited, measure ORDER BY value) AS rn,
        COUNT(*)     OVER (PARTITION BY exited, measure)                AS n
    FROM long_form
)
SELECT
    measure,
    ROUND(AVG(CASE WHEN exited = 1 THEN value END), 2) AS median_leavers,
    ROUND(AVG(CASE WHEN exited = 0 THEN value END), 2) AS median_stayers
FROM numbered
WHERE rn IN ((n + 1) / 2, (n + 2) / 2)   -- integer division picks the middle row(s)
GROUP BY measure
ORDER BY measure;


/* Q10.3 Total deposits lost, and what share of all deposits that is. */
SELECT
    ROUND(SUM(ac.balance), 2)                                         AS total_deposits,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END), 2) AS deposits_lost,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)
          / SUM(ac.balance), 4)                                        AS share_of_deposits_lost,
    SUM(act.exited)                                                    AS leavers,
    ROUND(SUM(act.exited) * 1.0 / COUNT(*), 4)                         AS share_of_customers_lost
FROM accounts AS ac
JOIN activity AS act ON act.customer_id = ac.customer_id;


/* Q10.4 Deposits lost by country - where is the money leaving from? */
SELECT
    c.country,
    COUNT(*)                                                           AS customers,
    SUM(act.exited)                                                    AS leavers,
    ROUND(SUM(ac.balance), 2)                                          AS total_deposits,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END), 2) AS deposits_lost,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)
          / SUM(ac.balance), 4)                                        AS share_of_country_deposits_lost,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)
          / SUM(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)) OVER (), 4)
                                                                       AS share_of_all_deposits_lost
FROM customers AS c
JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
JOIN activity  AS act ON act.customer_id = c.customer_id
GROUP BY c.country
ORDER BY deposits_lost DESC;


/* Q10.5 Deposits lost by balance band - are we losing big or small savers? */
SELECT
    bb.band_label                                                      AS balance_band,
    COUNT(*)                                                           AS customers,
    SUM(act.exited)                                                    AS leavers,
    ROUND(AVG(act.exited * 1.0), 4)                                    AS churn_rate,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END), 2) AS deposits_lost,
    ROUND(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)
          / SUM(SUM(CASE WHEN act.exited = 1 THEN ac.balance ELSE 0 END)) OVER (), 4)
                                                                       AS share_of_all_deposits_lost
FROM accounts AS ac
JOIN activity      AS act ON act.customer_id = ac.customer_id
JOIN balance_bands AS bb  ON ac.balance >= bb.lower_bound AND ac.balance < bb.upper_bound
GROUP BY bb.band_order, bb.band_label
ORDER BY bb.band_order;


/* Q10.6 Is the balance effect just the Germany effect? Germany has no
         zero balances AND the highest churn (data quality Q7.2), which could
         make "has a balance" look riskier than it is. Re-test zero vs
         non-zero balances in France and Spain only.                        */
SELECT
    CASE WHEN ac.balance = 0 THEN 'Zero balance' ELSE 'Has a balance' END AS balance_group,
    COUNT(*)                        AS customers,
    SUM(act.exited)                 AS leavers,
    ROUND(AVG(act.exited * 1.0), 4) AS churn_rate
FROM customers AS c
JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
JOIN activity  AS act ON act.customer_id = c.customer_id
WHERE c.country IN ('France', 'Spain')
GROUP BY CASE WHEN ac.balance = 0 THEN 'Zero balance' ELSE 'Has a balance' END
ORDER BY balance_group;
