# ""
# Fetch benchmark/instrument data from FMP API
# Populates: instruments, instrument_prices, benchmark_history tables
# """
# import sys
# from pathlib import Path
# import time

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import fmp_request, smart_batch_insert, get_connection
# from config import BENCHMARK_MAPPINGS, DATA_FETCH_CONFIG


# def fetch_benchmark_historical_prices():
#     """Fetch historical prices for benchmarks from FMP API."""
#     benchmarks = list(BENCHMARK_MAPPINGS.keys())
#     all_prices = {}

#     print(f"\nFetching historical prices for {len(benchmarks)} benchmarks...")

#     for benchmark in benchmarks:
#         try:
#             print(f"  Fetching {benchmark}...")

#             # Use FMP historical price EOD full endpoint
#             data = fmp_request(f"/stable/historical-price-eod/full", {'symbol': benchmark})

#             if data and isinstance(data, list) and len(data) > 0:
#                 all_prices[benchmark] = data
#                 print(f"    ✓ Fetched {len(data)} price records")
#             else:
#                 print(f"    ✗ No data found for {benchmark}")

#             time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

#         except Exception as e:
#             print(f"    ✗ Error fetching {benchmark}: {e}")
#             continue

#     return all_prices


# def load_instruments():
#     """Load instrument records for benchmarks."""
#     instruments_data = []

#     for benchmark, info in BENCHMARK_MAPPINGS.items():
#         instruments_data.append((
#             benchmark,
#             info['name'],
#             info['currency'],
#             info['country']
#         ))

#     columns = ['instrument_code', 'instrument_name', 'currency_code', 'exchange']
#     return smart_batch_insert('instruments', columns, instruments_data)


# def load_instrument_prices(all_prices):
#     """Load instrument_prices data."""
#     # Get instrument_id mapping
#     conn = get_connection()
#     cur = conn.cursor()

#     from config import USE_RDS_DIRECT
#     if USE_RDS_DIRECT:
#         cur.execute("SELECT instrument_id, instrument_code FROM ingest_db.instruments")
#     else:
#         cur.execute("SELECT instrument_id, instrument_code FROM instruments")

#     instrument_map = {code: inst_id for inst_id, code in cur.fetchall()}
#     conn.close()

#     prices_data = []

#     for benchmark, prices in all_prices.items():
#         instrument_id = instrument_map.get(benchmark)
#         if not instrument_id:
#             continue

#         currency = BENCHMARK_MAPPINGS[benchmark]['currency']

#         for price in prices:
#             prices_data.append((
#                 instrument_id,
#                 price.get('close'),
#                 currency,
#                 price.get('date')
#             ))

#     columns = ['instrument_id', 'price', 'currency_code', 'captured_at']
#     return smart_batch_insert('instrument_prices', columns, prices_data)


# def load_benchmark_history(all_prices):
#     """Load benchmark_history data."""
#     history_data = []

#     for benchmark, prices in all_prices.items():
#         benchmark_name = BENCHMARK_MAPPINGS[benchmark]['name']
#         currency = BENCHMARK_MAPPINGS[benchmark]['currency']

#         for price in prices:
#             history_data.append((
#                 benchmark_name,
#                 price.get('date'),
#                 price.get('close'),
#                 currency
#             ))

#     columns = ['benchmark_name', 'valuation_date', 'benchmark_value', 'currency_code']
#     return smart_batch_insert('benchmark_history', columns, history_data)


# def main():
#     """Main fetch function."""
#     print("\n" + "=" * 60)
#     print("FETCHING: Benchmark/Instrument Data from FMP")
#     print("=" * 60)

#     # Load instruments first
#     print("\n[1/4] Loading instrument definitions...")
#     instruments_inserted = load_instruments()

#     # Fetch historical prices
#     print("\n[2/4] Fetching historical prices from FMP API...")
#     all_prices = fetch_benchmark_historical_prices()
# "
#     if not all_prices:
#         print("No price data fetched. Exiting.")
#         return

#     # Load instrument_prices
#     print("\n[3/4] Loading instrument_prices...")
#     prices_inserted = load_instrument_prices(all_prices)

#     # Load benchmark_history
#     print("\n[4/4] Loading benchmark_history...")
#     history_inserted = load_benchmark_history(all_prices)

#     # Summary
#     print("\nSummary:")
#     print(f"  Instruments inserted: {instruments_inserted}")
#     print(f"  Instrument prices inserted: {prices_inserted}")
#     print(f"  Benchmark history inserted: {history_inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()
























# """
# Fetch benchmark/instrument data from FMP API
# Populates: instruments, instrument_prices, benchmark_history tables
# """
# import sys
# from pathlib import Path
# import time

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import fmp_request, smart_batch_insert, get_connection
# from config import BENCHMARK_MAPPINGS, DATA_FETCH_CONFIG, USE_RDS_DIRECT


# def fetch_benchmark_historical_prices():
#     """Fetch historical prices for benchmarks from FMP API."""
#     benchmarks = list(BENCHMARK_MAPPINGS.keys())
#     all_prices = {}

#     print(f"\nFetching historical prices for {len(benchmarks)} benchmarks...")

#     for benchmark in benchmarks:
#         try:
#             print(f"  Fetching {benchmark}...")

#             # Use FMP historical price EOD full endpoint
#             data = fmp_request("/stable/historical-price-eod/full", {"symbol": benchmark})

#             if data and isinstance(data, list) and len(data) > 0:
#                 all_prices[benchmark] = data
#                 print(f"    ✓ Fetched {len(data)} price records")
#             else:
#                 print(f"    ✗ No data found for {benchmark}")

#             # Rate limit
#             time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#         except Exception as e:
#             print(f"    ✗ Error fetching {benchmark}: {e}")
#             continue

#     return all_prices


# def load_instruments():
#     """
#     Load instrument records for benchmarks into ingest_db.instruments.

#     RDS schema:
#         symbol        text NOT NULL,
#         name          text NOT NULL,
#         type          text NOT NULL,
#         exchange      text NULL,
#         sector        varchar(100) NULL,
#         currency_code bpchar(3) NOT NULL,
#         country       varchar(50) NULL
#     """
#     instruments_data = []

#     for benchmark, info in BENCHMARK_MAPPINGS.items():
#         symbol = benchmark                      # e.g. "^N225"
#         name = info["name"]                     # benchmark name
#         type_ = "index"                         # consistent fixed type
#         exchange = info.get("exchange")        # may be None; that's okay
#         sector = info.get("sector")            # may be None; that's okay
#         currency = info["currency"]            # 3-letter currency code
#         country = info.get("country")          # may be None; that's okay

#         instruments_data.append(
#             (
#                 symbol,
#                 name,
#                 type_,
#                 exchange,
#                 sector,
#                 currency,
#                 country,
#             )
#         )

#     # Use RDS column names (NO instrument_code / instrument_name)
#     columns = [
#         "symbol",
#         "name",
#         "type",
#         "exchange",
#         "sector",
#         "currency_code",
#         "country",
#     ]

#     # If smart_batch_insert supports conflict_columns, you could pass ["symbol"]
#     # to avoid duplicates. If not, it will just try inserts and rely on errors/handling.
#     return smart_batch_insert("instruments", columns, instruments_data)


# def load_instrument_prices(all_prices):
#     """Load instrument_prices data, mapping by symbol (not instrument_code)."""
#     conn = get_connection()
#     cur = conn.cursor()

#     if USE_RDS_DIRECT:
#         # Match RDS schema: instrument_id + symbol
#         cur.execute(
#             "SELECT instrument_id, symbol FROM ingest_db.instruments"
#         )
#     else:
#         cur.execute("SELECT instrument_id, symbol FROM instruments")

#     instrument_map = {symbol: inst_id for inst_id, symbol in cur.fetchall()}
#     conn.close()

#     prices_data = []

#     for benchmark, prices in all_prices.items():
#         # benchmark is the symbol key in BENCHMARK_MAPPINGS
#         instrument_id = instrument_map.get(benchmark)
#         if not instrument_id:
#             # Symbol not found in instruments table, skip
#             continue

#         currency = BENCHMARK_MAPPINGS[benchmark]["currency"]

#         for price in prices:
#             prices_data.append(
#                 (
#                     instrument_id,
#                     price.get("close"),
#                     currency
#                     # price.get("date"),
#                 )
#             )

#     columns = ["instrument_id", "price", "currency_code", "captured_at"]
#     return smart_batch_insert("instrument_prices", columns, prices_data)


# def load_benchmark_history(all_prices):
#     """Load benchmark_history data (does not depend on instruments schema)."""
#     history_data = []

#     for benchmark, prices in all_prices.items():
#         benchmark_name = BENCHMARK_MAPPINGS[benchmark]["name"]
#         currency = BENCHMARK_MAPPINGS[benchmark]["currency"]

#         for price in prices:
#             history_data.append(
#                 (
#                     benchmark_name,
#                     price.get("date"),
#                     price.get("close"),
#                     currency,
#                 )
#             )

#     columns = ["benchmark_name", "valuation_date", "benchmark_value", "currency_code"]
#     return smart_batch_insert("benchmark_history", columns, history_data)


# def main():
#     """Main fetch function."""
#     print("\n" + "=" * 60)
#     print("FETCHING: Benchmark/Instrument Data from FMP")
#     print("=" * 60)

#     # [1/4] Load instruments
#     print("\n[1/4] Loading instrument definitions...")
#     instruments_inserted = load_instruments()

#     # [2/4] Fetch historical prices
#     print("\n[2/4] Fetching historical prices from FMP API...")
#     all_prices = fetch_benchmark_historical_prices()

#     if not all_prices:
#         print("No price data fetched. Exiting.")
#         return

#     # [3/4] Load instrument_prices
#     print("\n[3/4] Loading instrument_prices...")
#     prices_inserted = load_instrument_prices(all_prices)

#     # [4/4] Load benchmark_history
#     print("\n[4/4] Loading benchmark_history...")
#     history_inserted = load_benchmark_history(all_prices)

#     # Summary
#     print("\nSummary:")
#     print(f"  Instruments inserted: {instruments_inserted}")
#     print(f"  Instrument prices inserted: {prices_inserted}")
#     print(f"  Benchmark history inserted: {history_inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()



















# """
# Fetch benchmark history from FMP API
# Populates ONLY: benchmark_history table
# (Instrument prices are handled separately in fetch_instrument_prices.py)
# """

# import sys
# from pathlib import Path
# import time

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import fmp_request, smart_batch_insert
# from config import BENCHMARK_MAPPINGS, DATA_FETCH_CONFIG


# def fetch_benchmark_historical_prices():
#     """Fetch historical closing prices for all benchmarks."""
#     benchmarks = list(BENCHMARK_MAPPINGS.keys())
#     all_prices = {}

#     print(f"\nFetching historical prices for {len(benchmarks)} benchmarks...\n")

#     for benchmark in benchmarks:
#         try:
#             print(f"  Fetching {benchmark}...", end=" ")

#             data = fmp_request(
#                 "/stable/historical-price-eod/full",
#                 {"symbol": benchmark},
#             )

#             if data and isinstance(data, list):
#                 all_prices[benchmark] = data
#                 print(f"✓ {len(data)} records")
#             else:
#                 print("✗ No data")

#             time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#         except Exception as e:
#             print(f"✗ Error: {str(e)[:80]}")
#             continue

#     return all_prices


# def load_benchmark_history(all_prices):
#     from utils import get_connection

#     conn = get_connection()
#     cur = conn.cursor()

#     rows_inserted = 0

#     # Delete existing records to avoid duplicates
#     delete_sql = """
#         DELETE FROM ingest_db.benchmark_history
#         WHERE benchmark_name = %s AND valuation_date = %s;
#     """

#     # Insert new records
#     insert_sql = """
#         INSERT INTO ingest_db.benchmark_history
#             (benchmark_name, valuation_date, benchmark_value, currency_code)
#         VALUES (%s, %s, %s, %s);
#     """

#     for benchmark, prices in all_prices.items():
#         benchmark_name = BENCHMARK_MAPPINGS[benchmark]["name"]
#         currency = BENCHMARK_MAPPINGS[benchmark]["currency"]

#         for price in prices:
#             # Delete existing record if any
#             cur.execute(delete_sql, (benchmark_name, price.get("date")))

#             # Insert new record
#             cur.execute(insert_sql, (
#                 benchmark_name,
#                 price.get("date"),
#                 price.get("close"),
#                 currency
#             ))
#             rows_inserted += 1

#     conn.commit()
#     cur.close()
#     conn.close()

#     return rows_inserted



# def main():
#     print("\n" + "=" * 60)
#     print("FETCHING: Benchmark History Data (FMP API)")
#     print("=" * 60)

#     # (1) Fetch prices
#     print("\n[1/2] Fetching historical prices...")
#     all_prices = fetch_benchmark_historical_prices()

#     if not all_prices:
#         print("\n❌ No data fetched — exiting.")
#         return

#     # (2) Load benchmark_history table
#     print("\n[2/2] Loading benchmark_history table...")
#     inserted = load_benchmark_history(all_prices)

#     print("\nSummary:")
#     print(f"  Benchmark history records inserted: {inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()






























"""
Fetch benchmark history from FMP API
Populates ONLY: ingest_db.benchmark_history
(Instrument Prices handled separately)
"""

import sys
from pathlib import Path
import time

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request
from config import BENCHMARK_MAPPINGS, DATA_FETCH_CONFIG


# ------------------------------------------------------------
# 1. Fetch historical prices
# ------------------------------------------------------------
def fetch_benchmark_historical_prices():
    benchmarks = list(BENCHMARK_MAPPINGS.keys())
    all_prices = {}

    print(f"\nFetching historical prices for {len(benchmarks)} benchmarks...\n")

    for benchmark in benchmarks:
        try:
            print(f"  Fetching {benchmark}...", end=" ")

            data = fmp_request(
                "/stable/historical-price-eod/full",
                {"symbol": benchmark},
            )

            if data and isinstance(data, list):
                all_prices[benchmark] = data
                print(f"✓ {len(data)} records")
            else:
                print("✗ No data")

            time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

        except Exception as e:
            print(f"✗ Error: {str(e)[:80]}")
            continue

    return all_prices


# ------------------------------------------------------------
# 2. Load benchmark history (UPSERT)
# ------------------------------------------------------------
def load_benchmark_history(all_prices):
    from utils import get_connection
    import psycopg2

    conn = get_connection()
    cur = conn.cursor()
    rows_inserted = 0

    upsert_sql = """
        INSERT INTO ingest_db.benchmark_history (
            benchmark_name, valuation_date, benchmark_value, currency_code
        )
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (benchmark_name, valuation_date)
        DO UPDATE SET
            benchmark_value = EXCLUDED.benchmark_value,
            currency_code = EXCLUDED.currency_code,
            created_at = CURRENT_TIMESTAMP;
    """

    for benchmark, prices in all_prices.items():
        benchmark_name = BENCHMARK_MAPPINGS[benchmark]["name"]
        currency = BENCHMARK_MAPPINGS[benchmark]["currency"]

        print(f"→ Loading {benchmark_name}")

        for price in prices:
            valuation_date = price.get("date")
            benchmark_value = price.get("close")

            if not valuation_date or benchmark_value is None:
                continue

            for attempt in range(1, 6):
                try:
                    cur.execute(
                        upsert_sql,
                        (benchmark_name, valuation_date, benchmark_value, currency)
                    )
                    rows_inserted += 1
                    break
                except psycopg2.errors.DeadlockDetected:
                    conn.rollback()
                    print(f"⚠ Deadlock on {benchmark_name} {valuation_date}, retry {attempt}/5")
                    time.sleep(2)

        # 🔥 CRITICAL — release locks per benchmark
        conn.commit()

    cur.close()
    conn.close()
    return rows_inserted

# ------------------------------------------------------------
# 3. MAIN
# ------------------------------------------------------------
def main():
    print("\n" + "=" * 60)
    print("FETCHING: Benchmark History Data (FMP API)")
    print("=" * 60)

    # Step 1: Fetch
    print("\n[1/2] Fetching historical prices...")
    all_prices = fetch_benchmark_historical_prices()

    if not all_prices:
        print("\n❌ No data fetched — exiting.")
        return

    # Step 2: Load
    print("\n[2/2] Loading benchmark_history table...")
    inserted = load_benchmark_history(all_prices)

    print("\nSummary:")
    print(f"  Benchmark history rows inserted/updated: {inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
