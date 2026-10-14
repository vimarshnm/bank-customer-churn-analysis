# Analysis Findings

Baseline: **2,038 of 10,000 customers left - 20.38% churn** (Q8.1).
Lift = segment churn ÷ 20.38% (1.00 = average). Every number cites its query;
files are `sql/08`-`sql/11`.

## Top 5 findings

### 1. Middle-aged customers leave far more than anyone else
Churn rises steeply with age, peaks in the 50s, then falls again (Q8.2):

| Age band | Customers | Churn | Lift |
|---|---|---|---|
| 18-29 | 1,641 | 7.56% | 0.37 |
| 30-39 | 4,346 | 10.88% | 0.53 |
| 40-49 | 2,618 | 30.83% | 1.51 |
| **50-59** | **869** | **56.04%** | **2.75** |
| 60-69 | 375 | 35.20% | 1.73 |
| 70+ | 151 | 9.93% | 0.49 |

Customers aged 40-59 are 35% of the base but **63.5%** of leavers (39.60% + 23.90%).
Age is the second-strongest single driver after products held (Q8.3).

### 2. Inactivity doubles the risk: and combined with age it is severe
Inactive members churn at **26.87%** vs **14.27%** for active members, and
make up **63.94%** of all leavers (Q8.2). The combination is far worse than either alone (Q9.1):

- **Inactive 50-59: 81.23% churn** (303 of 373), lift 3.99
- Inactive 40-49: 38.04% - the largest single pool of leavers (**531**)
- Active 50-59: 37.10%, i.e. activity *halves* risk even in the riskiest age band

Adding country sharpens it further: **inactive Germans aged 50-59 churn at 86.30%**
(126 of 146). The top 10 country x age x activity segments together hold
**54.91%** of all leavers (Q9.3).

### 3. Two products is the sweet spot; one is risky, three or more is alarming
(Q8.2)

| Products | Customers | Churn | Share of leavers |
|---|---|---|---|
| 1 | 5,084 | 27.71% | 69.14% |
| **2** | **4,590** | **7.60%** | 17.12% |
| 3 | 266 | 82.71% | 10.79% |
| 4 | 60 | 100.00% | 2.94% |

Moving a single-product customer to a second product is associated with far lower churn.
The 3-4 product spike (280 of 326 left) suggests customers were over-sold
products they didn't want - but see the leakage caveat in `data_quality.md`.
The 1-vs-2-product gap holds in every country (Q9.2): Germany 42.85% vs 12.12%,
France 22.43% vs 5.75%, Spain 21.87% vs 7.35%. Only France has 100+ three-product
customers to test the spike (78.85%).

### 4. Germany loses customers at twice the rate: and over half the money lost
Germany churns at **32.44%** vs France **16.17%** and Spain **16.67%** (lift 1.59, Q8.2).
With 25% of customers, Germany accounts for **39.94%** of leavers and
**52.76% of all deposits lost - $97.97M** (Q10.4). Germany's leavers also skew to
mid-range balances: churn is 44.18% in its third balance quartile vs 25.32% in
its top quartile (Q11.3).

### 5. The bank loses more money than customers: $185.7M, 24.28% of deposits
Leavers had higher balances: average **$91,109** vs **$72,743** for stayers
(median $109,344 vs $92,063) (Q10.1, Q10.2). So 20.38% of customers took
**$185,681,112 - 24.28% of all deposits** (Q10.3). Most of the money lost
(**65.40%**, $121.4M) came from the $100k-150k balance band (Q10.5).

*Nuance:* among customers **with** a balance, leavers and stayers look alike
($120,729 vs $119,541, Q10.1) - the gap is mostly that fewer leavers have a zero
balance (24.53% vs 39.15%). Germany (no zero balances, highest churn) inflates
this, but the effect survives without it: in France and Spain, customers with a
balance churn at 18.69% vs 13.82% for zero-balance customers (Q10.6).

## What does *not* matter much (Q8.2, Q8.3)

| Attribute | Churn spread across its values |
|---|---|
| Credit score band | 4.19 pts (19.54%-23.73%) |
| Tenure band | 2.50 pts (18.87%-21.37%) |
| Has credit card | 0.62 pts (20.20% vs 20.81%) |
| Salary | Leavers avg $101,510 vs stayers $99,727 (Q10.1) |

These are unlikely to earn points in the risk score.

## Also noted

- **Gender:** women churn at 25.07% vs men 16.47% (lift 1.23 vs 0.81, Q8.2).
  Reported, but excluded from the risk score on fairness grounds (see the data-quality review).
- **Deposit concentration:** the top 10% of depositors hold 26.59% of France's and
  26.99% of Spain's deposits, but only 13.99% of Germany's - German balances are
  more evenly spread (Q11.2).
- **Biggest depositors leaving:** in Spain, 4 of the top 5 depositors left,
  including the single largest account in the bank ($250,898.09) (Q11.1).
- **Small groups flagged, not hidden:** inactive 60-69 (94 customers, 91.49%) and
  inactive 70+ (17 customers) are labelled "small group" in Q9.1.

## Implications for the risk score

Strongest candidate inputs: **products held, age band, activity status, country,
balance (zero vs non-zero)**. Interactions (age x inactivity) matter, so the score
should let points add up across factors. Final points must be set on the
**build set only**, then checked on the test set.
