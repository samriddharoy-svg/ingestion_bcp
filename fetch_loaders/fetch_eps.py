"""
Fetch EPS (Quarterly, Annual, TTM)
---------------------------------
Data Source:
 - Income Statement → FMP

Populates:
 - ingest_db.stocks_fundamentals
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


def fetch_income_statement(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/income-statement",
            params={
                "symbol": symbol,
                "period": period,
                "apikey": FMP_API_KEY,
            },
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Income statement error ({period}) for {symbol}: {e}")
        return []


def fetch_income_statement_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/income-statement-ttm",
            params={
                "symbol": symbol,
                "apikey": FMP_API_KEY,
            },
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Income statement TTM error for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_eps():
    conn = get_connection()
    cur = conn.cursor()

    # ----------------------------------------------
    # Load stocks from DB (filtered by config tickers)
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
        print("❌ No matching stocks found in DB")
        return

    # ----------------------------------------------
    # INSERT SQL
    # ----------------------------------------------
    insert_sql = """
        INSERT INTO ingest_db.stocks_fundamentals
        (
            stock_id,
            metric_type,
            metric_value,
            period_type,
            period_label,
            metric_category
        )
        VALUES (%s,%s,%s,%s,%s,%s)
        ON CONFLICT DO NOTHING;
    """

    records = []

    print(f"\nProcessing {len(stocks)} stocks (EPS)...\n")

    # ----------------------------------------------
    # Process each stock
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0
        ttm_rows = 0

        # ---------- QUARTERLY ----------
        q_data = fetch_income_statement(ticker, "quarter")
        latest_q_label = None

        for row in q_data:
            eps = row.get("eps")
            date_ = row.get("date")

            if eps is None or not date_:
                continue

            records.append(
                (
                    stock_id,
                    "EPS",
                    eps,
                    "Quarterly",
                    quarter_label(date_),
                    "EPS",
                )
            )
            q_rows += 1

        if q_data:
            latest_q_label = quarter_label(q_data[0]["date"])

        # ---------- ANNUAL ----------
        a_data = fetch_income_statement(ticker, "annual")

        for row in a_data:
            eps = row.get("eps")
            date_ = row.get("date")

            if eps is None or not date_:
                continue

            records.append(
                (
                    stock_id,
                    "EPS",
                    eps,
                    "Annual",
                    date_[:4],
                    "EPS",
                )
            )
            a_rows += 1

        # ---------- TTM ----------
        ttm_data = fetch_income_statement_ttm(ticker)

        if ttm_data and latest_q_label:
            eps_ttm = ttm_data[0].get("eps")
            if eps_ttm is not None:
                records.append(
                    (
                        stock_id,
                        "EPS",
                        eps_ttm,
                        "Quarterly - TTM",
                        latest_q_label,
                        "EPS",
                    )
                )
                ttm_rows = 1

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0 and ttm_rows == 0:
            print("  ⚠ No EPS data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  TTM row        : {'YES' if ttm_rows else 'NO'}")
            print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} EPS rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ EPS ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING EPS (Quarterly / Annual / TTM)")
    print("======================================\n")
    fetch_and_load_eps()


if __name__ == "__main__":
    main()
