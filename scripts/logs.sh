#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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

tool="${1:-}"
if [[ -z "$tool" ]]; then
  echo "Usage: $0 <tool-name>" >&2
  echo "Registered tools: $(get_available_tools)" >&2
  exit 1
fi

compose_file="$(get_tool_compose_file "$tool")"
if [[ ! -f "$compose_file" ]]; then
  echo "Error: Compose file for tool '$tool' not found at '$compose_file'" >&2
  exit 1
fi

shift || true
exec docker compose -p lingoria -f "$compose_file" logs -f --tail=100 "$@"
