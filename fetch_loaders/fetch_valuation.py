
"""
Fetch stock valuation metrics from FMP API
Populates: ingest_db.stocks_fundamentals table
"""

import sys
from pathlib import Path
import time
import requests
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection
from utils_date import is_date_valid_for_ingestion
from config import (
    TICKER_MAPPINGS,
    DATA_FETCH_CONFIG,
    FMP_API_KEY,
    USE_RDS_DIRECT
)

# --------------------------------------------------
# Fetch Market Cap
# --------------------------------------------------
def fetch_market_cap(ticker):
    try:
        url = (
            f"https://financialmodelingprep.com/stable/"
            f"market-capitalization?symbol={ticker}&apikey={FMP_API_KEY}"
        )
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Market Cap error for {ticker}: {e}")
        return []


# --------------------------------------------------
# Fetch Ratios (P/E, P/B, P/S)
# --------------------------------------------------
def fetch_ratios(ticker):
    try:
        url = (
            f"https://financialmodelingprep.com/stable/"
            f"ratios?symbol={ticker}&period=quarter&limit=1&apikey={FMP_API_KEY}"
        )
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json() or []
        return [data[0]] if data else []
    except Exception as e:
        print(f"    ✗ Ratios error for {ticker}: {e}")
        return []


# --------------------------------------------------
# Main Logic
# --------------------------------------------------
def fetch_and_load_fundamentals():
    tickers = list(set(TICKER_MAPPINGS.values()))

    conn = get_connection()
    cur = conn.cursor()

    # Load stock mapping
    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker FROM ingest_db.stocks")
    else:
        cur.execute("SELECT stock_id, ticker FROM stocks")

    stock_map = {ticker: stock_id for stock_id, ticker in cur.fetchall()}

    if not stock_map:
        print("❌ No stocks found")
        return

    # DELETE + INSERT (no UPSERT)
    delete_sql = """
        DELETE FROM ingest_db.stocks_fundamentals
        WHERE stock_id = %s AND metric_type = %s AND captured_date = %s;
    """

    insert_sql = """
        INSERT INTO ingest_db.stocks_fundamentals (
            stock_id,
            metric_type,
            metric_value,
            period_type,
            period_label,
            captured_date,
            metric_category
        )
        VALUES (%s,%s,%s,%s,%s,%s,%s);
    """

    total = 0

    print(f"\nFetching valuation data for {len(tickers)} stocks...\n")

    for ticker in tickers:
        stock_id = stock_map.get(ticker)
        if not stock_id:
            continue

        print(f"Fetching {ticker}...")

        # --------------------------------------------------
        # MARKET CAP
        # --------------------------------------------------
        cap_data = fetch_market_cap(ticker)

        for row in cap_data:
            date_str = row.get("date")
            value = row.get("marketCap")

            if not date_str or value is None:
                continue

            period_type = "Daily"
            period_label = date_str[:4]   # year
            captured = date_str
            metric_type = "Market Cap"

            # delete + insert
            cur.execute(delete_sql, (stock_id, metric_type, captured))
            cur.execute(
                insert_sql,
                (
                    stock_id,
                    metric_type,
                    value,
                    period_type,
                    period_label,
                    captured,
                    "Valuation"
                )
            )
            total += 1

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

        # --------------------------------------------------
        # RATIOS
        # --------------------------------------------------
        ratio_data = fetch_ratios(ticker)

        for row in ratio_data:
            date_str = row.get("date")
            if not date_str or not is_date_valid_for_ingestion(date_str):
                continue

            period_type = "Daily"
            period_label = date_str[:4]
            captured = date_str

            metrics = {
                "P/E Ratio": row.get("priceToEarningsRatio"),
                "Price to Book": row.get("priceToBookRatio"),
                "Price to Sales": row.get("priceToSalesRatio"),
            }

            for metric_type, value in metrics.items():
                if value is None:
                    continue

                cur.execute(delete_sql, (stock_id, metric_type, captured))

                cur.execute(
                    insert_sql,
                    (
                        stock_id,
                        metric_type,
                        value,
                        period_type,
                        period_label,
                        captured,
                        "Valuation"
                    )
                )
                total += 1

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    conn.commit()
    cur.close()
    conn.close()

    print("\n======================================")
    print(f"✓ Total records inserted: {total}")
    print("======================================\n")


def main():
    print("\n======================================")
    print("FETCHING: Stock Valuation Metrics")
    print("======================================")
    fetch_and_load_fundamentals()


if __name__ == "__main__":
    main()



