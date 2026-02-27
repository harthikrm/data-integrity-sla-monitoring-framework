# Validation Rules

This system enforces rigorous data testing pipelines. The application funnel is verified nightly via SQL-based data tests executing `UNION ALL` validation suites against the raw ATS exports. Any failure inserts an exception record into `v_data_exceptions`.

## Expected Exceptions

### `ORPHAN_STAGE_EVENT`
* **Why it matters**: A system or recruiter triggered an event log progression on an `application_id` that does not exist in the source-of-truth HRIS application ledger. This indicates integration ghosts or delayed source replication.
* **Severity**: `HIGH`
* **SQL Logic**: `WHERE application_id NOT IN applications` over the `stage_events_raw` table (which is deliberately not strictly FK constrained to permit these catch tests).

### `DUPLICATE_APPLICATION`
* **Why it matters**: Inflates top-of-funnel KPIs. Candidates spamming or accidentally double-submitting an application to the exact same requisition within `< 30 days` artificially depresses downstream conversion rates (Applied-To-Screen).
* **Severity**: `MED`
* **SQL Logic**: Self-join on `applications` ensuring unique `application_id`s share `candidate_id` and `req_id` tightly clustered temporally.

### `MISSING_RECRUITER`
* **Why it matters**: Violates tracking hygiene. Unassigned applications linger indefinitely and skew SLA compliance calculations for team bandwidth analytics.
* **Severity**: `LOW`
* **SQL Logic**: `WHERE recruiter_id IS NULL`.

### `STAGE_ORDER_VIOLATION`
* **Why it matters**: Represents upstream process/data-entry gaps. For instance, a recruiter back-dating an Onsite interview before a Screen interview breaks pivot duration bounds.
* **Severity**: `HIGH`
* **SQL Logic**: Timestamp precedence check constraints (e.g., `screen_ts > onsite_ts`).

### `NEGATIVE_DURATION`
* **Why it matters**: Corrupts DAX aggregation and arithmetic on PowerBI dashboard models. Durations in an event loop must move forward in time.
* **Severity**: `HIGH`
* **SQL Logic**: Any derived `EXTRACT(EPOCH)` yielding `< 0`.

### `MULTIPLE_TERMINAL_EVENTS`
* **Why it matters**: An application cannot concurrently resolve as `HIRED` and `REJECTED`, or `HIRED` and `WITHDRAWN`. It skews the final outcome denominators.
* **Severity**: `HIGH`
* **SQL Logic**: Multiple non-null checks across terminal statuses in `v_application_lifecycle`.

### `OFFER_BEFORE_ONSITE`
* **Why it matters**: A process hygiene red-flag. Indicates offers are being generated out-of-band without passing through required compliant technical checks/panels.
* **Severity**: `MED`
* **SQL Logic**: Temporal comparison of `offer_ts < onsite_ts` on joined `offers` view.
