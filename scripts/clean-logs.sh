#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

echo "Cleaning up container logs and old runtime logs (retention: 6 hours)..."

# 1. Clean Airflow execution logs older than 6 hours (360 minutes) inside container volume
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^lingoria-airflow-api-server$"; then
  echo "Pruning Airflow DAG task logs older than 6 hours in volume..."
  docker exec lingoria-airflow-api-server find /opt/airflow/logs -type f -mmin +360 -delete 2>/dev/null || true
  docker exec lingoria-airflow-api-server find /opt/airflow/logs -type d -empty -delete 2>/dev/null || true
fi

# 2. Truncate oversized container stdout JSON logs
docker ps -q --filter "name=lingoria-" 2>/dev/null | while read -r cid; do
  log_path="$(docker inspect --format='{{.LogPath}}' "$cid" 2>/dev/null || true)"
  if [[ -n "$log_path" && -f "$log_path" ]]; then
    # Truncate log file if accessible
    cat /dev/null > "$log_path" 2>/dev/null || true
  fi
done

echo "Container logs clean-up completed."
