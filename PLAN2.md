
# Dataset Packaging and Startup Auto-Import Plan (Lending Club-Format Synthetic CSV)
## Summary
- Add a **project-local dataset bootstrap flow** that generates a **Lending Club-format synthetic CSV** under `data/`, then **auto-imports it at startup** using the existing dataset import pipeline.
- Keep training **manual** (admin UI/API) after import, per your choice.
- Make startup import **idempotent**: skip repeated imports when the same dataset file has already been imported.
- Improve admin usability by exposing the **latest dataset import summary** so the training form can auto-fill `datasetVersion` even when import was done at startup.

## Goal and Success Criteria
- Goal:
  - The project should start with a usable dataset in `data/` and auto-import it without manual path entry.
- Success criteria:
  1. First startup generates `data/lending_club_synthetic.csv` (if missing), imports it, and stores a completed row in `dataset_ingestion_jobs`.
  2. Next startup skips re-import for the same file (idempotent behavior).
  3. Admin page shows latest imported dataset info and pre-fills `datasetVersion`.
  4. Manual training (`BASELINE`, `HSFSFOA`, `ISSA_XGBOOST`) still works using the startup-imported dataset version.
  5. Docker and local (`start.sh`) workflows both work with the project-local dataset path.

## Scope (In / Out)
- In scope:
  1. Synthetic Lending Club-format CSV generator.
  2. Startup auto-import runner.
  3. Idempotent import detection.
  4. `data/` project folder integration.
  5. Admin API/UI enhancement for latest dataset summary.
  6. Documentation and startup script alignment.
- Out of scope:
  1. Real Lending Club dataset download automation.
  2. Startup auto-training.
  3. Replacing heuristic model trainer with `xgboost4j`.
  4. CSV upload endpoint/UI.

## Current State (Grounded)
- Dataset import already exists via `POST /api/v1/admin/datasets/import` and requires `sourcePath` (`src/main/java/com/creditrisk/admin/DatasetImportRequest.java:6`).
- Preprocessing already expects a Lending Club-style CSV and excludes leakage fields (`src/main/java/com/creditrisk/ml/preprocessing/LendingClubFeaturePreprocessor.java:21`).
- Training re-reads dataset from the stored `source_path` (`src/main/java/com/creditrisk/admin/TrainingOrchestratorService.java:65`).
- Admin UI currently requires manual CSV path entry and only fills `datasetVersion` after manual import (`src/main/resources/static/admin.html:28`, `src/main/resources/static/js/admin.js:20`).
- No `.csv` file is currently bundled in the repo.

## Implementation Approach (Decision Complete)

## 1. Add Project Dataset Bootstrap Configuration
- Add new config block under `app.dataset.bootstrap` in `src/main/resources/application.yml`.
- Add strongly typed properties class `com.creditrisk.config.DatasetBootstrapProperties` using `@ConfigurationProperties`.
- Config fields (finalized):
  1. `enabled` (`boolean`)
  2. `sourcePath` (`String`) absolute or relative path; default `./data/lending_club_synthetic.csv`
  3. `sourceName` (`String`) default `lending-club-synthetic`
  4. `generateIfMissing` (`boolean`) default `true`
  5. `rows` (`int`) default `5000`
  6. `randomSeed` (`long`) default `42`
  7. `skipIfAlreadyImported` (`boolean`) default `true`
  8. `failOnError` (`boolean`) default `false`
- Env var mappings (for Docker/start.sh compatibility):
  1. `DATASET_BOOTSTRAP_ENABLED`
  2. `DATASET_BOOTSTRAP_SOURCE_PATH`
  3. `DATASET_BOOTSTRAP_SOURCE_NAME`
  4. `DATASET_BOOTSTRAP_GENERATE_IF_MISSING`
  5. `DATASET_BOOTSTRAP_ROWS`
  6. `DATASET_BOOTSTRAP_RANDOM_SEED`
  7. `DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED`
  8. `DATASET_BOOTSTRAP_FAIL_ON_ERROR`

## 2. Add Synthetic Lending Club-Format Dataset Generator
- Add service `com.creditrisk.ml.dataset.bootstrap.LendingClubSyntheticDatasetGenerator`.
- Add method:
  - `Path generate(Path outputPath, int rows, long seed)`
- Behavior:
  1. Create parent directories (`data/`) if missing.
  2. Write CSV with header row and deterministic random content.
  3. Overwrite only when explicitly called (startup runner will call only if file missing by default).
- CSV schema (must include headers required by current preprocessor and future training compatibility):
  1. Label field: `loan_status`
  2. Core categorical fields used by mappings:
     - `grade`, `sub_grade`, `verification_status`, `purpose`, `term`, `initial_list_status`, `emp_length`, `home_ownership`, `application_type`
  3. Core numeric/origination fields:
     - `loan_amnt`, `annual_inc`, `dti`, `delinq_2yrs`, `inq_last_6mths`, `open_acc`, `pub_rec`, `revol_bal`, `revol_util`, `total_acc`, `mort_acc`, `pub_rec_bankruptcies`
  4. Allowed date fields:
     - `issue_d`, `earliest_cr_line`
  5. Optional extra origination-like fields for realism:
     - `installment`, `int_rate`, `fico_range_low`, `fico_range_high`
  6. Include a small set of leakage columns intentionally so preprocessing drop rules are exercised:
     - `last_pymnt_amnt`, `last_pymnt_d`, `total_rec_int`, `addr_state`, `zip_code`
- Value generation rules:
  1. Use weighted distributions for `loan_status` so both classes exist (`Current`/`Fully Paid` and delinquent/default labels).
  2. Ensure valid `sub_grade` matches `grade`.
  3. Keep numeric ranges realistic and non-negative.
  4. Ensure `issue_d` and `earliest_cr_line` are parseable using current parser expectations.
  5. Ensure no blank `loan_status`.
- Determinism:
  - Same `rows` + `seed` must produce identical file content.

## 3. Add Startup Auto-Import Runner
- Add `com.creditrisk.config.DatasetBootstrapRunner` as a `CommandLineRunner`.
- Use `@Order` to run after DB/Flyway and seeders.
- Startup flow:
  1. If `app.dataset.bootstrap.enabled=false`, exit.
  2. Resolve `sourcePath` (relative paths resolved against app working dir).
  3. If file missing and `generateIfMissing=true`, generate synthetic CSV.
  4. If file missing and `generateIfMissing=false`, log warning or fail depending on `failOnError`.
  5. Compute file fingerprint (SHA-256) and file metadata.
  6. If `skipIfAlreadyImported=true` and a completed import exists for same `sourcePath` + fingerprint, log skip and exit.
  7. Otherwise call dataset import service internal method (not the controller) with trigger mode `STARTUP_BOOTSTRAP`.
  8. Log imported `datasetVersion`, `rowsRead`, `rowsLoaded`.
- Error handling:
  1. If `failOnError=false`, log structured error and continue app startup.
  2. If `failOnError=true`, throw and fail startup.

## 4. Extend Dataset Import Metadata for Idempotency and Observability
- Add Flyway migration `V2__dataset_ingestion_metadata.sql`.
- Schema additions to `dataset_ingestion_jobs`:
  1. `source_fingerprint VARCHAR(128) NULL` (SHA-256 hex)
  2. `trigger_mode VARCHAR(32) NOT NULL DEFAULT 'MANUAL'`
  3. `generated_file BOOLEAN NOT NULL DEFAULT FALSE`
- Add index:
  1. `(source_path, source_fingerprint, status, started_at)`
- Update entity `src/main/java/com/creditrisk/ml/dataset/DatasetIngestionJobEntity.java` with matching fields.
- Add enum `DatasetIngestionTriggerMode`:
  1. `MANUAL`
  2. `STARTUP_BOOTSTRAP`
- Update `DatasetImportService` to support internal import method with metadata:
  - `importDataset(Path sourcePath, String sourceName, DatasetIngestionTriggerMode triggerMode, boolean generatedFile, boolean skipIfSameFingerprint)`
- Keep existing controller-facing `importDataset(DatasetImportRequest)` as wrapper calling internal method with `MANUAL`.

## 5. Add Latest Dataset Summary API for Admin UI (Auto-Import Visibility)
- Add endpoint:
  - `GET /api/v1/admin/datasets/latest`
- Reuse existing `DatasetImportService.latestIngestionSummary()` and return structured DTO instead of raw `Map`.
- New response DTO `LatestDatasetSummaryResponse` fields:
  1. `jobId`
  2. `sourceName`
  3. `sourcePath`
  4. `datasetVersion`
  5. `status`
  6. `rowsRead`
  7. `rowsLoaded`
  8. `triggerMode`
  9. `startedAt`
  10. `endedAt`
- Authorization:
  - Same as dataset import endpoint: `ADMIN` and `RISK_ANALYST` (optionally include `LOAN_OFFICER` if you want visibility only; default plan keeps `ADMIN/RISK_ANALYST`).

## 6. Update Admin UI to Use Startup-Imported Dataset
- Update `src/main/resources/static/js/admin.js`:
  1. On page load, fetch `GET /api/v1/admin/datasets/latest`.
  2. If successful and status is `COMPLETED`, auto-fill training form `datasetVersion`.
  3. Display latest dataset import info in UI message area (including source path and trigger mode).
- Update `src/main/resources/static/admin.html`:
  1. Change CSV placeholder to project default `./data/lending_club_synthetic.csv`.
  2. Add small hint text indicating startup auto-import default.
  3. Add “Use Project Dataset Path” helper button (optional but included in plan) that fills the path input with the configured default.
- Preserve manual import form and behavior.

## 7. Update Docker and Local Startup Tooling
- `docker-compose.yml` changes:
  1. Mount project `./data` into app container at `/app/data`
  2. Add `DATASET_BOOTSTRAP_ENABLED=true`
  3. Add `DATASET_BOOTSTRAP_SOURCE_PATH=/app/data/lending_club_synthetic.csv`
  4. Add generator defaults if desired (`ROWS`, `SEED`)
- `start.sh` changes:
  1. Ensure `data/` directory exists locally before startup.
  2. Export dataset bootstrap env vars (with defaults aligned to local path `./data/lending_club_synthetic.csv`).
  3. Add optional flags for dataset bootstrap rows/seed and enable/disable startup import.
- `README.md` updates:
  1. Document project-local synthetic dataset behavior.
  2. Document how to disable startup auto-import.
  3. Document manual import override using a real Lending Club CSV later.

## 8. Preprocessor Compatibility Validation (No Behavior Change)
- No changes to core preprocessing rules in `LendingClubFeaturePreprocessor` are required.
- Add tests to ensure synthetic generator emits fields compatible with:
  1. Header parsing
  2. `loan_status` label mapping
  3. Categorical mappings
  4. Date parsing for `issue_d` and `earliest_cr_line`
  5. Leakage column drop logic

## Important Changes or Additions to Public APIs / Interfaces / Types
- REST API additions:
  1. `GET /api/v1/admin/datasets/latest` (new)
- REST API behavioral changes:
  1. `POST /api/v1/admin/datasets/import` remains supported and unchanged for manual imports
- Public DTO additions:
  1. `LatestDatasetSummaryResponse`
- Internal interfaces/types additions:
  1. `DatasetBootstrapProperties`
  2. `LendingClubSyntheticDatasetGenerator`
  3. `DatasetIngestionTriggerMode`
- Internal service signature additions:
  1. `DatasetImportService.importDataset(Path, String, DatasetIngestionTriggerMode, boolean, boolean)` (internal overload)
- DB schema additions:
  1. `dataset_ingestion_jobs.source_fingerprint`
  2. `dataset_ingestion_jobs.trigger_mode`
  3. `dataset_ingestion_jobs.generated_file`

## Data Flow (Finalized)
- First startup (default dev flow):
  1. App starts.
  2. Flyway runs.
  3. Seed admin and demo model runners execute.
  4. Dataset bootstrap runner checks `./data/lending_club_synthetic.csv`.
  5. If missing, generator creates CSV.
  6. Runner computes fingerprint.
  7. Runner imports dataset using `DatasetImportService`.
  8. `dataset_ingestion_jobs` row saved with `STARTUP_BOOTSTRAP`.
  9. Admin page loads and shows latest imported dataset; `datasetVersion` prefilled.
  10. User runs `BASELINE` / `HSFSFOA` / `ISSA_XGBOOST` manually.
- Subsequent startup:
  1. Runner computes same fingerprint.
  2. Finds completed ingestion row for same path+fingerprint.
  3. Logs skip and does not duplicate import.

## Implementation Phases (Recommended Order)
1. Add dataset bootstrap config + properties class.
2. Add synthetic CSV generator + unit tests.
3. Add DB migration and entity/repository updates for import metadata.
4. Add internal `DatasetImportService` overload with fingerprint + trigger metadata.
5. Add startup runner and idempotent skip logic.
6. Add latest dataset summary endpoint + DTO.
7. Update admin UI to display latest dataset and auto-fill `datasetVersion`.
8. Update `docker-compose.yml`, `start.sh`, and `README.md`.
9. Run end-to-end local and Docker smoke tests.

## Test Cases and Scenarios

## Unit Tests
1. `LendingClubSyntheticDatasetGenerator` creates CSV with expected headers and row count.
2. Generator is deterministic for same seed and row count.
3. Generated rows include both label classes recognized by `mapLoanStatusLabel`.
4. Generated date fields parse correctly in `LendingClubFeaturePreprocessor`.
5. Preprocessor drops leakage columns present in generated CSV.
6. Fingerprint utility returns stable SHA-256 for unchanged file.
7. Startup runner skips import when matching completed path+fingerprint exists.
8. Startup runner generates file when missing and `generateIfMissing=true`.
9. Startup runner respects `failOnError=false` and does not crash app on import failure.

## Integration Tests
1. Startup with empty `data/` generates and imports dataset successfully.
2. Startup rerun with same file produces no new import row (skip behavior).
3. `GET /api/v1/admin/datasets/latest` returns latest startup import with `triggerMode=STARTUP_BOOTSTRAP`.
4. Manual `POST /api/v1/admin/datasets/import` still works and records `triggerMode=MANUAL`.
5. Admin training run works using `datasetVersion` from latest startup import.

## UI Scenarios
1. Open `/admin.html` after startup auto-import and confirm training form `datasetVersion` is auto-filled.
2. Manually import another CSV path and confirm UI updates dataset message and training form.
3. Refresh admin page and verify latest dataset summary still appears.

## Docker/Local Smoke Tests
1. `./start.sh` local startup creates/imports project dataset and app reaches `Started CreditRiskApplication`.
2. `docker compose up --build` app container sees `/app/data/lending_club_synthetic.csv` and auto-imports it.
3. Container restart skips duplicate import for unchanged dataset.

## Rollout / Compatibility Notes
- Backward compatibility:
  1. Existing admin manual import flow remains valid.
  2. Existing training flow remains manual.
  3. Existing dataset versions continue to work.
- Migration:
  1. Apply new Flyway migration (`V2`) before startup runner logic depends on metadata columns.
- Operational defaults:
  1. Startup auto-import should be enabled for dev/demo usage.
  2. Can be disabled in production-like deployments via env var.

## Explicit Assumptions and Defaults Chosen
- Dataset strategy:
  1. Use a **generated synthetic Lending Club-format CSV**, not a real bundled Lending Club file.
  2. Store dataset at `./data/lending_club_synthetic.csv` (local) and `/app/data/lending_club_synthetic.csv` (Docker app container).
- Startup behavior:
  1. Auto-import runs on startup.
  2. Import is skipped if the same `sourcePath` + SHA-256 fingerprint was already imported successfully.
  3. No startup auto-training.
- Generator defaults:
  1. `rows=5000`
  2. `seed=42`
- Failure policy:
  1. Default `failOnError=false` so dataset bootstrap problems do not block the entire app startup in dev.
- UI/API:
  1. Add `GET /api/v1/admin/datasets/latest` rather than overloading `metrics/summary`.
  2. Keep `POST /api/v1/admin/datasets/import` request shape unchanged for manual import.
