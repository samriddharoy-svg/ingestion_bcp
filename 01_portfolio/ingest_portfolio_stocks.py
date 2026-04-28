"""
Ingest portfolio_stocks data from SQLite to AWS RDS
Table: ingest_db.portfolio_stocks
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_sqlite_connection, execute_batch_insert, get_row_count, table_exists
from config import TABLES


def extract_from_sqlite():
    """Extract portfolio_stocks data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            portfolio_stock_id,
            portfolio_id,
            stock_id,
            quantity,
            avg_buy_price,
            currency_code,
            last_updated
        FROM portfolio_stock
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} portfolio_stocks from SQLite")
    return rows


def transform_data(rows):
    """Transform data for AWS RDS format."""
    # Direct mapping - all columns match
    # portfolio_stock_id → portfolio_stock_id
    # portfolio_id → portfolio_id
    # stock_id → stock_id
    # quantity → quantity
    # avg_buy_price → avg_buy_price
    # currency_code → currency_code
    # last_updated → last_updated
    
    return rows  # No transformation needed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['portfolio_stocks']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'portfolio_stock_id', 'portfolio_id', 'stock_id', 
        'quantity', 'avg_buy_price', 'currency_code', 'last_updated'
    ]
    
    return execute_batch_insert(table, columns, data)


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.portfolio_stocks")
    print("=" * 60)
    
    # Check current state
    table = TABLES['portfolio_stocks']
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
