# src/config.py
from datetime import datetime

# Overall Scale
SCALE = {
    "n_candidates": 10000,
    "n_requisitions": 120,
    "mean_apps_per_candidate": 1.2,
    "n_recruiters": 35
}

# Date constraints
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2023, 12, 31)

# Stages
STAGES = {
    "APPLIED": "APPLIED",
    "SCREEN": "SCREEN",
    "ONSITE": "ONSITE",
    "OFFER": "OFFER",
    "HIRED": "HIRED",
    "REJECTED": "REJECTED",
    "WITHDRAWN": "WITHDRAWN"
}

# Transition Probabilities (forward progression)
TRANSITION_PROBS = {
    "APPLIED_TO_SCREEN": 0.40,
    "SCREEN_TO_ONSITE": 0.22,
    "ONSITE_TO_OFFER": 0.35,
    "OFFER_TO_HIRED": 0.72
}

# Terminal state probabilities when falling out at a specific stage
# For example, if candidate doesn't make it to screen, they end up REJECTED or WITHDRAWN
TERMINAL_PROBS = {
    "AFTER_APPLIED": {"REJECTED": 0.70, "WITHDRAWN": 0.30},
    "AFTER_SCREEN": {"REJECTED": 0.80, "WITHDRAWN": 0.20},
    "AFTER_ONSITE": {"REJECTED": 0.90, "WITHDRAWN": 0.10},
    "AFTER_OFFER": {"DECLINED": 0.70, "EXPIRED": 0.30}  # Note: declined/expired live in the offers table decision, not the terminal stage
}

# Stage Time Distributions (days): (mean, std_dev) for truncated normal distribution
STAGE_DURATIONS = {
    "APPLIED_TO_SCREEN": (2.5, 1.5),
    "SCREEN_TO_ONSITE": (7.0, 4.0),
    "ONSITE_TO_OFFER": (5.0, 3.0),
    "OFFER_TO_DECISION": (4.0, 2.0),
}

# SLA Thresholds (days)
SLA_THRESHOLDS = {
    "APPLIED_TO_SCREEN": 3,
    "SCREEN_TO_ONSITE": 10,
    "ONSITE_TO_OFFER": 7,
    "OFFER_TO_DECISION": 5
}

# Anomaly Injection Rates
ANOMALY_RATES = {
    "duplicate_applications": 0.05,
    "missing_recruiter_id": 0.03,
    "stage_order_violations": 0.02,
    "negative_duration": 0.01,
    "orphan_events": 0.01,
    "offer_before_onsite": 0.01
}
