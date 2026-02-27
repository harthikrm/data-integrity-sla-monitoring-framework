-- sql/05_sla.sql
-- SLA monitoring logic (stage transition SLAs)

CREATE OR REPLACE VIEW v_sla_transitions AS
SELECT
    application_id,
    recruiter_id,
    org,
    'APPLIED_TO_SCREEN' AS transition_name,
    applied_ts AS start_ts,
    screen_ts  AS end_ts,
    days_applied_to_screen AS duration_days,
    3::INT AS sla_days
FROM v_application_lifecycle
WHERE applied_ts IS NOT NULL
  AND screen_ts IS NOT NULL

UNION ALL

SELECT
    application_id,
    recruiter_id,
    org,
    'SCREEN_TO_ONSITE' AS transition_name,
    screen_ts AS start_ts,
    onsite_ts AS end_ts,
    days_screen_to_onsite AS duration_days,
    10::INT AS sla_days
FROM v_application_lifecycle
WHERE screen_ts IS NOT NULL
  AND onsite_ts IS NOT NULL

UNION ALL

SELECT
    application_id,
    recruiter_id,
    org,
    'ONSITE_TO_OFFER' AS transition_name,
    onsite_ts AS start_ts,
    offer_ts  AS end_ts,
    days_onsite_to_offer AS duration_days,
    7::INT AS sla_days
FROM v_application_lifecycle
WHERE onsite_ts IS NOT NULL
  AND offer_ts IS NOT NULL

UNION ALL

SELECT
    application_id,
    recruiter_id,
    org,
    'OFFER_TO_DECISION' AS transition_name,
    offer_ts AS start_ts,
    COALESCE(hired_ts, rejected_ts, withdrawn_ts) AS end_ts,
    days_offer_to_decision AS duration_days,
    5::INT AS sla_days
FROM v_application_lifecycle
WHERE offer_ts IS NOT NULL
  AND COALESCE(hired_ts, rejected_ts, withdrawn_ts) IS NOT NULL;


CREATE OR REPLACE VIEW v_sla_breaches AS
SELECT
    application_id,
    recruiter_id,
    org,
    transition_name,
    start_ts,
    end_ts,
    duration_days,
    sla_days,
    (duration_days > sla_days) AS is_breach
FROM v_sla_transitions
WHERE duration_days IS NOT NULL
  AND duration_days >= 0;   -- negative durations belong in data exceptions, not SLA


CREATE OR REPLACE VIEW v_sla_compliance_summary AS
SELECT
    recruiter_id,
    org,
    transition_name,
    COUNT(*) AS total_cases,
    SUM(is_breach::INT) AS breaches,
    1.0 - (SUM(is_breach::INT)::FLOAT / NULLIF(COUNT(*),0)) AS compliance_rate,
    AVG(duration_days) AS avg_duration_days,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY duration_days) AS p90_duration_days
FROM v_sla_breaches
GROUP BY 1,2,3;