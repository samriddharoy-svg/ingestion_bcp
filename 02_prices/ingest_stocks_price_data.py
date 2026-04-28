"""
Ingest stock price data from SQLite to AWS RDS
Table: ingest_db.stocks_price_data

NOTE: This table is MISSING in AWS RDS. This script will:
1. Check if the table exists
2. If not, generate the CREATE TABLE statement for the DBA
3. If yes, proceed with ingestion
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


# CREATE TABLE statement for missing table
CREATE_TABLE_SQL = """
-- Table: ingest_db.stocks_price_data
-- Purpose: Historical stock prices for portfolio holdings
-- Source: FMP API / SQLite stock_price_history table

CREATE TABLE IF NOT EXISTS ingest_db.stocks_price_data (
    stock_price_id SERIAL PRIMARY KEY,
    stock_id INTEGER NOT NULL REFERENCES ingest_db.stocks(stock_id),
    price_date DATE NOT NULL,
    open NUMERIC(18, 6),
    high NUMERIC(18, 6),
    low NUMERIC(18, 6),
    close NUMERIC(18, 6),
    adj_close NUMERIC(18, 6),
    volume BIGINT,
    change NUMERIC(18, 6),
    change_percent NUMERIC(10, 4),
    vwap NUMERIC(18, 6),
    UNIQUE(stock_id, price_date)
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_stocks_price_data_stock_id 
    ON ingest_db.stocks_price_data(stock_id);
CREATE INDEX IF NOT EXISTS idx_stocks_price_data_date 
    ON ingest_db.stocks_price_data(price_date);
CREATE INDEX IF NOT EXISTS idx_stocks_price_data_stock_date 
    ON ingest_db.stocks_price_data(stock_id, price_date);

-- Add comments
COMMENT ON TABLE ingest_db.stocks_price_data IS 'Historical stock prices for portfolio holdings';
COMMENT ON COLUMN ingest_db.stocks_price_data.vwap IS 'Volume-weighted average price';
"""


def check_and_create_table():
    """Check if table exists and show CREATE statement if not."""
    table = TABLES['stocks_price_data']
    
    if table_exists(table):
        print(f"✓ Table {table} exists")
        return True
    else:
        print(f"✗ Table {table} does NOT exist!")
        print("\n" + "-" * 60)
        print("Please run the following SQL to create the table:")
        print("-" * 60)
        print(CREATE_TABLE_SQL)
        print("-" * 60)
        
        # Also save to file
        output_path = Path(__file__).parent / "CREATE_stocks_price_data.sql"
        with open(output_path, 'w') as f:
            f.write(CREATE_TABLE_SQL)
        print(f"\nSQL saved to: {output_path}")
        
        return False


def extract_from_sqlite():
    """Extract stock price history from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    # First get total count
    cur.execute("SELECT COUNT(*) FROM stock_price_history")
    total_count = cur.fetchone()[0]
    print(f"Total rows in SQLite: {total_count}")
    
    # Extract all data
    cur.execute("""
        SELECT 
            stock_price_id,
            stock_id,
            date,
            open,
            high,
            low,
            close,
            adj_close,
            volume,
            change,
            change_percent,
            vwap
        FROM stock_price_history
        ORDER BY stock_id, date
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} stock price records from SQLite")
    return rows


def transform_data(rows):
    """Transform data for AWS RDS format."""
    # Column mapping:
    # stock_price_id → stock_price_id
    # stock_id → stock_id
    # date → price_date (renamed)
    # open → open
    # high → high
    # low → low
    # close → close
    # adj_close → adj_close
    # volume → volume
    # change → change
    # change_percent → change_percent
    # vwap → vwap
    
    # Data is already in correct format
    return rows


def load_to_aws(data, batch_size=500):
    """Load data into AWS RDS in batches."""
    table = TABLES['stocks_price_data']
    
    columns = [
        'stock_price_id', 'stock_id', 'price_date',
        'open', 'high', 'low', 'close', 'adj_close',
        'volume', 'change', 'change_percent', 'vwap'
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
            s.symbol,
            MIN(sph.date) as min_date,
            MAX(sph.date) as max_date,
            COUNT(*) as row_count
        FROM stock_price_history sph
        JOIN stocks s ON sph.stock_id = s.stock_id
        GROUP BY s.symbol
        ORDER BY s.symbol
    """)
    
    stats = cur.fetchall()
    conn.close()
    return stats


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.stocks_price_data")
    print("=" * 60)
    
    # Check if table exists
    if not check_and_create_table():
        print("\n⚠️  Cannot proceed with ingestion - table missing")
        print("Share the CREATE TABLE SQL with your DBA to create the table first.")
        return
    
    # Check current state
    table = TABLES['stocks_price_data']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show date range stats
    print("\nDate range statistics by stock:")
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
