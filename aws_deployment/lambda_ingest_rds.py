"""
Lambda Function: IngestToRDS
Purpose: Execute ingestion scripts to copy SQLite data to RDS PostgreSQL
Runtime: Python 3.11
Timeout: 15 minutes (900 seconds)
Memory: 2048 MB
"""

import json
import os
import sys
import subprocess
import boto3
from datetime import datetime

# Add /opt/python to path for Lambda Layer dependencies
sys.path.insert(0, '/opt/python')

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')

def get_rds_credentials():
    """Retrieve RDS credentials from Secrets Manager."""
    secret_name = os.environ.get('RDS_SECRET_NAME', 'rds-credentials')

    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        credentials = json.loads(response['SecretString'])
        return credentials
    except Exception as e:
        print(f"Error retrieving RDS credentials: {str(e)}")
        raise

def lambda_handler(event, context):
    """
    Execute ingestion scripts to copy SQLite data to RDS.

    Args:
        event: Output from FetchStocksData Lambda (via Step Functions)
        context: Lambda context

    Returns:
        dict: Ingestion status and results
    """
    start_time = datetime.utcnow()
    print(f"=== Starting RDS ingestion at {start_time} ===")

    try:
        # Get input from previous step (FetchStocksData)
        print(f"Input event: {json.dumps(event, indent=2)}")

        # Verify previous step succeeded
        if event.get('status') not in ['SUCCESS', 'PARTIAL_SUCCESS']:
            print(f"⚠ Previous step status: {event.get('status')}")
            print("Aborting RDS ingestion due to failed data fetch")
            return {
                'status': 'SKIPPED',
                'reason': 'Previous step (API fetch) did not succeed',
                'previous_status': event.get('status'),
                'timestamp': datetime.utcnow().isoformat()
            }

        # Get RDS credentials from Secrets Manager
        print("Retrieving RDS credentials from Secrets Manager...")
        rds_creds = get_rds_credentials()

        # Set environment variables for ingestion scripts
        os.environ['RDS_HOST'] = rds_creds['host']
        os.environ['RDS_PORT'] = str(rds_creds.get('port', 5432))
        os.environ['RDS_USER'] = rds_creds['username']
        os.environ['RDS_PASSWORD'] = rds_creds['password']
        os.environ['RDS_DATABASE'] = rds_creds.get('database', 'ingest_db')

        print("✓ RDS credentials retrieved successfully")
        print(f"  Host: {rds_creds['host']}")
        print(f"  Database: {rds_creds.get('database', 'ingest_db')}")

        # Set up paths
        efs_mount = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
        db_path = f"{efs_mount}/portfolio.db"
        ingestion_dir = efs_mount

        print(f"EFS mount path: {efs_mount}")
        print(f"SQLite database path: {db_path}")
        print(f"Ingestion directory: {ingestion_dir}")

        # Verify EFS is mounted
        if not os.path.exists(efs_mount):
            raise Exception(f"EFS mount point {efs_mount} does not exist")

        # Verify SQLite database exists
        if not os.path.exists(db_path):
            raise Exception(f"SQLite database not found at {db_path}")

        print(f"✓ EFS mounted and database found")

        # Run the master ingestion script
        print(f"\n{'='*60}")
        print("Executing: run_all.py (RDS ingestion)")
        print(f"{'='*60}\n")

        result = subprocess.run(
            [sys.executable, 'run_all.py'],
            cwd=ingestion_dir,
            capture_output=True,
            text=True,
            timeout=600,  # 10 minute timeout
            env=os.environ.copy()
        )

        # Print stdout for debugging
        if result.stdout:
            print(result.stdout)

        if result.returncode != 0:
            print(f"\n✗ ERROR in RDS ingestion")
            print(f"Return code: {result.returncode}")
            print(f"stderr: {result.stderr}")

            return {
                'status': 'FAILED',
                'return_code': result.returncode,
                'error': result.stderr,
                'output': result.stdout[-1000:] if result.stdout else '',
                'timestamp': datetime.utcnow().isoformat()
            }

        print(f"\n✓ SUCCESS: RDS ingestion completed")

        # Parse output for row counts (extract from run_all.py output)
        # This is a simple extraction - enhance as needed
        output_lines = result.stdout.split('\n') if result.stdout else []

        # Try to extract meaningful stats from output
        stocks_ingested = 0
        prices_ingested = 0

        for line in output_lines:
            if 'stocks' in line.lower() and 'inserted' in line.lower():
                try:
                    # Extract number from line like "Inserted 9 rows"
                    parts = line.split()
                    for i, part in enumerate(parts):
                        if part.lower() == 'inserted' and i + 1 < len(parts):
                            stocks_ingested = int(parts[i + 1])
                            break
                except:
                    pass
            elif 'price' in line.lower() and 'inserted' in line.lower():
                try:
                    parts = line.split()
                    for i, part in enumerate(parts):
                        if part.lower() == 'inserted' and i + 1 < len(parts):
                            prices_ingested = int(parts[i + 1])
                            break
                except:
                    pass

        # Use data from previous step if extraction failed
        if stocks_ingested == 0 and event.get('fetch'):
            stocks_ingested = event['fetch'].get('stocks_count', 0)
        if prices_ingested == 0 and event.get('fetch'):
            prices_ingested = event['fetch'].get('prices_count', 0)

        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()

        print(f"\n{'='*60}")
        print(f"Execution Summary")
        print(f"{'='*60}")
        print(f"Duration: {duration:.2f} seconds")
        print(f"Stocks ingested: {stocks_ingested}")
        print(f"Prices ingested: {prices_ingested}")
        print(f"=== Execution completed at {end_time} ===\n")

        return {
            'status': 'SUCCESS',
            'execution_time_seconds': duration,
            'ingest': {
                'stocks_count': stocks_ingested,
                'prices_count': prices_ingested
            },
            'output': result.stdout[-1000:] if result.stdout else '',
            'timestamp': end_time.isoformat(),
            'fetch': event.get('fetch', {})  # Pass through from previous step
        }

    except subprocess.TimeoutExpired:
        print(f"\n✗ TIMEOUT: RDS ingestion exceeded 10 minute limit")
        return {
            'status': 'TIMEOUT',
            'error': 'RDS ingestion exceeded 10 minute timeout',
            'timestamp': datetime.utcnow().isoformat()
        }
    except Exception as e:
        error_msg = f"Lambda execution failed: {str(e)}"
        print(f"\n✗ {error_msg}")

        import traceback
        traceback.print_exc()

        return {
            'status': 'FAILED',
            'error': error_msg,
            'traceback': traceback.format_exc(),
            'timestamp': datetime.utcnow().isoformat()
        }
