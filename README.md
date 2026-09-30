# AI-Based Credit Risk Assessment and Loan Approval System

A Java Full Stack project for managing loan applications and assessing credit risk. The application covers the complete flow from applicant registration and loan submission to risk scoring and loan decision.

## Features

* Applicant and loan application management
* Credit risk scoring with default probability
* Risk band and loan recommendation
* Loan decision with override reason
* Audit logging
* Admin dashboard for datasets and models
* JWT authentication and role-based access
* Dataset import and training workflow
* Dashboard with application and decision details

## Tech Stack

**Backend:** Java 17, Spring Boot, Spring Web, Spring Data JPA, Spring Security, JWT

**Database:** MySQL 8, H2, Flyway

**Frontend:** HTML, CSS, JavaScript, Chart.js

**Machine Learning:** Feature preprocessing, feature selection, XGBoost-compatible workflow

## Project Flow

```text
Applicant
   ↓
Loan Application
   ↓
Data Preprocessing
   ↓
Risk Assessment
   ↓
Risk Score + Default Probability
   ↓
Loan Recommendation
   ↓
Loan Decision
   ↓
Audit Log
```

### Main Workflow

1. Create an applicant.
2. Create and submit a loan application.
3. Run the risk assessment.
4. View the risk score, default probability, risk band, and recommendation.
5. Make a loan decision.
6. If the decision differs from the AI recommendation, provide an override reason.
7. The decision and important actions are recorded in the audit log.

## Machine Learning

The project includes preprocessing, feature selection, model training, and risk scoring components.

The ML module contains implementations/scaffolding for:

* HSFSFOA-based feature selection
* Improved SSA-based hyperparameter optimization
* Baseline training
* XGBoost-based training workflow

### Current Implementation

For easier local execution, the current runtime uses a **heuristic XGBoost-compatible model** instead of native `xgboost4j`. The training and scoring interfaces are already separated, making it possible to replace the current implementation with native XGBoost later.

## Admin Features

The admin section provides:

* Dataset import and profiling
* Dataset version tracking
* Model training
* Model registration
* Model promotion and retirement
* Metrics and decision reports

The application can also generate and automatically import a synthetic Lending Club-format dataset when the expected dataset is not available.

## Security

* JWT access and refresh tokens
* Role-based authorization
* Login, logout and user authentication
* Protected APIs
* Audit logging

**Roles:**
`ADMIN` · `LOAN_OFFICER` · `RISK_ANALYST`

## Project Structure

```text
src/
├── main/
│   ├── java/com/creditrisk/
│   │   ├── auth/
│   │   ├── applicant/
│   │   ├── loan/
│   │   ├── decision/
│   │   ├── audit/
│   │   ├── admin/
│   │   └── ml/
│   │
│   └── resources/
│       ├── static/
│       └── db/migration/
│
├── data/
└── model-artifacts/
```

## How to Run

### Local

```bash
mvn -DskipTests package
mvn spring-boot:run
```

The default setup uses embedded H2, so MySQL is not required for the basic local run.

### Docker

```bash
mvn -DskipTests package
docker compose up --build
```

Open:

```text
http://localhost:8080/login.html
```

Swagger UI:

```text
http://localhost:8080/swagger-ui.html
```

## Testing

Tests are included for:

* Data preprocessing
* Leakage exclusion
* Decision policy and thresholds
* Authentication APIs
* Login and user information

## Future Improvements

* Integrate native `xgboost4j`
* Replace heuristic training and scoring with actual XGBoost
* Add real cross-validation metrics
* Improve model explainability
* Extend dashboard analytics

## About the Project

This project combines **Java, Spring Boot, MySQL, REST APIs, frontend development, authentication, and machine-learning components** to implement a credit risk and loan approval workflow.

The main focus is on building the complete application flow while keeping the ML, decision, authentication, and data-management components separated.
