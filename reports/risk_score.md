# Churn Risk Score

A rule-based score that ranks every customer by churn risk so the
retention team can call the riskiest 10% each month. No machine learning:
four factors, points in a CASE statement, add them up.

Files: `sql/12_build_test_split.sql` -> `13_risk_points_derivation.sql` ->
`14_risk_score.sql` (final view `v_customer_risk`) -> `15_risk_score_evaluation.sql`.

## 1. Fair testing: build set vs test set

**Rule:** last digit of `customer_id` - `customer_id % 10` of 0-6 -> **build**, 7-9 -> **test**.

- **Deterministic:** the same customer always lands in the same set, in any SQL
  database, with no random seed to store. Anyone can reproduce it by hand.
- **Unrelated to churn:** churn by last digit ranges 18.31%-22.22% with no
  pattern (Q12.2).
- **Stable:** existing customers keep their set next month.

The two sets are alike (Q12.1):

| Set | Customers | Share | Leavers | Churn | Avg age | Germany share | Active share |
|---|---|---|---|---|---|---|---|
| Build | 7,005 | 70.05% | 1,433 | 20.46% | 38.96 | 25.32% | 51.88% |
| Test | 2,995 | 29.95% | 605 | 20.20% | 38.82 | 24.54% | 50.65% |

**All points were set using the build set only.** The test set was not looked at
until the score was final.

## 2. How the score works

**Inputs:** age band x activity status, products held, country, zero vs non-zero balance.
**Excluded:** `complained` (leakage), `satisfaction_score`, `points_earned`,
`card_type` (no signal / unclear timing), `gender` (fairness), identifiers.

**Method** (Q13.2), per group in the build set:
1. Churn rate of the group.
2. Smoothed toward the average by adding 10 imaginary average customers, so tiny
   groups cannot claim 0% or 100% risk.
3. Points = 10 x ln(smoothed rate ÷ build churn rate 20.46%), rounded -
   **+7 points ~double the risk**.
4. Each factor shifted so its safest group scores 0.

Assumption: smoothing weight (10) and scale (10) are judgement calls for readability, not tuned on the test set.

### Scorecard

| Factor | Group | Build customers | Build churn | Points |
|---|---|---|---|---|
| **Age x activity** | 18-29 Active | 606 | 5.12% | 0 |
| | 18-29 Inactive | 545 | 9.72% | 6 |
| | 30-39 Active | 1,523 | 8.27% | 4 |
| | 30-39 Inactive | 1,497 | 13.09% | 9 |
| | 40-49 Active | 863 | 22.60% | 14 |
| | 40-49 Inactive | 982 | 38.80% | 19 |
| | 50-59 Active | 347 | 38.04% | 19 |
| | 50-59 Inactive | 269 | 80.67% | 26 |
| | 60-69 Active | 199 | 14.57% | 10 |
| | 60-69 Inactive | 63 | 95.24% | 27 |
| | 70+ Active | 96 | 4.17% | 0 |
| | 70+ Inactive | 15 | 60.00% | 21 |
| **Products held** | 1 | 3,557 | 28.00% | 13 |
| | 2 | 3,230 | 7.68% | 0 |
| | 3 | 173 | 83.24% | 24 |
| | 4 | 45 | 100.00% | 24 |
| **Country** | France | 3,513 | 15.88% | 0 |
| | Germany | 1,774 | 33.03% | 8 |
| | Spain | 1,718 | 16.82% | 1 |
| **Balance** | Zero | 2,497 | 13.78% | 0 |
| | Has balance | 4,508 | 24.16% | 6 |

**Score range:** 0 to 65 (Q13.3).

**Smoothing at work** (Q13.4, log-lift before the shift to zero): the smallest
groups move most toward average - 70+ Inactive (15 customers) from +10.76 to
+7.70, 70+ Active (96) from −15.91 to −12.77, and 4 products (45 customers, 100%
churn) from +15.87 to +14.31, which is why 4 products scores the same 24 as
3 products. Large groups such as 18-29 Active (606) move by less than half a point.

**Example (Q14.3):** rank 1 is a German customer aged 60-69, inactive, with 3
products and a balance -> 27 + 24 + 8 + 6 = **65**.

Check H1 in `04_validation_checks.sql` fails if the CASE points ever differ from
the build-set derivation (tested: it fires when build data changes).

## 3. Results: build vs test

Customers ranked into deciles **within their own set** with `NTILE(10)`
(ties broken by balance, then customer ID). Q15.1:

| Metric | Build | **Test** |
|---|---|---|
| Overall churn rate | 20.46% | **20.20%** |
| **Churn rate in top 10%** | 73.47% | **73.33%** |
| **Lift of top 10%** | 3.59x | **3.63x** |
| Leavers captured - top 10% | 35.94% | **36.36%** |
| Leavers captured - top 20% | 55.62% | **54.55%** |
| Leavers captured - top 30% | 71.88% | **69.09%** |
| Churn rate in lowest-risk 10% | 1.57% | **1.34%** |
| Best possible capture - top 10% | 48.88% | 49.50% |

**On the test set:** calling the top 10% reaches people who leave
**73% of the time** - 3.6x the average - and finds **over a third of all
leavers**. Calling the top 30% finds **69%** of leavers. The bottom 10% almost
never leave (1.34%).

A top-10% list can hold at most 49.50% of the test set's leavers (300 slots,
605 leavers), so 36.36% capture means 73% of the list are true leavers.

### Test-set gains table (Q15.2)

| Decile | Score range | Customers | Leavers | Churn | Lift | Cumulative capture |
|---|---|---|---|---|---|---|
| 1 | 39-65 | 300 | 220 | 73.33% | 3.63 | 36.36% |
| 2 | 34-39 | 300 | 110 | 36.67% | 1.82 | 54.55% |
| 3 | 30-34 | 300 | 88 | 29.33% | 1.45 | 69.09% |
| 4 | 27-30 | 300 | 40 | 13.33% | 0.66 | 75.70% |
| 5 | 23-27 | 300 | 51 | 17.00% | 0.84 | 84.13% |
| 6 | 20-23 | 299 | 33 | 11.04% | 0.55 | 89.59% |
| 7 | 17-20 | 299 | 27 | 9.03% | 0.45 | 94.05% |
| 8 | 10-17 | 299 | 25 | 8.36% | 0.41 | 98.18% |
| 9 | 6-10 | 299 | 7 | 2.34% | 0.12 | 99.34% |
| 10 | 0-6 | 299 | 4 | 1.34% | 0.07 | 100.00% |

### Why the small drop at 20% and 30%?

Top-10% results held (even slightly improved), but capture fell 1.07 pts at 20%
and 2.79 pts at 30% (Q15.5). Reasons:

1. **It is within sampling noise.** The test set has only 605 leavers; the 95%
   margin on its capture rates is ±3.68 to ±3.97 pts, larger than every change
   (Q15.5 verdict: "within noise" for all three).
2. **Small groups shift most** (Q15.4): 60-69 Active churned 20.73% in test vs
   14.57% in build (scored only 10 points, so these leavers rank lower);
   60-69 Inactive fell from 95.24% to 83.87%. Smoothing limits, but cannot remove,
   this over-fitting to small build groups.
3. **Deciles 2-3 sit on tied scores** (34-39 and 30-34), so the boundary
   ordering of near-equal customers varies more between sets.

Conclusion: no sign of over-fitting beyond normal noise - **the score generalises**.

## 4. Final score for all customers: `v_customer_risk`

Ranked across all 10,000 customers. (These include build customers, so they are
slightly optimistic; quote the **test-set** figures above as the score's performance.)

**Risk tiers** (Assumption: boundaries are business choices) - Q14.1:

| Risk tier | Deciles | Customers | Score range | Leavers | Churn |
|---|---|---|---|---|---|
| Very high | 1 | 1,000 | 40-65 | 736 | 73.60% |
| High | 2-3 | 2,000 | 31-40 | 711 | 35.55% |
| Medium | 4-6 | 3,000 | 20-31 | 406 | 13.53% |
| Low | 7-10 | 4,000 | 0-20 | 185 | 4.62% |

**Call priority within the top 10%** (Assumption: value-based order) - Q14.2:

| Priority | Rule | Customers | Churn | Balance held |
|---|---|---|---|---|
| P1 High value | balance ≥ 100,000 | 761 | 74.64% | $98,190,201.65 |
| P2 Mid value | balance 0.01-99,999 | 190 | 65.26% | $16,071,532.38 |
| P3 No balance | balance = 0 | 49 | 89.80% | $0.00 |

P1 is called first because it combines high risk with the most money at stake.

## 5. Limitations

- Snapshot data: "risk" here means "looks like customers who left", not a
  forecast with a time horizon.
- Additive points partly double-count overlapping factors (e.g. Germany and
  having a balance).
- `num_products` 3-4 may be partly leakage if products are closed during exit
  (open question from the data-quality review).
- Tied scores mean the exact top-10% boundary depends on the tie-break rule
  (balance, then ID).
