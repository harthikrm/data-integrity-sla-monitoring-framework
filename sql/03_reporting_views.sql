-- sql/03_reporting_views.sql

CREATE OR REPLACE VIEW v_application_latest_stage AS
WITH ranked_events AS (
    SELECT
        application_id,
        stage,
        stage_ts,
        ROW_NUMBER() OVER (PARTITION BY application_id ORDER BY stage_ts DESC) AS rn
    FROM stage_events
)
SELECT
    application_id,
    stage AS latest_stage,
    stage_ts AS latest_stage_ts
FROM ranked_events
WHERE rn = 1;


CREATE OR REPLACE VIEW v_application_lifecycle AS
WITH p AS (
    SELECT
        a.application_id,
        a.candidate_id,
        a.req_id,
        a.recruiter_id,
        c.source,
        r.org,
        r.job_family,

        MAX(CASE WHEN e.stage = 'APPLIED'   THEN e.stage_ts END) AS applied_ts,
        MAX(CASE WHEN e.stage = 'SCREEN'    THEN e.stage_ts END) AS screen_ts,
        MAX(CASE WHEN e.stage = 'ONSITE'    THEN e.stage_ts END) AS onsite_ts,
        MAX(CASE WHEN e.stage = 'OFFER'     THEN e.stage_ts END) AS offer_ts,
        MAX(CASE WHEN e.stage = 'HIRED'     THEN e.stage_ts END) AS hired_ts,
        MAX(CASE WHEN e.stage = 'REJECTED'  THEN e.stage_ts END) AS rejected_ts,
        MAX(CASE WHEN e.stage = 'WITHDRAWN' THEN e.stage_ts END) AS withdrawn_ts,

        ls.latest_stage,
        ls.latest_stage_ts
    FROM applications a
    LEFT JOIN stage_events e
        ON a.application_id = e.application_id
    LEFT JOIN candidates c
        ON a.candidate_id = c.candidate_id
    LEFT JOIN requisitions r
        ON a.req_id = r.req_id
    LEFT JOIN v_application_latest_stage ls
        ON a.application_id = ls.application_id
    GROUP BY
        a.application_id, a.candidate_id, a.req_id, a.recruiter_id,
        c.source, r.org, r.job_family,
        ls.latest_stage, ls.latest_stage_ts
)
SELECT
    *,
    -- True terminal only if latest_stage is a terminal state
    CASE
        WHEN latest_stage IN ('HIRED','REJECTED','WITHDRAWN') THEN latest_stage
        ELSE NULL
    END AS terminal_stage,

    -- Durations (days) with explicit guards
    CASE WHEN applied_ts IS NOT NULL AND screen_ts IS NOT NULL
        THEN EXTRACT(EPOCH FROM (screen_ts - applied_ts)) / 86400.0 END AS days_applied_to_screen,

    CASE WHEN screen_ts IS NOT NULL AND onsite_ts IS NOT NULL
        THEN EXTRACT(EPOCH FROM (onsite_ts - screen_ts)) / 86400.0 END AS days_screen_to_onsite,

    CASE WHEN onsite_ts IS NOT NULL AND offer_ts IS NOT NULL
        THEN EXTRACT(EPOCH FROM (offer_ts - onsite_ts)) / 86400.0 END AS days_onsite_to_offer,

    CASE
        WHEN offer_ts IS NOT NULL AND (hired_ts IS NOT NULL OR rejected_ts IS NOT NULL OR withdrawn_ts IS NOT NULL)
        THEN EXTRACT(EPOCH FROM (
            COALESCE(hired_ts, rejected_ts, withdrawn_ts) - offer_ts
        )) / 86400.0
    END AS days_offer_to_decision,

    CASE WHEN applied_ts IS NOT NULL AND hired_ts IS NOT NULL
        THEN EXTRACT(EPOCH FROM (hired_ts - applied_ts)) / 86400.0 END AS total_time_to_hire
FROM p;


CREATE OR REPLACE VIEW v_funnel_metrics AS
SELECT
    org,
    job_family,
    source,
    DATE_TRUNC('week', applied_ts) AS apply_week,

    COUNT(*) AS applied,
    COUNT(screen_ts) AS screened,
    COUNT(onsite_ts) AS onsite,
    COUNT(offer_ts) AS offered,
    COUNT(hired_ts) AS hired,

    COUNT(screen_ts)::FLOAT / NULLIF(COUNT(*), 0) AS applied_to_screen_rate,
    COUNT(onsite_ts)::FLOAT / NULLIF(COUNT(screen_ts), 0) AS screen_to_onsite_rate,
    COUNT(offer_ts)::FLOAT / NULLIF(COUNT(onsite_ts), 0) AS onsite_to_offer_rate,
    COUNT(hired_ts)::FLOAT / NULLIF(COUNT(offer_ts), 0) AS offer_to_hire_rate
FROM v_application_lifecycle
GROUP BY 1,2,3,4;