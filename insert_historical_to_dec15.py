#!/usr/bin/env python3
"""
Fetch and insert historical stock data up to December 15, 2025
Excludes today's data (Dec 16)
"""
import sys
from pathlib import Path
from datetime import datetime, timedelta
from tabulate import tabulate
import requests
import time

sys.path.insert(0, str(Path(__file__).parent))

from config import TICKER_MAPPINGS, FMP_API_KEY, DATA_FETCH_CONFIG, USE_RDS_DIRECT
from utils import smart_batch_insert, get_connection

def fetch_historical_week(ticker):
    """Fetch last 10 days of historical data."""
    try:
        url = f"https://financialmodelingprep.com/stable/historical-price-eod/full?symbol={ticker}&apikey={FMP_API_KEY}"
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()

        if data:
            # Return last 10 records (sorted newest first)
            return data[:10]
        return []
    except Exception as e:
        print(f"Error: {e}")
        return []

def main(dry_run=True):
    """Fetch and insert data up to Dec 15."""
    print("\n" + "=" * 80)
    print("HISTORICAL DATA FETCH: Up to December 15, 2025")
    print("=" * 80)

    cutoff_date = datetime(2025, 12, 15).date()  # Dec 15
    today = datetime.now().date()

    print(f"\n📅 Date Range:")
    print(f"   Today: {today}")
    print(f"   Cutoff: {cutoff_date} (will include this and earlier)")
    print(f"   Will exclude: {today} (today)")

    # Get stock mapping
    conn = get_connection()
    cur = conn.cursor()

    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker, company_name, currency_code FROM ingest_db.stocks ORDER BY stock_id")
    else:
        cur.execute("SELECT stock_id, ticker, company_name, currency_code FROM stocks ORDER BY stock_id")

    db_stocks = {ticker: (stock_id, company, currency) for stock_id, ticker, company, currency in cur.fetchall()}

    # Check current state
    if USE_RDS_DIRECT:
        cur.execute("""
            SELECT s.ticker, MAX(spd.captured_at::date) as latest
            FROM ingest_db.stocks s
            LEFT JOIN ingest_db.stocks_price_data spd ON s.stock_id = spd.stock_id
            WHERE s.ticker IN ('0853.HK','6887.HK','9618.HK','008930.KS','068270.KS','032350.KS','6098.T','5216.T','CS.ST','NB2.DE')
            GROUP BY s.ticker
            ORDER BY s.ticker
        """)
    else:
        cur.execute("""
            SELECT s.ticker, MAX(spd.captured_at::date) as latest
            FROM stocks s
            LEFT JOIN stocks_price_data spd ON s.stock_id = spd.stock_id
            WHERE s.ticker IN ('0853.HK','6887.HK','9618.HK','008930.KS','068270.KS','032350.KS','6098.T','5216.T','CS.ST','NB2.DE')
            GROUP BY s.ticker
            ORDER BY s.ticker
        """)

    current_state = list(cur.fetchall())
    conn.close()

    print(f"\n📊 Current State (Latest dates in DB):")
    print(tabulate(current_state, headers=['Ticker', 'Latest Date'], tablefmt='simple'))

    # Fetch data
    print(f"\n🔄 Fetching historical data for {len(TICKER_MAPPINGS)} tickers...")
    print("   (This will take ~50 seconds)")
    print("-" * 80)

    all_data_to_insert = []
    summary = []

    tickers = list(set(TICKER_MAPPINGS.values()))

    for idx, ticker in enumerate(tickers, 1):
        if ticker not in db_stocks:
            print(f"  [{idx}/{len(tickers)}] {ticker:15s} - ⚠️  Not in database, skipping")
            continue

        stock_id, company, currency = db_stocks[ticker]

        print(f"  [{idx}/{len(tickers)}] {ticker:15s} - Fetching...", end=" ", flush=True)

        historical_data = fetch_historical_week(ticker)

        if not historical_data:
            print("✗ No data")
            summary.append([ticker, 0, 0, "Failed to fetch"])
            continue

        # Filter to only dates up to Dec 15
        valid_records = []
        for record in historical_data:
            date_str = record.get('date', '')
            try:
                record_date = datetime.strptime(date_str, '%Y-%m-%d').date()

                # Only include if date <= Dec 15 (and not today)
                if record_date <= cutoff_date and record_date < today:
                    valid_records.append(record)
            except ValueError:
                continue

        if not valid_records:
            print(f"✓ Fetched {len(historical_data)}, but all filtered out (all > Dec 15 or today)")
            summary.append([ticker, len(historical_data), 0, "All dates filtered"])
            continue

        print(f"✓ Found {len(valid_records)} records to insert (from {len(historical_data)} fetched)")

        # Prepare data for insertion
        for record in valid_records:
            date_str = record.get('date')
            opening_price = record.get('open', 0)
            closing_price = record.get('close', 0)
            price = closing_price
            volume = record.get('volume', 0)

            # For historical, calculate change from previous day in the dataset
            day_price_change = 0
            day_price_change_pct = 0

            all_data_to_insert.append((
                stock_id,
                price,
                opening_price,
                closing_price,
                day_price_change,
                currency,
                day_price_change_pct,
                volume,
                None,  # volume_30d
                None,  # market_cap
                f"{date_str} 00:00:00"  # captured_at
            ))

        summary.append([ticker, len(historical_data), len(valid_records), "Ready to insert"])

        # Rate limit
        if idx < len(tickers):
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

    # Show summary
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(tabulate(summary, headers=['Ticker', 'Fetched', 'Valid (≤Dec15)', 'Status'], tablefmt='grid'))

    print(f"\n📦 Total records ready to insert: {len(all_data_to_insert)}")

    if not all_data_to_insert:
        print("\n⚠️  No data to insert!")
        return

    # Show sample of what will be inserted
    print(f"\n📋 Sample of data to be inserted (first 10):")
    sample_display = []
    for record in all_data_to_insert[:10]:
        stock_id = record[0]
        # Find ticker
        ticker = "Unknown"
        for t, (sid, _, _) in db_stocks.items():
            if sid == stock_id:
                ticker = t
                break

        sample_display.append([
            ticker,
            record[10],  # captured_at (date)
            f"{record[1]:.2f}",  # price
            f"{record[2]:.2f}",  # open
            f"{record[3]:.2f}",  # close
        ])

    print(tabulate(sample_display, headers=['Ticker', 'Date', 'Price', 'Open', 'Close'], tablefmt='grid'))

    # Insert or dry run
    if dry_run:
        print("\n" + "=" * 80)
        print("🔍 DRY RUN MODE - NOT INSERTING TO DATABASE")
        print("=" * 80)
        print("\nTo actually insert this data, run:")
        print("  python3 insert_historical_to_dec15.py --insert")
    else:
        print("\n" + "=" * 80)
        print("💾 INSERTING TO DATABASE...")
        print("=" * 80)

        columns = [
            'stock_id', 'price', 'opening_price', 'closing_price',
            'day_price_change', 'currency_code', 'day_price_change_pct',
            'volume', 'volume_30d', 'market_cap', 'captured_at'
        ]

        try:
            inserted = smart_batch_insert('stocks_price_data', columns, all_data_to_insert)
            print(f"\n✅ Successfully inserted {inserted} records!")

            # Show new state
            conn = get_connection()
            cur = conn.cursor()
            if USE_RDS_DIRECT:
                cur.execute("""
                    SELECT s.ticker, MAX(spd.captured_at::date) as latest
                    FROM ingest_db.stocks s
                    JOIN ingest_db.stocks_price_data spd ON s.stock_id = spd.stock_id
                    WHERE s.ticker IN ('0853.HK','6887.HK','9618.HK','008930.KS','068270.KS','032350.KS','6098.T','5216.T','CS.ST','NB2.DE')
                    GROUP BY s.ticker
                    ORDER BY s.ticker
                """)

            new_state = list(cur.fetchall())
            conn.close()

            print(f"\n📊 New State (After insertion):")
            print(tabulate(new_state, headers=['Ticker', 'Latest Date'], tablefmt='simple'))

        except Exception as e:
            print(f"\n❌ Error during insertion: {e}")

if __name__ == '__main__':
    import sys

    # Check if --insert flag is provided
    insert_mode = '--insert' in sys.argv

    if insert_mode:
        print("\n⚠️  REAL INSERT MODE - Data will be written to database!")
        response = input("\nAre you sure you want to proceed? (yes/no): ")
        if response.lower() != 'yes':
            print("Cancelled.")
            sys.exit(0)
        main(dry_run=False)
    else:
        main(dry_run=True)
