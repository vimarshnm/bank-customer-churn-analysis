# Performance: Indexes and Query Plans

Files: `sql/05_indexes.sql` (indexes), `sql/06_query_plans.sql` (EXPLAIN QUERY PLAN).
Reproduce: `./scripts/explain_plans.sh` (plans) and `python3 scripts/benchmark_indexes.py` (timings).

## What was indexed and why

| Index | Column | Used for |
|---|---|---|
| `ix_customers_country` | `customers.country` | `WHERE country = ...` and `GROUP BY country` |
| `ix_customers_age` | `customers.age` | Age-band range filters (`age BETWEEN 40 AND 49`) |
| `ix_accounts_balance` | `accounts.balance` | High-balance filters and balance ordering |

**Not indexed**

- **Join key `customer_id`** - it is an `INTEGER PRIMARY KEY`, which in SQLite *is*
  the row id. Every join is already a direct lookup
  (`SEARCH ... USING INTEGER PRIMARY KEY`, visible in every plan below). A second
  index on it would be a redundant copy. (In PostgreSQL / SQL Server the primary
  key gets an index automatically too; *foreign keys* usually need one added by
  hand - here the FK columns are also the PKs, so they are covered.)
- **0/1 flags `exited`, `is_active_member`** - each value matches roughly half
  the table (exited = 1 is 20%), so an index barely narrows the search, while
  every insert pays to maintain it. Tested: the planner used them only as a
  substitute for the primary-key lookup, with no gain. Rejected.

## Before vs after

Plan keywords: **SCAN** reads every row; **SEARCH** jumps to matching rows;
**COVERING INDEX** answers from the index without touching the table;
**USE TEMP B-TREE** builds a temporary sort structure.

### P1: Churn rate by country

| | Plan |
|---|---|
| Before | `SCAN c` -> `SEARCH act USING INTEGER PRIMARY KEY` -> **`USE TEMP B-TREE FOR GROUP BY`** |
| After | `SCAN c USING COVERING INDEX ix_customers_country` -> `SEARCH act USING INTEGER PRIMARY KEY` |

**What changed:** the index stores customers already sorted by country, so the
GROUP BY no longer needs a temporary sort. Every row is still read (every
customer belongs to some country), but in order.

### P2: Inactive customers in Germany and their deposits

| | Plan |
|---|---|
| Before | **`SCAN c`** (10,000 rows) -> `SEARCH ac` / `SEARCH act` by primary key |
| After | **`SEARCH c USING COVERING INDEX ix_customers_country (country=?)`** (2,509 rows) -> `SEARCH ac` / `SEARCH act` by primary key |

**What changed:** a full table scan became an index search that only visits the
2,509 German customers, then joins by key.

### P3: Deposits lost from leavers with balance over 150,000

| | Plan |
|---|---|
| Before | **`SCAN act`** (10,000 rows, check `exited`) -> `SEARCH ac` by primary key |
| After | **`SEARCH ac USING COVERING INDEX ix_accounts_balance (balance>?)`** (969 rows) -> `SEARCH act` by primary key |

**What changed:** the planner switched which table drives the query. Instead of
reading every activity row and looking up balances, it starts from the 969
high-balance accounts in the index and checks only their churn flag.

## Timing

Best of 5 batches x 200 runs, on this laptop (indicative only - absolute times
depend on hardware). All three queries return identical results before and after.

| Query | Before (ms) | After (ms) | Speed-up |
|---|---|---|---|
| P1 | 3.369 | 2.001 | 1.7x |
| P2 | 1.388 | 0.945 | 1.5x |
| P3 | 0.666 | 0.230 | 2.9x |

**Caveat:** at 10,000 rows every query is already in the low
milliseconds, so the indexes matter for *practice* rather than need. The plan
changes (SCAN -> SEARCH, no temp sort) are what scale: on a 10-million-row
monthly history, P2 and P3 would read ~25% and ~10% of the rows instead of all of them.
