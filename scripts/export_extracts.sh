#!/usr/bin/env bash
# export_extracts.sh - write every v_extract_* view to data/extracts/<name>.csv
# (the logic lives in sql/18_extract_views.sql).
# Usage: ./scripts/export_extracts.sh   (run after ./scripts/build_db.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$ROOT/data/churn.db"
OUT="$ROOT/data/extracts"

sqlite3 -bail "$DB" ".read '$ROOT/sql/18_extract_views.sql'"

for view in $(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type = 'view' AND name LIKE 'v_extract_%' ORDER BY name;"); do
    name="${view#v_extract_}"
    # note: -csv must come BEFORE -header (in sqlite3 3.5x, -csv resets headers off)
    # dim_* views: column 2 is the sort order; everything else sorts on column 1
    if [[ "$name" == dim_* ]]; then order=2; else order=1; fi
    sqlite3 -csv -header "$DB" "SELECT * FROM $view ORDER BY $order;" > "$OUT/$name.csv"
    rows=$(( $(wc -l < "$OUT/$name.csv") - 1 ))
    printf '%-28s %6d rows\n' "$name.csv" "$rows"
done
