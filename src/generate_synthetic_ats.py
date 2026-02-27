# src/generate_synthetic_ats.py
import os
import random
import uuid
import pandas as pd
import numpy as np
from datetime import timedelta
from faker import Faker
from config import SCALE, START_DATE, END_DATE, STAGES, TRANSITION_PROBS, TERMINAL_PROBS, STAGE_DURATIONS, ANOMALY_RATES
from distributions import sample_truncated_normal, add_business_days, weighted_choice

fake = Faker()

def generate_random_date(start, end):
    delta = end - start
    random_days = random.randrange(delta.days)
    return start + timedelta(days=random_days)

def make_requisitions():
    reqs = []
    orgs = ["Engineering", "Manufacturing", "IT", "HR"]
    job_families = ["Data", "Software", "Manufacturing", "Operations"]
    levels = ["IC1", "IC2", "IC3", "IC4", "IC5"]
    
    for _ in range(SCALE["n_requisitions"]):
        open_date = generate_random_date(START_DATE, END_DATE - timedelta(days=60))
        # 20% of reqs are still open
        close_date = None if random.random() < 0.2 else generate_random_date(open_date + timedelta(days=14), END_DATE)
        reqs.append({
            "req_id": str(uuid.uuid4()),
            "org": random.choice(orgs),
            "job_family": random.choice(job_families),
            "level": random.choice(levels),
            "open_date": open_date,
            "close_date": close_date
        })
    return pd.DataFrame(reqs)

def make_candidates():
    candidates = []
    sources = ["LinkedIn", "Referral", "CareerSite", "Agency"]
    locations = ["Austin", "Dallas", "Fremont", "Remote", "Other"]
    
    for _ in range(SCALE["n_candidates"]):
        candidates.append({
            "candidate_id": str(uuid.uuid4()),
            "created_at": generate_random_date(START_DATE, END_DATE),
            "source": random.choice(sources),
            "location": random.choice(locations),
            "years_experience": random.randint(0, 50),
            "email_hash": fake.sha256()[:16]
        })
    return pd.DataFrame(candidates)

def make_applications(candidates_df, reqs_df):
    applications = []
    recruiters = [str(uuid.uuid4()) for _ in range(SCALE["n_recruiters"])]
    
    cand_ids = candidates_df["candidate_id"].tolist()
    req_list = reqs_df.to_dict('records')
    
    for cand_id in cand_ids:
        # Sample number of applications: 1, 2, or 3
        # Weighting towards 1 to get mean ~ 1.2
        num_apps = random.choices([1, 2, 3], weights=[0.85, 0.10, 0.05], k=1)[0]
        
        for _ in range(num_apps):
            req = random.choice(req_list)
            # Apply date within req open bounds (or simply after open if no close)
            close = req["close_date"] if pd.notnull(req["close_date"]) else END_DATE
            apply_ts = generate_random_date(req["open_date"], close)
            
            recruiter_id = random.choice(recruiters)
            
            applications.append({
                "application_id": str(uuid.uuid4()),
                "candidate_id": cand_id,
                "req_id": req["req_id"],
                "apply_ts": apply_ts,
                "recruiter_id": recruiter_id
            })
    
    return pd.DataFrame(applications)

def make_stage_events_and_offers(apps_df):
    events = []
    offers = []
    hires = []
    
    for _, app in apps_df.iterrows():
        app_id = app["application_id"]
        current_ts = app["apply_ts"]
        
        # 1. APPLIED
        events.append({
            "event_id": str(uuid.uuid4()),
            "application_id": app_id,
            "stage": STAGES["APPLIED"],
            "stage_ts": current_ts,
            "actor_type": "Candidate"
        })
        
        # SCREEN?
        if random.random() < TRANSITION_PROBS["APPLIED_TO_SCREEN"]:
            dur = sample_truncated_normal(*STAGE_DURATIONS["APPLIED_TO_SCREEN"])
            current_ts = add_business_days(current_ts, dur)
            events.append({
                "event_id": str(uuid.uuid4()), "application_id": app_id, 
                "stage": STAGES["SCREEN"], "stage_ts": current_ts, "actor_type": "Recruiter"
            })
            
            # ONSITE?
            if random.random() < TRANSITION_PROBS["SCREEN_TO_ONSITE"]:
                dur = sample_truncated_normal(*STAGE_DURATIONS["SCREEN_TO_ONSITE"])
                current_ts = add_business_days(current_ts, dur)
                events.append({
                    "event_id": str(uuid.uuid4()), "application_id": app_id, 
                    "stage": STAGES["ONSITE"], "stage_ts": current_ts, "actor_type": "Recruiter"
                })
                
                # OFFER?
                if random.random() < TRANSITION_PROBS["ONSITE_TO_OFFER"]:
                    dur = sample_truncated_normal(*STAGE_DURATIONS["ONSITE_TO_OFFER"])
                    current_ts = add_business_days(current_ts, dur)
                    events.append({
                        "event_id": str(uuid.uuid4()), "application_id": app_id, 
                        "stage": STAGES["OFFER"], "stage_ts": current_ts, "actor_type": "Recruiter"
                    })
                    
                    # OFFER DECISION (HIRE OR DECLINED/EXPIRED)
                    dur_decision = sample_truncated_normal(*STAGE_DURATIONS["OFFER_TO_DECISION"])
                    decision_ts = add_business_days(current_ts, dur_decision)
                    
                    if random.random() < TRANSITION_PROBS["OFFER_TO_HIRED"]:
                        events.append({
                            "event_id": str(uuid.uuid4()), "application_id": app_id, 
                            "stage": STAGES["HIRED"], "stage_ts": decision_ts, "actor_type": "Recruiter"
                        })
                        offers.append({
                            "offer_id": str(uuid.uuid4()), "application_id": app_id,
                            "offer_ts": current_ts, "decision": "ACCEPTED", "comp_band": random.choice(["A", "B", "C"])
                        })
                        hires.append({
                            "hire_id": str(uuid.uuid4()), "application_id": app_id,
                            "hired_ts": decision_ts, "start_date": add_business_days(decision_ts, random.randint(14, 45)).date()
                        })
                    else:
                        decision = weighted_choice(TERMINAL_PROBS["AFTER_OFFER"])
                        offers.append({
                            "offer_id": str(uuid.uuid4()), "application_id": app_id,
                            "offer_ts": current_ts, "decision": decision, "comp_band": random.choice(["A", "B", "C"])
                        })
                        # Also rejected in ATS
                        events.append({
                            "event_id": str(uuid.uuid4()), "application_id": app_id, 
                            "stage": STAGES["REJECTED"], "stage_ts": decision_ts, "actor_type": "System"
                        })
                else:
                    # After Onsite -> Rejected or Withdrawn
                    term = weighted_choice(TERMINAL_PROBS["AFTER_ONSITE"])
                    end_ts = add_business_days(current_ts, sample_truncated_normal(3, 2))
                    events.append({
                        "event_id": str(uuid.uuid4()), "application_id": app_id, 
                        "stage": term, "stage_ts": end_ts, "actor_type": "System" if term == "REJECTED" else "Candidate"
                    })
            else:
                # After Screen -> Rejected or Withdrawn
                term = weighted_choice(TERMINAL_PROBS["AFTER_SCREEN"])
                end_ts = add_business_days(current_ts, sample_truncated_normal(5, 3))
                events.append({
                    "event_id": str(uuid.uuid4()), "application_id": app_id, 
                    "stage": term, "stage_ts": end_ts, "actor_type": "System" if term == "REJECTED" else "Candidate"
                })
        else:
            # After Applied -> Rejected or Withdrawn
            term = weighted_choice(TERMINAL_PROBS["AFTER_APPLIED"])
            end_ts = add_business_days(current_ts, sample_truncated_normal(7, 4))
            events.append({
                "event_id": str(uuid.uuid4()), "application_id": app_id, 
                "stage": term, "stage_ts": end_ts, "actor_type": "System" if term == "REJECTED" else "Candidate"
            })
            
    return pd.DataFrame(events), pd.DataFrame(offers), pd.DataFrame(hires)


def inject_anomalies(apps, events, offers, hires):
    print("Injecting anomalies...")
    
    # Missing Recruiter
    n_missing = int(len(apps) * ANOMALY_RATES["missing_recruiter_id"])
    idx_missing = np.random.choice(apps.index, n_missing, replace=False)
    apps.loc[idx_missing, "recruiter_id"] = None
    
    # Duplicates
    n_dupes = int(len(apps) * ANOMALY_RATES["duplicate_applications"])
    dupes_source = apps.sample(n=n_dupes).copy()
    dupes_source["application_id"] = [str(uuid.uuid4()) for _ in range(n_dupes)]
    # Tweak apply_ts slightly so it looks like they reapplied structurally distinct
    dupes_source["apply_ts"] = dupes_source["apply_ts"] + pd.to_timedelta(np.arange(1, n_dupes + 1), unit='s') + pd.to_timedelta(2, unit='D')
    apps = pd.concat([apps, dupes_source], ignore_index=True)
    
    # Stage Order Violations (Swap Screen and Onsite)
    n_order = int(len(apps) * ANOMALY_RATES["stage_order_violations"])
    apps_order = apps.sample(n=n_order)
    for app_id in apps_order["application_id"]:
        app_events = events[events["application_id"] == app_id]
        if "SCREEN" in app_events["stage"].values and "ONSITE" in app_events["stage"].values:
            idx_screen = events[(events["application_id"] == app_id) & (events["stage"] == "SCREEN")].index[0]
            idx_onsite = events[(events["application_id"] == app_id) & (events["stage"] == "ONSITE")].index[0]
            # Swap timestamps
            ts_screen = events.at[idx_screen, "stage_ts"]
            events.at[idx_screen, "stage_ts"] = events.at[idx_onsite, "stage_ts"]
            events.at[idx_onsite, "stage_ts"] = ts_screen
            
    # Negative Duration (Subtract 10 days from an onsite or offer stage)
    n_neg = int(len(apps) * ANOMALY_RATES["negative_duration"])
    apps_neg = apps.sample(n=n_neg)
    for app_id in apps_neg["application_id"]:
        app_events = events[events["application_id"] == app_id]
        for stg in ["ONSITE", "OFFER", "HIRED"]:
            if stg in app_events["stage"].values:
                idx = events[(events["application_id"] == app_id) & (events["stage"] == stg)].index[0]
                events.at[idx, "stage_ts"] = events.at[idx, "stage_ts"] - pd.to_timedelta(10, unit='D')
                break

    # Orphan Events
    n_orphans = int(len(events) * ANOMALY_RATES["orphan_events"])
    orphan_events = []
    for _ in range(n_orphans):
        orphan_events.append({
            "event_id": str(uuid.uuid4()),
            "application_id": str(uuid.uuid4()), # Non-existent app ID
            "stage": random.choice(list(STAGES.values())),
            "stage_ts": generate_random_date(START_DATE, END_DATE),
            "actor_type": "System"
        })
    events = pd.concat([events, pd.DataFrame(orphan_events)], ignore_index=True)
    
    # Offer Before Onsite
    n_obo = int(len(offers) * ANOMALY_RATES["offer_before_onsite"])
    offers_obo = offers.sample(n=n_obo)
    for offer_id in offers_obo["offer_id"]:
        app_id = offers_obo[offers_obo["offer_id"] == offer_id]["application_id"].values[0]
        idx = offers[offers["offer_id"] == offer_id].index[0]
        # set offer exactly 10 days earlier
        offers.at[idx, "offer_ts"] = offers.at[idx, "offer_ts"] - pd.to_timedelta(10, unit='D')
        # Also sync this back to the event log!
        try:
            e_idx = events[(events["application_id"] == app_id) & (events["stage"] == "OFFER")].index[0]
            events.at[e_idx, "stage_ts"] = events.at[e_idx, "stage_ts"] - pd.to_timedelta(10, unit='D')
        except IndexError:
            pass

    return apps, events, offers, hires


def main():
    print("Setting random seed...")
    random.seed(42)
    np.random.seed(42)
    Faker.seed(42)
    
    print("Generating dimensions...")
    reqs = make_requisitions()
    cands = make_candidates()
    
    print("Generating applications...")
    apps = make_applications(cands, reqs)
    
    print(f"Generated {len(apps)} initial applications.")
    
    print("Simulating event logs...")
    events, offers, hires = make_stage_events_and_offers(apps)
    
    # Inject Anomalies
    apps, events, offers, hires = inject_anomalies(apps, events, offers, hires)
    
    # Write to CSV
    print("Writing CSV files...")
    os.makedirs("../data/raw", exist_ok=True)
    reqs.to_csv("../data/raw/requisitions.csv", index=False)
    cands.to_csv("../data/raw/candidates.csv", index=False)
    apps.to_csv("../data/raw/applications.csv", index=False)
    events.to_csv("../data/raw/stage_events_raw.csv", index=False)
    offers.to_csv("../data/raw/offers.csv", index=False)
    hires.to_csv("../data/raw/hires.csv", index=False)
    
    print("Generation complete!")
    print(f"Final Counts:\n  Candidates: {len(cands)}\n  Requisitions: {len(reqs)}\n  Applications: {len(apps)}\n  Events: {len(events)}\n  Offers: {len(offers)}\n  Hires: {len(hires)}")

if __name__ == "__main__":
    main()
