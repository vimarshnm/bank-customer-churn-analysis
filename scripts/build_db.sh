#!/usr/bin/env bash
# build_db.sh - rebuild data/churn.db from the raw CSV.
# Files 12-14 create the risk-score views; their report queries are silenced.
# Usage: ./scripts/build_db.sh   (run from anywhere)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$ROOT/data/churn.db"
RAW="$ROOT/data/raw/Customer-Churn-Records.csv"

rm -f "$DB"

sqlite3 -bail "$DB" <<SQL
.read '$ROOT/sql/00_staging.sql'
.import --csv --skip 1 '$RAW' stg_churn_raw
.read '$ROOT/sql/01_schema.sql'
.read '$ROOT/sql/02_transform.sql'
.read '$ROOT/sql/05_indexes.sql'
.read '$ROOT/sql/07_reference_bands.sql'
.read '$ROOT/sql/16_roi_assumptions.sql'
.output /dev/null
.read '$ROOT/sql/12_build_test_split.sql'
.read '$ROOT/sql/13_risk_points_derivation.sql'
.read '$ROOT/sql/14_risk_score.sql'
.output stdout
SQL

echo "Built $DB"
