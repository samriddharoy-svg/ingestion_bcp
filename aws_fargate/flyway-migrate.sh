#!/bin/bash
# Run this in AWS CloudShell whenever you have new DDL migrations to apply.
# It skips migrations already applied and only runs new ones.

RDS_HOST="equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com"
RDS_DB="equities_first_bcp_db"
RDS_USER="ef_bcp_admin"
RDS_PASS="admin@123!"
SCHEMAS="ingest_db,transform_db,semantic_db"

JDBC_URL="jdbc:postgresql://${RDS_HOST}:5432/${RDS_DB}"

# --- Pack migrations folder and upload to CloudShell before running ---
# From your laptop (PowerShell):
#   Compress-Archive db/migrations /tmp/migrations.zip
#   aws s3 cp /tmp/migrations.zip s3://bcp-rds-backups-2026/flyway/migrations.zip
# In CloudShell:
#   aws s3 cp s3://bcp-rds-backups-2026/flyway/migrations.zip .
#   unzip -o migrations.zip -d .

echo "==> Checking current migration status..."
docker run --rm \
  -v "$(pwd)/db/migrations:/flyway/sql" \
  flyway/flyway:10 \
  -url="${JDBC_URL}" \
  -user="${RDS_USER}" \
  -password="${RDS_PASS}" \
  -schemas="${SCHEMAS}" \
  info

echo ""
echo "==> Applying pending migrations..."
docker run --rm \
  -v "$(pwd)/db/migrations:/flyway/sql" \
  flyway/flyway:10 \
  -url="${JDBC_URL}" \
  -user="${RDS_USER}" \
  -password="${RDS_PASS}" \
  -schemas="${SCHEMAS}" \
  migrate

echo ""
echo "==> Final status:"
docker run --rm \
  -v "$(pwd)/db/migrations:/flyway/sql" \
  flyway/flyway:10 \
  -url="${JDBC_URL}" \
  -user="${RDS_USER}" \
  -password="${RDS_PASS}" \
  -schemas="${SCHEMAS}" \
  info
