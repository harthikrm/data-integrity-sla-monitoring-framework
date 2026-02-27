# Enterprise ATS Data Integrity & SLA Monitoring Framework

A People Systems engineering project designed to simulate an end-to-end Enterprise Applicant Tracking System (ATS), rigorously test its data quality via SQL exception models, and power an executive Power BI dashboard.

This framework was built with an "engineering first" mindset—focusing on scalable data models, trustworthiness via rigorous backend data tests (exceptions), SLA monitoring logic for operational efficiency, and simplified downstream reporting capabilities for non-technical audiences.

## Architecture & Data Flow

1. **Synthetic Generation System**: Python (`src/generate_synthetic_ats.py`) creates tens of thousands of event-log-driven ATS records built on constrained probability transitions (Applied $\rightarrow$ Screen $\rightarrow$ Onsite $\rightarrow$ Offer $\rightarrow$ Hired/Rejected/Withdrawn).
2. **Anomaly Injection**: To prove data validation robustness, the generator mathematically injects controlled permutations of corruptions: duplicate applications, missing IDs, timestamp drift (negative durations, stage order violations), and orphan integration events.
3. **PostgreSQL Loading Pipeline**: Bulk load via standard PSQL `\copy` routines (`sql/02_load.sql`).
4. **Relational Reporting System**: Pivots event chronologies using advanced windowed bounds (`v_application_lifecycle` & `v_funnel_metrics`).
5. **Data Tests Layer**: A rigorous SQL validation `UNION ALL` suite tracking anomaly exception volume over time (`v_data_exceptions`).
6. **SLA Monitoring**: Transition compliance constraints matching HR operational targets against actual elapsed timestamps (`v_sla_breaches`).

## Setup Instructions

### 1. Generating the Data
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python src/generate_synthetic_ats.py
```
This will cleanly deposit realistic ATS `.csv` representations inside `/data/raw`.

### 2. Loading the Postgres Schema
If running locally against a configured instance:
```bash
psql -d <your_db> -f sql/01_schema.sql
psql -d <your_db> -f sql/02_load.sql
psql -d <your_db> -f sql/03_reporting_views.sql
psql -d <your_db> -f sql/04_data_tests.sql
psql -d <your_db> -f sql/05_sla.sql
psql -d <your_db> -f sql/06_metrics.sql
```

### 3. Power BI Integration
Models are structured to plug cleanly into Power BI via the fast-access tables provisioned in `sql/06_metrics.sql`:
* `mart_application_lifecycle`
* `mart_data_exceptions`
* `mart_sla_breaches`

## Technical & Operational Focus
* **Discoverability & Trust**: Refer to `docs/data_dictionary.md` and `docs/metric_definitions.md` to map reporting formulas cleanly.
* **Non-Technical Communication**: Stakeholders view raw throughput logic isolated cleanly from backend data engineering validation complexity.
