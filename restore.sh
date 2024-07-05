#!/bin/sh

set -eo

if [ -z "${ENVIRONMENT}" ]; then
  echo "You need to set the ENVIRONMENT environment variable."
  exit 1
fi

if [ -z "${POSTGRES_DATABASE}" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ -z "${POSTGRES_HOST}" ]; then
  echo "You need to set the POSTGRES_HOST environment variable."
  exit 1
fi

if [ -z "${POSTGRES_USER}" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ -z "${POSTGRES_PASSWORD}" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

if [ -z "${BASIC_AUTH_PASSWORD}" ]; then
  echo "You need to set the BASIC_AUTH_PASSWORD environment variable."
  exit 1
fi

# env vars needed for pgdump
export PGPASSWORD="$POSTGRES_PASSWORD"

BACKUP_FILE="tariff-merged-production.sql.gz"

curl -o- "https://tariff:$BASIC_AUTH_PASSWORD@dumps.trade-tariff.service.gov.uk/$BACKUP_FILE" | \
  gzip -d | \
  pg_restore -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER"            \
  -d "$POSTGRES_DATABASE"        \
  --no-acl                       \
  --no-owner                     \
  --clean                        \
  --verbose                      \

echo "SQL backup restored successfully" && exit 0
