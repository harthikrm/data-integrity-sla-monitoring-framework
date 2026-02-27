# src/distributions.py
import numpy as np
from datetime import timedelta
import random

def sample_truncated_normal(mean: float, std_dev: float, min_val: float = 0.1) -> float:
    """
    Samples from a normal distribution but ensures the value is at least min_val.
    Used to ensure durations are strictly positive.
    """
    val = np.random.normal(mean, std_dev)
    while val < min_val:
        val = np.random.normal(mean, std_dev)
    return val

def add_business_days(start_date, days_to_add):
    """
    Approximation function to add days, ignoring exact business logic for simplicity 
    but converting a float days duration into a bounded timedelta.
    """
    return start_date + timedelta(days=days_to_add)

def weighted_choice(choices_dict):
    """
    Given a dictionary of {choice: probability}, returns a single choice.
    Example: {"REJECTED": 0.7, "WITHDRAWN": 0.3} -> "REJECTED"
    """
    choices = list(choices_dict.keys())
    weights = list(choices_dict.values())
    return random.choices(choices, weights=weights, k=1)[0]
