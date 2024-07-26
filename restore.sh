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

# env vars needed for pgdump
export PGPASSWORD="$POSTGRES_PASSWORD"

BACKUP_FILE="tariff-merged-production.sql.gz"

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
