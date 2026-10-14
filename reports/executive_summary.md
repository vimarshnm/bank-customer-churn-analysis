# Executive Summary: Customer Churn

**For:** Head of Retail Banking, **Basis:** 10,000 customers, France / Germany / Spain

## The problem

**One in five customers (20.38%) left - and they took $185.7 million, 24% of all
deposits.** Leavers held larger balances than average, so the bank loses more money
than customers. The retention team can call about 10% of customers a month and needs
to know *who*.

## Three key findings

1. **Middle-aged, inactive customers are the core of the problem.** Customers aged
   50-59 leave 56% of the time; if they are also inactive, **81%** leave. Inactive
   customers make up 64% of all leavers.

2. **Germany is the hot spot.** German customers leave at **twice the rate** of
   French or Spanish customers (32% vs 16-17%) and account for **53% of the money lost**
   ($98M).

3. **A simple score finds the leavers.** Four factors - age and activity, number of
   products, country, and whether the customer has a balance - produce a risk score.
   Tested on customers it had never seen, **73% of the top 10% did leave**:
   3.6 times better than calling at random, reaching **36% of all leavers** from just
   10% of customers.

## Recommendation

**Start a monthly retention call to the 1,000 highest-risk customers**, highest
balances first - **as a pilot with a control group** so the real save rate is
measured before scaling. In parallel:

- contact customers aged 40-59 as soon as they become inactive;
- offer single-product customers a second product (two-product customers churn at
  7.6% vs 27.7%) - tested on a sample first;
- commission a short root-cause review of German customers.

## Expected impact

*Illustrative - based on assumed costs to be replaced with the bank's own
figures:* $10 per call, 20% of would-be leavers saved.

| Calling the top 10% each month | |
|---|---|
| Customers called | 1,000 |
| Customers who would otherwise leave | 736 |
| Customers kept (at 20%) | ~147 |
| Deposits kept | ~$16.6M |
| Campaign cost | $10,000 |
| **Net benefit, first year** | **~$171,000** |

**The key point does not depend on the assumptions:** the campaign pays for itself
if it keeps just **1 in 90** of the would-be leavers it calls (a 1.1% save rate).

*Caveats:* one snapshot of data (no history yet); the ROI excludes the cost of any
retention offer; age and country are used in the score and should be reviewed by
compliance. Full detail: `reports/churn_report.md`.
