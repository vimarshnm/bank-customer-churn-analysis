# Data Dictionary: `data/extracts/`

All extracts are produced by `sql/18_extract_views.sql` (one `v_extract_*` view each)
and written by `./scripts/export_extracts.sh`. CSV, comma-separated, header row, UTF-8.
Rates are fractions (0.2038 = 20.38%). Money is in the source currency (shown as USD).

## Data model (star schema)

```
                 dim_age_band   dim_balance_band   dim_tenure_band
                        \              |              /
 dim_country ──── fact_customers (1 row per customer) ──── dim_credit_score_band
                        /                             \
                 dim_risk_tier                    dim_call_priority

 Stand-alone: roi_assumptions (model inputs), kpi_reference (SQL answers for reconciliation)
```

Every relationship is **many-to-one** from `fact_customers` to the dimension, joined on
the label column named in each dimension below.

---

## fact_customers.csv: 10,000 rows, one per customer

| Column | Type | Description | Values / notes |
|---|---|---|---|
| `customer_id` | integer | Bank customer number. **Primary key.** | 15565701-15815690 |
| `split_set` | text | Build/test split for the risk score | `build` (last digit 0-6), `test` (7-9) |
| `surname` | text | Customer surname. **PII** - used only for the call list | Not unique |
| `gender` | text | Customer gender | `Female`, `Male`. Not used in the risk score (fairness) |
| `age` | integer | Age in years | 18-92 |
| `age_band` | text | Age band -> `dim_age_band` | `18-29` ... `70+` |
| `country` | text | Country of the customer -> `dim_country` | `France`, `Germany`, `Spain` |
| `tenure_years` | integer | Years with the bank | 0-10 |
| `tenure_band` | text | Tenure band -> `dim_tenure_band` | `0-2 yrs` ... `9-10 yrs` |
| `credit_score` | integer | Credit score | 350-850 |
| `credit_score_band` | text | Credit score band -> `dim_credit_score_band` | `Under 500` ... `800+` |
| `balance` | decimal | Deposit balance | 0.00-250,898.09; 3,617 customers have 0 |
| `balance_band` | text | Balance band -> `dim_balance_band` | `Zero` ... `150k+` |
| `num_products` | integer | Number of bank products held | 1-4 |
| `has_credit_card` | integer | Holds a credit card | 1 = yes, 0 = no |
| `card_type` | text | Card / membership tier | `SILVER`, `GOLD`, `PLATINUM`, `DIAMOND`. Recorded even when `has_credit_card` = 0 - meaning unclear |
| `estimated_salary` | decimal | Bank's estimate of annual salary | 11.58-199,992.48; 59 values under 1,000 look implausible |
| `is_active_member` | integer | Active member flag | 1 = active, 0 = inactive |
| `activity_status` | text | Label for `is_active_member` | `Active`, `Inactive` |
| `complained` | integer | Customer has complained | 1 / 0. **Leakage - never use to predict churn** (matches churn in 99.86% of rows) |
| `satisfaction_score` | integer | Satisfaction survey score | 1-5. No churn signal; timing unknown |
| `points_earned` | integer | Loyalty points | 119-1,000. No churn signal |
| `exited` | integer | **Target: customer left the bank** | 1 = left, 0 = stayed |
| `churn_status` | text | Label for `exited` | `Left`, `Stayed` |
| `pts_age_activity` | integer | Risk points: age band x activity | 0-27 |
| `pts_products` | integer | Risk points: products held | 0, 13, 24 |
| `pts_country` | integer | Risk points: country | 0, 1, 8 |
| `pts_balance` | integer | Risk points: has a balance | 0, 6 |
| `risk_score` | integer | Total risk score = sum of the four `pts_` columns | 0-65; higher = riskier; +7 ~double the risk |
| `risk_rank` | integer | Position in the risk ranking (1 = riskiest) | 1-10,000. Ties broken by balance (higher first), then customer_id |
| `risk_decile` | integer | `NTILE(10)` of the ranking | 1 = riskiest 10% ... 10 = safest 10% |
| `risk_tier` | text | Tier from decile -> `dim_risk_tier` | `Very high`, `High`, `Medium`, `Low` |
| `call_priority` | text | Call order within the top 10% -> `dim_call_priority` | `P1 High value`, `P2 Mid value`, `P3 No balance`, `Not targeted` |
| `in_top10` | integer | In the riskiest 10% (decile 1) | 1 / 0 |
| `in_top20` | integer | In the riskiest 20% (deciles 1-2) | 1 / 0 |
| `in_top30` | integer | In the riskiest 30% (deciles 1-3) | 1 / 0 |

Source: `customers`, `accounts`, `activity` tables (raw CSV columns renamed in
`sql/02_transform.sql`), band tables (`sql/07`), risk view `v_customer_risk` (`sql/14`).
The raw `RowNumber` column is not carried forward (file row index only).

---

## Dimension tables

Band rule everywhere: a value belongs to a band if `value >= from` and `value <= to`
(or `< balance_below` for balance). An empty upper bound = open-ended top band.

### dim_age_band.csv: 6 rows

| Column | Type | Description |
|---|---|---|
| `age_band` | text | Band label. **Key** -> `fact_customers.age_band` |
| `age_band_order` | integer | Sort order (1 = youngest) |
| `age_from` | integer | Lowest age in the band |
| `age_to` | integer | Highest age in the band; empty for `70+` |

### dim_balance_band.csv: 5 rows

| Column | Type | Description |
|---|---|---|
| `balance_band` | text | Band label. **Key** -> `fact_customers.balance_band` |
| `balance_band_order` | integer | Sort order (1 = `Zero`) |
| `balance_from` | decimal | Lowest balance in the band (inclusive) |
| `balance_below` | decimal | Balances must be **below** this (exclusive); empty for `150k+` |

### dim_tenure_band.csv: 4 rows

| Column | Type | Description |
|---|---|---|
| `tenure_band` | text | Band label. **Key** -> `fact_customers.tenure_band` |
| `tenure_band_order` | integer | Sort order |
| `tenure_from` | integer | Lowest tenure (years) |
| `tenure_to` | integer | Highest tenure (years) |

### dim_credit_score_band.csv: 5 rows

| Column | Type | Description |
|---|---|---|
| `credit_score_band` | text | Band label. **Key** -> `fact_customers.credit_score_band` |
| `credit_score_band_order` | integer | Sort order (1 = lowest scores) |
| `score_from` | integer | Lowest score in the band |
| `score_to` | integer | Highest score in the band (850 = scale maximum) |

### dim_country.csv: 3 rows

| Column | Type | Description |
|---|---|---|
| `country` | text | Country name. **Key** -> `fact_customers.country` |
| `country_order` | integer | Sort order (alphabetical) |
| `iso_code` | text | ISO 3166 two-letter code (`FR`, `DE`, `ES`) - for maps |

### dim_risk_tier.csv: 4 rows

| Column | Type | Description |
|---|---|---|
| `risk_tier` | text | Tier label. **Key** -> `fact_customers.risk_tier` |
| `risk_tier_order` | integer | Sort order (1 = `Very high`) |
| `deciles` | text | Risk deciles in the tier (`1`, `2-3`, `4-6`, `7-10`) |
| `min_score` / `max_score` | integer | Risk-score range observed in the tier (edges can overlap where tied scores span a decile boundary) |
| `description` | text | What the retention team does with this tier |

Assumption: tier boundaries are a business choice (see `reports/risk_score.md`).

### dim_call_priority.csv: 4 rows

| Column | Type | Description |
|---|---|---|
| `call_priority` | text | Priority label. **Key** -> `fact_customers.call_priority` |
| `call_priority_order` | integer | Sort order (1 = call first) |
| `description` | text | Rule defining the priority |

---

## Stand-alone tables

### roi_assumptions.csv: 4 rows - ALL VALUES ARE assumptions

| Column | Type | Description |
|---|---|---|
| `parameter` | text | Input name. **Key** |
| `value` | decimal | Assumed value |
| `unit` | text | Unit of the value |
| `description` | text | Meaning, marked assumption |

| parameter | value | unit |
|---|---|---|
| `cost_per_call` | 10.00 | USD per customer called |
| `deposit_margin_rate` | 0.01 | fraction of balance per year |
| `save_rate` | 0.20 | fraction of called would-be leavers saved |
| `value_per_customer_fixed` | 100.00 | USD per retained customer per year |

Value of a retained customer (1 year) = `deposit_margin_rate` x balance + `value_per_customer_fixed`.

### kpi_reference.csv: 18 rows

The SQL answer for each headline KPI, computed on all 10,000 customers.
ROI rows use the assumed inputs in `roi_assumptions`. Used by
the Excel check column and `docs/reconciliation.md`.

| Column | Type | Description |
|---|---|---|
| `kpi_order` | integer | Display order |
| `kpi` | text | KPI name. **Key** |
| `sql_value` | number | Value computed in SQL (unrounded beyond 4 dp for rates, 2 dp for money) |
| `format` | text | How to display it: `count`, `percent`, `currency`, `ratio` |
| `source` | text | SQL file and query that produces the same number (e.g. `08 Q8.1`) |

| kpi | sql_value | Definition |
|---|---|---|
| `total_customers` | 10000 | Count of customers |
| `leavers` | 2038 | Count with `exited` = 1 |
| `churn_rate` | 0.2038 | leavers ÷ customers |
| `churn_rate_germany` | 0.3244 | Churn rate where `country` = Germany |
| `churn_rate_inactive` | 0.2687 | Churn rate where `is_active_member` = 0 |
| `churn_rate_age_50_59` | 0.5604 | Churn rate where `age_band` = 50-59 |
| `total_deposits` | 764858892.88 | Sum of `balance` |
| `deposits_lost` | 185681112.10 | Sum of `balance` where `exited` = 1 |
| `top10_churn_rate` | 0.7360 | Churn rate where `in_top10` = 1 |
| `top10_lift` | 3.61 | `top10_churn_rate` ÷ `churn_rate` |
| `top10_capture` | 0.3611 | Leavers in top 10% ÷ all leavers |
| `top10_deposits_held` | 114261734.03 | Sum of `balance` where `in_top10` = 1 |
| `top10_campaign_net_benefit` | 171148.65 | `save_rate` x Σ over top-10% leavers of (`deposit_margin_rate` x balance + `value_per_customer_fixed`) − 1,000 x `cost_per_call` |
| `top10_break_even_save_rate` | 0.0110 | Save rate at which the top-10% net benefit = 0 |
| `top10_roi` | 17.11 | `top10_campaign_net_benefit` ÷ campaign cost (1,000 x `cost_per_call`) |
| `top20_campaign_net_benefit` | 245257.26 | As `top10_campaign_net_benefit`, for `in_top20` = 1 (2,000 calls) |
| `top20_roi` | 12.26 | `top20_campaign_net_benefit` ÷ campaign cost (2,000 x `cost_per_call`) |
| `top20_break_even_save_rate` | 0.0151 | Save rate at which the top-20% net benefit = 0 |

Note: top-10% figures here use all customers. The out-of-sample
performance of the score is the **test-set** result in `reports/risk_score.md`
(top-10% churn 73.33%, lift 3.63x).
