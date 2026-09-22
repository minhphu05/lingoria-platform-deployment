SHELL := /usr/bin/env bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PATH := /usr/local/bin:/opt/homebrew/bin:$(PATH)

.PHONY: help init-config check docker-check config \
	deploy-postgres deploy-minio deploy-redis deploy-airflow deploy-pgadmin \
	ps logs down stop clean-data clean-logs \
	show-credentials credentials

help:
	@echo "Lingoria platform deployment (Modular Docker architecture)"
	@echo ""
	@echo "Deployment commands:"
	@echo "  make init-config           Create .env from .env.example"
	@echo "  make deploy-postgres       Start clean PostgreSQL instance"
	@echo "  make deploy-minio          Start clean MinIO instance (0 buckets)"
	@echo "  make deploy-redis          Start Redis instance"
	@echo "  make deploy-airflow        Start clean Airflow 3 services"
	@echo "  make deploy-pgadmin        Start pgAdmin 4 web UI"
	@echo "  make deploy-<tool>         Deploy any tool defined in values/ and configs/"
	@echo ""
	@echo "Credentials & Management:"
	@echo "  make show-credentials      Show all auto-generated admin passwords"
	@echo "  make stop-<tool>           Stop a specific tool (e.g. make stop-postgres)"
	@echo "  make logs-<tool>           Follow logs of a specific tool (e.g. make logs-airflow)"
	@echo "  make ps                    Show status of all Lingoria containers"
	@echo "  make clean-logs            Prune runtime logs older than 6h & truncate stdout"
	@echo "  make down | make stop      Stop all running platform containers"
	@echo "  make clean-data CONFIRM=YES Delete local Docker volumes"

init-config:
	@test -f .env || cp .env.example .env
	@echo "Config ready: $(ROOT_DIR)/.env"

check: docker-check config

docker-check:
	@command -v docker >/dev/null || { echo "Docker is required" >&2; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Docker daemon is not running" >&2; exit 1; }

config:
	@test -f .env || { echo "Missing .env. Run make init-config" >&2; exit 1; }

deploy-postgres: check
	@./scripts/deploy.sh postgres

deploy-minio: check
	@./scripts/deploy.sh minio

deploy-redis: check
	@./scripts/deploy.sh redis

deploy-airflow: check
	@./scripts/deploy.sh airflow

deploy-pgadmin: check
	@./scripts/deploy.sh pgadmin

deploy-%: check
	@./scripts/deploy.sh $*

stop-%: check
	@./scripts/stop.sh $*

logs-%: check
	@./scripts/logs.sh $*

show-credentials:
	@./scripts/show-credentials.sh

credentials: show-credentials

ps: check
	@docker ps --filter "name=lingoria-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

clean-logs: check
	@./scripts/clean-logs.sh

down: check
	@./scripts/stop.sh all

stop: down

clean-data: check
	@test "$(CONFIRM)" = "YES" || { echo "Refusing to delete volumes. Re-run with CONFIRM=YES" >&2; exit 1; }
	@./scripts/stop.sh all
	@docker volume rm -f lingoria_postgres_data lingoria_minio_data lingoria_redis_data lingoria_pgadmin_data airflow_logs airflow_auth_data airflow_dags 2>/dev/null || true
	@echo "Local volumes removed."
