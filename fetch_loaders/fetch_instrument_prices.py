# """
# Fetch historical instrument prices (benchmark indices) using FMP API
# Populates: ingest_db.instrument_prices table
# """
# import sys
# from pathlib import Path
# import time

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import fmp_request, smart_batch_insert, get_connection
# from utils_date import filter_data_by_max_date
# from config import BENCHMARK_MAPPINGS, DATA_FETCH_CONFIG, USE_RDS_DIRECT


# def fetch_instrument_historical_prices():
#     """Fetch historical price data for benchmark instruments using FMP API."""
#     instruments = list(BENCHMARK_MAPPINGS.keys())
#     all_prices = {}

#     print(f"\n📊 Fetching historical data for {len(instruments)} benchmark instruments...")
#     print(f"📅 Using FMP /stable/historical-price-eod/full endpoint")
#     print(f"🎯 Instruments: {', '.join(instruments)}\n")

#     for idx, symbol in enumerate(instruments, 1):
#         try:
#             instrument_name = BENCHMARK_MAPPINGS[symbol]['name']
#             print(f"[{idx}/{len(instruments)}] Fetching {symbol} ({instrument_name})...", end=" ")

#             # Use FMP historical price EOD full endpoint
#             # Symbol like ^HSI needs to be URL-encoded (^ becomes %5E)
#             data = fmp_request(f"/stable/historical-price-eod/full", {'symbol': symbol})

#             if data and isinstance(data, list) and len(data) > 0:
#                 # ✅ Filter to only include data up to yesterday (exclude today)
#                 all_records = []
#                 for record in data:
#                     all_records.append({
#                         'date': record.get('date'),
#                         'open': record.get('open', 0),
#                         'high': record.get('high', 0),
#                         'low': record.get('low', 0),
#                         'close': record.get('close', 0),
#                         'volume': record.get('volume', 0)
#                     })

#                 # Filter out today's data - only keep yesterday and earlier
#                 all_prices[symbol] = filter_data_by_max_date(all_records, date_field='date')
#                 print(f"✓ {len(all_prices[symbol])} records (filtered to yesterday or earlier)")
#             else:
#                 print(f"⚠️  No data")

#             # Rate limit delay (only if not the last instrument)
#             if idx < len(instruments):
#                 time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

#         except Exception as e:
#             print(f"✗ Error: {str(e)[:80]}")
#             continue

#     total_records = sum(len(prices) for prices in all_prices.values())
#     print(f"\n✓ Downloaded {total_records} total price records")

#     return all_prices


# def transform_and_load(all_prices):
#     """Transform and load instrument price data."""
#     # Get instrument_id mapping
#     conn = get_connection()
#     cur = conn.cursor()

#     if USE_RDS_DIRECT:
#         cur.execute("SELECT instrument_id, symbol, currency_code FROM ingest_db.instruments")
#     else:
#         cur.execute("SELECT instrument_id, symbol, currency_code FROM instruments")

#     instrument_map = {code: (instrument_id, currency) for instrument_id, code, currency in cur.fetchall()}

#     if not instrument_map:
#         conn.close()
#         print("\n⚠️  No instruments found in database!")
#         print("💡 Run fetch_benchmarks.py first to populate instruments table")
#         return 0

#     # Detect schema version by checking column names
#     schema_prefix = "ingest_db." if USE_RDS_DIRECT else ""
#     table_schema = 'ingest_db' if USE_RDS_DIRECT else 'public'

#     cur.execute(f"""
#         SELECT column_name
#         FROM information_schema.columns
#         WHERE table_schema = '{table_schema}'
#         AND table_name = 'instrument_prices'
#         AND column_name IN ('price_date', 'captured_at', 'open_price', 'high_price', 'low_price')
#     """)

#     schema_columns = [row[0] for row in cur.fetchall()]
#     conn.close()

#     # Determine if this is the detailed schema (RDS) or simple schema (local Docker)
#     has_price_date = 'price_date' in schema_columns
#     has_ohlc = 'open_price' in schema_columns

#     price_data = []
#     skipped_symbols = []

#     for symbol, prices in all_prices.items():
#         instrument_info = instrument_map.get(symbol)

#         if not instrument_info:
#             skipped_symbols.append(symbol)
#             continue

#         instrument_id, currency = instrument_info

#         for price in prices:
#             # Extract date (already in YYYY-MM-DD format)
#             date_str = price.get('date', '')

#             if not date_str:
#                 continue

#             if has_price_date and has_ohlc:
#                 # RDS schema: full OHLC data with price_date
#                 price_data.append((
#                     instrument_id,           # instrument_id
#                     date_str,                # price_date
#                     price.get('close', 0),   # price (using close as the primary price)
#                     price.get('open', 0),    # open_price
#                     price.get('close', 0),   # close_price
#                     price.get('high', 0),    # high_price
#                     price.get('low', 0),     # low_price
#                     currency,                # currency_code
#                     price.get('volume')      # volume
#                 ))
#             else:
#                 # Local Docker schema: simple price + captured_at
#                 # Convert date string to timestamp
#                 timestamp = f"{date_str} 00:00:00"
#                 price_data.append((
#                     instrument_id,           # instrument_id
#                     price.get('close', 0),   # price
#                     currency,                # currency_code
#                     timestamp                # captured_at
#                 ))

#     if skipped_symbols:
#         print(f"\n⚠️  Skipped {len(skipped_symbols)} symbols (not in instruments table):")
#         for symbol in skipped_symbols:
#             print(f"  - {symbol}")

#     if not price_data:
#         print("\n⚠️  No price data to insert")
#         return 0

#     if has_price_date and has_ohlc:
#         # RDS schema columns
#         columns = [
#             'instrument_id', 'price_date', 'price', 'open_price', 'close_price',
#             'high_price', 'low_price', 'currency_code', 'volume'
#         ]
#         print(f"  Using RDS schema (detailed OHLC)")
#     else:
#         # Local Docker schema columns
#         columns = [
#             'instrument_id', 'price', 'currency_code', 'captured_at'
#         ]
#         print(f"  Using local schema (simple price)")

#     return smart_batch_insert('instrument_prices', columns, price_data)


# def main():
#     """Main fetch function."""
#     print("\n" + "=" * 60)
#     print("FETCHING: Historical Instrument Prices (FMP API)")
#     print("=" * 60)

#     # Fetch historical prices
#     print("\n[1/2] Fetching historical prices from FMP API...")
#     all_prices = fetch_instrument_historical_prices()

#     if not all_prices:
#         print("\n❌ No price data fetched.")
#         print("💡 Possible causes:")
#         print("   - Invalid API key")
#         print("   - Network connectivity issues")
#         print("   - Invalid instrument symbols")
#         return

#     # Transform and load
#     print("\n[2/2] Transforming and loading to database...")
#     inserted = transform_and_load(all_prices)

#     # Summary
#     total_instruments = len(all_prices)
#     total_records = sum(len(prices) for prices in all_prices.values())

#     print("\nSummary:")
#     print(f"  Instruments processed: {total_instruments}")
#     print(f"  Total price records: {total_records}")
#     print(f"  Records inserted: {inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()






































































"""
Fetch historical benchmark / instrument prices using FMP API
Populates: ingest_db.instrument_prices

✔ Market date used as price_date
✔ No duplicates (instrument_id, price_date)
✔ Works in Docker / ECS / Step Functions
✔ Handles FMP response inconsistencies (dict OR list)
✔ Correctly URL-encodes ^ symbols
"""

import sys
import time
import urllib.parse
from pathlib import Path

# -------------------------------------------------------------------
# Path setup
# -------------------------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

# -------------------------------------------------------------------
# Imports
# -------------------------------------------------------------------
import requests
from utils import get_connection, smart_batch_insert
from config import (
    BENCHMARK_MAPPINGS,
    DATA_FETCH_CONFIG,
    FMP_API_KEY,
    FMP_BASE_URL,
)

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
def encode_symbol(symbol: str) -> str:
    """
    Encode benchmark symbols for FMP.
    Example:
        ^HSI   -> %5EHSI
        ^GDAXI -> %5EGDAXI
    """
    return urllib.parse.quote(symbol, safe="")

# -------------------------------------------------------------------
# Fetch prices from FMP
# -------------------------------------------------------------------
def fetch_instrument_historical_prices():
    instruments = list(BENCHMARK_MAPPINGS.keys())
    all_prices = {}

    print(f"\n📊 Fetching benchmark prices from FMP")
    print(f"📡 Endpoint: /stable/historical-price-eod/full\n")

    for idx, symbol in enumerate(instruments, 1):
        name = BENCHMARK_MAPPINGS[symbol]["name"]
        encoded_symbol = encode_symbol(symbol)

        url = (
            f"{FMP_BASE_URL}/stable/historical-price-eod/full"
            f"?symbol={encoded_symbol}&apikey={FMP_API_KEY}"
        )

        print(f"[{idx}/{len(instruments)}] Fetching {symbol} ({name})...", end=" ")

        try:
            r = requests.get(url, timeout=30)
            r.raise_for_status()
            data = r.json()

            # 🔥 FMP RETURNS EITHER dict OR list
            if isinstance(data, dict):
                prices = data.get("historical", [])
            elif isinstance(data, list):
                prices = data
            else:
                prices = []

            if not prices:
                print("⚠️ No data")
                continue

            normalized = []
            for row in prices:
                if not row.get("date"):
                    continue

                normalized.append({
                    "price_date": row["date"],
                    "open": row.get("open"),
                    "high": row.get("high"),
                    "low": row.get("low"),
                    "close": row.get("close"),
                    "volume": row.get("volume"),
                })

            all_prices[symbol] = normalized
            print(f"✓ {len(normalized)} records")

            time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

        except Exception as e:
            print(f"✗ Error: {str(e)[:120]}")

    return all_prices

# -------------------------------------------------------------------
# Transform + Load
# -------------------------------------------------------------------
def transform_and_load(all_prices):
    if not all_prices:
        print("\n⚠️ No data fetched — skipping insert")
        return 0

    conn = get_connection()
    cur = conn.cursor()

    # Map instruments
    cur.execute("""
        SELECT instrument_id, symbol, currency_code
        FROM ingest_db.instruments
    """)
    instrument_map = {
        symbol: (instrument_id, currency)
        for instrument_id, symbol, currency in cur.fetchall()
    }

    rows = []

    for symbol, prices in all_prices.items():
        if symbol not in instrument_map:
            print(f"⚠️ Skipping {symbol} (not in ingest_db.instruments)")
            continue

        instrument_id, currency = instrument_map[symbol]

        for p in prices:
            rows.append((
                instrument_id,
                p["price_date"],               # market date
                p["close"] or 0,               # price
                p["open"],
                p["close"] or 0,
                p["high"],
                p["low"],
                currency,
                p["volume"],
            ))

    cur.close()
    conn.close()

    if not rows:
        print("\n⚠️ No valid rows prepared")
        return 0

    print(f"\n📥 Inserting {len(rows)} rows into ingest_db.instrument_prices")

    return smart_batch_insert(
        table_name="instrument_prices",
        columns=[
            "instrument_id",
            "price_date",
            "price",
            "open_price",
            "close_price",
            "high_price",
            "low_price",
            "currency_code",
            "volume",
        ],
        data=rows,
        conflict_columns=["instrument_id", "price_date"],  # 🔒 no duplicates
    )

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------
def main():
    print("\n" + "=" * 60)
    print("FETCHING: Benchmark / Instrument Prices")
    print("=" * 60)

    print("\n[1/2] Fetching prices from FMP...")
    all_prices = fetch_instrument_historical_prices()

    print("\n[2/2] Loading into database...")
    inserted = transform_and_load(all_prices)

    print("\n✅ DONE")
    print(f"   Records inserted / updated: {inserted}")
    print("=" * 60)

# -------------------------------------------------------------------
if __name__ == "__main__":
    main()
