#!/bin/sh

set -eo

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

stop_connected_tasks() {
  for service in BACKEND_SERVICES; do
    local tasks
    tasks=$(aws ecs list-tasks --cluster trade-tariff-cluster-$ENVIRONMENT --service-name $service | jq -r '.taskArns[]')
    for task in $tasks; do
      aws ecs stop-task --cluster trade-tariff-cluster-$ENVIRONMENT --task $task
    done
  done
}

start_connected_tasks() {
  for service in BACKEND_SERVICES; do
    local tasks
    tasks=$(aws ecs list-tasks --cluster trade-tariff-cluster-$ENVIRONMENT --service-name $service | jq -r '.taskArns[]')
    for task in $tasks; do
      aws ecs start-task --cluster trade-tariff-cluster-$ENVIRONMENT --task $task
    done
  done
}

echo "Stopping connected tasks"
stop_connected_tasks

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

echo "Starting connected tasks"
start_connected_tasks
