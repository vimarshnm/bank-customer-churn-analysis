/* =============================================================================
   17_money_at_risk_roi.sql
   Business question: How much money sits with at-risk customers, and does a
                      retention call campaign pay for itself?
   Input   : v_customer_risk, roi_assumptions (ALL inputs are assumptions)
   Notes   :
     - Uses the final score for all 10,000 customers. Its top-10% churn
       (73.60%) is close to the test-set figure (73.33%), so the
       in-sample effect on these numbers is small.
     - "Would-be leavers" in a list = customers who actually left (exited = 1).
       That is the best available stand-in for who WILL leave next month.
     - One-year view: value of a retained customer = one year of profit.
     - NOT INCLUDED (assumption): the cost of any retention OFFER (fee waiver,
       rate bonus). Only the call itself is costed. Real campaigns usually
       include an offer, which would lower every ROI figure here.
   ============================================================================= */


/* Q17.1 Money at risk by risk tier: deposits held, and deposits actually
         lost (held by customers who left).                                 */
SELECT
    risk_tier,
    MIN(risk_decile)                                                 AS first_decile,
    COUNT(*)                                                         AS customers,
    SUM(exited)                                                      AS leavers,
    ROUND(AVG(exited * 1.0), 4)                                      AS churn_rate,
    ROUND(SUM(balance), 2)                                           AS deposits_held,
    ROUND(SUM(balance) / SUM(SUM(balance)) OVER (), 4)               AS share_of_all_deposits,
    ROUND(SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END), 2)      AS deposits_lost,
    ROUND(SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)
          / SUM(SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)) OVER (), 4)
                                                                     AS share_of_all_deposits_lost
FROM v_customer_risk
GROUP BY risk_tier
ORDER BY first_decile;


/* Q17.2 Money at risk by call priority inside the top 10%. */
SELECT
    call_priority,
    COUNT(*)                                                         AS customers,
    SUM(exited)                                                      AS leavers,
    ROUND(SUM(balance), 2)                                           AS deposits_held,
    ROUND(SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END), 2)      AS deposits_lost
FROM v_customer_risk
WHERE risk_decile = 1
GROUP BY call_priority
ORDER BY call_priority;


/* Q17.3 The inputs in use - printed so every ROI result shows its
         assumptions alongside it.                                          */
SELECT parameter, value, unit
FROM roi_assumptions
ORDER BY parameter;


/* Q17.4 Campaign cost-benefit: call the top 10% vs the top 20%.
         Step 1 (inputs): pivot the assumptions table into one row.
         Step 2 (lists):  totals for each call list.
         Step 3: cost, value saved, net benefit, ROI and break-even.
           cost           = customers called x cost_per_call
           customers_saved= would-be leavers x save_rate
           value_saved    = save_rate x SUM over would-be leavers of
                            (deposit_margin_rate x balance + value_per_customer_fixed)
           net_benefit    = value_saved - cost
           roi            = net_benefit / cost
           break_even_save_rate = the save rate at which net_benefit = 0     */
WITH inputs AS (
    SELECT
        MAX(CASE WHEN parameter = 'cost_per_call'            THEN value END) AS cost_per_call,
        MAX(CASE WHEN parameter = 'save_rate'                THEN value END) AS save_rate,
        MAX(CASE WHEN parameter = 'deposit_margin_rate'      THEN value END) AS margin_rate,
        MAX(CASE WHEN parameter = 'value_per_customer_fixed' THEN value END) AS fixed_value
    FROM roi_assumptions
),
call_lists AS (
    SELECT 'Top 10%' AS call_list, 1 AS max_decile UNION ALL
    SELECT 'Top 20%', 2
),
lists AS (
    SELECT
        cl.call_list,
        COUNT(*)                                                     AS customers_called,
        SUM(r.exited)                                                AS would_be_leavers,
        SUM(CASE WHEN r.exited = 1 THEN r.balance ELSE 0 END)        AS leaver_deposits
    FROM call_lists AS cl
    JOIN v_customer_risk AS r ON r.risk_decile <= cl.max_decile
    GROUP BY cl.call_list
),
economics AS (
    SELECT
        l.call_list,
        l.customers_called,
        l.would_be_leavers,
        l.leaver_deposits,
        l.customers_called * i.cost_per_call                                  AS campaign_cost,
        l.would_be_leavers * i.save_rate                                      AS customers_saved,
        l.leaver_deposits  * i.save_rate                                      AS deposits_retained,
        -- value of saving EVERY would-be leaver, before applying the save rate
        i.margin_rate * l.leaver_deposits + i.fixed_value * l.would_be_leavers AS value_if_all_saved,
        i.save_rate
    FROM lists AS l
    CROSS JOIN inputs AS i
)
SELECT
    call_list,
    customers_called,
    would_be_leavers,
    ROUND(customers_saved, 1)                                        AS customers_saved,
    ROUND(deposits_retained, 2)                                      AS deposits_retained,
    ROUND(campaign_cost, 2)                                          AS campaign_cost,
    ROUND(save_rate * value_if_all_saved, 2)                         AS value_saved,
    ROUND(save_rate * value_if_all_saved - campaign_cost, 2)         AS net_benefit,
    ROUND((save_rate * value_if_all_saved - campaign_cost) / campaign_cost, 2) AS roi,
    ROUND(campaign_cost / value_if_all_saved, 4)                     AS break_even_save_rate
FROM economics
ORDER BY call_list;


/* Q17.5 Is the SECOND 10% worth calling? Marginal economics of decile 2
         alone - what extending from the top 10% to the top 20% adds.        */
WITH inputs AS (
    SELECT
        MAX(CASE WHEN parameter = 'cost_per_call'            THEN value END) AS cost_per_call,
        MAX(CASE WHEN parameter = 'save_rate'                THEN value END) AS save_rate,
        MAX(CASE WHEN parameter = 'deposit_margin_rate'      THEN value END) AS margin_rate,
        MAX(CASE WHEN parameter = 'value_per_customer_fixed' THEN value END) AS fixed_value
    FROM roi_assumptions
),
decile_totals AS (
    SELECT
        risk_decile,
        COUNT(*)                                                 AS customers_called,
        SUM(exited)                                              AS would_be_leavers,
        SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)        AS leaver_deposits
    FROM v_customer_risk
    WHERE risk_decile IN (1, 2)
    GROUP BY risk_decile
)
SELECT
    CASE d.risk_decile WHEN 1 THEN 'Decile 1 (first 10%)' ELSE 'Decile 2 (next 10%)' END AS slice,
    d.customers_called,
    d.would_be_leavers,
    ROUND(d.customers_called * i.cost_per_call, 2)                             AS cost,
    ROUND(i.save_rate * (i.margin_rate * d.leaver_deposits
                         + i.fixed_value * d.would_be_leavers), 2)             AS value_saved,
    ROUND(i.save_rate * (i.margin_rate * d.leaver_deposits
                         + i.fixed_value * d.would_be_leavers)
          - d.customers_called * i.cost_per_call, 2)                           AS net_benefit,
    ROUND((i.save_rate * (i.margin_rate * d.leaver_deposits
                          + i.fixed_value * d.would_be_leavers)
           - d.customers_called * i.cost_per_call)
          / (d.customers_called * i.cost_per_call), 2)                         AS roi,
    -- the call cost at which this slice stops paying for itself
    ROUND(i.save_rate * (i.margin_rate * d.leaver_deposits
                         + i.fixed_value * d.would_be_leavers)
          / d.customers_called, 2)                                             AS break_even_cost_per_call
FROM decile_totals AS d
CROSS JOIN inputs AS i
ORDER BY d.risk_decile;


/* Q17.6 Sensitivity: net benefit of the top-10% campaign at different save
         rates (other inputs unchanged). The same table is rebuilt in Excel
         as a one-variable Data Table.                                      */
WITH inputs AS (
    SELECT
        MAX(CASE WHEN parameter = 'cost_per_call'            THEN value END) AS cost_per_call,
        MAX(CASE WHEN parameter = 'deposit_margin_rate'      THEN value END) AS margin_rate,
        MAX(CASE WHEN parameter = 'value_per_customer_fixed' THEN value END) AS fixed_value
    FROM roi_assumptions
),
top10 AS (
    SELECT
        COUNT(*)                                                 AS customers_called,
        SUM(exited)                                              AS would_be_leavers,
        SUM(CASE WHEN exited = 1 THEN balance ELSE 0 END)        AS leaver_deposits
    FROM v_customer_risk
    WHERE risk_decile = 1
),
save_rates AS (
    SELECT 0.05 AS save_rate UNION ALL SELECT 0.10 UNION ALL SELECT 0.15 UNION ALL
    SELECT 0.20 UNION ALL SELECT 0.25 UNION ALL SELECT 0.30
)
SELECT
    s.save_rate,
    ROUND(s.save_rate * (i.margin_rate * t.leaver_deposits
                         + i.fixed_value * t.would_be_leavers)
          - t.customers_called * i.cost_per_call, 2)                           AS net_benefit_top10,
    ROUND((s.save_rate * (i.margin_rate * t.leaver_deposits
                          + i.fixed_value * t.would_be_leavers)
           - t.customers_called * i.cost_per_call)
          / (t.customers_called * i.cost_per_call), 2)                         AS roi_top10
FROM save_rates AS s
CROSS JOIN top10 AS t
CROSS JOIN inputs AS i
ORDER BY s.save_rate;


/* Q17.7 The monthly call list (top 10%): how many leavers it reaches, as a
         share of ALL leavers in the bank.                                  */
SELECT
    COUNT(*)                                                          AS customers_on_list,
    SUM(exited)                                                       AS leavers_on_list,
    ROUND(SUM(exited) * 1.0 / (SELECT SUM(exited) FROM v_customer_risk), 4)
                                                                      AS share_of_all_leavers
FROM v_customer_risk
WHERE risk_decile = 1;


/* Q17.8 Who is on the call list, by country. The additive score gives
         Germany 8 points and every German customer has a balance (+6), so
         the list leans heavily German - see the limitations in the report. */
SELECT
    country,
    COUNT(*)                                       AS customers_on_list,
    ROUND(COUNT(*) * 1.0 / SUM(COUNT(*)) OVER (), 4) AS share_of_list,
    SUM(exited)                                    AS leavers_on_list
FROM v_customer_risk
WHERE risk_decile = 1
GROUP BY country
ORDER BY customers_on_list DESC;
