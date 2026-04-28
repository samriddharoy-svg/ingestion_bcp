"""
Ingest portfolio data from SQLite to AWS RDS
Table: ingest_db.portfolio
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_sqlite_connection, execute_batch_insert, get_row_count, table_exists
from config import TABLES


def extract_from_sqlite():
    """Extract portfolio data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            portfolio_id,
            portfolio_name,
            owner,
            created_at
        FROM portfolios
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} portfolios from SQLite")
    return rows


def transform_data(rows):
    """Transform data for AWS RDS format."""
    # Column mapping: SQLite → AWS RDS
    # portfolio_id → portfolio_id
    # portfolio_name → portfolio_name
    # owner → owner_id
    # created_at → created_at
    
    transformed = []
    for row in rows:
        portfolio_id, portfolio_name, owner, created_at = row
        transformed.append((
            portfolio_id,
            portfolio_name,
            owner,  # maps to owner_id
            created_at
        ))
    
    return transformed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['portfolio']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = ['portfolio_id', 'portfolio_name', 'owner_id', 'created_at']
    
    return execute_batch_insert(table, columns, data)


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.portfolio")
    print("=" * 60)
    
    # Check current state
    table = TABLES['portfolio']
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
