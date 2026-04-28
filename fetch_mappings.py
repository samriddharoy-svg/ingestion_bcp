"""
Create stock-benchmark mappings and auto-generate flags
Populates: stocks_benchmark_mapping, stocks_flags tables
No API calls - uses config data and existing DB data
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import smart_batch_insert, get_connection
from config import STOCK_BENCHMARK_MAP, USE_RDS_DIRECT


def create_benchmark_mappings():
    """Create stock-to-benchmark mappings."""
    conn = get_connection()
    cur = conn.cursor()

    # Get stock_id mapping
    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker FROM ingest_db.stocks")
    else:
        cur.execute("SELECT stock_id, ticker FROM stocks")

    stock_id_map = {ticker: stock_id for stock_id, ticker in cur.fetchall()}

    # Check which schema version we're using
    schema_prefix = "ingest_db." if USE_RDS_DIRECT else ""
    table_schema = 'ingest_db' if USE_RDS_DIRECT else 'public'
    cur.execute(f"""
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = '{table_schema}'
        AND table_name = 'stocks_benchmark_mapping'
        AND column_name IN ('instrument_id', 'benchmark_name')
    """)

    schema_columns = [row[0] for row in cur.fetchall()]
    uses_instrument_id = 'instrument_id' in schema_columns

    if uses_instrument_id:
        # RDS schema: use instrument_id (FK to instruments table)
        cur.execute(f"SELECT instrument_id, instrument_code FROM {schema_prefix}instruments")
        instrument_id_map = {symbol: instrument_id for instrument_id, symbol in cur.fetchall()}

        mapping_data = []
        skipped = []

        for ticker, benchmark_symbol in STOCK_BENCHMARK_MAP.items():
            stock_id = stock_id_map.get(ticker)
            instrument_id = instrument_id_map.get(benchmark_symbol)

            if stock_id and instrument_id:
                mapping_data.append((stock_id, instrument_id, 1))  # ranking_order = 1
            else:
                if not stock_id:
                    skipped.append(f"{ticker} (stock not found)")
                elif not instrument_id:
                    skipped.append(f"{ticker} → {benchmark_symbol} (instrument not found)")

        if skipped:
            print(f"  ⚠️  Skipped {len(skipped)} mapping(s):")
            for msg in skipped:
                print(f"    - {msg}")

        columns = ['stock_id', 'instrument_id', 'ranking_order']
    else:
        # Local schema: use benchmark_name (string)
        mapping_data = []
        for ticker, benchmark_symbol in STOCK_BENCHMARK_MAP.items():
            stock_id = stock_id_map.get(ticker)
            if stock_id:
                mapping_data.append((stock_id, benchmark_symbol))
            else:
                print(f"  ✗ Stock not found for ticker: {ticker}")

        columns = ['stock_id', 'benchmark_name']

    conn.close()
    return smart_batch_insert('stocks_benchmark_mapping', columns, mapping_data)


def create_stock_flags():
    """Auto-generate flags for stocks with missing data."""
    conn = get_connection()
    cur = conn.cursor()

    # Get all stocks
    if USE_RDS_DIRECT:
        cur.execute("""
            SELECT stock_id, ticker, logo_url, sector, market_cap_category_name
            FROM ingest_db.stocks
        """)
    else:
        cur.execute("""
            SELECT stock_id, ticker, logo_url, sector, market_cap_category_name
            FROM stocks
        """)

    stocks = cur.fetchall()
    conn.close()

    flags_data = []

    for stock_id, ticker, logo_url, sector, market_cap in stocks:
        # Check for missing logo
        if not logo_url or logo_url.strip() == '':
            flags_data.append((
                stock_id,
                'missing_logo',
                f'Logo URL is missing for {ticker}'
            ))

        # Check for missing sector
        if not sector or sector.strip() == '':
            flags_data.append((
                stock_id,
                'missing_sector',
                f'Sector information is missing for {ticker}'
            ))

        # Check for missing market cap
        if not market_cap or market_cap.strip() == '':
            flags_data.append((
                stock_id,
                'missing_market_cap',
                f'Market cap category is missing for {ticker}'
            ))

    if not flags_data:
        print("  ✓ No data quality issues found!")
        return 0

    columns = ['stock_id', 'flag_type', 'flag_description']
    return smart_batch_insert('stocks_flags', columns, flags_data)


def main():
    """Main function."""
    print("\n" + "=" * 60)
    print("CREATING: Stock-Benchmark Mappings & Flags")
    print("=" * 60)

    # Create mappings
    print("\n[1/2] Creating stock-benchmark mappings...")
    mappings_inserted = create_benchmark_mappings()

    # Create flags
    print("\n[2/2] Auto-generating data quality flags...")
    flags_inserted = create_stock_flags()

    # Summary
    print("\nSummary:")
    print(f"  Benchmark mappings created: {mappings_inserted}")
    print(f"  Data quality flags created: {flags_inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
