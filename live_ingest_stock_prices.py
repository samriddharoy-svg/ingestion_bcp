#!/usr/bin/env python3
# live_ingest_stock_prices.py
"""
Fetch live prices from FMP (stable/quote-short) for each symbol
and INSERT into: ingest_db.stocks_price_data

- Uses config.py for FMP_API_KEY, TICKER_MAPPINGS, TABLES
- Uses db.py get_pg_conn() for RDS connection
- This version uses plain INSERT (no ON CONFLICT) to avoid needing DB schema changes.
"""

import sys
from pathlib import Path
from datetime import datetime, timezone
import time
import requests

# ensure current folder is on sys.path so config.py and db.py import correctly
sys.path.append(str(Path(__file__).parent))

from config import FMP_API_KEY, TICKER_MAPPINGS, TABLES
from db import get_pg_conn
from psycopg2.extras import execute_values

def fetch_live_quotes_per_symbol():
    """Fetch quote-short for each symbol individually to avoid empty-batch results."""
    if not FMP_API_KEY:
        raise RuntimeError("FMP_API_KEY is not set. Put it in your .env file.")

    symbols = sorted(set(TICKER_MAPPINGS.values()))
    all_quotes = []

    for sym in symbols:
        url = f"https://financialmodelingprep.com/stable/quote-short?symbol={sym}&apikey={FMP_API_KEY}"
        try:
            print(f"Requesting: {url}")
            resp = requests.get(url, timeout=30)
            resp.raise_for_status()
        except Exception as e:
            print(f"  ! Request failed for {sym}: {e}")
            # continue to next symbol
            time.sleep(0.3)
            continue

        try:
            data = resp.json()
        except Exception as e:
            print(f"  ! Failed to decode JSON for {sym}: {e}")
            time.sleep(0.3)
            continue

        if isinstance(data, list) and len(data) > 0:
            quote = data[0]
            print(f"  -> Got quote for {sym}: price={quote.get('price')}, volume={quote.get('volume')}")
            all_quotes.append(quote)
        else:
            print(f"  -> No data returned for {sym}")

        # small sleep to be nice to the API & avoid rate limits
        time.sleep(0.3)

    print(f"\nTotal quotes fetched: {len(all_quotes)}")
    return all_quotes


def get_stocks_meta():
    """
    Build mapping: FMP symbol -> (stock_id, currency_code)
    by reading ingest_db.stocks and using TICKER_MAPPINGS.
    """
    conn = get_pg_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT stock_id, ticker, currency_code
        FROM ingest_db.stocks
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    local_map = { ticker: (stock_id, currency_code) for stock_id, ticker, currency_code in rows }

    # build map from FMP symbol -> meta
    fmp_to_meta = {}
    for local_ticker, fmp_symbol in TICKER_MAPPINGS.items():
        if local_ticker in local_map:
            fmp_to_meta[fmp_symbol] = local_map[local_ticker]

    return fmp_to_meta


def build_rows(quotes, fmp_to_meta):
    """Convert FMP quote-short items to DB rows for INSERT."""
    rows = []
    captured_at = datetime.now(timezone.utc)

    for item in quotes:
        symbol = item.get("symbol")
        if not symbol:
            continue

        meta = fmp_to_meta.get(symbol)
        if not meta:
            print(f"Skipping {symbol}: no mapping in ingest_db.stocks / TICKER_MAPPINGS")
            continue

        stock_id, currency_code = meta
        price = item.get("price")
        change = item.get("change")
        volume = item.get("volume")

        rows.append((
            stock_id,        # stock_id
            price,           # price
            None,            # opening_price
            None,            # closing_price
            change,          # day_price_change
            currency_code,   # currency_code
            None,            # day_price_change_pct
            volume,          # volume
            None,            # volume_30d
            None,            # market_cap
            captured_at,     # captured_at
        ))

    return rows


def insert_prices(rows):
    """Plain INSERT into stocks_price_data (no ON CONFLICT)."""
    if not rows:
        print("No rows to insert.")
        return

    table = TABLES["stocks_price_data"]
    sql = f"""
        INSERT INTO {table} (
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
            captured_at
        )
        VALUES %s;
    """

    conn = get_pg_conn()
    cur = conn.cursor()
    try:
        execute_values(cur, sql, rows, page_size=100)
        conn.commit()
    finally:
        cur.close()
        conn.close()

    print(f"\n✅ Inserted {len(rows)} rows into {table}")


def main():
    print("\n" + "=" * 70)
    print("LIVE INGEST: FMP → ingest_db.stocks_price_data (per-symbol)")
    print("=" * 70)

    quotes = fetch_live_quotes_per_symbol()
    fmp_to_meta = get_stocks_meta()
    rows = build_rows(quotes, fmp_to_meta)
    insert_prices(rows)


if __name__ == "__main__":
    main()
