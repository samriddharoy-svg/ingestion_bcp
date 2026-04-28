"""
Fetch Dividend Per Share (Quarterly, Annual)
--------------------------------------------
Data Sources:
 - Cash Flow Statement → FMP (dividends paid)
 - Income Statement   → FMP (shares outstanding)

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


def fetch_cash_flow(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/cash-flow-statement",
            params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Cash flow error ({period}) for {symbol}: {e}")
        return []


def fetch_income_statement(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/income-statement",
            params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Income statement error ({period}) for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_dividend_per_share():
    conn = get_connection()
    cur = conn.cursor()

    # ----------------------------------------------
    # Load stocks from DB
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

    print(f"\nProcessing {len(stocks)} stocks (Dividend Per Share)...\n")

    # ----------------------------------------------
    # PROCESS EACH STOCK
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0

        # ---------- QUARTERLY ----------
        cf_q = fetch_cash_flow(ticker, "quarter")
        is_q = fetch_income_statement(ticker, "quarter")

        is_q_map = {row.get("date"): row for row in is_q}

        for row in cf_q:
            date_ = row.get("date")
            if not date_:
                continue

            shares = is_q_map.get(date_, {}).get("weightedAverageShsOut", 0)
            dividends = abs(row.get("commonDividendsPaid") or 0)

            if shares <= 0:
                continue

            dps = dividends / shares

            records.append(
                (
                    stock_id,
                    "Dividend Per Share",
                    dps,
                    "Quarterly",
                    quarter_label(date_),
                    "Dividend",
                )
            )
            q_rows += 1

        # ---------- ANNUAL ----------
        cf_a = fetch_cash_flow(ticker, "annual")
        is_a = fetch_income_statement(ticker, "annual")

        is_a_map = {row.get("date"): row for row in is_a}

        for row in cf_a:
            date_ = row.get("date")
            if not date_:
                continue

            shares = is_a_map.get(date_, {}).get("weightedAverageShsOut", 0)
            dividends = abs(row.get("commonDividendsPaid") or 0)

            if shares <= 0:
                continue

            dps = dividends / shares

            records.append(
                (
                    stock_id,
                    "Dividend Per Share",
                    dps,
                    "Annual",
                    date_[:4],
                    "Dividend",
                )
            )
            a_rows += 1

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0:
            print("  ⚠ No Dividend Per Share data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} Dividend Per Share rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Dividend Per Share ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING DIVIDEND PER SHARE (Q / A)")
    print("======================================\n")
    fetch_and_load_dividend_per_share()


if __name__ == "__main__":
    main()
