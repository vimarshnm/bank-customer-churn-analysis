"""benchmark_indexes.py - time the 06_query_plans.sql queries with and without
the 05_indexes.sql indexes.

Runs on temporary copies, so data/churn.db is untouched.
Usage: python3 scripts/benchmark_indexes.py
"""
import re
import shutil
import sqlite3
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "churn.db"
RUNS, REPEATS = 200, 5  # best of 5 batches of 200 runs each

# Reuse the exact queries from 06_query_plans.sql (strip EXPLAIN QUERY PLAN).
plan_sql = (ROOT / "sql" / "06_query_plans.sql").read_text()
queries = [
    q.strip()
    for q in re.findall(r"EXPLAIN QUERY PLAN\s+(.*?);", plan_sql, flags=re.S)
]
index_sql = (ROOT / "sql" / "05_indexes.sql").read_text()
drop_sql = """
DROP INDEX IF EXISTS ix_customers_country;
DROP INDEX IF EXISTS ix_customers_age;
DROP INDEX IF EXISTS ix_accounts_balance;
ANALYZE;
"""


def time_query(con, sql):
    con.execute(sql).fetchall()  # warm-up
    best = float("inf")
    for _ in range(REPEATS):
        t0 = time.perf_counter()
        for _ in range(RUNS):
            con.execute(sql).fetchall()
        best = min(best, time.perf_counter() - t0)
    return best / RUNS * 1000, con.execute(sql).fetchall()


with tempfile.TemporaryDirectory() as tmp:
    results = {}
    for label, setup in [("before", drop_sql), ("after", index_sql)]:
        path = Path(tmp) / f"{label}.db"
        shutil.copy(DB, path)
        con = sqlite3.connect(path)
        con.executescript(setup)
        results[label] = [time_query(con, q) for q in queries]
        con.close()

print(f"{'query':<6}{'before ms':>11}{'after ms':>10}{'speed-up':>10}  same result?")
for i, ((b_ms, b_res), (a_ms, a_res)) in enumerate(
    zip(results["before"], results["after"]), start=1
):
    print(f"P{i:<5}{b_ms:>11.3f}{a_ms:>10.3f}{b_ms / a_ms:>9.1f}x  {b_res == a_res}")
