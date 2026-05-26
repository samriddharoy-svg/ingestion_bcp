"""
Lambda Function: FetchStocksData
Purpose: Execute fetch_loaders scripts to fetch data from APIs to SQLite
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
import sqlite3

# Add /opt/python to path for Lambda Layer dependencies
sys.path.insert(0, '/opt/python')

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')

def get_api_keys():
    """Retrieve API keys from Secrets Manager."""
    secret_name = "stock-api-keys"

    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secrets = json.loads(response['SecretString'])
        return secrets
    except Exception as e:
        print(f"Error retrieving secrets: {str(e)}")
        raise

def lambda_handler(event, context):
    """
    Execute fetch_loaders scripts to fetch data from APIs to SQLite.

    Args:
        event: EventBridge event or Step Functions input
        context: Lambda context

    Returns:
        dict: Execution status and results
    """
    start_time = datetime.utcnow()
    print(f"=== Starting API data fetch at {start_time} ===")

    try:
        # Get API keys from Secrets Manager
        print("Retrieving API keys from Secrets Manager...")
        secrets = get_api_keys()
        os.environ['FMP_API_KEY'] = secrets['FMP_API_KEY']
        os.environ['TIINGO_API_KEY'] = secrets['TIINGO_API_KEY']
        print("✓ API keys retrieved successfully")

        # Set up paths
        efs_mount = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
        db_path = f"{efs_mount}/portfolio.db"
        scripts_dir = f"{efs_mount}/fetch_loaders"

        print(f"EFS mount path: {efs_mount}")
        print(f"Database path: {db_path}")
        print(f"Scripts directory: {scripts_dir}")

        # Verify EFS is mounted
        if not os.path.exists(efs_mount):
            raise Exception(f"EFS mount point {efs_mount} does not exist")

        print(f"✓ EFS mounted successfully")

        # Scripts to run in order (excluding FMP /v3/ endpoints that fail)
        scripts = [
            'fetch_stocks.py',          # Yahoo Finance - stocks + company_profile
            'fetch_price_data.py',      # Yahoo Finance - historical prices
            'fetch_benchmarks.py',      # FMP - benchmark indices (may fail)
            'fetch_mappings.py',        # Config-based - mappings + flags
            'fetch_live_prices.py'      # FMP stable/quote-short - live prices
        ]

        results = {}
        failed_scripts = []

        # Execute each script
        for script in scripts:
            script_path = f"{scripts_dir}/{script}"

            # Check if script exists
            if not os.path.exists(script_path):
                print(f"⚠ Script not found: {script_path}")
                results[script] = {
                    'status': 'SKIPPED',
                    'error': 'Script file not found'
                }
                continue

            print(f"\n{'='*60}")
            print(f"Executing: {script}")
            print(f"{'='*60}")

            try:
                result = subprocess.run(
                    [sys.executable, script_path],
                    cwd=efs_mount,
                    capture_output=True,
                    text=True,
                    timeout=600,  # 10 minute timeout per script
                    env=os.environ.copy()
                )

                # Print stdout for debugging
                if result.stdout:
                    print(result.stdout)

                if result.returncode != 0:
                    print(f"✗ ERROR in {script}")
                    print(f"Return code: {result.returncode}")
                    print(f"stderr: {result.stderr}")

                    results[script] = {
                        'status': 'FAILED',
                        'return_code': result.returncode,
                        'error': result.stderr[-500:] if result.stderr else 'Unknown error',
                        'output': result.stdout[-500:] if result.stdout else ''
                    }
                    failed_scripts.append(script)
                else:
                    print(f"✓ SUCCESS: {script}")
                    results[script] = {
                        'status': 'SUCCESS',
                        'output': result.stdout[-500:] if result.stdout else ''
                    }

            except subprocess.TimeoutExpired:
                print(f"✗ TIMEOUT: {script} exceeded 10 minute limit")
                results[script] = {
                    'status': 'TIMEOUT',
                    'error': 'Script execution exceeded 10 minute timeout'
                }
                failed_scripts.append(script)
            except Exception as e:
                print(f"✗ EXCEPTION in {script}: {str(e)}")
                results[script] = {
                    'status': 'EXCEPTION',
                    'error': str(e)
                }
                failed_scripts.append(script)

        # Get row counts from SQLite
        print(f"\n{'='*60}")
        print("Querying SQLite database for row counts...")
        print(f"{'='*60}")

        try:
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()

            stocks_count = cur.execute("SELECT COUNT(*) FROM stocks").fetchone()[0]
            company_profile_count = cur.execute("SELECT COUNT(*) FROM company_profile").fetchone()[0]
            prices_count = cur.execute("SELECT COUNT(*) FROM stocks_price_data").fetchone()[0]
            mappings_count = cur.execute("SELECT COUNT(*) FROM stocks_benchmark_mapping").fetchone()[0]
            flags_count = cur.execute("SELECT COUNT(*) FROM stocks_flags").fetchone()[0]
            instruments_count = cur.execute("SELECT COUNT(*) FROM instruments").fetchone()[0]

            conn.close()

            print(f"✓ Stocks: {stocks_count}")
            print(f"✓ Company Profiles: {company_profile_count}")
            print(f"✓ Price Records: {prices_count}")
            print(f"✓ Benchmark Mappings: {mappings_count}")
            print(f"✓ Data Flags: {flags_count}")
            print(f"✓ Instruments: {instruments_count}")

        except Exception as e:
            print(f"⚠ Warning: Could not query database: {str(e)}")
            stocks_count = 0
            company_profile_count = 0
            prices_count = 0
            mappings_count = 0
            flags_count = 0
            instruments_count = 0

        # Determine overall status
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()

        print(f"\n{'='*60}")
        print(f"Execution Summary")
        print(f"{'='*60}")
        print(f"Duration: {duration:.2f} seconds")
        print(f"Failed scripts: {len(failed_scripts)}")
        print(f"Successful scripts: {len(scripts) - len(failed_scripts)}")

        # Determine status
        if len(failed_scripts) == len(scripts):
            status = 'FAILED'
        elif failed_scripts:
            # Allow partial success (e.g., benchmarks might fail but core data succeeds)
            status = 'PARTIAL_SUCCESS' if stocks_count > 0 and prices_count > 0 else 'FAILED'
        else:
            status = 'SUCCESS'

        print(f"Overall Status: {status}")
        print(f"=== Execution completed at {end_time} ===\n")

        return {
            'status': status,
            'execution_time_seconds': duration,
            'failed_scripts': failed_scripts,
            'fetch': {
                'stocks_count': stocks_count,
                'company_profile_count': company_profile_count,
                'prices_count': prices_count,
                'mappings_count': mappings_count,
                'flags_count': flags_count,
                'instruments_count': instruments_count
            },
            'results': results,
            'timestamp': end_time.isoformat(),
            'event': event  # Pass through for Step Functions
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
