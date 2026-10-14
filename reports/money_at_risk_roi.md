# Money at Risk & Campaign ROI

Files: `sql/16_roi_assumptions.sql` (inputs), `sql/17_money_at_risk_roi.sql` (queries).
Population: all 10,000 customers scored by `v_customer_risk`.

> **Every ROI input is an assumption, not a measured figure.** Change a
> value in `sql/16_roi_assumptions.sql`, run `./scripts/build_db.sh`, and rerun
> `sql/17_money_at_risk_roi.sql`. The money-at-risk figures (section 1) are facts
> from the data; the ROI figures (sections 2-4) are only as good as the inputs.

## 1. Money at risk by risk tier (Q17.1): facts from the data

| Risk tier | Customers | Churn | Deposits held | Share of deposits | Deposits lost | Share of deposits lost |
|---|---|---|---|---|---|---|
| Very high (top 10%) | 1,000 | 73.60% | $114,261,734.03 | 14.94% | $83,214,325.28 | **44.82%** |
| High (next 20%) | 2,000 | 35.55% | $203,196,362.15 | 26.57% | $59,660,409.15 | 32.13% |
| Medium | 3,000 | 13.53% | $303,026,055.21 | 39.62% | $33,355,913.24 | 17.96% |
| Low | 4,000 | 4.62% | $144,374,741.49 | 18.88% | $9,450,464.43 | 5.09% |

**The riskiest 10% of customers hold 14.94% of deposits but account for 44.82% of
all deposits lost ($83.2M of $185.7M).** The top 30% account for 76.95%.

Within the top 10% (Q17.2):

| Call priority | Customers | Leavers | Deposits held | Deposits lost |
|---|---|---|---|---|
| P1 High value (≥ $100k) | 761 | 568 | $98,190,201.65 | $72,682,892.34 |
| P2 Mid value | 190 | 124 | $16,071,532.38 | $10,531,432.94 |
| P3 No balance | 49 | 44 | $0.00 | $0.00 |

## 2. ROI inputs: all assumptions (Q17.3)

| Input | Assumed value | Meaning |
|---|---|---|
| `cost_per_call` | **$10** | Cost of one retention call; everyone on the list is called |
| `save_rate` | **20%** | Share of called would-be leavers who stay because of the call |
| `deposit_margin_rate` | **1%** | Annual profit on a retained balance |
| `value_per_customer_fixed` | **$100** | Annual profit from fees / other products |

Value of one retained customer (1 year) = 1% x balance + $100.

**Not included (assumption):** the cost of any retention *offer* (fee waiver,
better rate). Only the call is costed. Adding an offer would reduce every ROI below.
"Would-be leavers" = customers in the list who actually left - the best available
stand-in for who will leave next month.

## 3. Campaign scenarios: top 10% vs top 20% (Q17.4)

| | Top 10% | Top 20% |
|---|---|---|
| Customers called | 1,000 | 2,000 |
| Would-be leavers on the list | 736 | 1,126 |
| Customers saved (x 20%) | 147.2 | 225.2 |
| Deposits retained | $16,642,865.06 | $24,273,726.01 |
| Campaign cost | $10,000.00 | $20,000.00 |
| Value saved (1 year) | $181,148.65 | $265,257.26 |
| **Net benefit** | **$171,148.65** | **$245,257.26** |
| **ROI** (net ÷ cost) | **17.11x** | **12.26x** |
| **Break-even save rate** | **1.10%** | **1.51%** |

### Is the second 10% worth calling? (Q17.5)

| Slice | Would-be leavers | Cost | Value saved | Net benefit | ROI | Break-even cost per call |
|---|---|---|---|---|---|---|
| Decile 1 (first 10%) | 736 | $10,000.00 | $181,148.65 | $171,148.65 | 17.11x | $181.15 |
| Decile 2 (next 10%) | 390 | $10,000.00 | $84,108.61 | $74,108.61 | 7.41x | $84.11 |

Decile 2 has about half the leavers of decile 1, so each call is worth less -
but at these inputs it still pays: calls would need to cost more than $84.11 each
before extending to the top 20% stops adding profit.

## 4. Sensitivity to the save rate: top 10% (Q17.6)

| Save rate | Net benefit | ROI |
|---|---|---|
| 5% | $35,287.16 | 3.53x |
| 10% | $80,574.33 | 8.06x |
| 15% | $125,861.49 | 12.59x |
| **20% (assumed)** | **$171,148.65** | **17.11x** |
| 25% | $216,435.81 | 21.64x |
| 30% | $261,722.98 | 26.17x |

## 5. What this means

- **The conclusion holds even if the inputs are wrong.** The top-10% campaign
  breaks even if just **1.10%** of called would-be leavers are saved - roughly
  1 in 90. The model assumes 20%, so the save rate could be ~18x lower and
  the campaign would still not lose money.
- **Top 20% earns more in total, top 10% earns more per call.** Choose top 10%
  if calling capacity or budget is the constraint; top 20% if the aim is to
  maximise total profit.
- **The headline ROI figures are sensitive and should not be quoted as
  forecasts** until the inputs are replaced with the bank's real call cost,
  margin and a measured save rate (ideally from a small pilot with a control group).
