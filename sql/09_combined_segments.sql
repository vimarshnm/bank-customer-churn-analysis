/* =============================================================================
   09_combined_segments.sql
   Business question: Which COMBINATIONS of attributes have the highest churn,
                      and how many leavers do they account for?
   Input   : customers, accounts, activity, age_bands
   Output  : Segment tables ranked by churn rate.
   Assumption: segments with fewer than 100 customers are excluded (HAVING),
             because a churn rate on a tiny group is too noisy to act on.
             Q9.3 uses 50 because three-way segments are naturally smaller.
   ============================================================================= */


/* Q9.1 Age band x activity status - the full grid (12 cells), ranked.
        This grid feeds the Tableau heatmap, so every cell is shown;
        cells under 100 customers are labelled instead of hidden.          */
WITH segment AS (
    SELECT
        ab.band_order,
        ab.band_label AS age_band,
        CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS activity_status,
        act.exited
    FROM customers AS c
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands AS ab  ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
),
overall AS (
    SELECT AVG(exited * 1.0) AS churn_rate FROM activity
)
SELECT
    s.age_band,
    s.activity_status,
    COUNT(*)                                       AS customers,
    SUM(s.exited)                                  AS leavers,
    ROUND(AVG(s.exited * 1.0), 4)                  AS churn_rate,
    ROUND(AVG(s.exited * 1.0) / o.churn_rate, 2)   AS lift,
    RANK() OVER (ORDER BY AVG(s.exited * 1.0) DESC) AS churn_rank,
    CASE WHEN COUNT(*) < 100 THEN 'small group - read with care' END AS reliability
FROM segment AS s
CROSS JOIN overall AS o
GROUP BY s.band_order, s.age_band, s.activity_status, o.churn_rate
ORDER BY churn_rank;


/* Q9.2 Country x products held, ranked (segments of 100+ customers).
        Shows whether the products effect holds in every country.          */
WITH segment AS (
    SELECT c.country, ac.num_products, act.exited
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
)
SELECT
    country,
    num_products,
    COUNT(*)                                        AS customers,
    SUM(exited)                                     AS leavers,
    ROUND(AVG(exited * 1.0), 4)                     AS churn_rate,
    RANK() OVER (ORDER BY AVG(exited * 1.0) DESC)   AS churn_rank
FROM segment
GROUP BY country, num_products
HAVING COUNT(*) >= 100
ORDER BY churn_rank;


/* Q9.3 Top 10 three-way segments: country x age band x activity status.
        Also shows each segment's share of ALL leavers, and a running
        total of that share - i.e. "how many leavers would we reach by
        targeting the top N segments?"                                     */
WITH segment AS (
    SELECT
        c.country,
        ab.band_label AS age_band,
        CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS activity_status,
        act.exited
    FROM customers AS c
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands AS ab  ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
),
segment_rates AS (
    SELECT
        country,
        age_band,
        activity_status,
        COUNT(*)            AS customers,
        SUM(exited)         AS leavers,
        AVG(exited * 1.0)   AS churn_rate
    FROM segment
    GROUP BY country, age_band, activity_status
    HAVING COUNT(*) >= 50
),
ranked AS (
    SELECT
        segment_rates.*,
        RANK() OVER (ORDER BY churn_rate DESC) AS churn_rank,
        leavers * 1.0 / (SELECT SUM(exited) FROM activity) AS share_of_all_leavers
    FROM segment_rates
)
SELECT
    churn_rank,
    country,
    age_band,
    activity_status,
    customers,
    leavers,
    ROUND(churn_rate, 4)            AS churn_rate,
    ROUND(share_of_all_leavers, 4)  AS share_of_all_leavers,
    ROUND(SUM(share_of_all_leavers) OVER (
        ORDER BY churn_rate DESC, country, age_band, activity_status
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 4)                           AS cumulative_share_of_leavers
FROM ranked
WHERE churn_rank <= 10
ORDER BY churn_rank, country, age_band, activity_status;


/* Q9.4 The lowest-risk segments (bottom 5 of Q9.3's grid) - who is safe?
        Useful for knowing whom NOT to spend retention budget on.          */
WITH segment AS (
    SELECT
        c.country,
        ab.band_label AS age_band,
        CASE act.is_active_member WHEN 1 THEN 'Active' ELSE 'Inactive' END AS activity_status,
        act.exited
    FROM customers AS c
    JOIN activity  AS act ON act.customer_id = c.customer_id
    JOIN age_bands AS ab  ON c.age >= ab.lower_bound AND c.age < ab.upper_bound
)
SELECT
    country,
    age_band,
    activity_status,
    COUNT(*)                     AS customers,
    SUM(exited)                  AS leavers,
    ROUND(AVG(exited * 1.0), 4)  AS churn_rate
FROM segment
GROUP BY country, age_band, activity_status
HAVING COUNT(*) >= 50
ORDER BY churn_rate ASC, customers DESC
LIMIT 5;
