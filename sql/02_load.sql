-- sql/02_load.sql
-- Run from repo root:
-- psql -d <dbname> -f sql/02_load.sql

BEGIN;

-- Make reruns safe
TRUNCATE TABLE
  hires,
  offers,
  stage_events,
  stage_events_raw,
  applications,
  requisitions,
  candidates
RESTART IDENTITY;

\copy candidates FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/candidates.csv' WITH (FORMAT csv, HEADER true);
\copy requisitions FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/requisitions.csv' WITH (FORMAT csv, HEADER true);
\copy applications FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/applications.csv' WITH (FORMAT csv, HEADER true);

-- load raw events (may contain orphans)
\copy stage_events_raw FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/stage_events_raw.csv' WITH (FORMAT csv, HEADER true);

-- Filter raw events into FK-safe final table
INSERT INTO stage_events (event_id, application_id, stage, stage_ts, actor_type)
SELECT r.event_id, r.application_id, r.stage, r.stage_ts, r.actor_type
FROM stage_events_raw r
JOIN applications a ON r.application_id = a.application_id;

\copy offers FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/offers.csv' WITH (FORMAT csv, HEADER true);
\copy hires  FROM '/Users/harthikmallichetty/Desktop/ats-integrity-sla-framework/data/raw/hires.csv'  WITH (FORMAT csv, HEADER true);

COMMIT;