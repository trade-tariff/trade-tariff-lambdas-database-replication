#!/bin/sh

set -eo

if [ -z "${ENVIRONMENT}" ]; then
  echo "You need to set the ENVIRONMENT environment variable."
  exit 1
fi

if [ -z "${S3_BUCKET}" ]; then
  echo "You need to set the S3_BUCKET environment variable."
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

# env vars needed for pgdump
export PGPASSWORD="$POSTGRES_PASSWORD"

BACKUP_FILE="tariff-merged-production.sql.gz"

aws s3api get-object --bucket "$S3_BUCKET" --key "$BACKUP_FILE" "$BACKUP_FILE" || exit 2

gzip -d $BACKUP_FILE

pg_restore -h "$POSTGRES_HOST" \
  -U "$POSTGRES_USER"          \
   "$POSTGRES_DATABASE"        \
  --no-acl                     \
  --no-owner                   \
  --clean                      \
  --verbose                    \
  -f "${BACKUP_FILE%.gz}"

echo "SQL backup restored successfully" && exit 0
