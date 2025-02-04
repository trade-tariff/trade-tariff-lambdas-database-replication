#!/bin/bash

SECONDS=0

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

if [ "$DATABASE_SECRET" = "" ]; then
  echo "You need to set the DATABASE_SECRET environment variable."
  exit 1
fi

if [ "$BASIC_AUTH_PASSWORD" = "" ]; then
  echo "You need to set the BASIC_AUTH_PASSWORD environment variable."
  exit 1
fi

BACKEND_SERVICES="backend-admin-uk backend-admin-xi backend-uk backend-xi worker-uk worker-xi"
BACKUP_FILE="tariff-merged-production.sql.gz"
CLUSTER_NAME="trade-tariff-cluster-$ENVIRONMENT"

DATABASE_URL=$(aws secretsmanager get-secret-value \
  --secret-id $DATABASE_SECRET \
  --query SecretString \
  --output text
)

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

curl "https://tariff:$BASIC_AUTH_PASSWORD@dumps.trade-tariff.service.gov.uk/$BACKUP_FILE" -O
gzip -d $BACKUP_FILE | psql $DATABASE_URL

echo "SQL backup restored successfully"

cat after_restore.sql | psql $DATABASE_URL

echo "Applied after restore SQL script"

echo "Starting services"
start_services

echo "Database replication complete. Time: ${SECONDS}s"
