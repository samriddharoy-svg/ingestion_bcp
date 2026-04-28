"""
Ingest instrument prices (benchmark index prices) from SQLite to AWS RDS
Table: ingest_db.instrument_prices
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, get_aws_connection,
    execute_batch_insert, get_row_count, table_exists
)
from config import TABLES


def extract_from_sqlite(batch_size=1000):
    """Extract instrument prices from SQLite in batches."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    # First get total count
    cur.execute("SELECT COUNT(*) FROM instrument_prices")
    total_count = cur.fetchone()[0]
    print(f"Total rows in SQLite: {total_count}")
    
    # Extract all data
    cur.execute("""
        SELECT 
            instrument_price_id,
            instrument_id,
            price_date,
            open,
            high,
            low,
            close,
            adj_close,
            volume,
            change,
            change_percent
        FROM instrument_prices
        ORDER BY instrument_id, price_date
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} instrument price records from SQLite")
    return rows


def transform_data(rows):
    """Transform data for AWS RDS format."""
    # Column mapping is mostly 1:1:
    # instrument_price_id → instrument_price_id
    # instrument_id → instrument_id
    # price_date → price_date
    # open → open
    # high → high
    # low → low
    # close → close
    # adj_close → adj_close
    # volume → volume
    # change → change
    # change_percent → change_percent
    
    # No transformation needed - columns match directly
    return rows


def load_to_aws(data, batch_size=500):
    """Load data into AWS RDS in batches."""
    table = TABLES['instrument_prices']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'instrument_price_id', 'instrument_id', 'price_date',
        'open', 'high', 'low', 'close', 'adj_close',
        'volume', 'change', 'change_percent'
    ]
    
    # Process in batches
    total_inserted = 0
    for i in range(0, len(data), batch_size):
        batch = data[i:i + batch_size]
        rows_inserted = execute_batch_insert(table, columns, batch)
        total_inserted += rows_inserted
        
        if (i + batch_size) % 2000 == 0:
            print(f"  Processed {min(i + batch_size, len(data))}/{len(data)} rows...")
    
    return total_inserted


def get_date_range_stats():
    """Get date range statistics from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            i.symbol,
            MIN(ip.price_date) as min_date,
            MAX(ip.price_date) as max_date,
            COUNT(*) as row_count
        FROM instrument_prices ip
        JOIN instruments i ON ip.instrument_id = i.instrument_id
        GROUP BY i.symbol
        ORDER BY i.symbol
    """)
    
    stats = cur.fetchall()
    conn.close()
    return stats


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.instrument_prices")
    print("=" * 60)
    
    # Check current state
    table = TABLES['instrument_prices']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show date range stats
    print("\nDate range statistics by instrument:")
    stats = get_date_range_stats()
    for symbol, min_date, max_date, count in stats:
        print(f"  {symbol}: {min_date} to {max_date} ({count} rows)")
    
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
