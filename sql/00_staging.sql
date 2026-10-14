/* =============================================================================
   00_staging.sql
   Purpose : Create the staging table that receives an EXACT copy of the raw CSV.
   Input   : data/raw/Customer-Churn-Records.csv (loaded by scripts/build_db.sh
             using the sqlite3 `.import` command - no transformation applied)
   Output  : stg_churn_raw
   Notes   : Every column is TEXT and keeps its original CSV name (including
             the names with spaces) so the staging table is a faithful,
             auditable copy. Type conversion happens in 02_transform.sql.
   ============================================================================= */

DROP TABLE IF EXISTS stg_churn_raw;

CREATE TABLE stg_churn_raw (
    "RowNumber"          TEXT,
    "CustomerId"         TEXT,
    "Surname"            TEXT,
    "CreditScore"        TEXT,
    "Geography"          TEXT,
    "Gender"             TEXT,
    "Age"                TEXT,
    "Tenure"             TEXT,
    "Balance"            TEXT,
    "NumOfProducts"      TEXT,
    "HasCrCard"          TEXT,
    "IsActiveMember"     TEXT,
    "EstimatedSalary"    TEXT,
    "Exited"             TEXT,
    "Complain"           TEXT,
    "Satisfaction Score" TEXT,
    "Card Type"          TEXT,
    "Point Earned"       TEXT
);
