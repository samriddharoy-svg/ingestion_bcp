"""
Ingest earnings calendar data from SQLite to AWS RDS
Table: ingest_db.earnings_calendar
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, execute_batch_insert, 
    get_row_count, table_exists
)
from config import TABLES


def extract_from_sqlite():
    """Extract earnings calendar data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            earnings_id,
            stock_id,
            symbol,
            earnings_date,
            eps_estimated,
            eps_actual,
            revenue_estimated,
            revenue_actual,
            fiscal_date_ending,
            updated_from_date
        FROM earnings_calendar
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} earnings records from SQLite")
    return rows


def transform_data(rows):
    """
    Transform data for AWS RDS format.
    
    SQLite columns → AWS RDS columns:
    earnings_id → earnings_id
    stock_id → stock_id
    symbol → symbol
    earnings_date → earnings_date
    eps_estimated → eps_estimate
    eps_actual → eps_actual
    revenue_estimated → revenue_estimate
    revenue_actual → revenue_actual
    fiscal_date_ending → fiscal_date_ending
    updated_from_date → updated_from_date
    
    NEW AWS column: time (set NULL - FMP doesn't provide time in basic endpoint)
    """
    transformed = []
    
    for row in rows:
        (earnings_id, stock_id, symbol, earnings_date,
         eps_estimated, eps_actual, revenue_estimated,
         revenue_actual, fiscal_date_ending, updated_from_date) = row
        
        transformed.append((
            earnings_id,
            stock_id,
            symbol,
            earnings_date,
            None,              # time (not in SQLite)
            eps_estimated,     # → eps_estimate
            eps_actual,
            revenue_estimated, # → revenue_estimate
            revenue_actual,
            fiscal_date_ending,
            updated_from_date
        ))
    
    return transformed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['earnings_calendar']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'earnings_id', 'stock_id', 'symbol', 'earnings_date',
        'time', 'eps_estimate', 'eps_actual', 'revenue_estimate',
        'revenue_actual', 'fiscal_date_ending', 'updated_from_date'
    ]
    
    return execute_batch_insert(table, columns, data)


def get_earnings_stats():
    """Get earnings statistics from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            symbol,
            COUNT(*) as record_count,
            MIN(earnings_date) as earliest,
            MAX(earnings_date) as latest,
            SUM(CASE WHEN eps_actual IS NOT NULL THEN 1 ELSE 0 END) as with_actual
        FROM earnings_calendar
        GROUP BY symbol
        ORDER BY symbol
    """)
    
    stats = cur.fetchall()
    conn.close()
    return stats


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.earnings_calendar")
    print("=" * 60)
    
    # Check current state
    table = TABLES['earnings_calendar']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show earnings stats
    print("\nEarnings records by stock:")
    stats = get_earnings_stats()
    for symbol, count, earliest, latest, with_actual in stats:
        print(f"  {symbol}: {count} records ({with_actual} with actual EPS)")
    
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
