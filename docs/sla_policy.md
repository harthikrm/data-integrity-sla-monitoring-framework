# SLA Framework & Policies

To surface bottlenecks and systemic delays across hiring flows, the data ingestion pipeline overlays a Service Level Agreement (SLA) monitoring system measured via `v_sla_transitions`, `v_sla_breaches`, and aggregated in `v_sla_compliance_summary`.

## Defined Limits
Business policy determines target throughput times. Delays crossing these duration thresholds are flagged as `is_breach = TRUE`.

| Transition Loop | Expected SLA (Max Days) | Operational Context |
|-----------------|-------------------------|---------------------|
| Applied $\rightarrow$ Screen | `3 days` | Initial resume review and sourcer outreach bounding. |
| Screen $\rightarrow$ Onsite | `10 days` | Panel scheduling, HM syncs, and candidate availability lag. |
| Onsite $\rightarrow$ Offer | `7 days` | Exec/Compensation committee finalization and package derivations. |
| Offer $\rightarrow$ Decision | `5 days` | Candidate negotiation buffer ending in Accepted, Declined, or Expired terminal states. |

## Dashboard Aggregation
Recruiter and Org-level efficiency is mapped dynamically from the event logs. Breaches are reported dynamically against these targets in Power BI, displaying compliance rates globally down to the individual recruiter contributor level to enable fast operational triage and discoverability.
