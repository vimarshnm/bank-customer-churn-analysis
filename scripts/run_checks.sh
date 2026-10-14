#!/usr/bin/env bash
# run_checks.sh - run sql/04_validation_checks.sql against a database.
# Every check returns zero rows when healthy, so ANY output means failure.
# Usage: ./scripts/run_checks.sh [path/to/db]   (default: data/churn.db)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="${1:-$ROOT/data/churn.db}"

FAILURES="$(sqlite3 -bail -separator ' | ' "$DB" ".read '$ROOT/sql/04_validation_checks.sql'")"

if [[ -z "$FAILURES" ]]; then
    echo "PASS: all validation checks returned zero rows ($DB)"
else
    echo "FAIL: $(printf '%s\n' "$FAILURES" | wc -l | tr -d ' ') problem row(s) found"
    echo "check_name | customer_id | detail"
    printf '%s\n' "$FAILURES" | head -50
    exit 1
fi
