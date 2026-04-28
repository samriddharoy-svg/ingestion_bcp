"""
Fetch historical stock prices
Populates: ingest_db.stocks_price_data
"""

# --------------------------------------------------
# PATH FIX (CRITICAL)
# --------------------------------------------------
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

# --------------------------------------------------
# IMPORTS
# --------------------------------------------------
import time
import requests
import psycopg2
from datetime import datetime

from utils import get_connection
from utils_date import is_date_valid_for_ingestion
from config import (
    TICKER_MAPPINGS,
    DATA_FETCH_CONFIG,
    FMP_API_KEY,
)

BASE_URL = "https://financialmodelingprep.com/stable"

MAX_DEADLOCK_RETRIES = 3
DEADLOCK_RETRY_DELAY = 2  # seconds

# --------------------------------------------------
# Fetch historical prices from FMP
# --------------------------------------------------
def fetch_fmp_historical_prices(ticker):
    try:
        r = requests.get(
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

# --------------------------------------------------
# Fetch Yahoo prices (ONLY for 6887.HK)
# --------------------------------------------------
def fetch_yahoo_historical_prices(ticker, days=30):
    try:
        r = requests.get(
            f"https://query1.finance.yahoo.com/v8/finance/chart/"
            f"{ticker}?interval=1d&range={days}d",
            headers={"User-Agent": "Mozilla/5.0"},
            timeout=20,
        )
        r.raise_for_status()

        data = r.json()
        result = data.get("chart", {}).get("result")
        if not result:
            return []

        quotes = result[0]
        timestamps = quotes.get("timestamp") or []
        indicators = quotes.get("indicators", {}).get("quote", [{}])[0]

        opens = indicators.get("open") or []
        closes = indicators.get("close") or []
        volumes = indicators.get("volume") or []

        records = []
        for i, ts in enumerate(timestamps):
            if i >= len(opens) or i >= len(closes):
                continue

            records.append({
                "date": datetime.fromtimestamp(ts).strftime("%Y-%m-%d"),
                "open": opens[i],
                "close": closes[i],
                "volume": volumes[i] if i < len(volumes) else None,
            })

        return records

    except Exception as e:
        print(f"⚠ Yahoo error for {ticker}: {e}")
        return []

# --------------------------------------------------
# UPSERT SQL
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
    price_date
)
VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
ON CONFLICT (stock_id, price_date)
DO UPDATE SET
    price = EXCLUDED.price,
    opening_price = EXCLUDED.opening_price,
    closing_price = EXCLUDED.closing_price,
    day_price_change = EXCLUDED.day_price_change,
    day_price_change_pct = EXCLUDED.day_price_change_pct,
    currency_code = EXCLUDED.currency_code,
    volume = EXCLUDED.volume,
    captured_at = EXCLUDED.captured_at;
"""

# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_prices():
    conn = get_connection()
    cur = conn.cursor()

    # ----------------------------------------------
    # Load stocks ONLY from TICKER_MAPPINGS
    # ----------------------------------------------
    tickers = list(set(TICKER_MAPPINGS.values()))

    cur.execute(
        """
        SELECT stock_id, ticker, currency_code
        FROM ingest_db.stocks
        WHERE ticker = ANY(%s);
        """,
        (tickers,),
    )

    stock_map = {
        ticker: (stock_id, currency)
        for stock_id, ticker, currency in cur.fetchall()
    }

    if not stock_map:
        print("❌ No matching stocks found for configured tickers")
        return

    total_rows = 0
    print(f"\nFetching historical prices for {len(stock_map)} stocks\n")

    # ----------------------------------------------
    # PROCESS EACH STOCK
    # ----------------------------------------------
    for ticker in tickers:
        stock_info = stock_map.get(ticker)
        if not stock_info:
            print(f"⚠ Ticker {ticker} not found in DB, skipping")
            continue

        stock_id, currency = stock_info
        print(f"→ {ticker}")

        try:
            records = (
                fetch_yahoo_historical_prices(ticker, 30)
                if ticker == "6887.HK"
                else fetch_fmp_historical_prices(ticker)
            )

            if not records:
                print(f"  ⚠ No data for {ticker}")
                continue

            records.sort(key=lambda x: x.get("date") or "")
            previous_close = None

            for r in records:
                price_date = r.get("date")
                if not price_date or not is_date_valid_for_ingestion(price_date):
                    continue

                open_p = r.get("open")
                close_p = r.get("close")
                vol = r.get("volume")

                if open_p is None or close_p is None:
                    continue

                if previous_close not in (None, 0):
                    delta = close_p - previous_close
                    delta_pct = (delta / previous_close) * 100
                else:
                    delta = None
                    delta_pct = None

                previous_close = close_p

                # ---------- DEADLOCK-SAFE INSERT ----------
                for attempt in range(1, MAX_DEADLOCK_RETRIES + 1):
                    try:
                        cur.execute(
                            upsert_sql,
                            (
                                stock_id,
                                close_p,
                                open_p,
                                close_p,
                                delta,
                                currency,
                                delta_pct,
                                vol,
                                None,
                                None,
                                datetime.now(),
                                price_date
                            )
                        )
                        total_rows += 1
                        break

                    except psycopg2.errors.DeadlockDetected:
                        conn.rollback()
                        print(
                            f"⚠ Deadlock detected "
                            f"({ticker} @ {price_date}) "
                            f"retry {attempt}/{MAX_DEADLOCK_RETRIES}"
                        )
                        time.sleep(DEADLOCK_RETRY_DELAY)

                else:
                    raise Exception(
                        f"Insert failed after {MAX_DEADLOCK_RETRIES} retries "
                        f"for {ticker} on {price_date}"
                    )
            conn.commit()
            time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

        except Exception as e:
            print(f"❌ Fatal ticker error {ticker}: {e}")
            continue

    
    cur.close()
    conn.close()

    print(f"\n✓ Rows inserted / updated: {total_rows}")

# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    try:
        print("\nFETCHING: Historical Stock Price Data\n")
        fetch_and_load_prices()
        print("✅ Live prices task completed successfully")
    except Exception as e:
        print("❌ Fatal task error:", e)
        raise  # ECS marks failure only for real fatal errors

if __name__ == "__main__":
    main()
