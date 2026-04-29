#!/usr/bin/env python3
# create_sqlite_tables.py
import sqlite3
from pathlib import Path
from config import SQLITE_DB_PATH

db_path = Path(SQLITE_DB_PATH)
db_path.parent.mkdir(parents=True, exist_ok=True)

sql = """
PRAGMA foreign_keys = ON;

-- History table (time-series)
CREATE TABLE IF NOT EXISTS stocks_price_data_sqlite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    price REAL,
    day_price_change REAL,
    volume INTEGER,
    currency_code TEXT,
    captured_at TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(symbol, captured_at)
);

-- Latest snapshot (one row per symbol)
CREATE TABLE IF NOT EXISTS latest_prices_sqlite (
    symbol TEXT PRIMARY KEY,
    price REAL,
    day_price_change REAL,
    volume INTEGER,
    currency_code TEXT,
    captured_at TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
);
"""

def main():
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.executescript(sql)
    conn.commit()
    cur.close()
    conn.close()
    print(f"SQLite DB and tables created at: {db_path.resolve()}")

if __name__ == "__main__":
    main()
