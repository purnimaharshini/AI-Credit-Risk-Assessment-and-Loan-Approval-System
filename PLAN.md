# AI-Based Credit Risk Assessment and Loan Approval System (Java Full Stack) — Implementation Plan

## Summary
                                                                                                                                                                                                - Build a capstone-grade, end-to-end loan approval system using `Spring Boot + MySQL + HTML/CSS/JS` with a paper-aligned ML pipeline based on `Documentation/systems-13-00112.pdf`.
                                                                                                                                                                                                - Follow a phased, paper-first approach:
                                                                                                                                                                                                1. Baseline XGBoost credit risk model.
                                                                                                                                                                                                2. Paper-aligned feature selection (`HSFSFOA` concept: chi-square initialization + adaptive global seeding + greedy local search).
                                                                                                                                                                                                3. Paper-aligned hyperparameter optimization (`improved SSA` for XGBoost).
                                                                                                                                                                                                - Adapt the paper for real loan approval by using **application-time features only** (to avoid data leakage from post-loan repayment fields like `last_pymnt_amnt`).
                                                                                                                                                                                                - Deliver a modular monolith backend (REST APIs + static frontend) with offline training jobs, model versioning, scoring, decision workflow, and audit logs.

## Scope and Success Criteria
- In scope:
1. Applicant and loan application management.
2. AI risk scoring (default probability / risk score).
3. Loan decision workflow (auto-approve / manual review / decline).
4. Admin model training/evaluation screens.
5. Paper-aligned preprocessing and optimization phases.
6. Role-based access, audit trail, Dockerized local deployment.
- Out of scope for MVP:
1. Payment collection/disbursement integration.
2. External bureau API integration.
3. Production-grade MLOps platform (Kubernetes, feature store, drift service).
4. Regulatory-grade explainability (full SHAP engine) beyond reason codes + feature importance.
- Success criteria:
1. End-to-end flow works from application submission to decision issuance.
2. Training pipeline runs on Lending Club-derived dataset and produces a versioned model artifact.
3. Scoring API returns `riskScore`, `riskBand`, `decisionRecommendation`, and top reasons.
4. Optimized XGBoost (SSA phase) outperforms baseline XGBoost on selected evaluation metrics in the same leakage-free dataset split.
5. System deploys locally with `Docker Compose` and documented setup.

## Target Architecture
- Architecture style: **modular monolith**.
- Deployment shape: **single Spring Boot app** serving REST APIs and static frontend, backed by MySQL.
- Components:
1. `web-ui` (vanilla HTML/CSS/JS in Spring static resources).
2. `api` (Spring MVC REST).
3. `domain` (loan workflow, scoring, decisions, audit).
4. `ml-core` (preprocessing, feature selection, training, scoring adapters).
5. `jobs` (dataset import, training, evaluation, model promotion).
6. `mysql` (transactional data + metadata).
7. `model-artifacts` (filesystem path, versioned binaries and metadata JSON).
- Runtime data flow:
1. Applicant submits loan application.
2. Backend validates and stores application.
3. Backend transforms application into model feature vector.
4. Active model scores the vector and returns default probability.
5. Policy engine maps score to risk band and recommended decision.
6. Loan officer finalizes or overrides (with reason).
7. Audit event is recorded.
- Training data flow:
1. Admin imports Lending Club CSV.
2. Preprocessing job applies paper-aligned cleaning/mapping rules.
3. Baseline feature selection/training runs.
4. HSFSFOA phase selects features.
5. Improved SSA optimizes XGBoost hyperparameters.
6. Evaluation job reports metrics and stores artifacts.
7. Admin promotes best model to active.

## Paper-to-System Adaptation (Decision Complete)
- Paper-aligned elements to implement:
1. Chi-square-informed initialization for feature selection.
2. Hybrid forest optimization feature selection behavior (HSFSFOA).
3. Improved SSA with Tent map, sine-cosine discoverer update, reverse learning, Cauchy mutation, greedy update.
4. XGBoost final classifier.
5. Metrics: accuracy, AUC, precision, recall, F1; plus feature-selection fitness `CA + 0.01 * DR`.
- Adaptations required for a real approval system:
1. Exclude post-origination / repayment-history fields from approval model training and runtime scoring.
2. Use a separate “research benchmark mode” only if needed later (not MVP) for strict paper replication.
3. Use time-safe or leakage-safe evaluation splits for deployment decisions.
- Benchmark scope decision:
1. Main implementation in Java for the core pipeline.
2. LightGBM/CatBoost comparisons from the paper are optional and not required in Java MVP.

## Technology Stack
- Backend:
1. `Java 21`
2. `Spring Boot 3.x`
3. `Spring Web`, `Spring Validation`, `Spring Data JPA`, `Spring Security`
4. `Flyway` for DB migrations
5. `MySQL 8.0`
6. `Jackson` for JSON
7. `springdoc-openapi` for API docs
- Frontend:
1. Plain `HTML/CSS/JavaScript`
2. `Fetch API`
3. `Chart.js` for metrics dashboards
4. Static assets served from Spring Boot (`src/main/resources/static`)
- ML/Data (Java):
1. `xgboost4j` for XGBoost training/scoring
2. `Smile` for baseline ML utilities and metrics support
3. `Tablesaw` (or `univocity-parsers` + custom transforms) for CSV preprocessing
4. Custom Java implementation for `HSFSFOA` and `Improved SSA`
- Security:
1. JWT access token + refresh token (role-based API security)
2. Password hashing with BCrypt
- Build/Test/DevOps:
1. `Maven`
2. `JUnit 5`, `Mockito`, `Spring Boot Test`, `Testcontainers`
3. `Docker`, `Docker Compose`

## Core Modules and Package Boundaries
- `com.creditrisk.auth`
- `com.creditrisk.user`
- `com.creditrisk.applicant`
- `com.creditrisk.loan`
- `com.creditrisk.decision`
- `com.creditrisk.audit`
- `com.creditrisk.ml.preprocessing`
- `com.creditrisk.ml.featureselection`
- `com.creditrisk.ml.optimization`
- `com.creditrisk.ml.training`
- `com.creditrisk.ml.scoring`
- `com.creditrisk.admin`

## Database Schema (MySQL)
- `users`
1. `id`, `email`, `password_hash`, `full_name`, `status`, `created_at`, `updated_at`
- `roles`
1. `id`, `name` (`ADMIN`, `LOAN_OFFICER`, `RISK_ANALYST`)
- `user_roles`
1. `user_id`, `role_id`
- `refresh_tokens`
1. `id`, `user_id`, `token_hash`, `expires_at`, `revoked_at`
- `applicants`
1. `id`, `first_name`, `last_name`, `dob`, `phone`, `email`, `government_id_masked`, `created_at`
- `loan_applications`
1. `id`, `applicant_id`, `loan_amount`, `term_months`, `purpose`, `annual_income`, `employment_length_years`, `home_ownership`, `verification_status`, `dti`, `existing_debt`, `application_status`, `submitted_at`, `created_by`
2. `raw_feature_snapshot_json` (normalized feature snapshot used for scoring)
- `credit_profile_snapshots`
1. `id`, `loan_application_id`, `fico_low`, `fico_high`, `inq_last_6mths`, `delinq_2yrs`, `open_acc`, `pub_rec`, `revol_bal`, `revol_util`, `total_acc`, `mort_acc`, `pub_rec_bankruptcies`
- `risk_assessments`
1. `id`, `loan_application_id`, `model_id`, `risk_score`, `default_probability`, `risk_band`, `recommendation`, `top_reason_codes_json`, `scored_at`, `feature_vector_hash`
- `loan_decisions`
1. `id`, `loan_application_id`, `risk_assessment_id`, `decision_status`, `approved_amount`, `approved_term_months`, `interest_rate_offer`, `override_flag`, `override_reason`, `decided_by`, `decided_at`
- `ml_models`
1. `id`, `model_name`, `model_version`, `model_type`, `status` (`TRAINED`, `VALIDATED`, `ACTIVE`, `RETIRED`), `artifact_path`, `feature_schema_json`, `hyperparams_json`, `metrics_json`, `trained_on_dataset_version`, `created_at`, `promoted_at`
- `training_runs`
1. `id`, `run_type` (`BASELINE`, `HSFSFOA`, `ISSA_XGBOOST`), `dataset_version`, `status`, `started_at`, `ended_at`, `config_json`, `metrics_json`, `error_message`
- `feature_selection_runs`
1. `id`, `training_run_id`, `algorithm`, `selected_features_json`, `ca`, `dr`, `auc`, `fitness`, `seed`, `iterations`
- `dataset_ingestion_jobs`
1. `id`, `source_name`, `source_path`, `dataset_version`, `status`, `rows_read`, `rows_loaded`, `started_at`, `ended_at`, `log_summary`
- `audit_logs`
1. `id`, `actor_user_id`, `action_type`, `entity_type`, `entity_id`, `before_json`, `after_json`, `ip_address`, `created_at`
- `system_configs`
1. `config_key`, `config_value`, `updated_at`
- Required indexes:
1. `loan_applications(application_status, submitted_at)`
2. `risk_assessments(loan_application_id, scored_at)`
3. `loan_decisions(loan_application_id, decided_at)`
4. `ml_models(status, created_at)`
5. `training_runs(status, started_at)`

## Important Changes or Additions to Public APIs/Interfaces/Types
### REST APIs (public application/admin APIs)
- Authentication:
1. `POST /api/v1/auth/login`
2. `POST /api/v1/auth/refresh`
3. `POST /api/v1/auth/logout`
4. `GET /api/v1/auth/me`
- Applicants:
1. `POST /api/v1/applicants`
2. `GET /api/v1/applicants/{id}`
3. `GET /api/v1/applicants`
- Loan Applications:
1. `POST /api/v1/loan-applications`
2. `GET /api/v1/loan-applications/{id}`
3. `GET /api/v1/loan-applications`
4. `PATCH /api/v1/loan-applications/{id}/submit`
5. `PATCH /api/v1/loan-applications/{id}/status`
- Risk Scoring:
1. `POST /api/v1/loan-applications/{id}/score`
2. `GET /api/v1/loan-applications/{id}/risk-assessments`
- Decisions:
1. `POST /api/v1/loan-applications/{id}/decision`
2. `GET /api/v1/loan-decisions/{id}`
- Admin / ML:
1. `POST /api/v1/admin/datasets/import`
2. `POST /api/v1/admin/training-runs`
3. `GET /api/v1/admin/training-runs/{id}`
4. `GET /api/v1/admin/models`
5. `POST /api/v1/admin/models/{id}/promote`
6. `POST /api/v1/admin/models/{id}/retire`
7. `GET /api/v1/admin/metrics/summary`
- Audit / Reports:
1. `GET /api/v1/admin/audit-logs`
2. `GET /api/v1/admin/reports/decision-outcomes`

### Public DTOs / Types
- `LoginRequest { email, password }`
- `AuthTokenResponse { accessToken, refreshToken, expiresIn, roles }`
- `ApplicantCreateRequest { firstName, lastName, dob, phone, email, governmentId }`
- `LoanApplicationCreateRequest { applicantId, loanAmount, termMonths, purpose, annualIncome, employmentLengthYears, homeOwnership, verificationStatus, dti, existingDebt, creditProfile }`
- `CreditProfileDto { ficoLow, ficoHigh, inqLast6Months, delinq2Yrs, openAccounts, publicRecords, revolvingBalance, revolvingUtilization, totalAccounts, mortgageAccounts, bankruptcies }`
- `RiskAssessmentResponse { assessmentId, modelVersion, defaultProbability, riskScore, riskBand, recommendation, topReasons, scoredAt }`
- `LoanDecisionRequest { decisionStatus, approvedAmount, approvedTermMonths, interestRateOffer, overrideReason }`
- `ModelTrainRequest { datasetVersion, mode, featurePolicy, optimizerConfig, xgboostSearchSpace, evaluationStrategy }`
- `TrainingRunResponse { runId, status, runType, metrics, startedAt, endedAt }`

### Internal Extension Interfaces (to keep implementation swappable)
- `FeaturePreprocessor`
- `FeatureSelector`
- `HyperparameterOptimizer`
- `RiskModelTrainer`
- `RiskScorer`
- `DecisionPolicyEngine`
- `ModelRegistryService`

## Data and ML Pipeline Design
### Dataset Strategy
- Primary training dataset: Lending Club public dataset (paper basis).
- Dataset versioning rule: immutable imported dataset snapshots identified as `LC_YYYYMMDD_vN`.
- MVP demo data: synthetic/sample applications seeded separately from training data.

### Feature Availability Policy (locked)
- Use **application-time/origination-time features only** for approval scoring.
- Exclude post-loan repayment fields such as:
1. `last_pymnt_amnt`
2. `last_pymnt_d`
3. `next_pymnt_d`
4. `total_rec_*`
5. Any status updates after origination
- Exclude direct identifiers and proxy-heavy fields (paper also removes many):
1. `id`, `member_id`, `url`, `zip_code`, `emp_title`, `title`, `addr_state` (default exclusion for fairness/proxy risk)

### Preprocessing Rules (paper-aligned + deployment-safe)
- Apply these steps in fixed order:
1. Drop columns with missing rate `> 50%`.
2. Remove irrelevant/identifier/leakage columns.
3. Impute continuous features with median.
4. Impute categorical features with mode.
5. Normalize continuous features (min-max scaling).
6. Encode categorical features with deterministic mappings.
7. Parse date columns and derive numeric durations only if they are available at application time.
8. Map label from `loan_status` (`Current`/`Fully Paid` => `0`; delinquent/default statuses => `1`) for offline training.
9. Persist preprocessing schema and mappings with the model artifact.
- Categorical mappings to mirror the paper where applicable:
1. `grade`, `sub_grade`, `verification_status`, `purpose`, `term`, `initial_list_status`, `emp_length`, `home_ownership`, `application_type`
- Date handling adaptation:
1. Use `issue_d` and `earliest_cr_line` only for origination-safe derived features.
2. Do not use repayment-event dates in approval model.

### Modeling Phases (implementation order)
- Phase A: Baseline model
1. Chi-square top-K feature filtering.
2. XGBoost training with manual/default parameters.
3. Produce baseline metrics and active demo model.
- Phase B: Paper-aligned feature selection (`HSFSFOA`)
1. Implement forest/tree binary feature subset representation.
2. Chi-square initialization strategy.
3. Adaptive global seeding (`GSC`) based on fitness.
4. Greedy local search on top half of age-0 trees.
5. Fitness function `CA + 0.01 * DR`.
6. Output selected feature subset and feature-selection metrics.
- Phase C: Paper-aligned parameter optimization (`Improved SSA`)
1. Optimize XGBoost `learning_rate`, `max_depth`, `n_estimators`, `gamma`.
2. Use Tent map initialization.
3. Use sine-cosine discoverer updates.
4. Use reverse learning vs Cauchy mutation via dynamic probability.
5. Use greedy best-solution update.
6. Train final XGBoost with best params and selected features.

### Optimizer Defaults (chosen)
- Improved SSA defaults from paper:
1. `pop_size = 30`
2. `max_iter = 100`
3. `discoverer_ratio = 0.2`
4. `watcher_ratio = 0.1`
5. `ST = 0.8`
6. `v1 = 0.5`
7. `v2 = 0.1`
- XGBoost search space (deployment-safe defaults):
1. `learning_rate: [0.01, 0.30]`
2. `max_depth: [3, 10]`
3. `n_estimators: [100, 600]`
4. `gamma: [0.0, 5.0]`
- Additional fixed XGBoost defaults:
1. `objective = binary:logistic`
2. `eval_metric = auc`
3. `subsample = 0.8`
4. `colsample_bytree = 0.8`
5. `seed = 42`

### Evaluation Strategy (locked)
- Training optimization fitness:
1. Use stratified 3-fold CV for faster optimizer iterations.
- Final evaluation for reporting:
1. Repeated stratified 5-fold CV with 3 repeats (paper-aligned spirit).
2. Leakage-safe holdout evaluation (time-based or origination-safe split) for deployment decision.
- Metrics to store:
1. `accuracy`
2. `auc`
3. `precision`
4. `recall`
5. `f1`
6. `confusion_matrix`
7. `ca`
8. `dr`
9. `fitness`

## Loan Decisioning Logic (Policy Engine)
- Scoring output:
1. `defaultProbability` from XGBoost.
2. `riskScore = round((1 - defaultProbability) * 1000)` for UI readability.
3. `riskBand` derived from probability thresholds.
- Default threshold configuration (stored in `system_configs`):
1. `AUTO_APPROVE_PD_MAX = 0.12`
2. `MANUAL_REVIEW_PD_MAX = 0.25`
3. `AUTO_DECLINE_PD_MIN = 0.25`
- Recommendation rules:
1. `pd < 0.12` and no hard-rule violation => `AUTO_APPROVE`
2. `0.12 <= pd < 0.25` => `MANUAL_REVIEW`
3. `pd >= 0.25` => `AUTO_DECLINE`
- Hard-rule defaults (configurable):
1. `annualIncome > 0`
2. `loanAmount > 0`
3. `dti <= 0.65` (above this forces review/decline)
4. Missing critical credit-profile fields forces `MANUAL_REVIEW`
- Override policy:
1. Loan officer may override recommendation.
2. Override requires reason.
3. Override is audit logged.

## Frontend Plan (HTML/CSS/JS + Spring APIs)
- UI delivery model: static pages served by Spring Boot, API-driven rendering via vanilla JS.
- Screens to implement:
1. Login page
2. Dashboard (application counts, decision metrics, model version, recent activity)
3. Applicant create/view page
4. Loan application create form
5. Application detail page with scoring result and decision actions
6. Queue page (`SUBMITTED`, `MANUAL_REVIEW`, `DECIDED`)
7. Admin dataset import page
8. Admin training runs page
9. Admin model registry/promote page
10. Reports page (AUC/accuracy trends, decision outcomes)
- Frontend behavior:
1. Form validation in browser + server validation.
2. Token-based auth storage in secure pattern (prefer HTTP-only refresh token; access token in memory).
3. Fetch wrappers for auth/refresh handling.
4. Chart.js for training metrics and decision distribution.
5. Responsive layout for laptop/mobile demo.

## Implementation Phases and Milestones
### Phase 1: Project Bootstrap and Foundations (Week 1)
- Create Maven multi-module structure or single-module app with internal packages.
- Add Spring Boot, JPA, Security, Flyway, OpenAPI, MySQL config.
- Add Docker Compose for MySQL and app.
- Create base schema migrations.
- Implement auth and roles.
- Exit criteria:
1. App starts, migrations run, login works, Swagger/OpenAPI loads.

### Phase 2: Core Loan Workflow Backend (Week 2)
- Implement applicant, loan application, risk assessment, decision entities and repositories.
- Implement REST APIs for applicant/application CRUD and workflow transitions.
- Add audit logging for create/submit/decision actions.
- Implement basic queue filters and pagination.
- Exit criteria:
1. Application can be created, submitted, and manually decided through APIs.

### Phase 3: Frontend MVP (Week 3)
- Build HTML/CSS/JS screens for auth, dashboard, applicant, application form, queue, detail page.
- Integrate with backend APIs.
- Add basic charts for counts and outcomes.
- Exit criteria:
1. End-to-end manual workflow runs from browser.

### Phase 4: Dataset Import and Preprocessing Pipeline (Week 4)
- Implement dataset ingestion job for Lending Club CSV.
- Implement preprocessing pipeline with paper-aligned rules and leakage-safe exclusions.
- Persist dataset version metadata and preprocessing schema.
- Add admin endpoints/pages to trigger and monitor import jobs.
- Exit criteria:
1. Imported dataset can be preprocessed and summarized with row/column stats.

### Phase 5: Baseline XGBoost Risk Model (Week 5)
- Implement baseline feature filtering (chi-square top-K).
- Train baseline XGBoost model in Java.
- Save artifact + metrics + feature schema in model registry.
- Implement runtime model loading and scoring service.
- Connect scoring API to loan application flow.
- Exit criteria:
1. Submitted applications can be scored automatically using an active model.
2. Baseline metrics appear in admin UI.

### Phase 6: HSFSFOA Feature Selection (Paper Phase 1) (Weeks 6-7)
- Implement feature subset representation and forest/tree lifecycle.
- Implement chi-square initialization, adaptive GSC, greedy local seeding filter, size limits.
- Implement feature-selection fitness calculation and run persistence.
- Compare against baseline feature filter on same dataset split.
- Exit criteria:
1. HSFSFOA run completes and outputs selected feature subset + `CA`, `DR`, `AUC`, `fitness`.
2. Final XGBoost model trained on HSFSFOA-selected features.

### Phase 7: Improved SSA XGBoost Optimization (Paper Phase 2) (Weeks 8-9)
- Implement improved SSA components in Java.
- Implement XGBoost hyperparameter search wrapper and objective evaluation.
- Persist optimizer trajectories and best hyperparameters.
- Train final optimized model and register version.
- Exit criteria:
1. Optimized model beats baseline XGBoost on target metrics in the same evaluation setting.
2. Admin can promote optimized model to active.

### Phase 8: Decision Policy, Explainability, Reporting, Hardening (Week 10)
- Finalize policy engine and configurable thresholds.
- Add top reason codes and feature-importance display.
- Add decision override and audit views.
- Add error handling, validation messages, API docs polish.
- Exit criteria:
1. Complete capstone demo flow with traceable AI recommendation and human decision.

### Phase 9: Testing, Packaging, Demo Readiness (Week 11)
- Run unit/integration/e2e/performance tests.
- Finalize Docker Compose setup and README.
- Produce sample demo scripts and seeded data.
- Exit criteria:
1. New developer can run system locally and execute demo scenario from docs.

## Test Cases and Scenarios
### Unit Tests
- Preprocessing rules:
1. Drops columns with `>50%` missing values.
2. Median/mode imputation works deterministically.
3. Paper categorical mappings encode correctly.
4. Label mapping from `loan_status` matches spec.
5. Leakage filter excludes post-loan fields.
- ML algorithm internals:
1. HSFSFOA tree encoding/decoding correctness.
2. GSC stays within configured bounds.
3. Greedy local-search selection only uses top half eligible trees.
4. Improved SSA Tent initialization stays within search bounds.
5. Reverse learning and Cauchy mutation produce bounded candidate params.
6. Greedy best update selects better fitness.
- Policy engine:
1. Threshold mapping produces correct recommendation.
2. Hard-rule violations force expected review/decline.

### Integration Tests
- API + DB:
1. Create applicant and application persists all related records.
2. Submit application creates audit event.
3. Score endpoint stores `risk_assessment` linked to active model.
4. Decision endpoint stores decision and override metadata.
5. Admin training run endpoint persists run state transitions.
- Security:
1. Unauthorized requests rejected.
2. Role-restricted admin endpoints block non-admin users.
3. Refresh token rotation/revocation works.

### ML Pipeline Validation Tests
- Training job:
1. Dataset import -> preprocessing -> baseline training completes on sample dataset.
2. HSFSFOA run produces non-empty selected feature list.
3. Improved SSA optimizer returns valid XGBoost parameters.
4. Model artifact can be reloaded and score the same sample deterministically.
- Metric sanity:
1. AUC is in `[0.5, 1.0]`.
2. Precision/recall/F1 are computed and persisted.
3. Optimized model metrics are compared against baseline in the same split.

### End-to-End UI Scenarios
- Loan officer flow:
1. Log in, create applicant, create application, submit, score, review recommendation, approve/decline.
- Manual review flow:
1. Mid-risk application routed to manual review, officer overrides recommendation with reason.
- Admin ML flow:
1. Import dataset, start training run, inspect metrics, promote model, verify new model used in scoring.
- Error flow:
1. Missing required fields returns friendly validation messages.

### Performance and Reliability Tests
- API performance:
1. Scoring endpoint p95 latency under target load (single-node demo target: `<500 ms` excluding first model load).
- Concurrency:
1. Multiple simultaneous application submissions do not corrupt workflow status.
- Recovery:
1. Failed training run records error and does not affect active model.

## Non-Functional Requirements (MVP Targets)
- Security:
1. JWT auth, role-based authorization, password hashing, audit trail.
- Observability:
1. Structured logs with correlation IDs.
2. Training/job status persistence.
- Maintainability:
1. OpenAPI docs for all APIs.
2. Versioned DB migrations.
3. Clear module boundaries and interfaces.
- Reliability:
1. Active model promotion is atomic.
2. Model rollback supported by switching active model record.

## Rollout and Deployment Plan
- Local/dev deployment:
1. `docker-compose` service for MySQL.
2. Spring Boot app container or local run.
3. Mounted `model-artifacts` volume.
- Configuration via env vars:
1. DB connection
2. JWT secrets
3. Artifact storage path
4. Active dataset/model defaults
5. Training job limits
- Release process:
1. Run migrations.
2. Seed roles/admin user.
3. Import sample data.
4. Train or load baseline model.
5. Promote active model.
6. Run smoke tests.
- Rollback:
1. Re-point active model to prior version in `ml_models`.
2. Keep old artifacts until explicit retirement.

## Risks and Mitigations
- Risk: Paper metrics may not reproduce after leakage-safe feature filtering.
- Mitigation: Track two evaluations (paper-style benchmark notes vs deployment-safe holdout) and prioritize deployment-safe metrics.
- Risk: `xgboost4j` native dependency setup issues.
- Mitigation: Pin tested version, provide Docker build image, add startup self-check.
- Risk: HSFSFOA/ISSA runtime is slow on full dataset.
- Mitigation: Use sampling for dev iterations, bounded iterations, asynchronous jobs, resumable run metadata.
- Risk: Class imbalance hurts recall.
- Mitigation: Tune decision thresholds, evaluate precision/recall/F1/AUC, optionally set `scale_pos_weight`.
- Risk: Fairness/proxy bias in features.
- Mitigation: Exclude identifiers/proxy-heavy fields by default, log feature list per model version.

## Important Deliverables
1. Spring Boot backend with REST APIs and static frontend.
2. MySQL schema + Flyway migrations.
3. Java-based preprocessing and model training pipeline.
4. HSFSFOA feature selector implementation.
5. Improved SSA hyperparameter optimizer for XGBoost.
6. Model registry and scoring service.
7. Loan decision policy engine and audit trail.
8. Docker Compose setup and runbook.
9. Test suite (unit/integration/e2e).
10. Capstone demo script and documentation.

## Explicit Assumptions and Defaults Chosen
- User-selected defaults:
1. Delivery target is **Capstone MVP**.
2. ML scope is **Phased Paper-First**.
3. Frontend is **basic HTML/CSS/JS + Spring APIs**.
4. Feature policy is **application-time features only** (no leakage).
- Implementation defaults chosen in this plan:
1. Single Spring Boot app serving both APIs and static frontend.
2. `MySQL` as primary database with `Flyway`.
3. JWT-based auth with role-based access.
4. Java implementation for core ML pipeline (`xgboost4j` + custom HSFSFOA/ISSA).
5. Local `Docker Compose` deployment is the primary environment target.
6. Paper comparator models like `CatBoost`/`LightGBM` are optional and not required for Java MVP.
7. Model artifact storage uses local filesystem path with DB metadata registry.
8. Default decision thresholds are configurable and initialized to `0.12 / 0.25` PD cutoffs.
