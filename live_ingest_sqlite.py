#!/usr/bin/env python3
# live_ingest_sqlite.py
"""
Fetch live quotes from FMP per symbol and:
 - INSERT OR IGNORE into stocks_price_data_sqlite (history)
 - UPSERT into latest_prices_sqlite (snapshot)
"""

import sys
from pathlib import Path
from datetime import datetime, timezone
import time
import requests
import sqlite3

sys.path.append(str(Path(__file__).parent))
from config import FMP_API_KEY, TICKER_MAPPINGS, SQLITE_DB_PATH

DB = SQLITE_DB_PATH

def fetch_live_quotes_per_symbol():
    if not FMP_API_KEY:
        raise RuntimeError("FMP_API_KEY is not set in environment (.env)")

    symbols = sorted(set(TICKER_MAPPINGS.values()))
    quotes = []

    for sym in symbols:
        url = f"https://financialmodelingprep.com/stable/quote-short?symbol={sym}&apikey={FMP_API_KEY}"
        try:
            print(f"Requesting: {url}")
            resp = requests.get(url, timeout=30)
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            print(f"  ! Failed for {sym}: {e}")
            time.sleep(0.3)
            continue

        if isinstance(data, list) and data:
            q = data[0]
            print(f"  -> Got {sym}: price={q.get('price')}, vol={q.get('volume')}")
            quotes.append(q)
        else:
            print(f"  -> No data for {sym}")
        time.sleep(0.3)

    return quotes

def insert_history_and_upsert_latest(quotes):
    if not quotes:
        print("No quotes to write.")
        return

    now_iso = datetime.now(timezone.utc).isoformat()
    conn = sqlite3.connect(DB)
    cur = conn.cursor()

    # Insert history rows using INSERT OR IGNORE to avoid exact duplicate (symbol,captured_at)
    history_sql = """
    INSERT OR IGNORE INTO stocks_price_data_sqlite
    (symbol, price, day_price_change, volume, currency_code, captured_at)
    VALUES (?, ?, ?, ?, ?, ?);
    """

    latest_sql = """
    INSERT INTO latest_prices_sqlite (symbol, price, day_price_change, volume, currency_code, captured_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
    ON CONFLICT(symbol) DO UPDATE SET
       price=excluded.price,
       day_price_change=excluded.day_price_change,
       volume=excluded.volume,
       currency_code=excluded.currency_code,
       captured_at=excluded.captured_at,
       updated_at=datetime('now');
    """

    history_rows = []
    latest_rows = []

    for q in quotes:
        sym = q.get("symbol")
        price = q.get("price")
        change = q.get("change")
        vol = q.get("volume")
        # currency: we don't have currency from FMP quote-short; you may map currency via config or leave None
        currency = None

        captured_at = now_iso

        history_rows.append((sym, price, change, vol, currency, captured_at))
        latest_rows.append((sym, price, change, vol, currency, captured_at))

    try:
        cur.executemany(history_sql, history_rows)
        cur.executemany(latest_sql, latest_rows)
        conn.commit()
        print(f"Inserted {len(history_rows)} history rows and upserted {len(latest_rows)} latest rows into SQLite.")
    finally:
        cur.close()
        conn.close()

def main():
    print("="*60)
    print("LIVE INGEST → local SQLite")
    print("="*60)
    quotes = fetch_live_quotes_per_symbol()
    insert_history_and_upsert_latest(quotes)

if __name__ == "__main__":
    main()
