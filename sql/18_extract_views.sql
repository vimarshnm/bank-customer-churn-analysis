/* =============================================================================
   18_extract_views.sql
   Purpose : Define every CSV extract as a view, so the export script is pure
             a simple SELECT * FROM view -> CSV and all logic stays in SQL.
   Output  : v_extract_* views, exported by scripts/export_extracts.sh to
             data/extracts/<name>.csv. Columns are documented in
             docs/data_dictionary.md.
   Model   : a star schema -
               fact_customers  (one row per customer, the grain of everything)
               dim_*           (small lookup tables: labels + sort order)
             fact_customers.age_band      -> dim_age_band.age_band
             fact_customers.balance_band  -> dim_balance_band.balance_band
             fact_customers.tenure_band   -> dim_tenure_band.tenure_band
             fact_customers.credit_score_band -> dim_credit_score_band.credit_score_band
             fact_customers.country       -> dim_country.country
             fact_customers.risk_tier     -> dim_risk_tier.risk_tier
             fact_customers.call_priority -> dim_call_priority.call_priority
   ============================================================================= */

-- -----------------------------------------------------------------------------
-- fact_customers: everything known about each customer, plus the risk score.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_extract_fact_customers;

CREATE VIEW v_extract_fact_customers AS
SELECT
    c.customer_id,
    r.split_set,
    c.surname,
    c.gender,
    c.age,
    ab.band_label                                                    AS age_band,
    c.country,
    ac.tenure_years,
    tb.band_label                                                    AS tenure_band,
    ac.credit_score,
    cb.band_label                                                    AS credit_score_band,
    ROUND(ac.balance, 2)                                             AS balance,
    bb.band_label                                                    AS balance_band,
    ac.num_products,
    ac.has_credit_card,
    ac.card_type,
    ROUND(ac.estimated_salary, 2)                                    AS estimated_salary,
    act.is_active_member,
    r.activity_status,
    act.complained,
    act.satisfaction_score,
    act.points_earned,
    act.exited,
    CASE act.exited WHEN 1 THEN 'Left' ELSE 'Stayed' END             AS churn_status,
    r.pts_age_activity,
    r.pts_products,
    r.pts_country,
    r.pts_balance,
    r.risk_score,
    r.risk_rank,
    r.risk_decile,
    r.risk_tier,
    r.call_priority,
    CASE WHEN r.risk_decile <= 1 THEN 1 ELSE 0 END                   AS in_top10,
    CASE WHEN r.risk_decile <= 2 THEN 1 ELSE 0 END                   AS in_top20,
    CASE WHEN r.risk_decile <= 3 THEN 1 ELSE 0 END                   AS in_top30
FROM customers AS c
JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
JOIN activity  AS act ON act.customer_id = c.customer_id
JOIN v_customer_risk    AS r  ON r.customer_id = c.customer_id
JOIN age_bands          AS ab ON c.age           >= ab.lower_bound AND c.age           < ab.upper_bound
JOIN tenure_bands       AS tb ON ac.tenure_years >= tb.lower_bound AND ac.tenure_years < tb.upper_bound
JOIN credit_score_bands AS cb ON ac.credit_score >= cb.lower_bound AND ac.credit_score < cb.upper_bound
JOIN balance_bands      AS bb ON ac.balance      >= bb.lower_bound AND ac.balance      < bb.upper_bound;

-- -----------------------------------------------------------------------------
-- Band dimensions: label, sort order and the exact boundaries.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_extract_dim_age_band;
CREATE VIEW v_extract_dim_age_band AS
SELECT band_label AS age_band, band_order AS age_band_order,
       lower_bound AS age_from,
       CASE WHEN upper_bound >= 999 THEN NULL ELSE upper_bound - 1 END AS age_to  -- NULL = open-ended top band
FROM age_bands;

DROP VIEW IF EXISTS v_extract_dim_balance_band;
CREATE VIEW v_extract_dim_balance_band AS
SELECT band_label AS balance_band, band_order AS balance_band_order,
       lower_bound AS balance_from,
       CASE WHEN upper_bound >= 999999999 THEN NULL ELSE upper_bound END AS balance_below
FROM balance_bands;

DROP VIEW IF EXISTS v_extract_dim_tenure_band;
CREATE VIEW v_extract_dim_tenure_band AS
SELECT band_label AS tenure_band, band_order AS tenure_band_order,
       lower_bound AS tenure_from,
       CASE WHEN upper_bound >= 99 THEN 10 ELSE upper_bound - 1 END AS tenure_to  -- data caps tenure at 10
FROM tenure_bands;

DROP VIEW IF EXISTS v_extract_dim_credit_score_band;
CREATE VIEW v_extract_dim_credit_score_band AS
SELECT band_label AS credit_score_band, band_order AS credit_score_band_order,
       lower_bound AS score_from,
       CASE WHEN upper_bound >= 9999 THEN 850 ELSE upper_bound - 1 END AS score_to  -- 850 = scale maximum
FROM credit_score_bands;

-- -----------------------------------------------------------------------------
-- Other dimensions.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_extract_dim_country;
CREATE VIEW v_extract_dim_country AS
SELECT
    country,
    CASE country WHEN 'France' THEN 1 WHEN 'Germany' THEN 2 WHEN 'Spain' THEN 3 END AS country_order,
    CASE country WHEN 'France' THEN 'FR' WHEN 'Germany' THEN 'DE' WHEN 'Spain' THEN 'ES' END AS iso_code
FROM customers
GROUP BY country;

DROP VIEW IF EXISTS v_extract_dim_risk_tier;
CREATE VIEW v_extract_dim_risk_tier AS
SELECT
    risk_tier,
    CASE risk_tier WHEN 'Very high' THEN 1 WHEN 'High' THEN 2
                   WHEN 'Medium' THEN 3 ELSE 4 END              AS risk_tier_order,
    CASE WHEN MIN(risk_decile) = MAX(risk_decile) THEN CAST(MIN(risk_decile) AS TEXT)
         ELSE MIN(risk_decile) || '-' || MAX(risk_decile) END   AS deciles,
    MIN(risk_score)                                            AS min_score,
    MAX(risk_score)                                            AS max_score,
    CASE risk_tier
        WHEN 'Very high' THEN 'Top 10% by risk score - the monthly call list'
        WHEN 'High'      THEN 'Next 20% - candidates if calling capacity allows'
        WHEN 'Medium'    THEN 'Middle 30% - monitor'
        ELSE                  'Lowest 40% - no action'
    END                                                        AS description
FROM v_customer_risk
GROUP BY risk_tier;

DROP VIEW IF EXISTS v_extract_dim_call_priority;
CREATE VIEW v_extract_dim_call_priority AS
SELECT 'P1 High value' AS call_priority, 1 AS call_priority_order,
       'Top 10% and balance >= 100,000 - call first' AS description
UNION ALL SELECT 'P2 Mid value', 2, 'Top 10% and balance 0.01-99,999'
UNION ALL SELECT 'P3 No balance', 3, 'Top 10% and zero balance - call if capacity'
UNION ALL SELECT 'Not targeted', 4, 'Outside the top 10%';

-- -----------------------------------------------------------------------------
-- ROI inputs (assumptions) - so every tool starts from the same defaults.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_extract_roi_assumptions;
CREATE VIEW v_extract_roi_assumptions AS
SELECT parameter, value, unit, description FROM roi_assumptions;

-- -----------------------------------------------------------------------------
-- kpi_reference: the SQL answer for each headline number. Excel's check column
-- and docs/reconciliation.md compare against this. All on the full 10,000.
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_extract_kpi_reference;
CREATE VIEW v_extract_kpi_reference AS
WITH f AS (SELECT * FROM v_extract_fact_customers),
inputs AS (
    SELECT
        MAX(CASE WHEN parameter = 'cost_per_call'            THEN value END) AS cost_per_call,
        MAX(CASE WHEN parameter = 'save_rate'                THEN value END) AS save_rate,
        MAX(CASE WHEN parameter = 'deposit_margin_rate'      THEN value END) AS margin_rate,
        MAX(CASE WHEN parameter = 'value_per_customer_fixed' THEN value END) AS fixed_value
    FROM roi_assumptions
),
top10 AS (
    SELECT
        COUNT(*)                                            AS called,
        SUM(exited)                                         AS leavers,
        SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)   AS leaver_deposits
    FROM f WHERE in_top10 = 1
),
top20 AS (
    SELECT
        COUNT(*)                                            AS called,
        SUM(exited)                                         AS leavers,
        SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)   AS leaver_deposits
    FROM f WHERE in_top20 = 1
)
SELECT 1 AS kpi_order, 'total_customers' AS kpi, COUNT(*) AS sql_value, 'count' AS format, '08 Q8.1' AS source FROM f
UNION ALL SELECT 2, 'leavers', SUM(exited), 'count', '08 Q8.1' FROM f
UNION ALL SELECT 3, 'churn_rate', ROUND(AVG(exited * 1.0), 4), 'percent', '08 Q8.1' FROM f
UNION ALL SELECT 4, 'churn_rate_germany', ROUND(AVG(CASE WHEN country = 'Germany' THEN exited * 1.0 END), 4), 'percent', '08 Q8.2' FROM f
UNION ALL SELECT 5, 'churn_rate_inactive', ROUND(AVG(CASE WHEN is_active_member = 0 THEN exited * 1.0 END), 4), 'percent', '08 Q8.2' FROM f
UNION ALL SELECT 6, 'churn_rate_age_50_59', ROUND(AVG(CASE WHEN age_band = '50-59' THEN exited * 1.0 END), 4), 'percent', '08 Q8.2' FROM f
UNION ALL SELECT 7, 'total_deposits', ROUND(SUM(balance), 2), 'currency', '10 Q10.3' FROM f
UNION ALL SELECT 8, 'deposits_lost', ROUND(SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END), 2), 'currency', '10 Q10.3' FROM f
UNION ALL SELECT 9, 'top10_churn_rate', ROUND(AVG(CASE WHEN in_top10 = 1 THEN exited * 1.0 END), 4), 'percent', '14 Q14.1' FROM f
UNION ALL SELECT 10, 'top10_lift', ROUND(AVG(CASE WHEN in_top10 = 1 THEN exited * 1.0 END) / AVG(exited * 1.0), 2), 'ratio', '14 Q14.1' FROM f
UNION ALL SELECT 11, 'top10_capture', ROUND(SUM(CASE WHEN in_top10 = 1 THEN exited ELSE 0 END) * 1.0 / SUM(exited), 4), 'percent', '14 Q14.1' FROM f
UNION ALL SELECT 12, 'top10_deposits_held', ROUND(SUM(CASE WHEN in_top10 = 1 THEN balance ELSE 0 END), 2), 'currency', '17 Q17.1' FROM f
UNION ALL SELECT 13, 'top10_campaign_net_benefit',
    ROUND(i.save_rate * (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers)
          - t.called * i.cost_per_call, 2), 'currency', '17 Q17.4'
    FROM top10 AS t CROSS JOIN inputs AS i
UNION ALL SELECT 14, 'top10_break_even_save_rate',
    ROUND(t.called * i.cost_per_call
          / (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers), 4), 'percent', '17 Q17.4'
    FROM top10 AS t CROSS JOIN inputs AS i
UNION ALL SELECT 15, 'top10_roi',
    ROUND((i.save_rate * (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers)
           - t.called * i.cost_per_call) / (t.called * i.cost_per_call), 2), 'ratio', '17 Q17.4'
    FROM top10 AS t CROSS JOIN inputs AS i
UNION ALL SELECT 16, 'top20_campaign_net_benefit',
    ROUND(i.save_rate * (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers)
          - t.called * i.cost_per_call, 2), 'currency', '17 Q17.4'
    FROM top20 AS t CROSS JOIN inputs AS i
UNION ALL SELECT 17, 'top20_roi',
    ROUND((i.save_rate * (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers)
           - t.called * i.cost_per_call) / (t.called * i.cost_per_call), 2), 'ratio', '17 Q17.4'
    FROM top20 AS t CROSS JOIN inputs AS i
UNION ALL SELECT 18, 'top20_break_even_save_rate',
    ROUND(t.called * i.cost_per_call
          / (i.margin_rate * t.leaver_deposits + i.fixed_value * t.leavers), 4), 'percent', '17 Q17.4'
    FROM top20 AS t CROSS JOIN inputs AS i;
