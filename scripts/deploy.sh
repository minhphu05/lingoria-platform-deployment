#!/usr/bin/env bash
set -Eeuo pipefail

# Ensure standard bin paths are in PATH
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# ==============================================================================
# TOOL REGISTRY: Map tool name to its compose file in values/
# Compatible with macOS default Bash 3.2+ and Linux Bash 4/5
#
# To add a new tool (e.g. mongodb):
# 1. Add 'mongodb) echo "values/mongodb-compose.yaml" ;;' below
# 2. Add configs/mongodb.json
# 3. Add values/mongodb-compose.yaml
# ==============================================================================
get_tool_compose_file() {
  local target="$1"
  case "$target" in
    postgres) echo "values/postgres-compose.yaml" ;;
    minio)    echo "values/minio-compose.yaml" ;;
    redis)    echo "values/redis-compose.yaml" ;;
    airflow)  echo "values/airflow-compose.yaml" ;;
    pgadmin)  echo "values/pgadmin-compose.yaml" ;;
    *)        echo "values/${target}-compose.yaml" ;;
  esac
}

get_available_tools() {
  echo "postgres minio redis airflow pgadmin"
}

# Parse flags
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

tool="${1:-}"
if [[ -z "$tool" ]]; then
  echo "Usage: $0 [--dry-run] <tool-name>" >&2
  echo "Registered tools: $(get_available_tools)" >&2
  exit 1
fi

# Locate compose file
compose_file="$(get_tool_compose_file "$tool")"
if [[ ! -f "$compose_file" ]]; then
  echo "Error: Compose file for tool '$tool' not found at '$compose_file'" >&2
  exit 1
fi

# Check .env
if [[ ! -f .env ]]; then
  echo "Missing .env. Run: make init-config" >&2
  exit 1
fi

# Load .env (secrets & inter-service passwords)
# shellcheck disable=SC1091
set -a
source .env
set +a

# Load configs/<tool>.json if available
config_file="configs/${tool}.json"
tool_upper="$(echo "$tool" | tr '[:lower:]' '[:upper:]')"
if [[ -f "$config_file" ]]; then
  if command -v jq >/dev/null 2>&1; then
    eval "$(jq -r --arg tu "$tool_upper" 'to_entries | .[] | (if (.key | ascii_upcase) != "UID" then "export " + (.key | ascii_upcase) + "=\( .value | @sh )\n" else "" end) + "export " + $tu + "_" + (.key | ascii_upcase) + "=\( .value | @sh )"' "$config_file")"
  elif command -v python3 >/dev/null 2>&1; then
    eval "$(python3 -c "import json, sys
with open('$config_file') as f:
    d = json.load(f)
tu = sys.argv[1].upper()
for k, v in d.items():
    k_up = k.upper()
    val = json.dumps(str(v))
    if k_up != 'UID':
        print(f'export {k_up}={val}')
    print(f'export {tu}_{k_up}={val}')
" "$tool")"
  fi
fi

# Ensure shared docker network exists
NETWORK_NAME="${COMPOSE_NETWORK:-lingoria_network}"
if [[ "$DRY_RUN" -eq 0 ]] && command -v docker >/dev/null 2>&1; then
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Creating shared network: $NETWORK_NAME"
    docker network create "$NETWORK_NAME" >/dev/null 2>&1 || true
  fi
fi

# If dry-run, only validate compose config
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Validating configuration for '$tool' ($compose_file)..."
  docker compose -p lingoria --env-file .env -f "$compose_file" config
  exit 0
fi

echo "Deploying tool: $tool using $compose_file..."

if [[ "$tool" == "airflow" ]]; then
  # Airflow requires database migration before starting servers
  echo "Running Airflow database initialization (airflow db migrate)..."
  docker compose -p lingoria --env-file .env -f "$compose_file" up airflow-init
  echo "Starting Airflow daemon services..."
  docker compose -p lingoria --env-file .env -f "$compose_file" up -d --remove-orphans airflow-api-server airflow-scheduler airflow-dag-processor
  echo "Airflow deployed. Access at http://localhost:${AIRFLOW_API_SERVER_PORT:-8080}"
else
  docker compose -p lingoria --env-file .env -f "$compose_file" up -d
  # Wait for healthcheck if service is postgres, minio, or redis
  if [[ "$tool" =~ ^(postgres|minio|redis)$ ]]; then
    ./scripts/wait-for-service.sh "$tool"
  fi
  echo "$tool deployed successfully."
fi
