# Metric Definitions

A single source of truth for metric logic materialized in `v_funnel_metrics` and `v_application_lifecycle`.

## Funnel & Core Conversions
These metrics represent workflow progression drop-offs and yield rates.

* **Applied count**: The total number of valid applications assigned a given scope.
* **Screened count**: Total applications progressing to technical screen or hiring manager review.
* **Onsite count**: Total applications extended panel/onsite invitations.
* **Offered count**: Total applications extended formal compensation proposals.
* **Hired count**: Total applications successfully resolving in a `HIRED` state.

### Yield Rates
* **Applied to Screen Rate**: `screen_count / applied_count` - measures resume parsing/sourcing quality.
* **Screen to Onsite Rate**: `onsite_count / screen_count` - measures initial screening pass rate.
* **Onsite to Offer Rate**: `offered_count / onsite_count` - measures panel interview alignment.
* **Offer Acceptance Rate (OAR)** / **Offer to Hire Rate**: `hired_count / offered_count` - measures compensation competitiveness and closing efficacy.

## Durations & Timelines
Calculated via `EXTRACT(EPOCH FROM (end - start)) / 86400.0`. Validated through SQL data tests to prevent negative drifts.

* **Time to Hire (TTH)**: The duration from `applied_ts` to `hired_ts`. Only computed stringently for successful `HIRED` end states.
* **Time in Stage**: Continuous delay blocks computed between respective progression triggers:
  * `days_applied_to_screen`
  * `days_screen_to_onsite`
  * `days_onsite_to_offer`
  * `days_offer_to_decision`

## Data Quality & SLA Core
* **Exception Rate**: `count(distinct exception applications) / total applications`. Indicates percentage of the reporting funnel tainted by upstream systemic gaps.
* **SLA Compliance Rate**: `1.0 - (breaches / total_transition_cases)`. Ensures HR service level accountability directly inside dashboards.
