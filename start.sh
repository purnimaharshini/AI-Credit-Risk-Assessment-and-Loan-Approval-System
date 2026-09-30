#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

START_DOCKER_MYSQL=true
RESET_DB=false
RUN_BUILD=false
DATASET_BOOTSTRAP_ENABLED="${DATASET_BOOTSTRAP_ENABLED:-true}"
DATASET_BOOTSTRAP_ROWS="${DATASET_BOOTSTRAP_ROWS:-5000}"
DATASET_BOOTSTRAP_RANDOM_SEED="${DATASET_BOOTSTRAP_RANDOM_SEED:-42}"
DATASET_BOOTSTRAP_SOURCE_PATH="${DATASET_BOOTSTRAP_SOURCE_PATH:-$SCRIPT_DIR/data/lending_club_synthetic.csv}"
DATASET_BOOTSTRAP_SOURCE_NAME="${DATASET_BOOTSTRAP_SOURCE_NAME:-lending-club-synthetic}"
DATASET_BOOTSTRAP_GENERATE_IF_MISSING="${DATASET_BOOTSTRAP_GENERATE_IF_MISSING:-true}"
DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED="${DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED:-true}"
DATASET_BOOTSTRAP_FAIL_ON_ERROR="${DATASET_BOOTSTRAP_FAIL_ON_ERROR:-false}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3307}"
DB_NAME="${DB_NAME:-credit_risk}"
DB_USERNAME="${DB_USERNAME:-}"
DB_PASSWORD="${DB_PASSWORD:-}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"
MYSQL_HOST_PORT="${MYSQL_HOST_PORT:-$DB_PORT}"
JWT_SECRET="${JWT_SECRET:-replace-this-with-a-long-dev-secret-key-1234567890}"
MODEL_ARTIFACTS_PATH="${MODEL_ARTIFACTS_PATH:-$SCRIPT_DIR/model-artifacts}"

usage() {
  cat <<'EOF'
Usage: ./start.sh [options]

Starts the project in local-dev mode:
1) Docker MySQL (optional)
2) Spring Boot app via mvn spring-boot:run

Options:
  --db-host <host>         MySQL host (default: 127.0.0.1)
  --db-port <port>         MySQL host port for app connection (default: 3307)
  --db-name <name>         Database name (default: credit_risk)
  --db-user <user>         MySQL app username (prompts if omitted)
  --db-pass <password>     MySQL app password (prompts if omitted)
  --mysql-root-pass <pw>   Root password for Docker MySQL init (default: root)
  --no-docker-mysql        Use an existing MySQL instance; do not start Docker MySQL
  --reset-db               Runs docker compose down -v before starting MySQL
  --build                  Run mvn -DskipTests package before spring-boot:run
  --no-dataset-bootstrap   Disable startup dataset generation/import
  --dataset-rows <n>       Synthetic startup dataset row count (default: 5000)
  --dataset-seed <n>       Synthetic startup dataset seed (default: 42)
  -h, --help               Show this help

Environment variables supported:
  DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD,
  MYSQL_ROOT_PASSWORD, MYSQL_HOST_PORT, JWT_SECRET, MODEL_ARTIFACTS_PATH,
  DATASET_BOOTSTRAP_*

Examples:
  ./start.sh --db-user myuser --db-pass mypass
  ./start.sh --db-user myuser --db-pass mypass --db-port 3308
  ./start.sh --no-docker-mysql --db-host 127.0.0.1 --db-port 3306 --db-user root --db-pass secret
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-host)
      DB_HOST="$2"
      shift 2
      ;;
    --db-port)
      DB_PORT="$2"
      MYSQL_HOST_PORT="$2"
      shift 2
      ;;
    --db-name)
      DB_NAME="$2"
      shift 2
      ;;
    --db-user)
      DB_USERNAME="$2"
      shift 2
      ;;
    --db-pass)
      DB_PASSWORD="$2"
      shift 2
      ;;
    --mysql-root-pass)
      MYSQL_ROOT_PASSWORD="$2"
      shift 2
      ;;
    --no-docker-mysql)
      START_DOCKER_MYSQL=false
      shift
      ;;
    --reset-db)
      RESET_DB=true
      shift
      ;;
    --build)
      RUN_BUILD=true
      shift
      ;;
    --no-dataset-bootstrap)
      DATASET_BOOTSTRAP_ENABLED=false
      shift
      ;;
    --dataset-rows)
      DATASET_BOOTSTRAP_ROWS="$2"
      shift 2
      ;;
    --dataset-seed)
      DATASET_BOOTSTRAP_RANDOM_SEED="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$DB_USERNAME" ]]; then
  read -r -p "MySQL app username [creditrisk]: " input_user
  DB_USERNAME="${input_user:-creditrisk}"
fi

if [[ -z "$DB_PASSWORD" ]]; then
  read -r -s -p "MySQL app password [creditrisk]: " input_pass
  echo
  DB_PASSWORD="${input_pass:-creditrisk}"
fi

if ! command -v mvn >/dev/null 2>&1; then
  echo "Error: 'mvn' not found in PATH." >&2
  exit 1
fi

if [[ "$START_DOCKER_MYSQL" == true ]] && ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is required when not using --no-docker-mysql." >&2
  exit 1
fi

mkdir -p "$MODEL_ARTIFACTS_PATH"
mkdir -p "$SCRIPT_DIR/data"

if [[ "$START_DOCKER_MYSQL" == true ]]; then
  export MYSQL_DATABASE="$DB_NAME"
  export MYSQL_APP_USER="$DB_USERNAME"
  export MYSQL_APP_PASSWORD="$DB_PASSWORD"
  export MYSQL_ROOT_PASSWORD
  export MYSQL_HOST_PORT

  if [[ "$RESET_DB" == true ]]; then
    echo "Resetting Docker MySQL volume..."
    docker compose down -v
  fi

  echo "Starting Docker MySQL on host port ${MYSQL_HOST_PORT}..."
  docker compose up -d mysql

  echo "Waiting for MySQL container to become healthy..."
  deadline=$((SECONDS + 120))
  while true; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' creditrisk-mysql 2>/dev/null || true)"
    case "$status" in
      healthy)
        echo "MySQL is healthy."
        break
        ;;
      unhealthy|exited|dead)
        echo "MySQL container status: ${status}" >&2
        docker compose logs --tail=100 mysql || true
        exit 1
        ;;
      *)
        if (( SECONDS >= deadline )); then
          echo "Timed out waiting for MySQL to become healthy." >&2
          docker compose logs --tail=100 mysql || true
          exit 1
        fi
        sleep 2
        ;;
    esac
  done

  DB_HOST="127.0.0.1"
  DB_PORT="$MYSQL_HOST_PORT"
fi

DB_URL="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"

export DB_URL
export DB_USERNAME
export DB_PASSWORD
export JWT_SECRET
export MODEL_ARTIFACTS_PATH
export DATASET_BOOTSTRAP_ENABLED
export DATASET_BOOTSTRAP_SOURCE_PATH
export DATASET_BOOTSTRAP_SOURCE_NAME
export DATASET_BOOTSTRAP_GENERATE_IF_MISSING
export DATASET_BOOTSTRAP_ROWS
export DATASET_BOOTSTRAP_RANDOM_SEED
export DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED
export DATASET_BOOTSTRAP_FAIL_ON_ERROR

echo "Starting Spring Boot application..."
echo "DB host: ${DB_HOST}"
echo "DB port: ${DB_PORT}"
echo "DB name: ${DB_NAME}"
echo "DB user: ${DB_USERNAME}"
echo "Dataset bootstrap: ${DATASET_BOOTSTRAP_ENABLED} (${DATASET_BOOTSTRAP_SOURCE_PATH})"
echo "UI will be available at: http://localhost:${SERVER_PORT:-8080}/login.html"

if [[ "$RUN_BUILD" == true ]]; then
  mvn -DskipTests package
fi

exec mvn spring-boot:run
