"""
Ingest stocks data from SQLite to AWS RDS
Table: ingest_db.stocks
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, 
    execute_batch_insert, 
    get_row_count, 
    table_exists,
    fmp_request
)
from config import TABLES, TICKER_MAPPINGS


def extract_from_sqlite():
    """Extract stocks data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            stock_id,
            ticker,
            exchange,
            company_name,
            sector,
            currency_code,
            country,
            market_cap_category,
            created_at
        FROM stocks
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} stocks from SQLite")
    return rows


def fetch_logo_urls(tickers):
    """Fetch logo URLs from FMP API."""
    logo_urls = {}
    
    for ticker in tickers:
        fmp_ticker = TICKER_MAPPINGS.get(ticker, ticker)
        
        try:
            data = fmp_request(f"/v3/profile/{fmp_ticker}")
            if data and len(data) > 0:
                logo_urls[ticker] = data[0].get('image', '')
                print(f"  ✓ Got logo for {ticker}")
            else:
                logo_urls[ticker] = ''
                print(f"  ✗ No logo for {ticker}")
        except Exception as e:
            logo_urls[ticker] = ''
            print(f"  ✗ Error fetching logo for {ticker}: {e}")
    
    return logo_urls


def transform_data(rows, logo_urls):
    """Transform data for AWS RDS format."""
    # Column mapping: SQLite → AWS RDS
    # stock_id → stock_id
    # ticker → ticker  
    # exchange → exchange
    # company_name → company_name
    # sector → sector
    # currency_code → currency_code
    # country → country
    # market_cap_category → market_cap_category_name
    # NEW: logo_url
    # created_at → created_at
    
    transformed = []
    for row in rows:
        (stock_id, ticker, exchange, company_name, sector, 
         currency_code, country, market_cap_category, created_at) = row
        
        logo_url = logo_urls.get(ticker, '')
        
        transformed.append((
            stock_id,
            ticker,
            exchange,
            company_name,
            sector,
            currency_code,
            country,
            market_cap_category or 'Unknown',  # market_cap_category_name is NOT NULL
            logo_url,
            created_at
        ))
    
    return transformed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['stocks']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'stock_id', 'ticker', 'exchange', 'company_name', 'sector',
        'currency_code', 'country', 'market_cap_category_name', 
        'logo_url', 'created_at'
    ]
    
    return execute_batch_insert(table, columns, data)


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.stocks")
    print("=" * 60)
    
    # Check current state
    table = TABLES['stocks']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Extract
    print("\n[1/4] Extracting from SQLite...")
    raw_data = extract_from_sqlite()
    
    if not raw_data:
        print("No data to ingest")
        return
    
    # Fetch logos
    print("\n[2/4] Fetching logo URLs from FMP...")
    tickers = [row[1] for row in raw_data]  # ticker is at index 1
    logo_urls = fetch_logo_urls(tickers)
    
    # Transform
    print("\n[3/4] Transforming data...")
    transformed_data = transform_data(raw_data, logo_urls)
    
    # Load
    print("\n[4/4] Loading to AWS RDS...")
    rows_inserted = load_to_aws(transformed_data)
    
    # Verify
    new_count = get_row_count(table)
    print(f"\nFinal rows in {table}: {new_count}")
    print("=" * 60)


if __name__ == "__main__":
    main()
