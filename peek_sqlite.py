#!/usr/bin/env python3
# peek_sqlite.py
import sqlite3
from config import SQLITE_DB_PATH

DB = SQLITE_DB_PATH

def peek_history(limit=20):
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        SELECT id, symbol, price, volume, currency_code, captured_at
        FROM stocks_price_data_sqlite
        ORDER BY captured_at DESC
        LIMIT ?;
    """, (limit,))
    rows = cur.fetchall()
    cur.close()
    conn.close()

    print("\nHistory (latest):")
    for r in rows:
        print(r)

def peek_latest():
    conn = sqlite3.connect(DB)
    cur = conn.cursor()
    cur.execute("""
        SELECT symbol, price, volume, currency_code, captured_at, updated_at
        FROM latest_prices_sqlite
        ORDER BY symbol;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    print("\nLatest snapshot:")
    for r in rows:
        print(r)

if __name__ == "__main__":
    peek_history()
    peek_latest()
