"""
Fetch Margin & Growth – Daily Snapshot
-------------------------------------
Data Sources:
 - Ratios            → FMP: /stable/ratios (quarterly)
 - Key Metrics       → FMP: /stable/key-metrics (quarterly)
 - Income Statement  → FMP: /stable/income-statement (quarterly)

Populates:
 - ingest_db.stocks_fundamentals

Rules:
- period_type   = 'NULL'
- period_label  = 'NULL'
- captured_date = CURRENT_DATE
- metric_category = 'Margin & Growth'
- ON CONFLICT DO NOTHING
"""

import sys
from pathlib import Path
import time
import requests
from datetime import date

# -------------------------------------------------
# Project Root
# -------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection
from config import (
    FMP_API_KEY,
    TICKER_MAPPINGS,
    DATA_FETCH_CONFIG
)

BASE_URL = "https://financialmodelingprep.com/stable"
TODAY = date.today()

# -------------------------------------------------
# API Helpers
# -------------------------------------------------
def fetch_ratios(ticker):
    try:
        r = requests.get(
            f"{BASE_URL}/ratios",
            params={"symbol": ticker, "period": "quarter", "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0] if data else {}
    except Exception as e:
        print(f"    ✗ Ratios error for {ticker}: {e}")
        return {}


def fetch_key_metrics(ticker):
    try:
        r = requests.get(
            f"{BASE_URL}/key-metrics",
            params={"symbol": ticker, "period": "quarter", "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0] if data else {}
    except Exception as e:
        print(f"    ✗ Key metrics error for {ticker}: {e}")
        return {}


def fetch_income_statement(ticker):
    try:
        r = requests.get(
            f"{BASE_URL}/income-statement",
            params={"symbol": ticker, "period": "quarter", "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Income statement error for {ticker}: {e}")
        return []


# -------------------------------------------------
# Main Loader
# -------------------------------------------------
def fetch_and_load_margin_growth_daily():

    conn = get_connection()
    cur = conn.cursor()

    # -------------------------------------------------
    # Load configured stocks only
    # -------------------------------------------------
    tickers = list(set(TICKER_MAPPINGS.values()))

    cur.execute(
        """
        SELECT stock_id, ticker
        FROM ingest_db.stocks
        WHERE ticker = ANY(%s)
        ORDER BY stock_id;
        """,
        (tickers,)
    )

    stocks = cur.fetchall()

    if not stocks:
        print("❌ No matching stocks found.")
        return

    insert_sql = """
        INSERT INTO ingest_db.stocks_fundamentals
        (
            stock_id,
            metric_type,
            metric_value,
            period_type,
            period_label,
            captured_date,
            metric_category
        )
        VALUES (%s, %s, %s, 'NULL', 'NULL', %s, 'Margin & Growth')
        ON CONFLICT DO NOTHING;
    """

    records = []

    print(f"\nProcessing {len(stocks)} stocks (Margin & Growth – Daily)...\n")

    # -------------------------------------------------
    # Process each stock
    # -------------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        ratios = fetch_ratios(ticker)
        key_metrics = fetch_key_metrics(ticker)
        income = fetch_income_statement(ticker)

        if not ratios or not key_metrics or len(income) < 5:
            print("  ⚠ Skipping due to insufficient data")
            continue

        # ---- Margins
        profit_margin = ratios.get("netProfitMargin")
        operating_margin = ratios.get("operatingProfitMargin")

        # ---- Earnings Yield
        earnings_yield = key_metrics.get("earningsYield")

        # ---- Revenue YoY (Quarterly)
        revenue_yoy = None
        latest_rev = income[0].get("revenue")
        prev_year_rev = income[4].get("revenue")

        if latest_rev and prev_year_rev and prev_year_rev != 0:
            revenue_yoy = (latest_rev - prev_year_rev) / abs(prev_year_rev)

        # ---- Helper to add metric
        def add(metric, value):
            if value is not None:
                records.append((
                    stock_id,
                    metric,
                    round(value, 4),
                    TODAY
                ))

        add("Profit Margin", profit_margin)
        add("Operating Margin", operating_margin)
        add("Quarterly Earnings Yield", earnings_yield)
        add("Quarterly Revenue YoY", revenue_yoy)

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # -------------------------------------------------
    # Bulk Insert
    # -------------------------------------------------
    print(f"\nInserting {len(records)} Margin & Growth rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Margin & Growth daily ingestion complete")

    cur.close()
    conn.close()


# -------------------------------------------------
# Entry Point
# -------------------------------------------------
def main():
    print("\n=====================================")
    print(" FETCHING MARGIN & GROWTH – DAILY ")
    print("=====================================\n")
    fetch_and_load_margin_growth_daily()


if __name__ == "__main__":
    main()
