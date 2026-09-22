#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

get_json_prop() {
  local file="$1"
  local prop="$2"
  local fallback="$3"
  if [[ -f "$file" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local val
      val="$(jq -r ".$prop // empty" "$file" 2>/dev/null || true)"
      if [[ -n "$val" ]]; then
        echo "$val"
        return
      fi
    elif command -v python3 >/dev/null 2>&1; then
      local val
      val="$(python3 -c "import json; print(json.load(open('$file')).get('$prop', ''))" 2>/dev/null || true)"
      if [[ -n "$val" ]]; then
        echo "$val"
        return
      fi
    fi
  fi
  echo "$fallback"
}

running_containers="$(docker ps --format '{{.Names}}' 2>/dev/null || true)"

is_running() {
  local name="$1"
  echo "$running_containers" | grep -q "^${name}$"
}

echo "=================================================================================="
echo "       LINGORIA PLATFORM - CONTAINER VOLUME ADMIN CREDENTIALS"
echo "=================================================================================="
printf "%-14s %-24s %-22s %s\n" "Tool" "Admin / Superuser" "Password" "Access / URL"
echo "----------------------------------------------------------------------------------"

# 1. PostgreSQL
pg_container="lingoria-postgres"
pg_user="$(get_json_prop "configs/postgres.json" "superuser" "postgres")"
pg_port="$(get_json_prop "configs/postgres.json" "port" "55432")"
if is_running "$pg_container"; then
  pg_pwd="$(docker exec "$pg_container" cat /var/lib/postgresql/data/.admin_password 2>/dev/null || echo '[Not found in volume]')"
  printf "%-14s %-24s %-22s %s\n" "Postgres" "$pg_user" "$pg_pwd" "localhost:${pg_port}"
else
  printf "%-14s %-24s %-22s %s\n" "Postgres" "$pg_user" "[Container stopped]" "localhost:${pg_port}"
fi

# 2. MinIO
minio_container="lingoria-minio"
minio_user="$(get_json_prop "configs/minio.json" "admin" "minioadmin")"
minio_port="$(get_json_prop "configs/minio.json" "console_port" "9001")"
if is_running "$minio_container"; then
  minio_pwd="$(docker exec "$minio_container" cat /data/.minio_admin_password 2>/dev/null || echo '[Not found in volume]')"
  printf "%-14s %-24s %-22s %s\n" "Minio" "$minio_user" "$minio_pwd" "http://localhost:${minio_port}"
else
  printf "%-14s %-24s %-22s %s\n" "Minio" "$minio_user" "[Container stopped]" "http://localhost:${minio_port}"
fi

# 3. Airflow
airflow_container="lingoria-airflow-api-server"
airflow_user="$(get_json_prop "configs/airflow.json" "admin" "admin")"
airflow_port="$(get_json_prop "configs/airflow.json" "api_server_port" "8080")"
if is_running "$airflow_container"; then
  airflow_raw="$(docker exec "$airflow_container" cat /opt/airflow/auth/simple_auth_manager_passwords.json.generated 2>/dev/null || echo '')"
  if [[ -n "$airflow_raw" ]]; then
    airflow_pwd="$(echo "$airflow_raw" | grep -o '"admin": *"[^"]*"' | cut -d'"' -f4 || echo "$airflow_raw")"
  else
    airflow_pwd="[Not found in volume]"
  fi
  printf "%-14s %-24s %-22s %s\n" "Airflow" "$airflow_user" "$airflow_pwd" "http://localhost:${airflow_port}"
else
  printf "%-14s %-24s %-22s %s\n" "Airflow" "$airflow_user" "[Container stopped]" "http://localhost:${airflow_port}"
fi

# 4. pgAdmin
pgadmin_container="lingoria-pgadmin"
pgadmin_user="$(get_json_prop "configs/pgadmin.json" "admin" "admin@lingoria.local")"
pgadmin_port="$(get_json_prop "configs/pgadmin.json" "port" "5050")"
if is_running "$pgadmin_container"; then
  pgadmin_pwd="$(docker exec "$pgadmin_container" cat /var/lib/pgadmin/.admin_password 2>/dev/null || echo '[Not found in volume]')"
  printf "%-14s %-24s %-22s %s\n" "Pgadmin" "$pgadmin_user" "$pgadmin_pwd" "http://localhost:${pgadmin_port}"
else
  printf "%-14s %-24s %-22s %s\n" "Pgadmin" "$pgadmin_user" "[Container stopped]" "http://localhost:${pgadmin_port}"
fi

# 5. Redis
redis_container="lingoria-redis"
redis_user="$(get_json_prop "configs/redis.json" "admin" "default")"
redis_port="$(get_json_prop "configs/redis.json" "port" "6379")"
if is_running "$redis_container"; then
  printf "%-14s %-24s %-22s %s\n" "Redis" "$redis_user" "[No auth / Open cache]" "localhost:${redis_port}"
else
  printf "%-14s %-24s %-22s %s\n" "Redis" "$redis_user" "[Container stopped]" "localhost:${redis_port}"
fi

echo "=================================================================================="
echo "* Admin usernames and ports are defined in configs/<tool>.json"
echo "* Passwords are generated and stored exclusively inside container volumes."
echo "* Inter-service communication credentials (e.g. Airflow -> Postgres) are in .env"
echo "=================================================================================="
