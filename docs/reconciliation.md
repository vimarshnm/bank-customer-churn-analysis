# Reconciliation: Do the Tools Agree?

Ten headline numbers. The **SQL** column is the system of record (`sql/` query ID
given); Excel and Tableau must show the same value at the stated precision.

**Rules**

- Compare at the precision shown: counts exact, rates to **2 dp of a percent**,
  money to the **dollar**, ratios to **2 dp**.
- ROI figures assume the **default inputs** (cost per call $10, save rate 20%,
  deposit margin 1%, $100 fixed value) and a **10% call list**.
- No filters or selections applied unless the row says so.

## Headline numbers

| # | Measure | SQL value | SQL source | Excel | Tableau | Match? |
|---|---|---|---|---|---|---|
| 1 | Total customers | **10,000** | Q8.1 | 10,000 | n/a | Yes |
| 2 | Leavers | **2,038** | Q8.1 | 2,038 | n/a | Yes |
| 3 | Churn rate | **20.38%** | Q8.1 | 20.38% | n/a | Yes |
| 4 | Churn rate - Germany | **32.44%** | Q8.2 | 32.44% | 32.44% | Yes |
| 5 | Churn rate - age 50-59 | **56.04%** | Q8.2 | 56.04% | n/a | Yes |
| 6 | Churn rate - age 50-59 *and* inactive | **81.23%** | Q9.1 | 81.23% | 81.23% | Yes |
| 7 | Deposits lost (balances of leavers) | **$185,681,112** | Q10.3 | $185,681,112 | n/a | Yes |
| 8 | Top 10% by risk score - churn rate | **73.60%** | Q14.1 | 73.60% | 73.60% | Yes |
| 9 | Top 10% - share of all leavers captured | **36.11%** | Q17.7 | 36.11% | n/a | Yes |
| 10 | Top-10% campaign net benefit (default inputs) | **$171,148.65** | Q17.4 | $171,148.65 | n/a | Yes |

*n/a* = not shown in the published Tableau story, which focuses on drivers and the
call list rather than totals and ROI.

## Where to read each number

| # | Excel (`excel/churn_analysis.xlsx`) | Tableau (published story) |
|---|---|---|
| 1 | Summary!C5 | - |
| 2 | Summary!C6 | - |
| 3 | Summary!C7 | - |
| 4 | Summary!C8 | *Churn by Country* - Germany bar; *Country Map* - Germany |
| 5 | Summary!C10 | - |
| 6 | Segments!J9 (heatmap, 50-59 x Inactive) | *Age x Activity* - 50-59 / Inactive |
| 7 | Summary!C12 | - |
| 8 | Summary!C13 | *Who to Call* - bar 1 with Top N % = 10 |
| 9 | Summary!C15 | - |
| 10 | Summary!C17, Scenario!B22 | - |

The Excel workbook also reconciles all 18 KPIs automatically: the Summary sheet's
check column compares each Excel formula with the SQL value from
`data/extracts/kpi_reference.csv`.

## Note on test-set performance

Rows 8-9 use the final score on **all** customers. The out-of-sample result on the
**test set** (customers the score never saw) is: top-10% churn **73.33%**, lift
**3.63x**, **36.36%** of leavers captured (Q15.1). Quote the test-set figures when
describing how well the score works; use rows 8-9 to reconcile the tools.

## Sign-off

| Tool | Date reconciled | Result | Notes |
|---|---|---|---|
| SQL | 2026-10-14 | Source of truth | 15 validation checks pass |
| Excel | 2026-10-14 | All 10 rows match | Values recalculated in Excel; the Summary check column shows Yes for all 18 KPIs |
| Tableau | 2026-10-14 | Rows 4, 6, 8 match | Read from the published story |
