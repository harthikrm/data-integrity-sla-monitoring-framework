-- sql/06_metrics.sql
-- Materialized reporting tables for BI consumption

DROP TABLE IF EXISTS mart_application_lifecycle;
DROP TABLE IF EXISTS mart_data_exceptions;
DROP TABLE IF EXISTS mart_sla_breaches;
DROP TABLE IF EXISTS mart_sla_compliance_summary;

-- Lifecycle mart
CREATE TABLE mart_application_lifecycle AS
SELECT
    application_id,
    candidate_id,
    req_id,
    recruiter_id,
    source,
    org,
    job_family,
    applied_ts,
    screen_ts,
    onsite_ts,
    offer_ts,
    hired_ts,
    rejected_ts,
    withdrawn_ts,
    latest_stage,
    terminal_stage,
    days_applied_to_screen,
    days_screen_to_onsite,
    days_onsite_to_offer,
    days_offer_to_decision,
    total_time_to_hire
FROM v_application_lifecycle;

CREATE INDEX idx_mart_lifecycle_app ON mart_application_lifecycle(application_id);
CREATE INDEX idx_mart_lifecycle_org ON mart_application_lifecycle(org);
CREATE INDEX idx_mart_lifecycle_recruiter ON mart_application_lifecycle(recruiter_id);


-- Data integrity mart
CREATE TABLE mart_data_exceptions AS
SELECT
    exception_type,
    severity,
    application_id,
    event_id,
    details,
    detected_ts
FROM v_data_exceptions;

CREATE INDEX idx_mart_exceptions_type ON mart_data_exceptions(exception_type);
CREATE INDEX idx_mart_exceptions_app ON mart_data_exceptions(application_id);


-- SLA breach mart
CREATE TABLE mart_sla_breaches AS
SELECT
    application_id,
    recruiter_id,
    org,
    transition_name,
    start_ts,
    end_ts,
    duration_days,
    sla_days,
    is_breach
FROM v_sla_breaches;

CREATE INDEX idx_mart_sla_recruiter ON mart_sla_breaches(recruiter_id);
CREATE INDEX idx_mart_sla_org ON mart_sla_breaches(org);


-- SLA compliance summary mart
CREATE TABLE mart_sla_compliance_summary AS
SELECT
    recruiter_id,
    org,
    transition_name,
    total_cases,
    breaches,
    compliance_rate,
    avg_duration_days,
    p90_duration_days
FROM v_sla_compliance_summary;

CREATE INDEX idx_mart_sla_summary_recruiter ON mart_sla_compliance_summary(recruiter_id);
CREATE INDEX idx_mart_sla_summary_org ON mart_sla_compliance_summary(org);