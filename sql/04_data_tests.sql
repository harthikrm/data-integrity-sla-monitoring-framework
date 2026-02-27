-- sql/04_data_tests.sql
-- Validation layer catching upstream/system integrity issues before KPIs

CREATE OR REPLACE VIEW v_data_exceptions AS

-- 1) ORPHAN_STAGE_EVENT (raw event references missing application)
SELECT
    'ORPHAN_STAGE_EVENT' AS exception_type,
    'HIGH' AS severity,
    r.application_id,
    r.event_id,
    'Stage event references non-existent application_id' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM stage_events_raw r
WHERE NOT EXISTS (
    SELECT 1
    FROM applications a
    WHERE a.application_id = r.application_id
)

UNION ALL

-- 2) DUPLICATE_APPLICATION (same candidate+req within 30 days)
-- Canonicalize to avoid double counting pairs
SELECT
    'DUPLICATE_APPLICATION' AS exception_type,
    'MED' AS severity,
    a1.application_id,
    NULL::UUID AS event_id,
    'Candidate ' || a1.candidate_id || ' has multiple applications to req ' || a1.req_id || ' within 30 days' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM applications a1
JOIN applications a2
    ON a1.candidate_id = a2.candidate_id
   AND a1.req_id = a2.req_id
   AND a1.application_id > a2.application_id
WHERE a1.apply_ts BETWEEN a2.apply_ts AND (a2.apply_ts + INTERVAL '30 days')

UNION ALL

-- 3) MISSING_RECRUITER
SELECT
    'MISSING_RECRUITER' AS exception_type,
    'LOW' AS severity,
    application_id,
    NULL::UUID AS event_id,
    'Application has no recruiter_id assigned' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM applications
WHERE recruiter_id IS NULL

UNION ALL

-- 4a) STAGE_ORDER_VIOLATION (screen after onsite)
SELECT
    'STAGE_ORDER_VIOLATION' AS exception_type,
    'HIGH' AS severity,
    application_id,
    NULL::UUID AS event_id,
    'Screen timestamp occurs after Onsite timestamp' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle
WHERE screen_ts IS NOT NULL
  AND onsite_ts IS NOT NULL
  AND screen_ts > onsite_ts

UNION ALL

-- 4b) STAGE_ORDER_VIOLATION (onsite after offer)
SELECT
    'STAGE_ORDER_VIOLATION' AS exception_type,
    'HIGH' AS severity,
    application_id,
    NULL::UUID AS event_id,
    'Onsite timestamp occurs after Offer timestamp' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle
WHERE onsite_ts IS NOT NULL
  AND offer_ts IS NOT NULL
  AND onsite_ts > offer_ts

UNION ALL

-- 5) NEGATIVE_DURATION (any duration < 0)
SELECT
    'NEGATIVE_DURATION' AS exception_type,
    'HIGH' AS severity,
    application_id,
    NULL::UUID AS event_id,
    'One or more computed duration metrics are negative' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle
WHERE (days_applied_to_screen IS NOT NULL AND days_applied_to_screen < 0)
   OR (days_screen_to_onsite IS NOT NULL AND days_screen_to_onsite < 0)
   OR (days_onsite_to_offer IS NOT NULL AND days_onsite_to_offer < 0)
   OR (days_offer_to_decision IS NOT NULL AND days_offer_to_decision < 0)

UNION ALL

-- 6) MULTIPLE_TERMINAL_EVENTS
SELECT
    'MULTIPLE_TERMINAL_EVENTS' AS exception_type,
    'HIGH' AS severity,
    application_id,
    NULL::UUID AS event_id,
    'Application has multiple terminal outcomes (HIRED/REJECTED/WITHDRAWN)' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle
WHERE (hired_ts IS NOT NULL AND rejected_ts IS NOT NULL)
   OR (hired_ts IS NOT NULL AND withdrawn_ts IS NOT NULL)
   OR (rejected_ts IS NOT NULL AND withdrawn_ts IS NOT NULL)

UNION ALL

-- 7) OFFER_BEFORE_ONSITE (offer timestamp earlier than onsite)
SELECT
    'OFFER_BEFORE_ONSITE' AS exception_type,
    'MED' AS severity,
    l.application_id,
    NULL::UUID AS event_id,
    'Offer timestamp occurs before Onsite timestamp' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle l
JOIN offers o
  ON l.application_id = o.application_id
WHERE l.onsite_ts IS NOT NULL
  AND o.offer_ts < l.onsite_ts

UNION ALL

-- 8) OFFER_WITHOUT_ONSITE (very realistic ATS integrity issue)
SELECT
    'OFFER_WITHOUT_ONSITE' AS exception_type,
    'MED' AS severity,
    l.application_id,
    NULL::UUID AS event_id,
    'Offer exists but no Onsite stage recorded' AS details,
    CURRENT_TIMESTAMP AS detected_ts
FROM v_application_lifecycle l
JOIN offers o
  ON l.application_id = o.application_id
WHERE l.onsite_ts IS NULL;