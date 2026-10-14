#!/usr/bin/env bash
# explain_plans.sh - print query plans before and after indexing.
# Works on a temporary copy so data/churn.db keeps its indexes.
# Usage: ./scripts/explain_plans.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf -- "${WORK:?}"' EXIT
cp "$ROOT/data/churn.db" "$WORK/plans.db"

echo "===== BEFORE indexes ====="
sqlite3 "$WORK/plans.db" <<SQL
DROP INDEX IF EXISTS ix_customers_country;
DROP INDEX IF EXISTS ix_customers_age;
DROP INDEX IF EXISTS ix_accounts_balance;
ANALYZE;
.read '$ROOT/sql/06_query_plans.sql'
SQL

echo
echo "===== AFTER indexes ====="
sqlite3 "$WORK/plans.db" <<SQL
.read '$ROOT/sql/05_indexes.sql'
.read '$ROOT/sql/06_query_plans.sql'
SQL
