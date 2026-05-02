"""
Full daily pg_dump of equities_first_bcp_db -> S3
Scheduled via EventBridge -> Step Functions -> Fargate

Required env vars (from Secrets Manager in Fargate, from .env locally):
    RDS_HOST, RDS_PORT, RDS_USER, RDS_PASSWORD, RDS_DATABASE
    BACKUP_S3_BUCKET  (default: equities-first-bcp-backups)
"""

import os
import sys
import subprocess
import boto3
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from config import AWS_RDS

S3_BUCKET  = os.getenv("BACKUP_S3_BUCKET", "equities-first-bcp-backups")
S3_PREFIX  = "daily"
AWS_REGION = "ap-south-1"
DUMP_DIR   = "/tmp"

DB_HOST     = AWS_RDS["host"]
DB_PORT     = str(AWS_RDS["port"])
DB_NAME     = AWS_RDS["database"]
DB_USER     = AWS_RDS["user"]
DB_PASSWORD = AWS_RDS["password"]


def run_pg_dump(dump_path):
    """Full pg_dump of all schemas in the database."""
    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASSWORD

    cmd = [
        "pg_dump",
        f"--host={DB_HOST}",
        f"--port={DB_PORT}",
        f"--username={DB_USER}",
        f"--dbname={DB_NAME}",
        "--format=custom",    # compressed, supports pg_restore
        "--no-owner",
        "--no-acl",
        "--verbose",
        f"--file={dump_path}",
    ]

    print(f"  Running: pg_dump {DB_NAME} @ {DB_HOST}")
    result = subprocess.run(cmd, env=env, capture_output=True, text=True)

    if result.returncode != 0:
        raise RuntimeError(f"pg_dump failed:\n{result.stderr}")

    size_mb = os.path.getsize(dump_path) / (1024 * 1024)
    print(f"  Dump size: {size_mb:.1f} MB")


def upload_to_s3(local_path, s3_key):
    """Upload dump file to S3."""
    s3 = boto3.client("s3", region_name=AWS_REGION)
    print(f"  Uploading -> s3://{S3_BUCKET}/{s3_key}")
    s3.upload_file(
        local_path, S3_BUCKET, s3_key,
        ExtraArgs={"ServerSideEncryption": "AES256"}
    )
    print(f"  Done: s3://{S3_BUCKET}/{s3_key}")
    return f"s3://{S3_BUCKET}/{s3_key}"


def main():
    today     = datetime.utcnow().strftime("%Y-%m-%d")
    timestamp = datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
    filename  = f"{DB_NAME}_{timestamp}.dump"
    dump_path = os.path.join(DUMP_DIR, filename)
    s3_key    = f"{S3_PREFIX}/{today}/{filename}"

    print("=" * 60)
    print("FULL DATABASE BACKUP -> S3")
    print("=" * 60)
    print(f"DB      : {DB_NAME} @ {DB_HOST}")
    print(f"Target  : s3://{S3_BUCKET}/{s3_key}")
    print(f"Time    : {timestamp} UTC")
    print("=" * 60)

    try:
        print("\n[1/3] Running pg_dump (full database)...")
        run_pg_dump(dump_path)

        print("\n[2/3] Uploading to S3...")
        s3_uri = upload_to_s3(dump_path, s3_key)

        print("\n[3/3] Cleanup...")
        os.remove(dump_path)

        print(f"\nBackup complete: {s3_uri}")
        print("=" * 60)

    except Exception as e:
        try:
            os.remove(dump_path)
        except OSError:
            pass
        print(f"\nBACKUP FAILED: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
