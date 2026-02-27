-- sql/01_schema.sql

DROP TABLE IF EXISTS hires CASCADE;
DROP TABLE IF EXISTS offers CASCADE;
DROP TABLE IF EXISTS stage_events CASCADE;
DROP TABLE IF EXISTS stage_events_raw CASCADE;
DROP TABLE IF EXISTS applications CASCADE;
DROP TABLE IF EXISTS requisitions CASCADE;
DROP TABLE IF EXISTS candidates CASCADE;

CREATE TABLE candidates (
    candidate_id UUID PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    source VARCHAR(50) NOT NULL,
    location VARCHAR(100) NOT NULL,
    years_experience INT NOT NULL CHECK (years_experience BETWEEN 0 AND 50),
    email_hash VARCHAR(100) NOT NULL
);

CREATE TABLE requisitions (
    req_id UUID PRIMARY KEY,
    org VARCHAR(100) NOT NULL,
    job_family VARCHAR(100) NOT NULL,
    level VARCHAR(10) NOT NULL CHECK (level IN ('IC1','IC2','IC3','IC4','IC5')),
    open_date TIMESTAMP NOT NULL,
    close_date TIMESTAMP,
    CHECK (close_date IS NULL OR close_date >= open_date)
);

CREATE TABLE applications (
    application_id UUID PRIMARY KEY,
    candidate_id UUID NOT NULL REFERENCES candidates(candidate_id),
    req_id UUID NOT NULL REFERENCES requisitions(req_id),
    apply_ts TIMESTAMP NOT NULL,
    recruiter_id UUID,
    -- Optional: prevent exact duplicates (same candidate, req, timestamp)
    UNIQUE (candidate_id, req_id, apply_ts)
);

CREATE INDEX idx_applications_candidate ON applications(candidate_id);
CREATE INDEX idx_applications_req ON applications(req_id);
CREATE INDEX idx_applications_apply_ts ON applications(apply_ts);

-- Raw events, no FK to applications yet to allow orphan loading
CREATE TABLE stage_events_raw (
    event_id UUID PRIMARY KEY,
    application_id UUID NOT NULL,
    stage VARCHAR(50) NOT NULL CHECK (stage IN (
        'APPLIED','SCREEN','ONSITE','OFFER','HIRED','REJECTED','WITHDRAWN'
    )),
    stage_ts TIMESTAMP NOT NULL,
    actor_type VARCHAR(50) NOT NULL CHECK (actor_type IN ('Recruiter','System','Candidate')),
    UNIQUE (application_id, stage, stage_ts)
);

-- Final events with firm FK
CREATE TABLE stage_events (
    event_id UUID PRIMARY KEY,
    application_id UUID NOT NULL REFERENCES applications(application_id),
    stage VARCHAR(50) NOT NULL CHECK (stage IN (
        'APPLIED','SCREEN','ONSITE','OFFER','HIRED','REJECTED','WITHDRAWN'
    )),
    stage_ts TIMESTAMP NOT NULL,
    actor_type VARCHAR(50) NOT NULL CHECK (actor_type IN ('Recruiter','System','Candidate')),
    UNIQUE (application_id, stage, stage_ts)
);

CREATE INDEX idx_stage_events_app_ts ON stage_events(application_id, stage_ts);
CREATE INDEX idx_stage_events_stage_ts ON stage_events(stage, stage_ts);
CREATE INDEX idx_stage_events_app_stage ON stage_events(application_id, stage);

CREATE TABLE offers (
    offer_id UUID PRIMARY KEY,
    application_id UUID NOT NULL REFERENCES applications(application_id),
    offer_ts TIMESTAMP NOT NULL,
    decision VARCHAR(50) NOT NULL CHECK (decision IN ('ACCEPTED','DECLINED','EXPIRED')),
    comp_band VARCHAR(10) NOT NULL CHECK (comp_band IN ('A','B','C')),
    CHECK (offer_ts IS NOT NULL)
);

CREATE INDEX idx_offers_app ON offers(application_id);

CREATE TABLE hires (
    hire_id UUID PRIMARY KEY,
    application_id UUID NOT NULL REFERENCES applications(application_id),
    hired_ts TIMESTAMP NOT NULL,
    start_date DATE NOT NULL
);

CREATE INDEX idx_hires_app ON hires(application_id);