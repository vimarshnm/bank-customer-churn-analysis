/* =============================================================================
   11_balance_rank_by_country.sql
   Business question: Who are each country's biggest depositors, how
                      concentrated are deposits, and are the richest
                      customers more likely to leave?
   Input   : customers, accounts, activity
   Output  : Window-function rankings within each country.
   Window functions used:
     RANK()       - position by balance, ties share a rank (gaps after ties)
     DENSE_RANK() - same, but no gaps after ties (shown for comparison)
     NTILE(4)     - split each country into 4 equal-sized balance quartiles
     SUM() OVER (ORDER BY ...) - running total of deposits
   ============================================================================= */


/* Q11.1 Top 5 depositors in each country, with running deposit totals.
         PARTITION BY country restarts the ranking for every country.      */
WITH ranked AS (
    SELECT
        c.country,
        c.customer_id,
        c.surname,
        ac.balance,
        act.exited,
        RANK()       OVER (PARTITION BY c.country ORDER BY ac.balance DESC) AS balance_rank,
        DENSE_RANK() OVER (PARTITION BY c.country ORDER BY ac.balance DESC) AS balance_dense_rank,
        SUM(ac.balance) OVER (
            PARTITION BY c.country
            ORDER BY ac.balance DESC, c.customer_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                                   AS running_deposits,
        SUM(ac.balance) OVER (PARTITION BY c.country)                       AS country_deposits
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
)
SELECT
    country,
    balance_rank,
    customer_id,
    surname,
    ROUND(balance, 2)                              AS balance,
    CASE exited WHEN 1 THEN 'Left' ELSE 'Stayed' END AS status,
    ROUND(running_deposits, 2)                     AS running_deposits,
    ROUND(running_deposits / country_deposits, 4)  AS running_share_of_country
FROM ranked
WHERE balance_rank <= 5
ORDER BY country, balance_rank;


/* Q11.2 Deposit concentration: what share of each country's deposits sits
         with its top 10% of customers by balance?                          */
WITH ranked AS (
    SELECT
        c.country,
        ac.balance,
        NTILE(10) OVER (PARTITION BY c.country ORDER BY ac.balance DESC) AS balance_decile
    FROM customers AS c
    JOIN accounts  AS ac ON ac.customer_id = c.customer_id
)
SELECT
    country,
    COUNT(*)                                                         AS customers,
    ROUND(SUM(balance), 2)                                           AS country_deposits,
    ROUND(SUM(CASE WHEN balance_decile = 1 THEN balance ELSE 0 END), 2) AS top_10pct_deposits,
    ROUND(SUM(CASE WHEN balance_decile = 1 THEN balance ELSE 0 END)
          / SUM(balance), 4)                                         AS top_10pct_share
FROM ranked
GROUP BY country
ORDER BY country;


/* Q11.3 Churn by balance quartile WITHIN each country.
         NTILE(4) ranks customers against their own country, so a "top
         quartile" German is compared with other Germans - this removes the
         Germany zero-balance quirk found in data quality (Q7.2).
         Quartile 1 = highest balances.                                     */
WITH quartiles AS (
    SELECT
        c.country,
        ac.balance,
        act.exited,
        NTILE(4) OVER (PARTITION BY c.country ORDER BY ac.balance DESC, c.customer_id) AS balance_quartile
    FROM customers AS c
    JOIN accounts  AS ac  ON ac.customer_id  = c.customer_id
    JOIN activity  AS act ON act.customer_id = c.customer_id
)
SELECT
    country,
    balance_quartile,
    COUNT(*)                       AS customers,
    ROUND(MIN(balance), 2)         AS min_balance,
    ROUND(MAX(balance), 2)         AS max_balance,
    SUM(exited)                    AS leavers,
    ROUND(AVG(exited * 1.0), 4)    AS churn_rate
FROM quartiles
GROUP BY country, balance_quartile
ORDER BY country, balance_quartile;
