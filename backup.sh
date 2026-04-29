#!/bin/bash
set -e

DB_HOST="equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com"
DB_NAME="equities_first_dev_db"
DB_USER="ef_dev_admin"
PORT="5432"

S3_BUCKET="s3://test-bij/equities-first-backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

BACKUP_FILE="/tmp/${DB_NAME}_${DATE}.dump"

echo "Starting backup at $(date)"

pg_dump -h $DB_HOST -p $PORT -U $DB_USER -d $DB_NAME -F c -Z 9 -f $BACKUP_FILE

echo "Backup successful"

aws s3 cp $BACKUP_FILE $S3_BUCKET/dev/$(date +%Y/%m/%d)/

echo "Upload successful"

rm $BACKUP_FILE
echo "Cleanup done"
