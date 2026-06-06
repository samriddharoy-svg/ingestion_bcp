"""
Fetch Earnings Outlook
----------------------
Analyst Estimates (Quarterly + Annual)

Data Sources:
 - Analyst Estimates → FMP

Populates:
 - ingest_db.stocks_earnings_outlook
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
from datetime import datetime

from utils import get_connection
from config import TICKER_MAPPINGS, FMP_API_KEY, DATA_FETCH_CONFIG

BASE_URL = "https://financialmodelingprep.com/stable"

# --------------------------------------------------
# HELPERS
# --------------------------------------------------
def quarter_label(date_str: str) -> str:
    d = datetime.strptime(date_str, "%Y-%m-%d")
    q = (d.month - 1) // 3 + 1
    return f"{d.year}-Q{q}"


def fetch_estimates(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/analyst-estimates",
            params={
                "symbol": symbol,
                "period": period,
                "apikey": FMP_API_KEY
            },
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Analyst estimates error ({period}) for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_earnings_outlook():
    # Short-lived connection just to load the stock list
    conn = get_connection()
    cur  = conn.cursor()
    tickers = list(set(TICKER_MAPPINGS.values()))
    cur.execute(
        """
        SELECT stock_id, ticker
        FROM ingest_db.stocks
        WHERE ticker = ANY(%s)
        ORDER BY stock_id;
        """,
        (tickers,),
    )
    stocks = cur.fetchall()
    cur.close()
    conn.close()

    if not stocks:
        print("❌ No matching stocks found for given tickers")
        return

    insert_sql = """
        INSERT INTO ingest_db.stocks_earnings_outlook
        (
            stock_id,
            ticker,
            period,
            num_estimates,
            avg_estimate,
            low_estimate,
            high_estimate,
            metric_type
        )
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT DO NOTHING;
    """

    total_inserted = 0

    print(f"\nProcessing {len(stocks)} stocks (Earnings Outlook)...\n")

    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0
        records = []

        # ---------- QUARTERLY ----------
        data_q = fetch_estimates(ticker, "quarter")

        for r in data_q:
            date_ = r.get("date")
            if not date_:
                continue

            label = quarter_label(date_)

            if r.get("revenueAvg") is not None:
                records.append((
                    stock_id, ticker, label,
                    r.get("numAnalystsRevenue"),
                    r.get("revenueAvg"),
                    r.get("revenueLow"),
                    r.get("revenueHigh"),
                    "Revenue"
                ))
                q_rows += 1

            if r.get("epsAvg") is not None:
                records.append((
                    stock_id, ticker, label,
                    r.get("numAnalystsEps"),
                    r.get("epsAvg"),
                    r.get("epsLow"),
                    r.get("epsHigh"),
                    "EPS"
                ))
                q_rows += 1

        # ---------- ANNUAL ----------
        data_a = fetch_estimates(ticker, "annual")

        for r in data_a:
            date_ = r.get("date")
            if not date_:
                continue

            year = date_

            if r.get("revenueAvg") is not None:
                records.append((
                    stock_id, ticker, year,
                    r.get("numAnalystsRevenue"),
                    r.get("revenueAvg"),
                    r.get("revenueLow"),
                    r.get("revenueHigh"),
                    "Revenue"
                ))
                a_rows += 1

            if r.get("epsAvg") is not None:
                records.append((
                    stock_id, ticker, year,
                    r.get("numAnalystsEps"),
                    r.get("epsAvg"),
                    r.get("epsLow"),
                    r.get("epsHigh"),
                    "EPS"
                ))
                a_rows += 1

        if q_rows == 0 and a_rows == 0:
            print("  ⚠ No earnings outlook data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows}")

        # Fresh DB connection per stock — opened only after API calls finish
        if records:
            conn = get_connection()
            cur  = conn.cursor()
            try:
                cur.executemany(insert_sql, records)
                conn.commit()
                total_inserted += len(records)
            finally:
                cur.close()
                conn.close()

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    print(f"\n✔ Earnings outlook ingestion completed — {total_inserted} rows inserted")


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING EARNINGS OUTLOOK (REV & EPS)")
    print("======================================\n")
    fetch_and_load_earnings_outlook()


if __name__ == "__main__":
    main()
