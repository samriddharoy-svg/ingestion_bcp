"""
Fetch upcoming earnings for stocks
Populates: ingest_db.stocks_upcoming_earnings

✔ Uses Yahoo Finance for earnings dates
✔ Uses FMP → fallback to Yahoo for market cap
✔ ECS / Docker / Step Functions compatible
"""

import sys
from pathlib import Path
from datetime import datetime
import requests
import yfinance as yf
import pandas as pd

# --------------------------------------------------
# Path setup
# --------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

# --------------------------------------------------
# Imports
# --------------------------------------------------
from utils import get_connection
from config import (
    FMP_API_KEY,
    TICKER_MAPPINGS,
)

# --------------------------------------------------
# Helpers
# --------------------------------------------------
def fetch_market_cap_fmp(ticker: str):
    try:
        r = requests.get(
            "https://financialmodelingprep.com/stable/market-capitalization",
            params={"symbol": ticker, "apikey": FMP_API_KEY},
            timeout=20
        )
        r.raise_for_status()
        data = r.json()
        return data[0]["marketCap"] if data else None
    except Exception:
        return None


def fetch_market_cap_yf(ticker: str):
    try:
        return yf.Ticker(ticker).info.get("marketCap")
    except Exception:
        return None


# --------------------------------------------------
# Fetch earnings data
# --------------------------------------------------
def fetch_upcoming_earnings():
    tickers = list(TICKER_MAPPINGS.keys())
    rows = []

    print(f"\n📊 Fetching upcoming earnings for {len(tickers)} stocks\n")

    for idx, ticker in enumerate(tickers, 1):
        print(f"[{idx}/{len(tickers)}] {ticker}", end=" ")

        try:
            t = yf.Ticker(ticker)
            df = t.get_earnings_dates(limit=10)

            if df is None or df.empty:
                print("⚠️ No earnings data")
                continue

            df = df.reset_index()

            # Prefer future earnings, fallback to latest
            future = df[df["Earnings Date"] >= pd.Timestamp.utcnow()]
            row = future.iloc[0] if not future.empty else df.iloc[0]

            earnings_date = pd.to_datetime(row["Earnings Date"]).date()
            eps_est = row.get("EPS Estimate")
            eps_rep = row.get("Reported EPS")

            rows.append({
                "ticker": ticker,
                "earnings_date": earnings_date,
                "estimated_eps": round(eps_est, 2) if pd.notna(eps_est) else None,
                "actual_eps": round(eps_rep, 2) if pd.notna(eps_rep) else None,
            })

            print(f"✓ {earnings_date}")

        except Exception as e:
            print(f"✗ Error: {str(e)[:80]}")

    return rows


# --------------------------------------------------
# Transform + Load
# --------------------------------------------------
def transform_and_load(earnings_rows):
    if not earnings_rows:
        print("\n⚠️ No earnings data fetched")
        return 0

    conn = get_connection()
    cur = conn.cursor()

    # Fetch stock_id + currency from DB (authoritative)
    cur.execute("""
        SELECT stock_id, ticker, currency_code
        FROM ingest_db.stocks
    """)
    stock_map = {
        ticker: (stock_id, currency)
        for stock_id, ticker, currency in cur.fetchall()
    }

    records = []

    for row in earnings_rows:
        ticker = row["ticker"]

        if ticker not in stock_map:
            print(f"⚠️ Skipping {ticker} (not in stocks table)")
            continue

        stock_id, currency = stock_map[ticker]

        market_cap = fetch_market_cap_fmp(ticker)
        if market_cap is None:
            market_cap = fetch_market_cap_yf(ticker)

        records.append((
            stock_id,
            ticker,
            market_cap,
            row["earnings_date"],
            row["estimated_eps"],
            row["actual_eps"],
            currency
        ))

    if not records:
        print("\n⚠️ No valid rows to insert")
        return 0

    print(f"\n📥 Inserting {len(records)} rows into ingest_db.stocks_upcoming_earnings")

    insert_sql = """
        INSERT INTO ingest_db.stocks_upcoming_earnings (
            stock_id,
            ticker,
            market_cap,
            earnings_date,
            estimated_eps,
            actual_eps,
            currency_code
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
    """

    cur.executemany(insert_sql, records)
    conn.commit()

    cur.close()
    conn.close()

    return len(records)


# --------------------------------------------------
# Main
# --------------------------------------------------
def main():
    print("\n" + "=" * 60)
    print("FETCHING: Upcoming Earnings")
    print("=" * 60)

    earnings = fetch_upcoming_earnings()
    inserted = transform_and_load(earnings)

    print("\n✅ DONE")
    print(f"   Rows processed: {inserted}")
    print("=" * 60)


# --------------------------------------------------
if __name__ == "__main__":
    main()
