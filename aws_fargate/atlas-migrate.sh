#!/bin/bash
# Run this in AWS CloudShell whenever you have new DDL migrations to apply.
# Atlas skips already-applied migrations and only runs new ones.

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

echo "==> Checking current migration status..."
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate status \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db"

echo ""
echo "==> Applying pending migrations..."
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate apply \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db"

echo ""
echo "==> Final status:"
docker run --rm \
  -v "$(pwd)/db/atlas-migrations:/migrations" \
  arigaio/atlas:latest \
  migrate status \
  --url "${ATLAS_URL}" \
  --dir "file:///migrations" \
  --revisions-schema "ingest_db"
