# Data Quality & Leakage Review

Source: `data/raw/Customer-Churn-Records.csv` -> `data/churn.db`.
Every number below comes from `sql/03_data_quality.sql` (query IDs in brackets).
Automated monthly checks: `sql/04_validation_checks.sql` (run with `./scripts/run_checks.sh`).

## 1. Summary

| Area | Result | Query |
|---|---|---|
| Row counts | 10,000 in staging, `customers`, `accounts`, `activity` | Q1.1 |
| Missing values | 0 NULL or blank values in all 18 raw columns | Q2.1 |
| Duplicate IDs | 0 duplicate `CustomerId` | Q3.1 |
| Duplicate people | 0 customers repeated under a different ID | Q3.2 |
| Categories | No misspellings: 3 countries, 2 genders, 4 card types, all flags 0/1 | Q4.2 |
| Churn rate (class balance) | **2,038 leavers / 10,000 = 20.38%** (7,962 stayers) | Q5.1 |
| Automated checks | 15 checks, 0 failures; each check proven to fire on broken test data | 04 |

The data is complete and structurally clean. The real issues are **leakage** and a
few **oddities** that affect interpretation, not loading.

## 2. Value ranges (Q4.1)

| Column | Min | Avg | Max |
|---|---|---|---|
| age | 18 | 38.92 | 92 |
| credit_score | 350 | 650.53 | 850 |
| tenure_years | 0 | 5.01 | 10 |
| balance | 0.00 | 76,485.89 | 250,898.09 |
| num_products | 1 | 1.53 | 4 |
| estimated_salary | 11.58 | 100,090.24 | 199,992.48 |
| satisfaction_score | 1 | 3.01 | 5 |
| points_earned | 119 | 606.52 | 1,000 |

All within the business rules in `01_schema.sql`.

## 3. Oddities (pass the rules, but affect interpretation)

| Finding | Count | Query | Impact |
|---|---|---|---|
| Annual salary under 1,000 (min 11.58) | 59 | Q4.3 | `estimated_salary` is unreliable at the low end; use with care |
| Credit score exactly 850 (scale cap) | 233 | Q4.3 | Scores are capped; top band is compressed |
| Zero balance | 3,617 (36%) | Q4.3 | Normal for customers holding non-deposit products |
| **Germany has no zero balances** (France 48.22%, Spain 48.41%) | 0 of 2,509 | Q7.2 | Suggests Germany's data was collected differently; balance comparisons across countries are confounded |
| `card_type` recorded for customers with **no credit card** | 2,945 | Q7.1 | `card_type` is not the credit card's tier - likely a membership tier. Meaning is unclear |
| Age 80+ | 15 | Q4.3 | Plausible, kept |
| **Credit score under 405: all 21 left** (100% churn) | 21 | Q7.3 | Perfect separation on a tiny group - possible artefact; do not build a rule on it |

Assumption: a salary under 1,000 is treated as implausible. These are kept, not
deleted - there is no evidence they are errors rather than, e.g., part-time income.

## 4. Leakage review

A column leaks if it would only be known **after** (or because) a customer left.
Using it would make the risk score look excellent in testing and useless in practice.

### 4.1 Binary flags (Q6.1, Q6.2)

| Flag | Churn when 1 | Churn when 0 | Gap | Share of leavers flagged |
|---|---|---|---|---|
| **complained** | **99.51%** | **0.05%** | **+99.46 pts** | **99.80%** |
| is_active_member | 14.27% | 26.87% | −12.60 pts | 36.06% |
| has_credit_card | 20.20% | 20.81% | −0.62 pts | 69.92% |

Complaint x churn cross-tab: of 2,044 complainers, 2,034 left; of 7,956 non-complainers, only 4 left.

### 4.2 Categorical / banded columns (Q6.3, Q6.4)

| Column | Lowest churn | Highest churn | Spread |
|---|---|---|---|
| num_products | 7.60% (2 products) | **100.00% (4 products, 60 of 60)** | 92.40 pts |
| country | 16.17% (France) | 32.44% (Germany) | 16.27 pts |
| gender | 16.47% (Male) | 25.07% (Female) | 8.60 pts |
| tenure_years | 17.22% | 23.00% | 5.78 pts |
| card_type | 19.26% | 21.78% | 2.51 pts |
| satisfaction_score | 19.64% | 21.80% | 2.16 pts |

### 4.3 Numeric columns: leavers vs stayers (Q6.5)

Standardised difference = (leaver mean − stayer mean) ÷ overall std dev
(|0.2| small, |0.5| medium, |0.8| large).

| Column | Avg leavers | Avg stayers | Std. diff |
|---|---|---|---|
| age | 44.84 | 37.41 | **+0.708** |
| balance | 91,109.48 | 72,742.75 | +0.294 |
| credit_score | 645.41 | 651.84 | −0.066 |
| tenure_years | 4.93 | 5.03 | −0.034 |
| estimated_salary | 101,509.91 | 99,726.85 | +0.031 |
| satisfaction_score | 3.00 | 3.02 | −0.015 |
| points_earned | 604.45 | 607.04 | −0.011 |

### 4.4 Verdicts

- **complained - LEAKAGE, exclude.** It matches churn in 99.86% of rows. A complaint
  is almost certainly logged as part of the exit (or the dataset recorded it after
  the outcome). A retention team cannot wait for a complaint that, in this data,
  nearly always arrives with the departure.
- **satisfaction_score - exclude.** No signal (2.16-pt spread, std. diff −0.015)
  and its timing is unknown (often an exit survey). Nothing to gain, some risk.
- **is_active_member - keep (not leakage).** If it were recorded after exit, every
  leaver would be inactive; in fact 36.06% of leavers were still active members.
  That pattern fits a status measured *before* leaving.
- **num_products - keep, but flag for review.** 4 products = 100% churn (60 of 60)
  is "suspiciously close". However, 3 products is 82.71% (220 of 266) - not perfect -
  so the pattern looks like a genuine "over-sold customer" effect rather than a
  post-exit artefact. Risk: if products are closed/consolidated during exit, it
  leaks. **Question for the business: is the product count taken before the exit date?**
- **Weak / no-signal columns** (not leakage, just unhelpful): `has_credit_card`,
  `card_type`, `points_earned`, `tenure_years`, `estimated_salary`, `credit_score`.
  Final selection happens on the build set only (risk-score step), so these are not ruled
  out here - but they are unlikely to earn points.

## 5. Recommendation: columns for the risk score

| Use? | Columns | Reason |
|---|---|---|
| **Exclude - leakage** | `complained` | Near-perfect match with churn; known too late to act |
| **Exclude - timing / no signal** | `satisfaction_score`, `points_earned`, `card_type` | No measurable signal; timing or meaning unclear |
| **Exclude - identifiers** | `customer_id`, `surname` | Not behaviour; surname is PII |
| **Exclude - fairness (assumption)** | `gender` | Has a real gap (8.60 pts), but scoring people by gender for different treatment is a fairness/regulatory risk. Still reported in the analysis |
| **Candidates** | `age`, `num_products`, `is_active_member`, `country`, `balance` | Clear, plausible pre-exit signals |
| **Candidates (likely weak)** | `credit_score`, `tenure_years`, `estimated_salary`, `has_credit_card` | Tested on the build set when setting points |

Note on `age` and `country`: also sensitive attributes in some jurisdictions. They
are kept as candidates because retention offers (unlike credit decisions) commonly
use them, but this is flagged as an assumption for review.

## 6. Automated checks (`sql/04_validation_checks.sql`)

Each query returns **zero rows when healthy**; any row names the check, the customer and the bad value.

| ID | Check | Level |
|---|---|---|
| A1 | No NULL / blank raw fields | Staging |
| A2 | No duplicate `CustomerId` | Staging |
| B1 | Whole-number columns contain only digits | Staging |
| B2 | Money columns are valid decimals | Staging |
| C1 | Flags are 0 or 1 | Typed |
| C2 | Categories use agreed codes | Typed |
| D1 | Numbers inside business ranges | Typed |
| E1 | No orphan `accounts` / `activity` rows | Typed |
| E2 | Every customer has an `accounts` and `activity` row | Typed |
| F0 | At least 1,000 customers loaded (empty tables would otherwise pass) | Reconciliation |
| F1 | Row counts agree across all 4 tables | Reconciliation |
| F2 | Total balance and leaver count agree, staging vs typed | Reconciliation |
| F3 | Churn rate within 5-40% (assumption) | Reconciliation |
| G1 | Every customer falls in exactly one age / balance / tenure / credit-score band | Reference bands |
| H1 | Risk-score CASE points equal the build-set derivation | Risk score |

**Test:** on this month's data, 0 rows (PASS). On a copy with one deliberate
fault per check (blank surname, duplicate ID, `Age='4O'`, `Balance='1.2.3'`, flag=2,
country='Italy', credit score 1200, orphan activity row, deleted account row,
3,000 extra leavers), every one of the 12 checks fired. G1
was tested separately: removing the 70+ age band and overlapping two tenure
bands produced 151 gap rows and 1,009 overlap rows. F0 fired on emptied tables;
H1 fired (4,883 rows) when 1,500 build-set balances were zeroed, changing the derived points.

Staging checks (A-B) exist because type conversion hides bad text:
`CAST('4O' AS INTEGER)` silently returns `4`.
