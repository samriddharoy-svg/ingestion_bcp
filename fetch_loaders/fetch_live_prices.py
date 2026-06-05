# """
# Fetch live stock prices from FMP API (stable/historical-price-eod/full)
# Special handling: 6887.HK uses Yahoo Finance direct API
# Updates: stocks_price_data table with latest prices

# Note: Day price change and day price change % are CALCULATED, not fetched:
# - Day Price Change = P_close,t - P_close,t-1 (today's close - yesterday's close)
# - Day Price Change % = ((P_close,t - P_close,t-1) / P_close,t-1) × 100
# """
# import sys
# from pathlib import Path
# import time
# import requests
# from datetime import datetime, timedelta

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import smart_batch_insert, get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG, FMP_API_KEY, USE_RDS_DIRECT

# # Note: yfinance library not needed - using direct Yahoo Finance API for 6887.HK


# def fetch_latest_price(ticker):
#     """Fetch latest price from FMP stable/historical-price-eod/full endpoint."""
#     try:
#         url = f"https://financialmodelingprep.com/stable/historical-price-eod/full?symbol={ticker}&apikey={FMP_API_KEY}"
#         response = requests.get(url, timeout=30)
#         response.raise_for_status()
#         data = response.json()

#         # Get the two most recent records to calculate change
#         if data and len(data) >= 2:
#             latest = data[0]  # Most recent
#             previous = data[1]  # Previous day
#             return latest, previous
#         elif data and len(data) == 1:
#             return data[0], None
#         return None, None
#     except Exception as e:
#         print(f"      Error: {e}")
#         return None, None


# def fetch_yahoo_direct_api(ticker):
#     """Fetch latest price from Yahoo Finance API directly for 6887.HK.

#     This bypasses yfinance library which has rate limiting issues.
#     Uses Yahoo Finance v8 chart API directly.
#     """
#     try:
#         url = f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range=5d"
#         headers = {
#             'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
#         }

#         response = requests.get(url, headers=headers, timeout=10)
#         response.raise_for_status()

#         data = response.json()

#         if 'chart' in data and 'result' in data['chart']:
#             result = data['chart']['result']
#             if not result or len(result) == 0:
#                 return None, None

#             # Extract data from result
#             quotes = result[0]
#             timestamps = quotes.get('timestamp', [])
#             indicators = quotes.get('indicators', {})
#             quote_data = indicators.get('quote', [{}])[0]

#             if not timestamps or not quote_data:
#                 return None, None

#             # Get the most recent trading day
#             latest_idx = -1
#             latest = {
#                 'date': datetime.fromtimestamp(timestamps[latest_idx]).strftime('%Y-%m-%d'),
#                 'open': quote_data.get('open', [None])[latest_idx],
#                 'high': quote_data.get('high', [None])[latest_idx],
#                 'low': quote_data.get('low', [None])[latest_idx],
#                 'close': quote_data.get('close', [None])[latest_idx],
#                 'volume': quote_data.get('volume', [None])[latest_idx]
#             }

#             # Get previous day if available
#             previous = None
#             if len(timestamps) >= 2:
#                 prev_idx = -2
#                 previous = {
#                     'date': datetime.fromtimestamp(timestamps[prev_idx]).strftime('%Y-%m-%d'),
#                     'close': quote_data.get('close', [None])[prev_idx]
#                 }

#             return latest, previous

#     except Exception as e:
#         print(f"      Yahoo API Error: {str(e)[:100]}")
#         return None, None


# def fetch_all_live_prices():
#     """Fetch live prices for all stocks. Uses FMP for all except 6887.HK (uses yfinance)."""
#     tickers = list(set(TICKER_MAPPINGS.values()))

#     # Get stock mapping
#     conn = get_connection()
#     cur = conn.cursor()

#     if USE_RDS_DIRECT:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
#     else:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

#     stock_map = {ticker: (stock_id, currency) for stock_id, ticker, currency in cur.fetchall()}
#     conn.close()

#     price_data = []

#     print(f"\nFetching live prices for {len(tickers)} stocks...")

#     for ticker in tickers:
#         stock_info = stock_map.get(ticker)
#         if not stock_info:
#             continue

#         stock_id, currency = stock_info

#         try:
#             # Special handling for 6887.HK - use Yahoo Finance direct API
#             if ticker == '6887.HK':
#                 print(f"  Fetching {ticker} (Yahoo Finance API)...")
#                 latest, previous = fetch_yahoo_direct_api(ticker)
#                 source = "Yahoo API"
#             else:
#                 print(f"  Fetching {ticker} (FMP)...")
#                 latest, previous = fetch_latest_price(ticker)
#                 source = "FMP"

#             if latest:
#                 # ✅ CHECK: Only accept data from yesterday or earlier (not today)
#                 latest_date = latest.get('date', '')
#                 if not is_date_valid_for_ingestion(latest_date):
#                     print(f"    ⚠️  Skipping {ticker} - data is from today ({latest_date}), waiting for yesterday's close")
#                     continue

#                 # Extract data from latest record
#                 opening_price = latest.get('open', 0)
#                 closing_price = latest.get('close', 0)
#                 price = closing_price  # Use closing price as current price
#                 volume = latest.get('volume', 0)

#                 # ✅ CALCULATE day price change (NOT fetched from API)
#                 # Formula 1: Day Price Change = P_close,t - P_close,t-1
#                 # Formula 2: Day Price Change % = ((P_close,t - P_close,t-1) / P_close,t-1) × 100
#                 if previous:
#                     previous_close = previous.get('close', 0)
#                     # Day-over-day change (today's close vs yesterday's close)
#                     day_price_change = (closing_price - previous_close)/previous_close if previous_close else 0
#                     day_price_change_pct = ((closing_price - previous_close) / previous_close * 100) if previous_close else 0
#                 else:
#                     # Fallback: If no previous data available, use intraday change (close vs open)
#                     day_price_change = closing_price - opening_price if opening_price else 0
#                     day_price_change_pct = ((closing_price - opening_price) / opening_price * 100) if opening_price else 0

#                 # ✅ Use the market data date, not the current timestamp
#                 # Format: 'YYYY-MM-DD 00:00:00' to match the market close date
#                 market_date = f"{latest_date} 00:00:00"

#                 price_data.append((
#                     stock_id,
#                     price,                        # price (closing price)
#                     opening_price,                # opening_price
#                     closing_price,                # closing_price
#                     day_price_change,             # day_price_change
#                     currency,                     # currency_code
#                     day_price_change_pct,         # day_price_change_pct
#                     volume,                       # volume
#                     None,                         # volume_30d (not available)
#                     None,                         # market_cap (not available)
#                     market_date                   # captured_at (use market date, not script run time)
#                 ))

#                 print(f"    ✓ {source} - Price: {price}, Open: {opening_price}, Close: {closing_price}, Change: {day_price_change:.2f} ({day_price_change_pct:.2f}%)")
#             else:
#                 print(f"    ✗ No data found for {ticker} ({source})")

#             # Rate limit delay (only for FMP, skip for yfinance)
#             if source == "FMP":
#                 time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

#         except Exception as e:
#             print(f"    ✗ Error fetching {ticker}: {e}")
#             continue

#     return price_data


# def main():
#     """Main fetch function."""
#     print("\n" + "=" * 60)
#     print("FETCHING: Live Stock Prices (FMP + Yahoo API for 6887.HK)")
#     print("=" * 60)

#     # Fetch
#     print("\n[1/2] Fetching live prices...")
#     price_data = fetch_all_live_prices()

#     if not price_data:
#         print("No price data fetched. Exiting.")
#         return

#     # Load
#     print("\n[2/2] Loading to database...")
#     columns = [
#         'stock_id', 'price', 'opening_price', 'closing_price',
#         'day_price_change', 'currency_code', 'day_price_change_pct',
#         'volume', 'volume_30d', 'market_cap', 'captured_at'
#     ]
#     inserted = smart_batch_insert('stocks_price_data', columns, price_data)

#     # Summary
#     print("\nSummary:")
#     print(f"  Live price records inserted: {inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()






















# """
# Fetch historical stock prices
# Sources:
# - FMP API for most tickers
# - Yahoo Finance chart API for 6887.HK

# Populates: ingest_db.stocks_price_data

# Rules:
# - Uses price_date as market date
# - Day price change = today_close - yesterday_close
# - UPSERT on (stock_id, price_date)
# - Safe for re-runs (updates existing rows)
# """

# import sys
# from pathlib import Path
# import time
# import requests
# from datetime import datetime

# # --------------------------------------------------
# # Path setup
# # --------------------------------------------------
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import (
#     TICKER_MAPPINGS,
#     DATA_FETCH_CONFIG,
#     FMP_API_KEY,
#     USE_RDS_DIRECT
# )

# # --------------------------------------------------
# # Fetch historical prices from FMP
# # --------------------------------------------------
# def fetch_fmp_historical_prices(ticker):
#     try:
#         url = (
#             "https://financialmodelingprep.com/stable/"
#             f"historical-price-eod/full?symbol={ticker}&apikey={FMP_API_KEY}"
#         )
#         response = requests.get(url, timeout=30)
#         response.raise_for_status()
#         return response.json() or []
#     except Exception as e:
#         print(f"    ✗ FMP error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # Fetch historical prices from Yahoo (6887.HK)
# # --------------------------------------------------
# def fetch_yahoo_historical_prices(ticker, days=30):
#     try:
#         url = (
#             f"https://query1.finance.yahoo.com/v8/finance/chart/"
#             f"{ticker}?interval=1d&range={days}d"
#         )
#         headers = {"User-Agent": "Mozilla/5.0"}

#         response = requests.get(url, headers=headers, timeout=20)
#         response.raise_for_status()
#         data = response.json()

#         result = data.get("chart", {}).get("result")
#         if not result:
#             return []

#         quotes = result[0]
#         timestamps = quotes.get("timestamp", [])
#         indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

#         records = []
#         for i, ts in enumerate(timestamps):
#             records.append({
#                 "date": datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
#                 "open": indicators.get("open", [None])[i],
#                 "high": indicators.get("high", [None])[i],
#                 "low": indicators.get("low", [None])[i],
#                 "close": indicators.get("close", [None])[i],
#                 "volume": indicators.get("volume", [None])[i],
#             })

#         return records

#     except Exception as e:
#         print(f"    ✗ Yahoo error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # Main fetch + load logic
# # --------------------------------------------------
# def fetch_and_load_prices():
#     tickers = list(set(TICKER_MAPPINGS.values()))

#     conn = get_connection()
#     cur = conn.cursor()

#     # Load stock mapping
#     if USE_RDS_DIRECT:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
#     else:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

#     stock_map = {
#         ticker: (stock_id, currency)
#         for stock_id, ticker, currency in cur.fetchall()
#     }

#     if not stock_map:
#         print("❌ No stocks found in DB")
#         return

#     # Delete existing record to avoid duplicates
#     delete_sql = """
#         DELETE FROM ingest_db.stocks_price_data
#         WHERE stock_id = %s
#         AND DATE(captured_at) = %s;
#     """

#     insert_sql = """
#         INSERT INTO ingest_db.stocks_price_data (
#             stock_id,
#             price,
#             opening_price,
#             closing_price,
#             day_price_change,
#             currency_code,
#             day_price_change_pct,
#             volume,
#             volume_30d,
#             market_cap,
#             captured_at
#         )
#         VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);
#     """

#     total_rows = 0

#     print(f"\nFetching historical prices for {len(tickers)} stocks...\n")

#     for ticker in tickers:
#         stock_info = stock_map.get(ticker)
#         if not stock_info:
#             continue

#         stock_id, currency = stock_info
#         print(f"Fetching {ticker}...")

#         # Choose source
#         if ticker == "6887.HK":
#             records = fetch_yahoo_historical_prices(ticker, days=30)
#         else:
#             records = fetch_fmp_historical_prices(ticker)

#         # ✅ Sort by date (CRITICAL for correct day change)
#         records = sorted(records, key=lambda x: x.get("date"))
#         previous_close = None

#         for r in records:
#             price_date = r.get("date")
#             if not price_date:
#                 continue

#             # Skip today / invalid market dates
#             if not is_date_valid_for_ingestion(price_date):
#                 continue

#             open_price = r.get("open")
#             close_price = r.get("close")
#             volume = r.get("volume")

#             if open_price is None or close_price is None:
#                 continue

#             # ✅ Day-over-day calculation (CORRECT LOGIC)
#             if previous_close not in (None, 0):
#                 day_change = (close_price - previous_close)
#                 day_change_pct = ((close_price - previous_close) / previous_close) * 100
#             else:
#                 day_change = None
#                 day_change_pct = None
#             previous_close = close_price

#             # ✅ Market date timestamp (NOT runtime)
#             captured_at = datetime.now()

#             cur.execute(
#                 upsert_sql,
#                 (
#                     stock_id,
#                     close_price,      # price
#                     open_price,
#                     close_price,
#                     day_change,
#                     currency,
#                     day_change_pct,
#                     volume,
#                     None,             # volume_30d
#                     None,             # market_cap
#                     captured_at,
#                     price_date
#                 )
#             )
#             total_rows += 1

#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     conn.commit()
#     cur.close()
#     conn.close()

#     print("\n======================================")
#     print(f"✓ Rows inserted / updated: {total_rows}")
#     print("======================================\n")

# # --------------------------------------------------
# # Entry point
# # --------------------------------------------------
# def main():
#     print("\n======================================")
#     print("FETCHING: Historical Stock Price Data")
#     print("======================================")
#     fetch_and_load_prices()

# if __name__ == "__main__":
#     main()
















































# """
# Fetch historical stock prices
# Populates: ingest_db.stocks_price_data
# """

# import sys
# from pathlib import Path
# import time
# import requests
# from datetime import datetime

# # --------------------------------------------------
# # Path setup
# # --------------------------------------------------
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import (
#     TICKER_MAPPINGS,
#     DATA_FETCH_CONFIG,
#     FMP_API_KEY,
#     USE_RDS_DIRECT
# )

# # --------------------------------------------------
# # Fetch historical prices from FMP
# # --------------------------------------------------
# def fetch_fmp_historical_prices(ticker):
#     try:
#         url = (
#             "https://financialmodelingprep.com/stable/"
#             f"historical-price-eod/full?symbol={ticker}&apikey={FMP_API_KEY}"
#         )
#         response = requests.get(url, timeout=30)
#         response.raise_for_status()
#         return response.json() or []
#     except Exception as e:
#         print(f"    ✗ FMP error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # Fetch historical prices from Yahoo (for 6887.HK)
# # --------------------------------------------------
# def fetch_yahoo_historical_prices(ticker, days=30):
#     try:
#         url = (
#             f"https://query1.finance.yahoo.com/v8/finance/chart/"
#             f"{ticker}?interval=1d&range={days}d"
#         )
#         headers = {"User-Agent": "Mozilla/5.0"}

#         response = requests.get(url, headers=headers, timeout=20)
#         response.raise_for_status()
#         data = response.json()

#         result = data.get("chart", {}).get("result")
#         if not result:
#             return []

#         quotes = result[0]
#         timestamps = quotes.get("timestamp", [])
#         indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

#         records = []
#         for i, ts in enumerate(timestamps):
#             records.append({
#                 "date": datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
#                 "open": indicators.get("open", [None])[i],
#                 "high": indicators.get("high", [None])[i],
#                 "low": indicators.get("low", [None])[i],
#                 "close": indicators.get("close", [None])[i],
#                 "volume": indicators.get("volume", [None])[i],
#             })

#         return records

#     except Exception as e:
#         print(f"    ✗ Yahoo error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # UPSERT SQL (FIXED)
# # --------------------------------------------------
# upsert_sql = """
# INSERT INTO ingest_db.stocks_price_data (
#     stock_id,
#     price,
#     opening_price,
#     closing_price,
#     day_price_change,
#     currency_code,
#     day_price_change_pct,
#     volume,
#     volume_30d,
#     market_cap,
#     captured_at,
#     price_date
# )
# VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
# ON CONFLICT (stock_id, price_date)
# DO UPDATE SET
#     price = EXCLUDED.price,
#     opening_price = EXCLUDED.opening_price,
#     closing_price = EXCLUDED.closing_price,
#     day_price_change = EXCLUDED.day_price_change,
#     day_price_change_pct = EXCLUDED.day_price_change_pct,
#     currency_code = EXCLUDED.currency_code,
#     volume = EXCLUDED.volume,
#     captured_at = EXCLUDED.captured_at;
# """

# # --------------------------------------------------
# # Main fetch + load logic
# # --------------------------------------------------
# def fetch_and_load_prices():
#     tickers = list(set(TICKER_MAPPINGS.values()))

#     conn = get_connection()
#     cur = conn.cursor()

#     # Load mapping
#     if USE_RDS_DIRECT:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
#     else:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

#     stock_map = {
#         ticker: (stock_id, currency)
#         for stock_id, ticker, currency in cur.fetchall()
#     }

#     if not stock_map:
#         print("❌ No stocks found in DB")
#         return

#     total_rows = 0

#     print(f"\nFetching historical prices for {len(tickers)} stocks...\n")

#     for ticker in tickers:
#         stock_info = stock_map.get(ticker)
#         if not stock_info:
#             continue

#         stock_id, currency = stock_info
#         print(f"Fetching {ticker}...")

#         # Choose API source
#         if ticker == "6887.HK":
#             records = fetch_yahoo_historical_prices(ticker, days=30)
#         else:
#             records = fetch_fmp_historical_prices(ticker)

#         # Sort by date (CRITICAL)
#         records = sorted(records, key=lambda x: x.get("date"))

#         previous_close = None

#         for r in records:
#             price_date = r.get("date")
#             if not price_date:
#                 continue

#             if not is_date_valid_for_ingestion(price_date):
#                 continue

#             open_price = r.get("open")
#             close_price = r.get("close")
#             volume = r.get("volume")

#             if open_price is None or close_price is None:
#                 continue

#             # Day-over-day calculation
#             if previous_close not in (None, 0):
#                 day_change = close_price - previous_close
#                 day_change_pct = (day_change / previous_close) * 100
#             else:
#                 day_change = None
#                 day_change_pct = None

#             previous_close = close_price

#             captured_at = datetime.now()

#             cur.execute(
#                 upsert_sql,
#                 (
#                     stock_id,
#                     close_price,
#                     open_price,
#                     close_price,
#                     day_change,
#                     currency,
#                     day_change_pct,
#                     volume,
#                     None,
#                     None,
#                     captured_at,
#                     price_date
#                 )
#             )

#             total_rows += 1

#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     conn.commit()
#     cur.close()
#     conn.close()

#     print("\n======================================")
#     print(f"✓ Rows inserted / updated: {total_rows}")
#     print("======================================\n")

# # --------------------------------------------------
# # Entry point
# # --------------------------------------------------
# def main():
#     print("\n======================================")
#     print("FETCHING: Historical Stock Price Data")
#     print("======================================")
#     fetch_and_load_prices()

# if __name__ == "__main__":
#     main()



















# """
# Fetch historical stock prices
# Populates: ingest_db.stocks_price_data
# """

# import sys
# from pathlib import Path
# import time
# import requests
# from datetime import datetime

# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import (
#     TICKER_MAPPINGS,
#     DATA_FETCH_CONFIG,
#     FMP_API_KEY,
#     USE_RDS_DIRECT
# )

# # --------------------------------------------------
# # Fetch historical prices from FMP
# # --------------------------------------------------
# def fetch_fmp_historical_prices(ticker):
#     try:
#         url = (
#             "https://financialmodelingprep.com/stable/"
#             f"historical-price-eod/full?symbol={ticker}&apikey={FMP_API_KEY}"
#         )
#         r = requests.get(url, timeout=30)
#         r.raise_for_status()
#         data = r.json()

#         # ✅ Normalize response
#         if isinstance(data, dict):
#             return data.get("historical", []) or []
#         elif isinstance(data, list):
#             return data
#         return []

#     except Exception as e:
#         print(f"⚠ FMP error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # Fetch Yahoo prices (SAFE)
# # --------------------------------------------------
# def fetch_yahoo_historical_prices(ticker, days=30):
#     try:
#         url = (
#             f"https://query1.finance.yahoo.com/v8/finance/chart/"
#             f"{ticker}?interval=1d&range={days}d"
#         )
#         headers = {"User-Agent": "Mozilla/5.0"}
#         r = requests.get(url, headers=headers, timeout=20)
#         r.raise_for_status()

#         data = r.json()
#         result = data.get("chart", {}).get("result")
#         if not result:
#             return []

#         quotes = result[0]
#         timestamps = quotes.get("timestamp") or []
#         indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

#         opens = indicators.get("open") or []
#         closes = indicators.get("close") or []
#         volumes = indicators.get("volume") or []

#         records = []
#         for i, ts in enumerate(timestamps):
#             if i >= len(opens) or i >= len(closes):
#                 continue

#             records.append({
#                 "date": datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
#                 "open": opens[i],
#                 "close": closes[i],
#                 "volume": volumes[i] if i < len(volumes) else None,
#             })

#         return records

#     except Exception as e:
#         print(f"⚠ Yahoo error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # UPSERT SQL
# # --------------------------------------------------
# upsert_sql = """
# INSERT INTO ingest_db.stocks_price_data (
#     stock_id,
#     price,
#     opening_price,
#     closing_price,
#     day_price_change,
#     currency_code,
#     day_price_change_pct,
#     volume,
#     volume_30d,
#     market_cap,
#     captured_at,
#     price_date
# )
# VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
# ON CONFLICT (stock_id, price_date)
# DO UPDATE SET
#     price = EXCLUDED.price,
#     opening_price = EXCLUDED.opening_price,
#     closing_price = EXCLUDED.closing_price,
#     day_price_change = EXCLUDED.day_price_change,
#     day_price_change_pct = EXCLUDED.day_price_change_pct,
#     currency_code = EXCLUDED.currency_code,
#     volume = EXCLUDED.volume,
#     captured_at = EXCLUDED.captured_at;
# """

# # --------------------------------------------------
# # Main logic
# # --------------------------------------------------
# def fetch_and_load_prices():
#     conn = get_connection()
#     cur = conn.cursor()

#     cur.execute("""
#         SELECT stock_id, ticker, currency_code
#         FROM ingest_db.stocks
#     """)
#     stock_map = {t: (sid, c) for sid, t, c in cur.fetchall()}

#     if not stock_map:
#         print("❌ No stocks found")
#         return

#     total_rows = 0
#     print(f"Fetching historical prices for {len(stock_map)} stocks\n")

#     for ticker, (stock_id, currency) in stock_map.items():
#         try:
#             print(f"→ {ticker}")

#             records = (
#                 fetch_yahoo_historical_prices(ticker, 30)
#                 if ticker == "6887.HK"
#                 else fetch_fmp_historical_prices(ticker)
#             )

#             if not records:
#                 print(f"  ⚠ No data for {ticker}")
#                 continue

#             records.sort(key=lambda x: x.get("date") or "")
#             previous_close = None

#             for r in records:
#                 date_ = r.get("date")
#                 if not date_ or not is_date_valid_for_ingestion(date_):
#                     continue

#                 open_p = r.get("open")
#                 close_p = r.get("close")
#                 vol = r.get("volume")

#                 if open_p is None or close_p is None:
#                     continue

#                 if previous_close not in (None, 0):
#                     delta = close_p - previous_close
#                     delta_pct = (delta / previous_close) * 100
#                 else:
#                     delta = None
#                     delta_pct = None

#                 previous_close = close_p

#                 cur.execute(
#                     upsert_sql,
#                     (
#                         stock_id,
#                         close_p,
#                         open_p,
#                         close_p,
#                         delta,
#                         currency,
#                         delta_pct,
#                         vol,
#                         None,
#                         None,
#                         datetime.utcnow(),
#                         date_
#                     )
#                 )
#                 total_rows += 1

#             time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#         except Exception as e:
#             print(f"❌ Fatal ticker error {ticker}: {e}")
#             continue

#     conn.commit()
#     cur.close()
#     conn.close()

#     print(f"\n✓ Rows inserted / updated: {total_rows}")

# # --------------------------------------------------
# # Entry point (CRITICAL)
# # --------------------------------------------------
# def main():
#     try:
#         print("\nFETCHING: Historical Stock Price Data\n")
#         fetch_and_load_prices()
#         print("✅ Live prices task completed successfully")
#     except Exception as e:
#         print("❌ Fatal task error:", e)
#         raise  # ECS will mark failure ONLY on true fatal error

# if __name__ == "__main__":
#     main()
























# """
# Fetch historical stock prices
# Populates: ingest_db.stocks_price_data
# """

# # --------------------------------------------------
# # PATH FIX (CRITICAL)
# # --------------------------------------------------
# import sys
# from pathlib import Path

# sys.path.insert(0, str(Path(__file__).parent.parent))

# if hasattr(sys.stdout, 'reconfigure'):
#     sys.stdout.reconfigure(encoding='utf-8', errors='replace')
# if hasattr(sys.stderr, 'reconfigure'):
#     sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# # --------------------------------------------------
# # IMPORTS
# # --------------------------------------------------
# import time
# import requests
# import psycopg2
# from datetime import datetime

# from utils import get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import (
#     TICKER_MAPPINGS,
#     DATA_FETCH_CONFIG,
#     FMP_API_KEY,
# )

# BASE_URL = "https://financialmodelingprep.com/stable"

# MAX_DEADLOCK_RETRIES = 3
# DEADLOCK_RETRY_DELAY = 2  # seconds

# # --------------------------------------------------
# # Fetch historical prices from FMP
# # --------------------------------------------------
# def fetch_fmp_historical_prices(ticker):
#     try:
#         r = requests.get(
#             f"{BASE_URL}/historical-price-eod/full",
#             params={"symbol": ticker, "apikey": FMP_API_KEY},
#             timeout=30,
#         )
#         r.raise_for_status()
#         data = r.json()

#         if isinstance(data, dict):
#             return data.get("historical", []) or []
#         elif isinstance(data, list):
#             return data
#         return []

#     except Exception as e:
#         print(f"⚠ FMP error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # Fetch Yahoo prices (ONLY for 6887.HK)
# # --------------------------------------------------
# def fetch_yahoo_historical_prices(ticker, days=30):
#     try:
#         r = requests.get(
#             f"https://query1.finance.yahoo.com/v8/finance/chart/"
#             f"{ticker}?interval=1d&range={days}d",
#             headers={"User-Agent": "Mozilla/5.0"},
#             timeout=20,
#         )
#         r.raise_for_status()

#         data = r.json()
#         result = data.get("chart", {}).get("result")
#         if not result:
#             return []

#         quotes = result[0]
#         timestamps = quotes.get("timestamp") or []
#         indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

#         opens = indicators.get("open") or []
#         closes = indicators.get("close") or []
#         volumes = indicators.get("volume") or []

#         records = []
#         for i, ts in enumerate(timestamps):
#             if i >= len(opens) or i >= len(closes):
#                 continue

#             records.append({
#                 "date": datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
#                 "open": opens[i],
#                 "close": closes[i],
#                 "volume": volumes[i] if i < len(volumes) else None,
#             })

#         return records

#     except Exception as e:
#         print(f"⚠ Yahoo error for {ticker}: {e}")
#         return []

# # --------------------------------------------------
# # UPSERT SQL
# # --------------------------------------------------
# upsert_sql = """
# INSERT INTO ingest_db.stocks_price_data (
#     stock_id,
#     price,
#     opening_price,
#     closing_price,
#     day_price_change,
#     currency_code,
#     day_price_change_pct,
#     volume,
#     volume_30d,
#     market_cap,
#     captured_at,
#     price_date
# )
# VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
# ON CONFLICT (stock_id, price_date)
# DO UPDATE SET
#     price = EXCLUDED.price,
#     opening_price = EXCLUDED.opening_price,
#     closing_price = EXCLUDED.closing_price,
#     day_price_change = EXCLUDED.day_price_change,
#     day_price_change_pct = EXCLUDED.day_price_change_pct,
#     currency_code = EXCLUDED.currency_code,
#     volume = EXCLUDED.volume,
#     captured_at = EXCLUDED.captured_at;
# """

# # --------------------------------------------------
# # CORE LOGIC
# # --------------------------------------------------
# def fetch_and_load_prices():
#     conn = get_connection()
#     cur = conn.cursor()

#     # ----------------------------------------------
#     # Load stocks ONLY from TICKER_MAPPINGS
#     # ----------------------------------------------
#     tickers = list(set(TICKER_MAPPINGS.values()))

#     cur.execute(
#         """
#         SELECT stock_id, ticker, currency_code
#         FROM ingest_db.stocks
#         WHERE ticker = ANY(%s);
#         """,
#         (tickers,),
#     )

#     stock_map = {
#         ticker: (stock_id, currency)
#         for stock_id, ticker, currency in cur.fetchall()
#     }

#     if not stock_map:
#         print(" No matching stocks found for configured tickers")
#         return

#     total_rows = 0
#     print(f"\nFetching historical prices for {len(stock_map)} stocks\n")

#     # ----------------------------------------------
#     # PROCESS EACH STOCK
#     # ----------------------------------------------
#     for ticker in tickers:
#         stock_info = stock_map.get(ticker)
#         if not stock_info:
#             print(f"⚠ Ticker {ticker} not found in DB, skipping")
#             continue

#         stock_id, currency = stock_info
#         print(f"→ {ticker}")

#         try:
#             records = (
#                 fetch_yahoo_historical_prices(ticker, 30)
#                 if ticker == "6887.HK"
#                 else fetch_fmp_historical_prices(ticker)
#             )

#             if not records:
#                 print(f"  ⚠ No data for {ticker}")
#                 continue

#             records.sort(key=lambda x: x.get("date") or "")
#             previous_close = None

#             for r in records:
#                 price_date = r.get("date")
#                 if not price_date:
#                     continue

#                 open_p = r.get("open")
#                 close_p = r.get("close")
#                 vol = r.get("volume")

#                 if open_p is None or close_p is None:
#                     continue

#                 if previous_close not in (None, 0):
#                     delta = close_p - previous_close
#                     delta_pct = (delta / previous_close) * 100
#                 else:
#                     delta = None
#                     delta_pct = None

#                 previous_close = close_p

#                 # ---------- DEADLOCK-SAFE INSERT ----------
#                 for attempt in range(1, MAX_DEADLOCK_RETRIES + 1):
#                     try:
#                         cur.execute(
#                             upsert_sql,
#                             (
#                                 stock_id,
#                                 close_p,
#                                 open_p,
#                                 close_p,
#                                 delta,
#                                 currency,
#                                 delta_pct,
#                                 vol,
#                                 None,
#                                 None,
#                                 datetime.now(),
#                                 price_date
#                             )
#                         )
#                         total_rows += 1
#                         break

#                     except psycopg2.errors.DeadlockDetected:
#                         conn.rollback()
#                         print(
#                             f"⚠ Deadlock detected "
#                             f"({ticker} @ {price_date}) "
#                             f"retry {attempt}/{MAX_DEADLOCK_RETRIES}"
#                         )
#                         time.sleep(DEADLOCK_RETRY_DELAY)

#                 else:
#                     raise Exception(
#                         f"Insert failed after {MAX_DEADLOCK_RETRIES} retries "
#                         f"for {ticker} on {price_date}"
#                     )
#             conn.commit()
#             time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#         except Exception as e:
#             print(f" Fatal ticker error {ticker}: {e}")
#             continue

    
#     cur.close()
#     conn.close()

#     print(f"\n✓ Rows inserted / updated: {total_rows}")

# # --------------------------------------------------
# # ENTRY POINT
# # --------------------------------------------------
# def main():
#     try:
#         print("\nFETCHING: Historical Stock Price Data\n")
#         fetch_and_load_prices()
#         print(" Live prices task completed successfully")
#     except Exception as e:
#         print(" Fatal task error:", e)
#         raise  # ECS marks failure only for real fatal errors

# if __name__ == "__main__":
#     main()



"""
Fetch historical stock prices
Populates: ingest_db.stocks_price_data
"""

# --------------------------------------------------
# PATH FIX
# --------------------------------------------------
import sys
import os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

# --------------------------------------------------
# IMPORTS
# --------------------------------------------------
import threading
import time
import requests
import psycopg2
import concurrent.futures
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from psycopg2.extras import execute_values

from utils import get_connection
from config import FMP_API_KEY

BASE_URL = "https://financialmodelingprep.com/stable"

MAX_DEADLOCK_RETRIES    = 3
DEADLOCK_RETRY_DELAY    = 2
PRICE_FETCH_MAX_WORKERS = int(os.environ.get("PRICE_FETCH_MAX_WORKERS", "8"))
YFINANCE_FALLBACK_PERIOD = os.environ.get("YFINANCE_FALLBACK_PERIOD", "max")

# Max concurrent FMP calls and per-call delay to stay within rate limits
FMP_CONCURRENCY   = int(float(os.environ.get("FMP_CONCURRENCY", "3")))
FMP_CALL_DELAY    = float(os.environ.get("FMP_CALL_DELAY", "0.4"))
_fmp_semaphore    = threading.Semaphore(FMP_CONCURRENCY)

# UAE tickers that fall back to StockAnalysis ADX scraper
STOCKANALYSIS_ADX_SYMBOLS = {
    "ALDAR.AD":  "ALDAR",
    "ALDAR.AE":  "ALDAR",
    "ALDAR.ADX": "ALDAR",
    "ESHRAQ.AD":  "ESHRAQ",
    "ESHRAQ.AE":  "ESHRAQ",
    "ESHRAQ.ADX": "ESHRAQ",
}

_HTTP_SESSION = None


# --------------------------------------------------
# SHARED HTTP SESSION (connection pooling + auto-retry)
# --------------------------------------------------
def _get_session():
    global _HTTP_SESSION
    if _HTTP_SESSION is None:
        session = requests.Session()
        retry = Retry(
            total=3,
            backoff_factor=0.3,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=("GET",),
            raise_on_status=False,
        )
        adapter = HTTPAdapter(pool_connections=100, pool_maxsize=100, max_retries=retry)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        _HTTP_SESSION = session
    return _HTTP_SESSION


# --------------------------------------------------
# FETCH FROM FMP (primary)
# --------------------------------------------------
def fetch_fmp_historical_prices(ticker):
    with _fmp_semaphore:
        try:
            r = _get_session().get(
                f"{BASE_URL}/historical-price-eod/full",
                params={"symbol": ticker, "apikey": FMP_API_KEY},
                timeout=30,
            )
            r.raise_for_status()
            data = r.json()

            if isinstance(data, dict):
                return data.get("historical", []) or []
            elif isinstance(data, list):
                return data
            return []

        except Exception as e:
            print(f"⚠ FMP error for {ticker}: {e}")
            return []
        finally:
            time.sleep(FMP_CALL_DELAY)


# --------------------------------------------------
# FETCH FROM YAHOO (primary for 6887.HK)
# --------------------------------------------------
def fetch_yahoo_historical_prices(ticker, days=30):
    try:
        r = _get_session().get(
            f"https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?interval=1d&range={days}d",
            headers={"User-Agent": "Mozilla/5.0"},
            timeout=20,
        )
        r.raise_for_status()

        data   = r.json()
        result = data.get("chart", {}).get("result")
        if not result:
            return []

        quotes     = result[0]
        timestamps = quotes.get("timestamp") or []
        indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

        opens   = indicators.get("open")   or []
        closes  = indicators.get("close")  or []
        volumes = indicators.get("volume") or []

        records = []
        for i, ts in enumerate(timestamps):
            if i >= len(opens) or i >= len(closes):
                continue
            records.append({
                "date":   datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
                "open":   opens[i],
                "close":  closes[i],
                "volume": volumes[i] if i < len(volumes) else None,
            })
        return records

    except Exception as e:
        print(f"⚠ Yahoo error for {ticker}: {e}")
        return []


# --------------------------------------------------
# FALLBACK 1: yfinance (when FMP returns nothing)
# --------------------------------------------------
def fetch_yfinance_historical_prices(ticker, period=None, quiet=False):
    period = period or YFINANCE_FALLBACK_PERIOD
    try:
        import yfinance as yf

        df = None

        # Try Ticker.history() — works in both yfinance v0.1 and v0.2
        try:
            df = yf.Ticker(ticker).history(period=period, interval="1d")
        except Exception:
            df = None

        # Fallback to yf.download() without deprecated params
        if df is None or df.empty:
            try:
                df = yf.download(ticker, period=period, interval="1d", progress=False)
            except Exception:
                df = None

        if df is None or df.empty:
            return []

        # yfinance ≥0.2 returns MultiIndex columns ("Close", "TICKER") — flatten them
        if hasattr(df.columns, "levels"):
            df.columns = df.columns.get_level_values(0)

        records = []
        for index, row in df.iterrows():
            date_value  = getattr(index, "date", lambda: index)()
            open_price  = row.get("Open")
            close_price = row.get("Close")
            volume      = row.get("Volume")
            if open_price is None or close_price is None:
                continue
            if hasattr(open_price,  "item"): open_price  = open_price.item()
            if hasattr(close_price, "item"): close_price = close_price.item()
            if hasattr(volume,      "item"): volume      = volume.item()
            records.append({
                "date":   date_value.isoformat(),
                "open":   open_price,
                "close":  close_price,
                "volume": None if volume != volume else volume,
            })
        return records

    except Exception as e:
        if not quiet:
            print(f"⚠ yfinance fallback error for {ticker}: {e}")
        return []


# --------------------------------------------------
# FALLBACK 2: StockAnalysis ADX scraper (UAE only)
# --------------------------------------------------
def _parse_stockanalysis_number(value):
    value = (value or "").strip().replace(",", "")
    if value in {"", "-", "—", "N/A"}:
        return None
    return float(value)


def _parse_stockanalysis_volume(value):
    value = (value or "").strip().replace(",", "")
    if value in {"", "-", "—", "N/A"}:
        return None
    return int(float(value))


def fetch_stockanalysis_adx_prices(ticker):
    adx_symbol = STOCKANALYSIS_ADX_SYMBOLS.get(ticker)
    if not adx_symbol:
        return []
    try:
        response = _get_session().get(
            f"https://stockanalysis.com/quote/adx/{adx_symbol}/history/",
            headers={"User-Agent": "Mozilla/5.0"},
            timeout=20,
        )
        response.raise_for_status()
        soup    = BeautifulSoup(response.text, "html.parser")
        records = []
        for row in soup.select("table tbody tr"):
            cells = [c.get_text(" ", strip=True) for c in row.find_all(["td", "th"])]
            if len(cells) < 8:
                continue
            try:
                price_date = datetime.strptime(cells[0], "%b %d, %Y").date().isoformat()
            except ValueError:
                try:
                    price_date = datetime.strptime(cells[0], "%B %d, %Y").date().isoformat()
                except ValueError:
                    continue
            open_price  = _parse_stockanalysis_number(cells[1])
            close_price = _parse_stockanalysis_number(cells[4])
            volume      = _parse_stockanalysis_volume(cells[7])
            if open_price is None or close_price is None:
                continue
            records.append({
                "date": price_date, "open": open_price,
                "close": close_price, "volume": volume,
            })
        return records

    except Exception as e:
        print(f"⚠ StockAnalysis ADX fallback error for {ticker}: {e}")
        return []


# --------------------------------------------------
# UPSERT SQL  (VALUES %s  →  bulk execute_values)
# --------------------------------------------------
upsert_sql = """
INSERT INTO ingest_db.stocks_price_data (
    stock_id,
    price,
    opening_price,
    closing_price,
    day_price_change,
    currency_code,
    day_price_change_pct,
    volume,
    volume_30d,
    market_cap,
    captured_at,
    price_date,
    yfinance_closing_price,
    yfinance_close_price_change_pct,
    yfinance_close_price_change
)
VALUES %s
ON CONFLICT (stock_id, price_date)
DO UPDATE SET
    price = EXCLUDED.price,
    opening_price = EXCLUDED.opening_price,
    closing_price = EXCLUDED.closing_price,
    day_price_change = EXCLUDED.day_price_change,
    day_price_change_pct = EXCLUDED.day_price_change_pct,
    currency_code = EXCLUDED.currency_code,
    volume = EXCLUDED.volume,
    captured_at = EXCLUDED.captured_at,
    yfinance_closing_price = COALESCE(EXCLUDED.yfinance_closing_price, stocks_price_data.yfinance_closing_price),
    yfinance_close_price_change_pct = COALESCE(EXCLUDED.yfinance_close_price_change_pct, stocks_price_data.yfinance_close_price_change_pct),
    yfinance_close_price_change = COALESCE(EXCLUDED.yfinance_close_price_change, stocks_price_data.yfinance_close_price_change);
"""


# --------------------------------------------------
# DEDICATED YFINANCE LOOKUP  (date → yfinance values)
# --------------------------------------------------
# FMP ticker suffix → Yahoo Finance suffix mapping for exchanges that differ
_YF_SUFFIX_MAP = {
    ".AD":  ".AE",   # Abu Dhabi → Yahoo uses .AE
    ".ADX": ".AE",
    ".KQ":  ".KQ",   # KOSDAQ — same
    ".SS":  ".SS",   # Shanghai — same
    ".SZ":  ".SZ",   # Shenzhen — same
}


def _to_yahoo_ticker(ticker):
    """Convert FMP ticker format to Yahoo Finance format where they differ."""
    for fmp_suffix, yf_suffix in _YF_SUFFIX_MAP.items():
        if ticker.endswith(fmp_suffix):
            return ticker[: -len(fmp_suffix)] + yf_suffix
    return ticker


def _fetch_yfinance_date_map(ticker):
    """
    Fetch full price history via direct Yahoo Finance API (no yfinance library).
    Returns {price_date: (closing_price, change, change_pct)}.
    Using direct HTTP makes behaviour identical across all machines regardless of
    yfinance version.
    """
    yf_ticker = _to_yahoo_ticker(ticker)
    try:
        r = _get_session().get(
            f"https://query1.finance.yahoo.com/v8/finance/chart/{yf_ticker}",
            params={"interval": "1d", "range": "max"},
            headers={"User-Agent": "Mozilla/5.0"},
            timeout=20,
        )
        r.raise_for_status()
        result = r.json().get("chart", {}).get("result")
        if not result:
            return {}

        quotes     = result[0]
        timestamps = quotes.get("timestamp") or []
        closes     = quotes.get("indicators", {}).get("quote", [{}])[0].get("close") or []

        records = []
        for i, ts in enumerate(timestamps):
            if i >= len(closes) or closes[i] is None:
                continue
            records.append({
                "date":  datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
                "close": closes[i],
            })
    except Exception:
        return {}

    if not records:
        return {}

    records.sort(key=lambda x: x["date"])
    previous_close = None
    date_map = {}

    for r in records:
        price_date = r["date"]
        close_p    = r["close"]

        if previous_close not in (None, 0):
            yf_change     = close_p - previous_close
            yf_change_pct = (yf_change / previous_close) * 100
        else:
            yf_change     = None
            yf_change_pct = None
        previous_close = close_p

        date_map[price_date] = (close_p, yf_change, yf_change_pct)

    return date_map


# --------------------------------------------------
# FETCH + BUILD ROWS FOR ONE TICKER  (runs in thread)
# --------------------------------------------------
def _build_ticker_price_rows(ticker, stock_id, currency):
    # --- choose primary source ---
    if ticker == "6887.HK":
        records = fetch_yahoo_historical_prices(ticker, 30)
        source  = "Yahoo direct"
    else:
        records = fetch_fmp_historical_prices(ticker)
        source  = "FMP"

    # --- fallback 1: yfinance ---
    if not records and ticker != "6887.HK":
        print(f"  ⚠ FMP empty for {ticker}; trying yfinance")
        records = fetch_yfinance_historical_prices(ticker)
        source  = "yfinance"

    # --- fallback 2: StockAnalysis ADX (UAE only) ---
    if not records and ticker in STOCKANALYSIS_ADX_SYMBOLS:
        print(f"  ⚠ yfinance empty for {ticker}; trying StockAnalysis ADX")
        records = fetch_stockanalysis_adx_prices(ticker)
        source  = "StockAnalysis ADX"

    if not records:
        return ticker, []

    # --- dedicated yfinance fetch for the three yfinance columns ---
    # If yfinance is already the primary source, build the map from existing records
    # to avoid a redundant network call; otherwise call the dedicated function.
    if source == "yfinance":
        yf_records = records
        yf_records.sort(key=lambda x: x.get("date") or "")
        prev = None
        yf_date_map = {}
        for r in yf_records:
            d  = r.get("date")
            cp = r.get("close")
            if not d or cp is None:
                continue
            if prev not in (None, 0):
                ch     = cp - prev
                ch_pct = (ch / prev) * 100
            else:
                ch = ch_pct = None
            prev = cp
            yf_date_map[d] = (cp, ch, ch_pct)
    else:
        yf_date_map = _fetch_yfinance_date_map(ticker)

    records.sort(key=lambda x: x.get("date") or "")
    previous_close = None
    # Today's midnight — date part is always "today", time part encodes price_date uniquely.
    # This avoids UNIQUE(stock_id, captured_at) collisions with existing DB rows from
    # previous runs while keeping the captured date as today's date.
    today_midnight = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    rows = []

    for r in records:
        price_date = r.get("date")
        open_p     = r.get("open")
        close_p    = r.get("close")
        vol        = r.get("volume")

        if not price_date or open_p is None or close_p is None:
            continue

        # FMP day-over-day calculations (unchanged)
        if previous_close not in (None, 0):
            delta     = close_p - previous_close
            delta_pct = (delta / previous_close) * 100
        else:
            delta     = None
            delta_pct = None
        previous_close = close_p

        # yfinance columns from the dedicated date map
        yf_entry      = yf_date_map.get(price_date)
        yf_close      = yf_entry[0] if yf_entry else None
        yf_change     = yf_entry[1] if yf_entry else None
        yf_change_pct = yf_entry[2] if yf_entry else None

        # captured_at = today midnight + price_date ordinal as microseconds
        # → date part is today, unique per price_date, deterministic across re-runs
        captured_at = today_midnight + timedelta(
            microseconds=datetime.fromisoformat(price_date).toordinal()
        )

        rows.append((
            stock_id, close_p, open_p, close_p,
            delta, currency, delta_pct, vol,
            None, None, captured_at, price_date,
            yf_close, yf_change_pct, yf_change,
        ))

    if rows:
        print(f"  → {ticker}: {len(rows)} rows [{source}]")
    return ticker, rows


# --------------------------------------------------
# CORE FUNCTION
# --------------------------------------------------
def fetch_and_load_prices():
    conn = get_connection()
    cur  = conn.cursor()

    cur.execute("""
        SELECT stock_id, ticker, currency_code
        FROM ingest_db.stocks
        WHERE is_peer = false;
    """)
    stock_map = {
        ticker.strip().upper(): (stock_id, currency)
        for stock_id, ticker, currency in cur.fetchall()
    }
    tickers = list(stock_map.keys())

    print(f"\nFetching historical prices for {len(tickers)} stocks\n")

    jobs       = [(t, stock_map[t][0], stock_map[t][1]) for t in tickers]
    all_rows   = []
    total_rows = 0

    # fetch all tickers in parallel
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(PRICE_FETCH_MAX_WORKERS, max(1, len(jobs)))
    ) as executor:
        futures = {
            executor.submit(_build_ticker_price_rows, t, sid, cur_): t
            for t, sid, cur_ in jobs
        }
        for future in concurrent.futures.as_completed(futures):
            ticker = futures[future]
            try:
                _, ticker_rows = future.result()
            except Exception as e:
                print(f"❌ Fatal ticker error {ticker}: {e}")
                continue
            if not ticker_rows:
                print(f"  ⚠ No data for {ticker}")
                continue
            all_rows.extend(ticker_rows)
            total_rows += len(ticker_rows)

    # bulk upsert all rows in one DB round-trip
    if all_rows:
        for attempt in range(1, MAX_DEADLOCK_RETRIES + 1):
            try:
                execute_values(cur, upsert_sql, all_rows, page_size=1000)
                conn.commit()
                break
            except psycopg2.errors.DeadlockDetected:
                conn.rollback()
                print(f"⚠ Deadlock during bulk upsert retry {attempt}/{MAX_DEADLOCK_RETRIES}")
                time.sleep(DEADLOCK_RETRY_DELAY)
        else:
            raise RuntimeError(f"Bulk upsert failed after {MAX_DEADLOCK_RETRIES} retries")

    cur.close()
    conn.close()

    print("\n======================================")
    print(f"✓ Rows inserted / updated: {total_rows}")
    print("======================================\n")


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\nFETCHING: Historical Stock Price Data\n")
    fetch_and_load_prices()
    print("✅ Completed successfully")


if __name__ == "__main__":
    main()