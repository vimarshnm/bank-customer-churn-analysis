/* =============================================================================
   08_churn_by_attribute.sql
   Business question: Which single customer attributes are linked to higher
                      churn?
   Input   : customers, accounts, activity, *_bands lookup tables
   Output  : One row per attribute value: customers, leavers, churn rate,
             share of all leavers, and lift vs the overall churn rate.
   Reading : lift = segment churn rate / overall churn rate.
             1.00 = average; 1.50 = 50% more likely to leave than average.
   ============================================================================= */


/* Q8.1 Overall baseline - every lift in this file is relative to this. */
SELECT
    COUNT(*)                    AS customers,
    SUM(exited)                 AS leavers,
    ROUND(AVG(exited * 1.0), 4) AS churn_rate
FROM activity;


/* Q8.2 Churn by every key attribute, in one comparable table.
        Step 1 (customer_base): join the three tables and attach bands.
        Step 2 (by_attribute): one GROUP BY per attribute, stacked with
                UNION ALL into a common shape.
        Step 3: add share of leavers and lift using the overall totals.     */
WITH customer_base AS (
    SELECT
        c.customer_id,
        c.country,
        c.gender,
        ab.band_label  AS age_band,
        ab.band_order  AS age_order,
        ac.num_products,
        CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS activity_status,
        CASE ac.has_credit_card   WHEN 1 THEN 'Has card' ELSE 'No card' END AS credit_card,
        bb.band_label  AS balance_band,
        bb.band_order  AS balance_order,
        tb.band_label  AS tenure_band,
        tb.band_order  AS tenure_order,
        cb.band_label  AS credit_band,
        cb.band_order  AS credit_order,
        act.exited
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands          AS ab ON c.age           >= ab.lower_bound AND c.age           < ab.upper_bound
    JOIN balance_bands      AS bb ON ac.balance      >= bb.lower_bound AND ac.balance      < bb.upper_bound
    JOIN tenure_bands       AS tb ON ac.tenure_years >= tb.lower_bound AND ac.tenure_years < tb.upper_bound
    JOIN credit_score_bands AS cb ON ac.credit_score >= cb.lower_bound AND ac.credit_score < cb.upper_bound
),
by_attribute AS (
    SELECT 1 AS attr_order, 'Country' AS attribute, country AS value, 0 AS value_order,
           COUNT(*) AS customers, SUM(exited) AS leavers
    FROM customer_base GROUP BY country
    UNION ALL
    SELECT 2, 'Gender', gender, 0, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY gender
    UNION ALL
    SELECT 3, 'Age band', age_band, age_order, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY age_band, age_order
    UNION ALL
    SELECT 4, 'Products held', CAST(num_products AS TEXT), num_products, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY num_products
    UNION ALL
    SELECT 5, 'Activity status', activity_status, 0, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY activity_status
    UNION ALL
    SELECT 6, 'Balance band', balance_band, balance_order, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY balance_band, balance_order
    UNION ALL
    SELECT 7, 'Tenure band', tenure_band, tenure_order, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY tenure_band, tenure_order
    UNION ALL
    SELECT 8, 'Credit score band', credit_band, credit_order, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY credit_band, credit_order
    UNION ALL
    SELECT 9, 'Credit card', credit_card, 0, COUNT(*), SUM(exited)
    FROM customer_base GROUP BY credit_card
),
overall AS (
    SELECT COUNT(*) AS customers, SUM(exited) AS leavers, AVG(exited * 1.0) AS churn_rate
    FROM activity
)
SELECT
    b.attribute,
    b.value,
    b.customers,
    b.leavers,
    ROUND(b.leavers * 1.0 / b.customers, 4)                  AS churn_rate,
    ROUND(b.leavers * 1.0 / o.leavers, 4)                    AS share_of_all_leavers,
    ROUND((b.leavers * 1.0 / b.customers) / o.churn_rate, 2) AS lift
FROM by_attribute AS b
CROSS JOIN overall AS o
ORDER BY b.attr_order, b.value_order, b.value;


/* Q8.3 Which attribute separates churn the most? For each attribute, the
        gap between its highest- and lowest-churn values. Only values with
        at least 100 customers count, so tiny groups (e.g. 4 products = 60
        customers) cannot dominate.
        Assumption: 100 customers = minimum group size for a reliable rate. */
WITH customer_base AS (
    SELECT
        c.country, c.gender, ab.band_label AS age_band, ac.num_products,
        act.is_active_member, bb.band_label AS balance_band,
        tb.band_label AS tenure_band, cb.band_label AS credit_band,
        ac.has_credit_card, act.exited
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands          AS ab ON c.age           >= ab.lower_bound AND c.age           < ab.upper_bound
    JOIN balance_bands      AS bb ON ac.balance      >= bb.lower_bound AND ac.balance      < bb.upper_bound
    JOIN tenure_bands       AS tb ON ac.tenure_years >= tb.lower_bound AND ac.tenure_years < tb.upper_bound
    JOIN credit_score_bands AS cb ON ac.credit_score >= cb.lower_bound AND ac.credit_score < cb.upper_bound
),
rates AS (
    SELECT 'Country' AS attribute, AVG(exited * 1.0) AS churn_rate FROM customer_base
    GROUP BY country HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Gender', AVG(exited * 1.0) FROM customer_base
    GROUP BY gender HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Age band', AVG(exited * 1.0) FROM customer_base
    GROUP BY age_band HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Products held', AVG(exited * 1.0) FROM customer_base
    GROUP BY num_products HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Activity status', AVG(exited * 1.0) FROM customer_base
    GROUP BY is_active_member HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Balance band', AVG(exited * 1.0) FROM customer_base
    GROUP BY balance_band HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Tenure band', AVG(exited * 1.0) FROM customer_base
    GROUP BY tenure_band HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Credit score band', AVG(exited * 1.0) FROM customer_base
    GROUP BY credit_band HAVING COUNT(*) >= 100
    UNION ALL
    SELECT 'Credit card', AVG(exited * 1.0) FROM customer_base
    GROUP BY has_credit_card HAVING COUNT(*) >= 100
)
SELECT
    attribute,
    ROUND(MIN(churn_rate), 4)                   AS lowest_churn_rate,
    ROUND(MAX(churn_rate), 4)                   AS highest_churn_rate,
    ROUND(MAX(churn_rate) - MIN(churn_rate), 4) AS spread,
    RANK() OVER (ORDER BY MAX(churn_rate) - MIN(churn_rate) DESC) AS spread_rank
FROM rates
GROUP BY attribute
ORDER BY spread_rank;
