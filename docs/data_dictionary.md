# Data Dictionary

This document defines the core conceptual entities and the final tabular structure representing the ATS dataset. 

## Source Tables

### `candidates`
| Column | Type | Description |
|--------|------|-------------|
| `candidate_id` | UUID (PK) | Unique identifier for a candidate profile. |
| `created_at` | TIMESTAMP | Timestamp when the profile was created in the ATS. |
| `source` | VARCHAR | Acquisition source (LinkedIn, Referral, CareerSite, Agency). |
| `location` | VARCHAR | Candidate stated location. |
| `years_experience` | INT | Years of professional experience. |
| `email_hash` | VARCHAR | Anonymized identifier for the candidate. |

### `requisitions`
| Column | Type | Description |
|--------|------|-------------|
| `req_id` | UUID (PK) | Unique identifier for a job opening. |
| `org` | VARCHAR | Department/Organization (Engineering, HR, Manufacturing, IT). |
| `job_family` | VARCHAR | Specific job family under the org overlay. |
| `level` | VARCHAR | Seniority level constraint (IC1 - IC5). |
| `open_date` | TIMESTAMP | Timestamp when the requisition began accepting applications. |
| `close_date` | TIMESTAMP | Timestamp when the requisition stopped accepting applications (nullable). |

### `applications`
| Column | Type | Description |
|--------|------|-------------|
| `application_id` | UUID (PK) | Unique identifier for an application instance. |
| `candidate_id` | UUID (FK) | Candidate applying to the role. |
| `req_id` | UUID (FK) | The specific role requisition applied to. |
| `apply_ts` | TIMESTAMP | The initial submission time. |
| `recruiter_id` | UUID | HR point of contact assigned to triage and handle the application. |

### `stage_events`
*(This is the immutable event-log append source of truth for the ATS)*
| Column | Type | Description |
|--------|------|-------------|
| `event_id` | UUID (PK) | Unique identifier for the logging event. |
| `application_id` | UUID (FK) | The application adjusting stages. |
| `stage` | VARCHAR | Lifecycle phase (APPLIED, SCREEN, ONSITE, OFFER, HIRED, REJECTED, WITHDRAWN). |
| `stage_ts` | TIMESTAMP | The timestamp when the state phase was granted. |
| `actor_type` | VARCHAR | The trigger source (Candidate, Recruiter, System). |

### `offers`
| Column | Type | Description |
|--------|------|-------------|
| `offer_id` | UUID (PK) | Unique identifier for compensation proposal. |
| `application_id` | UUID (FK) | Tied application. |
| `offer_ts` | TIMESTAMP | Timestamp of proposal matching the `OFFER` stage event. |
| `decision` | VARCHAR | Current resolution state of the offer (ACCEPTED, DECLINED, EXPIRED). |
| `comp_band` | VARCHAR | Financial band classification for the proposal. |

### `hires`
| Column | Type | Description |
|--------|------|-------------|
| `hire_id` | UUID (PK) | Unique identifier for employee onboarding instantiation. |
| `application_id` | UUID (FK) | Associated successful application flow. |
| `hired_ts` | TIMESTAMP | Timestamp matching `HIRED` stage event upon verbal acceptance / signature. |
| `start_date` | DATE | Expected official day 1 orientation date. |
