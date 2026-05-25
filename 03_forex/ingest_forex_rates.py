"""
Ingest forex rates from SQLite to AWS RDS
Table: ingest_db.forex_rates

NOTE: SQLite stores currency code + rate per row.
AWS RDS stores individual forex pairs (from_currency, to_currency, rate).
This requires transformation.
"""
import sys
from pathlib import Path
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, get_aws_connection,
    execute_batch_insert, get_row_count, table_exists
)
from config import TABLES


def extract_from_sqlite():
    """Extract forex rates from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            currency_code,
            rate,
            last_updated
        FROM forex_rates
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} forex rate records from SQLite")
    return rows


def transform_data(rows):
    """
    Transform SQLite format to AWS RDS format.
    
    SQLite format:
        currency_code | rate | last_updated
        HKD           | 7.77 | 2024-01-01
        (rates are USD-based: 1 USD = X units of currency)
    
    AWS RDS format:
        forex_rate_id | from_currency_code | to_currency_code | rate | rate_date
        1             | USD                | HKD              | 7.77 | 2024-01-01
    """
    transformed = []
    forex_rate_id = 1
    
    for row in rows:
        currency_code, rate, last_updated = row
        
        # Skip USD to USD
        if currency_code == 'USD':
            continue
        
        # Create USD → currency pair
        transformed.append((
            forex_rate_id,
            'USD',           # from_currency_code
            currency_code,   # to_currency_code
            rate,            # rate
            last_updated     # rate_date
        ))
        forex_rate_id += 1
        
        # Also create inverse: currency → USD
        if rate and rate != 0:
            inverse_rate = round(1 / rate, 6)
            transformed.append((
                forex_rate_id,
                currency_code,  # from_currency_code
                'USD',          # to_currency_code
                inverse_rate,   # rate
                last_updated    # rate_date
            ))
            forex_rate_id += 1
    
    print(f"Transformed to {len(transformed)} forex rate pairs")
    return transformed


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['forex_rates']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'forex_rate_id', 'from_currency_code', 'to_currency_code', 
        'rate', 'rate_date'
    ]
    
    return execute_batch_insert(table, columns, data)


def get_required_currencies():
    """Get currencies needed for our portfolio stocks."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT DISTINCT currency_code FROM stocks
    """)
    
    currencies = [row[0] for row in cur.fetchall()]
    conn.close()
    
    return currencies


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.forex_rates")
    print("=" * 60)
    
    # Check current state
    table = TABLES['forex_rates']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show required currencies
    required = get_required_currencies()
    print(f"\nCurrencies required for portfolio: {required}")
    
    # Extract
    print("\n[1/3] Extracting from SQLite...")
    raw_data = extract_from_sqlite()
    
    if not raw_data:
        print("No data to ingest")
        return
    
    # Transform
    print("\n[2/3] Transforming data...")
    transformed_data = transform_data(raw_data)
    
    # Show sample transformations
    print("\nSample transformations:")
    for item in transformed_data[:6]:
        print(f"  {item[1]} → {item[2]}: {item[3]}")
    
    # Load
    print("\n[3/3] Loading to AWS RDS...")
    rows_inserted = load_to_aws(transformed_data)
    
    # Verify
    new_count = get_row_count(table)
    print(f"\nFinal rows in {table}: {new_count}")
    print("=" * 60)


if __name__ == "__main__":
    main()
