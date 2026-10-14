# Customer Churn Analysis: Full Report

**Scope:** 10,000 retail bank customers (France, Germany, Spain), one snapshot.
**Goal:** find who is likely to leave so the retention team can call the riskiest
10% each month - and show whether that pays off.
**Method:** SQL (SQLite) for all analysis; Excel and Tableau built on the same SQL
extracts and reconciled to it (`docs/reconciliation.md`).

Every number cites the SQL query that produces it (e.g. *Q8.2* =
`sql/08_churn_by_attribute.sql`, query 8.2). Supporting detail:
`reports/data_quality.md`, `analysis_findings.md`, `risk_score.md`,
`money_at_risk_roi.md`.

---

## 1. Headline

- **2,038 of 10,000 customers left - 20.38% churn** (Q8.1).
- They took **$185.7M, 24.28% of all deposits** (Q10.3) - the bank loses a larger
  share of its money than of its customers.
- A simple four-factor risk score finds them: on customers it was **not** built
  from, the riskiest 10% churn at **73.33%** (**3.63x** average) and include
  **36.36%** of all leavers (Q15.1).
- A call campaign on that 10% breaks even if it saves just **1.10%** of the
  would-be leavers it reaches (Q17.4, assumed costs).

## 2. Data and quality

- Raw CSV loaded unchanged into a staging table, then typed and split into three
  related tables (`customers`, `accounts`, `activity`) with keys and CHECK rules
  (`sql/00`-`02`).
- **Clean structure:** 0 missing values, 0 duplicate IDs, all categories valid (Q2.1-Q4.2).
- **15 automated checks** return zero rows when the data is healthy; each was proven
  to fire on broken test data (`sql/04_validation_checks.sql`).
- **Leakage removed:** `complained` matches churn in 99.86% of rows - 2,034 of 2,044
  complainers left, only 4 of 7,956 non-complainers (Q6.1, Q6.2). It is almost
  certainly recorded with the exit, so it is excluded from the score.
- **Oddities to keep in mind:** Germany has **no** zero-balance customers (France
  48.22%, Spain 48.41%, Q7.2); 59 salaries under 1,000 (Q4.3); `card_type` is set
  for 2,945 customers with no credit card (Q7.1); all 21 customers with a credit
  score under 405 left (Q7.3).

## 3. Key churn drivers

| Driver | Finding | Query |
|---|---|---|
| **Age** | Churn peaks at **56.04%** for ages 50-59 (lift 2.75) and falls again after 60; under-40s churn ≤ 10.88% | Q8.2 |
| **Activity** | Inactive members churn **26.87%** vs **14.27%** active, and are **63.94%** of leavers | Q8.2 |
| **Age x activity** | Inactive 50-59: **81.23%** (303 of 373). Inactive 40-49 is the biggest pool of leavers: **531** | Q9.1 |
| **Products held** | 2 products: **7.60%**; 1 product: **27.71%** (69.14% of all leavers); 3 products: **82.71%**; 4: **100%** (60 of 60) | Q8.2 |
| **Country** | Germany **32.44%** vs France 16.17%, Spain 16.67%; Germany is 25% of customers but **52.76%** of deposits lost ($97.97M) | Q8.2, Q10.4 |
| **Balance** | Leavers held more: average $91,109 vs $72,743; the $100k-150k band alone is **65.40%** of deposits lost. Holds outside Germany too (France+Spain: 18.69% vs 13.82% for zero balance) | Q10.1, Q10.5, Q10.6 |
| **Gender** | Women 25.07% vs men 16.47% - reported, but *not* used in the score (fairness) | Q8.2 |
| **Not drivers** | Credit score (4.19-pt spread), tenure (2.50), credit card (0.62), salary (avg $101,510 vs $99,727) | Q8.3, Q10.1 |

The worst combined segment: **inactive Germans aged 50-59 - 86.30% churn** (126 of
146). The top 10 country x age x activity segments hold **54.91%** of all leavers (Q9.3).

## 4. How the risk score works

A **scorecard**, not a black box: four factors, points added up, 0-65.

| Factor | Points | Highest-risk group |
|---|---|---|
| Age band x activity | 0-27 | 60-69 inactive (27), 50-59 inactive (26) |
| Products held | 0 / 13 / 24 | 3 or 4 products (24) |
| Country | 0 / 1 / 8 | Germany (8) |
| Has a balance | 0 / 6 | Has balance (6) |

- **Points come from the build set only** (70% of customers, chosen by the last
  digit of the customer ID: 0-6 build, 7-9 test - reproducible and unrelated to
  churn, Q12.2).
- Points = 10 x ln(group churn ÷ average churn), with small groups smoothed toward
  average; **+7 points ~double the risk** (Q13.2).
- Excluded: `complained` (leakage), `satisfaction_score`, `points_earned`,
  `card_type` (no signal), `gender` (fairness), identifiers.
- Customers are ranked with `NTILE(10)`; decile 1 is the call list. Inside it,
  **P1** = balance ≥ $100k (761 customers), **P2** = smaller balance (190),
  **P3** = zero balance (49) (Q14.2).
- A validation check (H1) fails if the scoring CASE logic ever drifts from the
  build-set derivation.

## 5. Build vs test performance

| Metric | Build set | **Test set** |
|---|---|---|
| Customers / leavers | 7,005 / 1,433 | **2,995 / 605** |
| Churn rate in top 10% | 73.47% | **73.33%** |
| Lift of top 10% | 3.59x | **3.63x** |
| Leavers captured - top 10% / 20% / 30% | 35.94% / 55.62% / 71.88% | **36.36% / 54.55% / 69.09%** |
| Churn in lowest-risk 10% | 1.57% | **1.34%** |

Source: Q15.1. The small drops at 20% and 30% (−1.07 and −2.79 points) are inside
the 95% sampling margin of about ±3.7-4.0 points (Q15.5), so the score
**generalises**. A perfect top-10% list could hold at most 49.50% of test leavers,
so 36.36% means 73% of the people called are true leavers.

## 6. Money at risk

| Risk tier | Customers | Churn | Deposits held | Deposits lost | Share of deposits lost |
|---|---|---|---|---|---|
| Very high (top 10%) | 1,000 | 73.60% | $114.3M | **$83.2M** | **44.82%** |
| High (next 20%) | 2,000 | 35.55% | $203.2M | $59.7M | 32.13% |
| Medium (30%) | 3,000 | 13.53% | $303.0M | $33.4M | 17.96% |
| Low (40%) | 4,000 | 4.62% | $144.4M | $9.5M | 5.09% |

Source: Q17.1. **The riskiest 10% hold 14.94% of deposits but 44.82% of the
deposits that leave.**

## 7. ROI scenarios

**All inputs are assumptions** (`sql/16_roi_assumptions.sql`):
$10 per call, 20% of called would-be leavers saved, value of a retained customer =
1% of balance + $100 per year. No retention-offer cost is included.

| | Top 10% | Top 20% |
|---|---|---|
| Customers called | 1,000 | 2,000 |
| Would-be leavers reached | 736 | 1,126 |
| Customers saved | 147.2 | 225.2 |
| Deposits retained | $16.6M | $24.3M |
| Cost | $10,000 | $20,000 |
| Net benefit (1 year) | **$171,148.65** | **$245,257.26** |
| ROI | 17.11x | 12.26x |
| **Break-even save rate** | **1.10%** | **1.51%** |

Source: Q17.4. Sensitivity: at a 5% save rate the top-10% campaign still nets
$35,287.16 (Q17.6). Calling the *second* 10% adds $74,108.61 and stays profitable
unless a call costs more than $84.11 (Q17.5).

**Read this as:** the decision holds up: the campaign pays even if the save rate
is ~18x lower than assumed - but the dollar figures are illustrative until the
bank supplies real costs and a measured save rate.

## 8. Recommended retention actions

1. **Run a monthly call campaign on the top 10%, P1 first.** 736 of the 1,000
   would leave; P1 customers alone hold $98.2M (Q14.2). Start with a **pilot with a
   control group** (call half of the list, not the other half) to measure the real
   save rate - the one input everything depends on.
2. **Re-engage inactive customers aged 40-59 before they go quiet for good.**
   Inactivity doubles churn, and inactive 40-59s account for **834** leavers
   (531 + 303, Q9.1). Trigger a contact when a customer in this age band becomes
   inactive, rather than waiting for the monthly list.
3. **Move single-product customers to a second product.** One product: 27.71%
   churn; two: 7.60% (Q8.2). Single-product customers are 69.14% of leavers.
   *This is correlation* - test it with an offer to a randomised group before scaling.
4. **Investigate Germany.** It churns at twice the rate (32.44%) and accounts for
   52.76% of deposits lost - and 761 of the 1,000 customers on the call list are
   German (Q17.8). Quantitative data cannot say *why*; commission exit interviews
   or a competitor pricing review there.
5. **Review how 3+ product holdings arise.** 280 of 326 customers with 3-4
   products left (82.71% / 100%, Q8.2). Either they were sold products they did not
   want, or product counts change during exit (a leakage risk) - the business
   should confirm which before acting.

## 9. Limitations

- **One snapshot, no dates:** "risk" means *resembles customers who left*, not a
  forecast with a time horizon; next month's data is needed for a true
  out-of-time test.
- **Observed churn stands in for future churn** in the ROI model.
- **Assumed ROI inputs**, and no retention-offer cost - dollar results are
  illustrative only.
- **Possible leakage in `num_products`** (3-4 products) - open question for the business.
- **Additive points double-count overlapping factors** (Germany always has a balance),
  which is why the call list is 76% German; a cap or interaction term could be tested.
- **Small groups** (e.g. inactive 70+, 17 customers) are smoothed but still noisy.
- **Fairness:** gender excluded; age and country are used (common for retention
  offers, but should be reviewed by compliance).
- **Dataset:** a public Kaggle dataset; some fields (`card_type`, low salaries,
  Germany's balances) have unclear meaning.
- The **all-customer** call-list figures (e.g. 73.60%) are slightly optimistic;
  the **test-set** figures (73.33%) are the better measure.
