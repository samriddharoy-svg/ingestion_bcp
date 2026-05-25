#!/bin/bash
# Run this ONCE in AWS CloudShell to baseline the existing database.
# After this, Flyway knows V1 is already applied and won't re-run it.

RDS_HOST="equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com"
RDS_DB="equities_first_bcp_db"
RDS_USER="ef_bcp_admin"
RDS_PASS="admin@123!"
SCHEMAS="ingest_db,transform_db,semantic_db"

JDBC_URL="jdbc:postgresql://${RDS_HOST}:5432/${RDS_DB}"

echo "==> Step 1: Running Flyway baseline (marks V1 as already applied)..."
docker run --rm \
  flyway/flyway:10 \
  -url="${JDBC_URL}" \
  -user="${RDS_USER}" \
  -password="${RDS_PASS}" \
  -schemas="${SCHEMAS}" \
  -baselineVersion="1" \
  -baselineDescription="baseline_existing_schema" \
  baseline

echo ""
echo "==> Step 2: Checking Flyway status..."
docker run --rm \
  flyway/flyway:10 \
  -url="${JDBC_URL}" \
  -user="${RDS_USER}" \
  -password="${RDS_PASS}" \
  -schemas="${SCHEMAS}" \
  info

echo ""
echo "Done. V1 is now marked as the baseline."
echo "Future migrations (V2__, V3__, ...) will be applied by running flyway-migrate.sh"
