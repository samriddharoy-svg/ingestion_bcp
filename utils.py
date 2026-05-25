"""
Utility functions for AWS RDS Ingestion Scripts
"""
import psycopg2
import sqlite3
import requests
from datetime import datetime
from typing import Optional, List, Dict, Any
from config import AWS_RDS, SQLITE_DB_PATH, FMP_API_KEY, FMP_BASE_URL, TIINGO_API_KEY, TIINGO_BASE_URL


def get_aws_connection():
    """Get connection to AWS RDS PostgreSQL database."""
    print(f"[DEBUG] Connecting to PostgreSQL:")
    print(f"  Host: {AWS_RDS['host']}")
    print(f"  Port: {AWS_RDS['port']}")
    print(f"  Database: {AWS_RDS['database']}")
    print(f"  User: {AWS_RDS['user']}")
    print(f"  SSL Mode: {AWS_RDS['sslmode']}")

    return psycopg2.connect(
        host=AWS_RDS['host'],
        port=AWS_RDS['port'],
        database=AWS_RDS['database'],
        user=AWS_RDS['user'],
        password=AWS_RDS['password'],
        sslmode=AWS_RDS['sslmode']
    )


def get_sqlite_connection():
    """Get connection to local SQLite database."""
    return sqlite3.connect(SQLITE_DB_PATH)


def get_connection():
    """
    Get database connection based on USE_RDS_DIRECT config.
    Returns RDS connection if USE_RDS_DIRECT=true, otherwise SQLite.
    """
    from config import USE_RDS_DIRECT
    if USE_RDS_DIRECT:
        return get_aws_connection()
    else:
        return get_sqlite_connection()


def fmp_request(endpoint: str, params: Optional[Dict] = None) -> Dict:
    """Make a request to FMP API."""
    if params is None:
        params = {}
    params['apikey'] = FMP_API_KEY
    
    url = f"{FMP_BASE_URL}{endpoint}"
    response = requests.get(url, params=params)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"FMP API Error: {response.status_code} - {response.text}")
        return {}


def truncate_table(table_name: str, cascade: bool = False):
    """Truncate a table in AWS RDS."""
    conn = get_aws_connection()
    cur = conn.cursor()
    
    try:
        cascade_str = "CASCADE" if cascade else ""
        cur.execute(f"TRUNCATE TABLE {table_name} {cascade_str}")
        conn.commit()
        print(f"✓ Truncated {table_name}")
    except Exception as e:
        conn.rollback()
        print(f"✗ Error truncating {table_name}: {e}")
    finally:
        conn.close()


def get_row_count(table_name: str) -> int:
    """Get row count from AWS RDS table."""
    conn = get_aws_connection()
    cur = conn.cursor()
    
    try:
        cur.execute(f"SELECT COUNT(*) FROM {table_name}")
        count = cur.fetchone()[0]
        return count
    except Exception as e:
        print(f"Error getting count for {table_name}: {e}")
        return -1
    finally:
        conn.close()


def table_exists(table_name: str) -> bool:
    """Check if a table exists in AWS RDS."""
    # Parse schema.table
    parts = table_name.split('.')
    if len(parts) == 2:
        schema, table = parts
    else:
        schema, table = 'public', parts[0]
    
    conn = get_aws_connection()
    cur = conn.cursor()
    
    try:
        cur.execute("""
            SELECT COUNT(*) 
            FROM information_schema.tables 
            WHERE table_schema = %s AND table_name = %s
        """, (schema, table))
        return cur.fetchone()[0] > 0
    finally:
        conn.close()


def execute_batch_insert(
    table_name: str,
    columns: List[str],
    data: List[tuple],
    batch_size: int = 1000
) -> int:
    """Execute batch insert into AWS RDS table."""
    if not data:
        print(f"No data to insert into {table_name}")
        return 0
    
    conn = get_aws_connection()
    cur = conn.cursor()
    
    # Build INSERT statement
    placeholders = ', '.join(['%s'] * len(columns))
    columns_str = ', '.join(columns)
    sql = f"INSERT INTO {table_name} ({columns_str}) VALUES ({placeholders})"
    
    total_inserted = 0
    
    try:
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            cur.executemany(sql, batch)
            conn.commit()
            total_inserted += len(batch)
            print(f"  Inserted {total_inserted}/{len(data)} rows into {table_name}")
        
        print(f"✓ Total inserted: {total_inserted} rows into {table_name}")
        return total_inserted
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error inserting into {table_name}: {e}")
        raise
    finally:
        conn.close()


def upsert_data(
    table_name: str,
    columns: List[str],
    data: List[tuple],
    conflict_columns: List[str],
    update_columns: Optional[List[str]] = None
) -> int:
    """Upsert data into AWS RDS table (INSERT ... ON CONFLICT UPDATE)."""
    if not data:
        print(f"No data to upsert into {table_name}")
        return 0
    
    conn = get_aws_connection()
    cur = conn.cursor()
    
    # Build UPSERT statement
    placeholders = ', '.join(['%s'] * len(columns))
    columns_str = ', '.join(columns)
    conflict_str = ', '.join(conflict_columns)
    
    if update_columns:
        update_str = ', '.join([f"{col} = EXCLUDED.{col}" for col in update_columns])
        sql = f"""
            INSERT INTO {table_name} ({columns_str}) 
            VALUES ({placeholders})
            ON CONFLICT ({conflict_str}) 
            DO UPDATE SET {update_str}
        """
    else:
        sql = f"""
            INSERT INTO {table_name} ({columns_str}) 
            VALUES ({placeholders})
            ON CONFLICT ({conflict_str}) DO NOTHING
        """
    
    total_affected = 0
    
    try:
        for row in data:
            cur.execute(sql, row)
            total_affected += cur.rowcount
        
        conn.commit()
        print(f"✓ Upserted {total_affected} rows into {table_name}")
        return total_affected
        
    except Exception as e:
        conn.rollback()
        print(f"✗ Error upserting into {table_name}: {e}")
        raise
    finally:
        conn.close()


def log_ingestion(table_name: str, rows_affected: int, status: str, notes: str = ""):
    """Log ingestion operation (for future audit trail)."""
    timestamp = datetime.now().isoformat()
    print(f"[{timestamp}] {table_name}: {status} - {rows_affected} rows. {notes}")


def format_date(date_str: str) -> str:
    """Format date string to YYYY-MM-DD."""
    if not date_str:
        return None
    
    # Try various formats
    formats = ['%Y-%m-%d', '%Y-%m-%d %H:%M:%S', '%d/%m/%Y', '%m/%d/%Y']
    
    for fmt in formats:
        try:
            return datetime.strptime(date_str, fmt).strftime('%Y-%m-%d')
        except ValueError:
            continue
    
    return date_str  # Return as-is if no format matches


def safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert value to float."""
    if value is None:
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def safe_int(value: Any, default: int = 0) -> int:
    """Safely convert value to int."""
    if value is None:
        return default
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def tiingo_request(endpoint: str, params: Optional[Dict] = None) -> Dict:
    """Make a request to Tiingo API."""
    if params is None:
        params = {}

    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Token {TIINGO_API_KEY}'
    }

    url = f"{TIINGO_BASE_URL}{endpoint}"
    response = requests.get(url, params=params, headers=headers)

    if response.status_code == 200:
        return response.json()
    else:
        print(f"Tiingo API Error: {response.status_code} - {response.text}")
        return {}


def sqlite_batch_insert(
    table_name: str,
    columns: List[str],
    data: List[tuple],
    batch_size: int = 1000
) -> int:
    """Execute batch insert into SQLite table."""
    if not data:
        print(f"No data to insert into {table_name}")
        return 0

    conn = get_sqlite_connection()
    cur = conn.cursor()

    # Build INSERT statement
    placeholders = ', '.join(['?'] * len(columns))
    columns_str = ', '.join(columns)
    sql = f"INSERT OR IGNORE INTO {table_name} ({columns_str}) VALUES ({placeholders})"

    total_inserted = 0

    try:
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            cur.executemany(sql, batch)
            conn.commit()
            total_inserted += cur.rowcount
            print(f"  Inserted {i + len(batch)}/{len(data)} rows into {table_name}")

        print(f"✓ Total inserted: {total_inserted} rows into {table_name}")
        return total_inserted

    except Exception as e:
        conn.rollback()
        print(f"✗ Error inserting into {table_name}: {e}")
        raise
    finally:
        conn.close()


def rds_batch_insert(
    table_name: str,
    columns: List[str],
    data: List[tuple],
    schema: str = 'ingest_db',
    batch_size: int = 1000,
    conflict_columns: Optional[List[str]] = None
) -> int:
    """
    Execute batch insert into AWS RDS PostgreSQL table.
    Uses INSERT ... ON CONFLICT DO NOTHING for idempotency (like SQLite's INSERT OR IGNORE).

    Args:
        table_name: Name of the table (without schema)
        columns: List of column names
        data: List of tuples containing row data
        schema: Database schema (default: 'ingest_db')
        batch_size: Number of rows to insert per batch (default: 1000)
        conflict_columns: Columns to check for conflicts (optional, uses DO NOTHING on any conflict if not specified)

    Returns:
        Number of rows inserted
    """
    if not data:
        print(f"No data to insert into {table_name}")
        return 0

    conn = get_aws_connection()
    cur = conn.cursor()

    # Build INSERT statement with schema
    full_table_name = f"{schema}.{table_name}"
    placeholders = ', '.join(['%s'] * len(columns))
    columns_str = ', '.join(columns)

    # Build ON CONFLICT clause
    if conflict_columns:
        conflict_str = ', '.join(conflict_columns)
        sql = f"""
            INSERT INTO {full_table_name} ({columns_str})
            VALUES ({placeholders})
            ON CONFLICT ({conflict_str}) DO NOTHING
        """
    else:
        # Use ON CONFLICT DO NOTHING without specifying columns (requires unique constraint)
        # Fall back to try-except for tables without explicit unique constraints
        sql = f"""
            INSERT INTO {full_table_name} ({columns_str})
            VALUES ({placeholders})
        """

    total_inserted = 0
    errors = 0

    try:
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            try:
                if conflict_columns:
                    # With ON CONFLICT, safe to use executemany
                    cur.executemany(sql, batch)
                    conn.commit()
                    total_inserted += cur.rowcount
                else:
                    # Without ON CONFLICT, insert one by one to handle duplicates
                    for row in batch:
                        try:
                            cur.execute(sql, row)
                            conn.commit()
                            total_inserted += 1
                        except psycopg2.IntegrityError:
                            conn.rollback()
                            errors += 1
                            # Silently skip duplicates
                        except Exception as e:
                            conn.rollback()
                            print(f"  Warning: Error inserting row: {e}")
                            errors += 1

                print(f"  Inserted {i + len(batch)}/{len(data)} rows into {full_table_name} (skipped {errors} duplicates)")

            except psycopg2.IntegrityError as e:
                conn.rollback()
                print(f"  Warning: Batch integrity error (likely duplicates): {e}")
                errors += len(batch)
            except Exception as e:
                conn.rollback()
                print(f"  Warning: Batch error: {e}")
                errors += len(batch)

        print(f"✓ Total inserted: {total_inserted} rows into {full_table_name} ({errors} skipped)")
        return total_inserted

    except Exception as e:
        conn.rollback()
        print(f"✗ Error inserting into {full_table_name}: {e}")
        raise
    finally:
        conn.close()


def smart_batch_insert(
    table_name: str,
    columns: List[str],
    data: List[tuple],
    schema: str = 'ingest_db',
    batch_size: int = 1000,
    conflict_columns: Optional[List[str]] = None
) -> int:
    """
    Smart batch insert that uses RDS or SQLite based on USE_RDS_DIRECT config.

    Args:
        table_name: Name of the table
        columns: List of column names
        data: List of tuples containing row data
        schema: Database schema (for RDS only)
        batch_size: Number of rows to insert per batch
        conflict_columns: Columns to check for conflicts (for RDS only)

    Returns:
        Number of rows inserted
    """
    from config import USE_RDS_DIRECT

    if USE_RDS_DIRECT:
        return rds_batch_insert(table_name, columns, data, schema, batch_size, conflict_columns)
    else:
        return sqlite_batch_insert(table_name, columns, data, batch_size)
