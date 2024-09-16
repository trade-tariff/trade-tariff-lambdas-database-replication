#!/bin/bash

[[ "$TRACE" ]] && set -o xtrace
set -o errexit
set -o nounset
set -o pipefail
set -o noclobber

declare -A SERVICE_COUNTS

if [ "$ENVIRONMENT" = "" ]; then
  echo "You need to set the ENVIRONMENT environment variable."
  exit 1
fi

if [ "$POSTGRES_DATABASE" = "" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "$POSTGRES_HOST" = "" ]; then
  echo "You need to set the POSTGRES_HOST environment variable."
  exit 1
fi

if [ "$POSTGRES_USER" = "" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "$POSTGRES_PASSWORD" = "" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ "$BASIC_AUTH_PASSWORD" = "" ]; then
  echo "You need to set the BASIC_AUTH_PASSWORD environment variable."
  exit 1
fi

export PGPASSWORD="$POSTGRES_PASSWORD" # env var needed for psql
BACKEND_SERVICES="backend-admin-uk backend-admin-xi backend-uk backend-xi worker-uk worker-xi"
BACKUP_FILE="tariff-merged-production.sql.gz"
CLUSTER_NAME="trade-tariff-cluster-$ENVIRONMENT"

get_desired_count_for_service() {
    local service=$1

    aws ecs describe-services --cluster trade-tariff-cluster-$ENVIRONMENT \
        --services $service \
        --query 'services[0].desiredCount' \
        --output text
}

set_desired_count_for_service_to() {
    local service=$1
    local desired_count=$2

    aws ecs update-service --cluster trade-tariff-cluster-$ENVIRONMENT \
        --service $service \
        --desired-count $desired_count > /dev/null
}

stop_services() {
  for service in $BACKEND_SERVICES; do
      SERVICE_COUNTS[$service]=$(get_desired_count_for_service $service)

      set_desired_count_for_service_to $service 0
  done

  sleep 20 # Give the services time to stop
}

start_services() {
  for service in $BACKEND_SERVICES; do
      local desired_count
      desired_count=${SERVICE_COUNTS[$service]}

      if [ $desired_count -eq 0 ]; then
          desired_count=1
      fi

      set_desired_count_for_service_to $service $desired_count
  done
}

echo "Stopping services"
stop_services

curl -o- "https://tariff:$BASIC_AUTH_PASSWORD@dumps.trade-tariff.service.gov.uk/$BACKUP_FILE" | \
  gzip -d | \
  psql -h "$POSTGRES_HOST"         \
  -U "$POSTGRES_USER"              \
  -d "$POSTGRES_DATABASE"

echo "SQL backup restored successfully"

cat after_restore.sql | psql -h "$POSTGRES_HOST"         \
  -U "$POSTGRES_USER"              \
  -d "$POSTGRES_DATABASE"

echo "Applied after restore SQL script"

echo "Starting services"
start_services
