/* =============================================================================
   05_indexes.sql
   Purpose : Indexes for the columns the analysis filters and groups on.
   Input   : customers, accounts, activity
   Output  : 3 indexes + planner statistics (ANALYZE)
   Design  : See docs/performance.md for the before/after query plans.
     - JOINS need no extra index: customer_id is an INTEGER PRIMARY KEY, which
       in SQLite IS the table's row id, so every join is already a direct
       lookup ("SEARCH ... USING INTEGER PRIMARY KEY"). An index on it would
       be a redundant copy.
     - 0/1 FLAGS (exited, is_active_member) are NOT indexed: with two values
       each matches ~half the table, so the planner gains little and every
       insert pays to maintain the index. Tested and rejected.
     - Indexed: country (filter + GROUP BY), age (range filters for age
       bands), balance (range filters and ORDER BY for balance ranking).
   ============================================================================= */

-- Country: segment filters (WHERE country = 'Germany') and GROUP BY country.
CREATE INDEX IF NOT EXISTS ix_customers_country ON customers (country);

-- Age: range filters such as WHERE age BETWEEN 40 AND 49 (age bands).
CREATE INDEX IF NOT EXISTS ix_customers_age ON customers (age);

-- Balance: range filters (high-value customers) and balance ordering.
CREATE INDEX IF NOT EXISTS ix_accounts_balance ON accounts (balance);

-- Refresh the statistics the query planner uses to choose between plans.
ANALYZE;
