/* =============================================================================
   12_build_test_split.sql
   Purpose : Split customers into a BUILD set (~70%) used to design the risk
             score, and a TEST set (~30%) kept aside to check it fairly.
   Output  : view v_build_test_split (customer_id, split_set)
   Rule    : last digit of customer_id:  0-6 -> 'build',  7-9 -> 'test'
             (customer_id % 10, where % is the remainder after dividing by 10)
   Why this rule:
     - Deterministic and reproducible: same customer, same set, every run,
       in any SQL database - no random seed to store.
     - Unrelated to churn: a customer number's last digit is assigned at
       account opening and carries no meaning (verified in Q12.2 - churn by
       digit ranges 18.31%-22.22% with no pattern).
     - Stable over time: next month's existing customers stay in the same set,
       so test results remain comparable month to month.
   Caveat  : a pure random split would be equally valid; the last-digit rule
             is preferred because anyone can reproduce it by hand.
   ============================================================================= */

DROP VIEW IF EXISTS v_build_test_split;

CREATE VIEW v_build_test_split AS
SELECT
    customer_id,
    CASE WHEN customer_id % 10 <= 6 THEN 'build' ELSE 'test' END AS split_set
FROM customers;


/* Q12.1 Are the two sets alike? Size, churn rate and the key drivers
         should be close, otherwise the test would not be a fair check.     */
SELECT
    s.split_set,
    COUNT(*)                                                       AS customers,
    ROUND(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (), 4)               AS share_of_customers,
    SUM(act.exited)                                                AS leavers,
    ROUND(AVG(act.exited * 1.0), 4)                                AS churn_rate,
    ROUND(AVG(c.age), 2)                                           AS avg_age,
    ROUND(AVG(CASE WHEN c.country = 'Germany' THEN 1.0 ELSE 0 END), 4) AS germany_share,
    ROUND(AVG(act.is_active_member * 1.0), 4)                      AS active_share,
    ROUND(AVG(ac.num_products * 1.0), 2)                           AS avg_products
FROM v_build_test_split AS s
JOIN customers AS c   ON c.customer_id   = s.customer_id
JOIN accounts  AS ac  ON ac.customer_id  = s.customer_id
JOIN activity  AS act ON act.customer_id = s.customer_id
GROUP BY s.split_set
ORDER BY s.split_set;


/* Q12.2 Is the last digit unrelated to churn? Each digit should hold ~10%
         of customers with churn close to the overall 20.38%.               */
SELECT
    customer_id % 10                AS last_digit,
    COUNT(*)                        AS customers,
    ROUND(AVG(exited * 1.0), 4)     AS churn_rate
FROM activity
GROUP BY customer_id % 10
ORDER BY last_digit;
