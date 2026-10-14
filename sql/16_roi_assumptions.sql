/* =============================================================================
   16_roi_assumptions.sql
   Purpose : The editable inputs for the retention-campaign cost-benefit model.
   Output  : table roi_assumptions (one row per input)
   Note: every value below is an assumption, not a measured figure.
   They are starting points for discussion. Change a value here, rebuild
   (./scripts/build_db.sh) and every ROI figure in 17_money_at_risk_roi.sql,
   the extracts and the reports updates. The Excel workbook exposes the
   same four inputs as editable cells with these defaults.
   ============================================================================= */

DROP TABLE IF EXISTS roi_assumptions;

CREATE TABLE roi_assumptions (
    parameter    TEXT PRIMARY KEY,
    value        REAL NOT NULL CHECK (value >= 0),
    unit         TEXT NOT NULL,
    description  TEXT NOT NULL
);

INSERT INTO roi_assumptions (parameter, value, unit, description) VALUES
    ('cost_per_call',
        10.00, 'USD per customer called',
        'Assumption: fully loaded cost of one retention call (agent time + admin). '
        || 'Everyone on the list is called, whether or not they would have left.'),
    ('save_rate',
        0.20, 'fraction (0-1)',
        'Assumption: share of called customers who WOULD have left but stay because '
        || 'of the call. Customers who were never going to leave cannot be "saved".'),
    ('deposit_margin_rate',
        0.01, 'fraction of balance per year',
        'Assumption: annual profit the bank earns on a retained deposit balance '
        || '(net interest margin). Part 1 of a retained customer''s value.'),
    ('value_per_customer_fixed',
        100.00, 'USD per retained customer per year',
        'Assumption: annual profit from fees and other products, regardless of '
        || 'balance. Part 2 of a retained customer''s value.');

-- Value of one retained customer (1-year horizon, assumption):
--     deposit_margin_rate x balance + value_per_customer_fixed
-- e.g. balance 120,000 -> 0.01 x 120,000 + 100 = 1,300 per year.
