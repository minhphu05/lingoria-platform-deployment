#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

service="${1:?usage: wait-for-service.sh SERVICE [TIMEOUT_SECONDS]}"
timeout="${2:-90}"
start="$(date +%s)"
container="lingoria-$service"

echo "Waiting for $service to become ready..."

while true; do
  has_healthcheck="$(docker inspect --format '{{if .State.Health}}yes{{else}}no{{end}}' "$container" 2>/dev/null || true)"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"

  if [[ "$has_healthcheck" == "no" && "$health" == "running" ]]; then
    echo "$service is running"
    exit 0
  elif [[ "$health" == "healthy" ]]; then
    echo "$service is healthy"
    exit 0
  fi

  if (( $(date +%s) - start >= timeout )); then
    echo "Timed out waiting for $service (current status: ${health:-not_found})" >&2
    docker logs --tail=50 "$container" 2>/dev/null || true
    exit 1
  fi
  sleep 2
done
