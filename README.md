# AI-Based Credit Risk Assessment and Loan Approval System (Java Full Stack)

Spring Boot + MySQL + HTML/CSS/JS implementation scaffold for an AI-driven loan approval workflow, based on the paper in `Documentation/systems-13-00112.pdf`.

## What is implemented

- End-to-end loan workflow:
  - Applicant creation
  - Loan application creation/submission
  - AI risk scoring (`riskScore`, `defaultProbability`, `riskBand`, recommendation, reasons)
  - Loan decision with override reason enforcement
  - Audit logging
- Admin/ML operations:
  - Dataset import/profile endpoint (Lending Club CSV path)
  - Training run orchestration (`BASELINE`, `HSFSFOA`, `ISSA_XGBOOST`)
  - Model registry, promote/retire
  - Metrics summary and decision outcome reports
- Security:
  - JWT access token + refresh token
  - Seeded admin user
- Frontend:
  - Login, dashboard, applications queue/forms, application detail (score/decision), admin page
- Dataset bootstrap:
  - Generates a project-local synthetic Lending Club-format CSV (`data/lending_club_synthetic.csv`) if missing
  - Auto-imports the dataset on startup (idempotent via file fingerprint)
- Tests:
  - Preprocessing rules (paper mappings + leakage exclusions)
  - Decision policy thresholds/hard rules
  - Auth API login/me integration test (Spring Boot + H2 + Flyway)

## Important implementation note (ML runtime)

The project includes **paper-aligned Java scaffolding** for:
- `HSFSFOA` feature selection behavior (chi-square initialization, greedy local seeding, adaptive global seeding)
- `Improved SSA` hyperparameter optimization (Tent init, sine-cosine, reverse learning, Cauchy mutation)

For portability and immediate execution, the current runtime scoring and training artifact generation use a **heuristic XGBoost-compatible stub** instead of native `xgboost4j`. The interfaces and admin/training flow are in place so you can swap in real `xgboost4j` training/scoring next.

## Dataset bootstrap (new default)

On startup, the app now:
1. Checks for `data/lending_club_synthetic.csv`
2. Generates a synthetic Lending Club-format CSV if missing
3. Auto-imports it through the same dataset import pipeline
4. Skips duplicate imports on future startups if the file content is unchanged

You can disable this with:

```bash
DATASET_BOOTSTRAP_ENABLED=false mvn spring-boot:run
```

## Tech stack

- Java 17 (compatible with this environment; plan targets Java 21)
- Spring Boot 3.3.x
- Spring Web, Validation, Data JPA, Security
- MySQL 8 + Flyway
- H2 (tests)
- OpenAPI (springdoc)
- HTML/CSS/JS + Chart.js (frontend)

## Quick start (Docker)

```bash
mvn -DskipTests package
docker compose up --build
```

Open:
- UI: `http://localhost:8080/login.html`
- Swagger UI: `http://localhost:8080/swagger-ui.html`

Seeded admin credentials:
- Email: `admin@creditrisk.local`
- Password: `Admin@123`

## Quick start (STS / local IDE)

Run `CreditRiskApplication` directly from STS or IntelliJ.

The default local runtime now uses embedded H2, so it starts without Docker or a pre-created MySQL user.
This is the easiest path for IDE development and for verifying the project after import.

## Quick start (local app + MySQL)

1. Start MySQL (recommended: `docker compose up -d mysql`, exposed on host port `3307`)
2. Run app with MySQL overrides:

```bash
DB_URL='jdbc:mysql://localhost:3307/credit_risk?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC' \
DB_USERNAME=creditrisk \
DB_PASSWORD=creditrisk \
mvn spring-boot:run
```

The default no-env startup path uses embedded H2.
If you want MySQL instead, override `DB_URL`, `DB_USERNAME`, and `DB_PASSWORD`, or use the provided start scripts.
Startup dataset bootstrap is enabled by default and uses `./data/lending_club_synthetic.csv`.

If you see `Access denied for user 'creditrisk'` while using Docker MySQL, your existing MySQL volume was likely initialized with different credentials. Reset it with:

```bash
docker compose down -v
docker compose up -d mysql
```

## Demo flow

1. Login at `/login.html`
2. Go to `/applications.html`
3. Create an applicant
4. Create a loan application using that applicant ID
5. Open the application detail page
6. Click `Submit`, then `Run AI Score`
7. Submit a decision (override reason required if changing the AI recommendation)
8. View metrics and models on `/admin.html`

## Dataset import and training (admin page)

- Dataset import requires a server-local CSV path (the project now auto-generates/imports `./data/lending_club_synthetic.csv` by default)
- You can still manually import a real Lending Club CSV from the Admin page by providing its absolute path
- Example training sequence:
  1. Import dataset
  2. Copy generated `datasetVersion` into training form
  3. Run `BASELINE`
  4. Run `HSFSFOA`
  5. Run `ISSA_XGBOOST`
  6. Promote the best model

## Project structure (high level)

- `src/main/java/com/creditrisk/auth` - JWT auth/refresh flow
- `src/main/java/com/creditrisk/applicant` - applicant APIs
- `src/main/java/com/creditrisk/loan` - loan application APIs/workflow
- `src/main/java/com/creditrisk/decision` - policy engine + decision APIs
- `src/main/java/com/creditrisk/audit` - audit logging
- `src/main/java/com/creditrisk/admin` - dataset/training/model admin APIs
- `src/main/java/com/creditrisk/ml/*` - preprocessing, feature selection, optimization, training, scoring abstractions + implementations
- `src/main/resources/static` - frontend pages and JS
- `src/main/resources/db/migration` - Flyway schema

## Next step to make ML fully paper-faithful in runtime

1. Integrate `xgboost4j` native dependencies and real booster serialization
2. Replace `HeuristicRiskModelTrainer` with actual XGBoost training
3. Replace `ArtifactHeuristicRiskScorer` with XGBoost inference
4. Use real CV metrics from training instead of generated metrics in the stub trainer

## Run helpers

Linux/macOS (`bash`):

```bash
./start.sh --db-user creditrisk --db-pass creditrisk
```

Windows (PowerShell):

```powershell
.\start.ps1 --db-user creditrisk --db-pass creditrisk
```

Windows (CMD wrapper):

```bat
start.bat --db-user creditrisk --db-pass creditrisk
```

If port `8080` is busy, use:

```bash
SERVER_PORT=8081 ./start.sh --db-user creditrisk --db-pass creditrisk
```

```powershell
$env:SERVER_PORT='8081'; .\start.ps1 --db-user creditrisk --db-pass creditrisk
```

Disable startup dataset bootstrap if needed:

```bash
./start.sh --no-dataset-bootstrap --db-user creditrisk --db-pass creditrisk
```

```powershell
.\start.ps1 --no-dataset-bootstrap --db-user creditrisk --db-pass creditrisk
```

Check imported dataset records in Docker MySQL:

```bash
docker compose exec mysql mysql -uroot -proot -D credit_risk -e \
"SELECT id, source_name, source_path, dataset_version, status, trigger_mode, rows_read, rows_loaded, started_at FROM dataset_ingestion_jobs ORDER BY id DESC;"
```




## Step-by-step explanation of the entire project
1. App startup and configuration

Spring Boot starts from CreditRiskApplication.java.
Core config is read from application.yml.
Security, JWT properties, and dataset bootstrap properties are wired in AppConfig.java.
Flyway runs DB migrations from src/main/resources/db/migration.

2. Database schema initialization

Base schema is created by V1__init_schema.sql.
Dataset import metadata (fingerprint / trigger mode) is added by V2__dataset_ingestion_metadata.sql (line 1).

3. Seed data and bootstrap runners

Admin user is seeded by SeedDataRunner.java.
Demo model is seeded/promoted by DemoModelSeedRunner.java.
Dataset bootstrap runs after those via DatasetBootstrapRunner.java (line 17).

4. Dataset bootstrap (new default behavior)

The runner reads settings from app.dataset.bootstrap in application.yml (line 42).
It checks for lending_club_synthetic.csv.
If missing, it generates a synthetic Lending Club-format CSV using LendingClubSyntheticDatasetGenerator.java (line 20).
It computes a SHA-256 fingerprint and checks whether the same file was already imported.
If already imported, it skips.
If not, it imports through DatasetImportService.java (line 45).

5. Dataset import pipeline

Manual import API is POST /api/v1/admin/datasets/import in AdminController.java (line 28).
Request payload is sourcePath + optional sourceName (DatasetImportRequest.java).
Import service saves a dataset_ingestion_jobs record, profiles the CSV, and stores counts/version/fingerprint/trigger mode (DatasetImportService.java (line 66)).
Latest dataset summary API is GET /api/v1/admin/datasets/latest in AdminController.java (line 34).

6. Preprocessing (paper-aligned, leakage-safe)

CSV preprocessing is implemented in LendingClubFeaturePreprocessor.java.
It removes leakage/post-loan fields (payment-related columns).
It maps loan_status into binary labels (good/bad).
It prepares metadata such as selected columns, dropped columns, missing counts, and label distribution.
Output is a PreparedDataset (PreparedDataset.java).

7. Feature selection and optimizer scaffolding

Baseline and HSFSFOA-like feature selection are in HsfsfoaFeatureSelector.java.
Improved SSA-like hyperparameter optimization is in ImprovedSsaHyperparameterOptimizer.java.
These are currently scaffolded/heuristic implementations to support end-to-end flow.

8. Model training (current runtime behavior)

Training orchestration is handled by TrainingOrchestratorService.java.
It loads the dataset by datasetVersion, preprocesses it, runs feature selection and (optionally) optimization.
It trains a heuristic stub model via HeuristicRiskModelTrainer.java.
It registers the trained model artifact in the model registry.

9. Model registry and artifacts

Models are stored in DB (ml_models) and on disk (model-artifacts path).
Registry services live in src/main/java/com/creditrisk/ml/model.
Active model promotion/retirement APIs are under the admin controller (/api/v1/admin/models/...).

10. Applicant and loan application workflow

Applicant CRUD is implemented in src/main/java/com/creditrisk/applicant.
Loan application creation/submission is implemented in src/main/java/com/creditrisk/loan.
When you create an applicant, the API returns ApplicantResponse with id (this is your applicantId for the loan form).

11. Risk scoring flow

Scoring API is in RiskScoringController.java.
RiskScoringService loads the active model, builds the feature snapshot, and computes defaultProbability, riskScore, and recommendation.
Current inference uses a heuristic artifact scorer (ArtifactHeuristicRiskScorer.java), not xgboost4j yet.
Each scoring action persists a risk_assessments record and audit log.

12. Decision policy and loan decisions

Policy engine applies thresholds and hard rules in src/main/java/com/creditrisk/decision.
It maps probability to recommendation (AUTO_APPROVE, MANUAL_REVIEW, AUTO_DECLINE) and risk band.
Loan officers can override decisions with reasons; decisions are persisted and audited.

13. Authentication and authorization

JWT login/refresh/logout/me endpoints are under src/main/java/com/creditrisk/auth.
Security configuration is in SecurityConfig.java.
Roles like ADMIN, LOAN_OFFICER, RISK_ANALYST gate APIs.

14. Frontend (vanilla HTML/CSS/JS)

Pages are in src/main/resources/static.
Admin page admin.html now shows dataset import status and auto-fills datasetVersion after startup import (admin.js (line 131)).
Applications page handles applicant creation, loan creation, queue listing, and links to detail page.
UI communicates with REST APIs using fetch.

15. Local/Docker run flow

start.sh (Linux/macOS) and start.ps1 / start.bat (Windows) start Docker MySQL (optional), export env vars, and run mvn spring-boot:run.
Docker Compose also supports running the app container with mounted ./data and ./model-artifacts (docker-compose.yml).
The startup scripts pass dataset bootstrap env vars so the synthetic dataset is generated/imported automatically.

16. What happens on first run vs next run

First run:
DB migrations execute.
Synthetic CSV is generated.
Dataset is imported and recorded as STARTUP_BOOTSTRAP.
Next run:
Same CSV fingerprint is detected.
Import is skipped (idempotent).
Admin page still reads latest dataset summary and shows the version.

17. Current ML limitation (important)

The training/scoring pipeline is structurally ready, but runtime ML is a heuristic stub.
To make it fully paper-faithful, replace the trainer/scorer with xgboost4j in:
HeuristicRiskModelTrainer.java
ArtifactHeuristicRiskScorer.java
