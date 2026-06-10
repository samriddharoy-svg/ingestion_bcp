#!/bin/bash
# Run this ONCE in AWS CloudShell to baseline the existing database.
# Atlas will mark 20260101000000 as already applied and skip it on all future runs.
# After this, only new migrations (20260530100000, 20260530110000, ...) will be applied.

RDS_HOST="bernailab-dev-postgres.c9gsc4m26hgn.ap-south-1.rds.amazonaws.com"
RDS_DB="app"
RDS_USER="infra_admin"
RDS_PASS='nVH#r0F_6lc!gfU>LJ<u?byQK?7S'

ATLAS_URL="postgresql://${RDS_USER}:${RDS_PASS}@${RDS_HOST}:5432/${RDS_DB}?sslmode=require"

# --- Pack migrations folder and upload to CloudShell before running ---
# From your laptop:
#   zip -r atlas-migrations.zip db/atlas-migrations/
#   aws s3 cp atlas-migrations.zip s3://bcp-rds-backups-2026/atlas/atlas-migrations.zip
# In CloudShell:
#   aws s3 cp s3://bcp-rds-backups-2026/atlas/atlas-migrations.zip .
#   unzip -o atlas-migrations.zip

echo "==> Step 1: Checking current Atlas migration status..."
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate status \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db"

echo ""
echo "==> Step 2: Applying migrations with baseline (skips 20260101000000, runs everything after)..."
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate apply \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db" \
  --baseline "20260101000000" \
  --allow-dirty

echo ""
echo "==> Step 3: Final status..."
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate status \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db"

echo ""
echo "Done. Baseline applied. Future migrations will be tracked in ingest_db.atlas_schema_revisions."
