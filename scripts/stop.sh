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

tool="${1:-all}"
extra_args=()
if [[ $# -ge 2 ]]; then
  extra_args=("${@:2}")
fi

stop_tool() {
  local target="$1"
  local compose_file
  compose_file="$(get_tool_compose_file "$target")"
  if [[ -f "$compose_file" ]]; then
    echo "Stopping tool: $target..."
    if [[ ${#extra_args[@]} -gt 0 ]]; then
      docker compose -p lingoria -f "$compose_file" down "${extra_args[@]}" 2>/dev/null || true
    else
      docker compose -p lingoria -f "$compose_file" down 2>/dev/null || true
    fi
  else
    echo "Warning: Compose file for '$target' not found at '$compose_file'" >&2
  fi
}

if [[ "$tool" == "all" ]]; then
  echo "Stopping all tools..."
  for t in $(get_available_tools); do
    stop_tool "$t"
  done
  echo "All tools stopped."
else
  stop_tool "$tool"
fi
