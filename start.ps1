$ErrorActionPreference = "Stop"

function Show-Usage {
    @"
Usage: .\start.ps1 [options]

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

Examples:
  .\start.ps1 --db-user creditrisk --db-pass creditrisk
  .\start.ps1 --db-port 3308 --db-user myuser --db-pass mypass
  .\start.ps1 --no-docker-mysql --db-host 127.0.0.1 --db-port 3306 --db-user root --db-pass secret
"@
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found in PATH: $Name"
    }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgumentList
    )
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($ArgumentList -join ' ')"
    }
}

function Read-PasswordOrDefault {
    param(
        [string]$Prompt,
        [string]$DefaultValue
    )
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
    if ([string]::IsNullOrWhiteSpace($plain)) {
        return $DefaultValue
    }
    return $plain
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$StartDockerMySql = $true
$ResetDb = $false
$RunBuild = $false

$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "127.0.0.1" }
$DB_PORT = if ($env:DB_PORT) { [int]$env:DB_PORT } else { 3307 }
$DB_NAME = if ($env:DB_NAME) { $env:DB_NAME } else { "credit_risk" }
$DB_USERNAME = if ($env:DB_USERNAME) { $env:DB_USERNAME } else { "" }
$DB_PASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "" }
$MYSQL_ROOT_PASSWORD = if ($env:MYSQL_ROOT_PASSWORD) { $env:MYSQL_ROOT_PASSWORD } else { "root" }
$MYSQL_HOST_PORT = if ($env:MYSQL_HOST_PORT) { [int]$env:MYSQL_HOST_PORT } else { $DB_PORT }
$JWT_SECRET = if ($env:JWT_SECRET) { $env:JWT_SECRET } else { "replace-this-with-a-long-dev-secret-key-1234567890" }
$MODEL_ARTIFACTS_PATH = if ($env:MODEL_ARTIFACTS_PATH) { $env:MODEL_ARTIFACTS_PATH } else { (Join-Path $ScriptDir "model-artifacts") }

$DATASET_BOOTSTRAP_ENABLED = if ($env:DATASET_BOOTSTRAP_ENABLED) { $env:DATASET_BOOTSTRAP_ENABLED } else { "true" }
$DATASET_BOOTSTRAP_ROWS = if ($env:DATASET_BOOTSTRAP_ROWS) { $env:DATASET_BOOTSTRAP_ROWS } else { "5000" }
$DATASET_BOOTSTRAP_RANDOM_SEED = if ($env:DATASET_BOOTSTRAP_RANDOM_SEED) { $env:DATASET_BOOTSTRAP_RANDOM_SEED } else { "42" }
$DATASET_BOOTSTRAP_SOURCE_PATH = if ($env:DATASET_BOOTSTRAP_SOURCE_PATH) { $env:DATASET_BOOTSTRAP_SOURCE_PATH } else { (Join-Path $ScriptDir "data\lending_club_synthetic.csv") }
$DATASET_BOOTSTRAP_SOURCE_NAME = if ($env:DATASET_BOOTSTRAP_SOURCE_NAME) { $env:DATASET_BOOTSTRAP_SOURCE_NAME } else { "lending-club-synthetic" }
$DATASET_BOOTSTRAP_GENERATE_IF_MISSING = if ($env:DATASET_BOOTSTRAP_GENERATE_IF_MISSING) { $env:DATASET_BOOTSTRAP_GENERATE_IF_MISSING } else { "true" }
$DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED = if ($env:DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED) { $env:DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED } else { "true" }
$DATASET_BOOTSTRAP_FAIL_ON_ERROR = if ($env:DATASET_BOOTSTRAP_FAIL_ON_ERROR) { $env:DATASET_BOOTSTRAP_FAIL_ON_ERROR } else { "false" }

$i = 0
while ($i -lt $args.Count) {
    $arg = [string]$args[$i]
    switch ($arg) {
        "--db-host" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --db-host" }
            $DB_HOST = [string]$args[$i]
        }
        "--db-port" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --db-port" }
            $DB_PORT = [int]$args[$i]
            $MYSQL_HOST_PORT = $DB_PORT
        }
        "--db-name" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --db-name" }
            $DB_NAME = [string]$args[$i]
        }
        "--db-user" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --db-user" }
            $DB_USERNAME = [string]$args[$i]
        }
        "--db-pass" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --db-pass" }
            $DB_PASSWORD = [string]$args[$i]
        }
        "--mysql-root-pass" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --mysql-root-pass" }
            $MYSQL_ROOT_PASSWORD = [string]$args[$i]
        }
        "--no-docker-mysql" {
            $StartDockerMySql = $false
        }
        "--reset-db" {
            $ResetDb = $true
        }
        "--build" {
            $RunBuild = $true
        }
        "--no-dataset-bootstrap" {
            $DATASET_BOOTSTRAP_ENABLED = "false"
        }
        "--dataset-rows" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --dataset-rows" }
            $DATASET_BOOTSTRAP_ROWS = [string]$args[$i]
        }
        "--dataset-seed" {
            $i++; if ($i -ge $args.Count) { throw "Missing value for --dataset-seed" }
            $DATASET_BOOTSTRAP_RANDOM_SEED = [string]$args[$i]
        }
        "-h" { Show-Usage; exit 0 }
        "--help" { Show-Usage; exit 0 }
        default { throw "Unknown option: $arg" }
    }
    $i++
}

if ([string]::IsNullOrWhiteSpace($DB_USERNAME)) {
    $inputUser = Read-Host "MySQL app username [creditrisk]"
    if ([string]::IsNullOrWhiteSpace($inputUser)) {
        $DB_USERNAME = "creditrisk"
    } else {
        $DB_USERNAME = $inputUser
    }
}

if ([string]::IsNullOrWhiteSpace($DB_PASSWORD)) {
    $DB_PASSWORD = Read-PasswordOrDefault -Prompt "MySQL app password [creditrisk]" -DefaultValue "creditrisk"
}

Require-Command "mvn"
if ($StartDockerMySql) {
    Require-Command "docker"
}

New-Item -ItemType Directory -Force -Path $MODEL_ARTIFACTS_PATH | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ScriptDir "data") | Out-Null

if ($StartDockerMySql) {
    $env:MYSQL_DATABASE = $DB_NAME
    $env:MYSQL_APP_USER = $DB_USERNAME
    $env:MYSQL_APP_PASSWORD = $DB_PASSWORD
    $env:MYSQL_ROOT_PASSWORD = $MYSQL_ROOT_PASSWORD
    $env:MYSQL_HOST_PORT = [string]$MYSQL_HOST_PORT

    if ($ResetDb) {
        Write-Host "Resetting Docker MySQL volume..."
        & docker compose down -v
        if ($LASTEXITCODE -ne 0) { throw "docker compose down -v failed ($LASTEXITCODE)" }
    }

    Write-Host "Starting Docker MySQL on host port $MYSQL_HOST_PORT..."
    Invoke-External docker compose up -d mysql

    Write-Host "Waiting for MySQL container to become healthy..."
    $deadline = (Get-Date).AddSeconds(120)
    while ($true) {
        $status = (& docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' creditrisk-mysql 2>$null)
        if ($LASTEXITCODE -ne 0) { $status = "" }
        $status = "$status".Trim()
        switch ($status) {
            "healthy" {
                Write-Host "MySQL is healthy."
                break
            }
            "unhealthy" {
                Write-Error "MySQL container status: $status"
                & docker compose logs --tail=100 mysql
                exit 1
            }
            "exited" {
                Write-Error "MySQL container status: $status"
                & docker compose logs --tail=100 mysql
                exit 1
            }
            "dead" {
                Write-Error "MySQL container status: $status"
                & docker compose logs --tail=100 mysql
                exit 1
            }
            default {
                if ((Get-Date) -gt $deadline) {
                    Write-Error "Timed out waiting for MySQL to become healthy."
                    & docker compose logs --tail=100 mysql
                    exit 1
                }
                Start-Sleep -Seconds 2
            }
        }
    }

    $DB_HOST = "127.0.0.1"
    $DB_PORT = $MYSQL_HOST_PORT
}

$DB_URL = "jdbc:mysql://$DB_HOST`:$DB_PORT/$DB_NAME?createDatabaseIfNotExist=true&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC"

$env:DB_URL = $DB_URL
$env:DB_USERNAME = $DB_USERNAME
$env:DB_PASSWORD = $DB_PASSWORD
$env:JWT_SECRET = $JWT_SECRET
$env:MODEL_ARTIFACTS_PATH = $MODEL_ARTIFACTS_PATH
$env:DATASET_BOOTSTRAP_ENABLED = $DATASET_BOOTSTRAP_ENABLED
$env:DATASET_BOOTSTRAP_SOURCE_PATH = $DATASET_BOOTSTRAP_SOURCE_PATH
$env:DATASET_BOOTSTRAP_SOURCE_NAME = $DATASET_BOOTSTRAP_SOURCE_NAME
$env:DATASET_BOOTSTRAP_GENERATE_IF_MISSING = $DATASET_BOOTSTRAP_GENERATE_IF_MISSING
$env:DATASET_BOOTSTRAP_ROWS = [string]$DATASET_BOOTSTRAP_ROWS
$env:DATASET_BOOTSTRAP_RANDOM_SEED = [string]$DATASET_BOOTSTRAP_RANDOM_SEED
$env:DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED = $DATASET_BOOTSTRAP_SKIP_IF_ALREADY_IMPORTED
$env:DATASET_BOOTSTRAP_FAIL_ON_ERROR = $DATASET_BOOTSTRAP_FAIL_ON_ERROR

$serverPort = if ($env:SERVER_PORT) { $env:SERVER_PORT } else { "8080" }
Write-Host "Starting Spring Boot application..."
Write-Host "DB host: $DB_HOST"
Write-Host "DB port: $DB_PORT"
Write-Host "DB name: $DB_NAME"
Write-Host "DB user: $DB_USERNAME"
Write-Host "Dataset bootstrap: $DATASET_BOOTSTRAP_ENABLED ($DATASET_BOOTSTRAP_SOURCE_PATH)"
Write-Host "UI will be available at: http://localhost:$serverPort/login.html"

if ($RunBuild) {
    Invoke-External mvn "-DskipTests" "package"
}

& mvn "spring-boot:run"
exit $LASTEXITCODE
