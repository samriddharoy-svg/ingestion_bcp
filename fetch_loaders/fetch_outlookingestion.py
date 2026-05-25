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
import requests
import psycopg2
from datetime import datetime

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
    conn = psycopg2.connect(
        host="equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com",
        port=5432,
        dbname="equities_first_dev_db",
        user="ef_dev_user_rw",
        password="ef_dev_user_rw@123!",
        sslmode="require",
    )
    cur = conn.cursor()

    # ----------------------------------------------
    # Load stocks from TICKER_MAPPINGS
    # ----------------------------------------------
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

    if not stocks:
        print("❌ No matching stocks found for given tickers")
        cur.close()
        conn.close()
        return

    # ----------------------------------------------
    # INSERT SQL
    # ----------------------------------------------
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

    records = []

    print(f"\nProcessing {len(stocks)} stocks (Earnings Outlook)...\n")

    # ----------------------------------------------
    # PROCESS EACH STOCK
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0

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

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0:
            print("  ⚠ No earnings outlook data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows}")

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} earnings outlook rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Earnings outlook ingestion completed")

    cur.close()
    conn.close()


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
