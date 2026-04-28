"""
Ingest instruments data from SQLite to AWS RDS
Table: ingest_db.instruments
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_sqlite_connection, execute_batch_insert, get_row_count, table_exists
from config import TABLES


def extract_from_sqlite():
    """Extract instruments (benchmarks) data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            instrument_id,
            symbol,
            name,
            type,
            exchange,
            currency_code,
            country
        FROM instruments
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} instruments from SQLite")
    return rows


def transform_data(rows):
    """Transform data for AWS RDS format."""
    # Column mapping: SQLite → AWS RDS
    # instrument_id → instrument_id
    # symbol → symbol
    # name → name
    # type → type
    # exchange → exchange
    # NEW: sector (set to 'Index')
    # currency_code → currency_code
    # country → country
    
    transformed = []
    for row in rows:
        (instrument_id, symbol, name, inst_type, 
         exchange, currency_code, country) = row
        
        transformed.append((
            instrument_id,
            symbol,
            name,
            inst_type,
            exchange,
            'Index',  # sector - all benchmarks are indexes
            currency_code,
            country
        ))
    
    return transformed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['instruments']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'instrument_id', 'symbol', 'name', 'type', 
        'exchange', 'sector', 'currency_code', 'country'
    ]
    
    return execute_batch_insert(table, columns, data)


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.instruments")
    print("=" * 60)
    
    # Check current state
    table = TABLES['instruments']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Extract
    print("\n[1/3] Extracting from SQLite...")
    raw_data = extract_from_sqlite()
    
    if not raw_data:
        print("No data to ingest")
        return
    
    # Transform
    print("\n[2/3] Transforming data...")
    transformed_data = transform_data(raw_data)
    
    # Load
    print("\n[3/3] Loading to AWS RDS...")
    rows_inserted = load_to_aws(transformed_data)
    
    # Verify
    new_count = get_row_count(table)
    print(f"\nFinal rows in {table}: {new_count}")
    print("=" * 60)


if __name__ == "__main__":
    main()
