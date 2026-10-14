/* =============================================================================
   06_query_plans.sql
   Purpose : Show HOW SQLite runs three key queries, so the effect of the
             indexes in 05_indexes.sql can be compared before and after.
   Run     : ./scripts/explain_plans.sh  (drops the indexes, runs this file,
             recreates the indexes, runs this file again)
   Reading : SCAN    = reads every row of the table
             SEARCH  = jumps straight to matching rows via a key or index
             COVERING INDEX = answered from the index alone, table not touched
             USE TEMP B-TREE = builds a temporary sort structure (extra work)
   ============================================================================= */

-- P1. Churn rate by country (the most-used segment cut).
EXPLAIN QUERY PLAN
SELECT
    c.country,
    COUNT(*)              AS customers,
    AVG(act.exited * 1.0) AS churn_rate
FROM customers AS c
JOIN activity  AS act ON act.customer_id = c.customer_id
GROUP BY c.country;

-- P2. Inactive customers in Germany and their deposits (a targeted segment).
EXPLAIN QUERY PLAN
SELECT
    COUNT(*)        AS customers,
    SUM(ac.balance) AS total_balance
FROM customers AS c
JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
JOIN activity  AS act ON act.customer_id = c.customer_id
WHERE c.country = 'Germany'
  AND act.is_active_member = 0;

-- P3. Deposits lost from high-balance leavers (balance over 150,000).
EXPLAIN QUERY PLAN
SELECT
    SUM(ac.balance) AS deposits_lost
FROM accounts AS ac
JOIN activity AS act ON act.customer_id = ac.customer_id
WHERE ac.balance > 150000
  AND act.exited = 1;
