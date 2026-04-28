"""
Fetch Cash & Debt (Quarterly, Annual, TTM)
-----------------------------------------
Data Source:
 - Balance Sheet → FMP

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


def fetch_balance_sheet(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/balance-sheet-statement",
            params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Balance sheet error ({period}) for {symbol}: {e}")
        return []


def fetch_balance_sheet_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/balance-sheet-statement-ttm",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Balance sheet TTM error for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_cash_debt():
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

    print(f"\nProcessing {len(stocks)} stocks (Cash & Debt)...\n")

    # ----------------------------------------------
    # Process each stock
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0
        ttm_rows = 0
        latest_q_label = None

        # ---------- QUARTERLY ----------
        bs_q = fetch_balance_sheet(ticker, "quarter")

        for row in bs_q:
            cash = row.get("cashAndCashEquivalents")
            debt = row.get("totalDebt")
            date_ = row.get("date")

            if cash is None or debt is None or not date_:
                continue

            label = quarter_label(date_)

            records.extend([
                (stock_id, "Cash", cash, "Quarterly", label, "Cash & Debt"),
                (stock_id, "Debt", debt, "Quarterly", label, "Cash & Debt"),
            ])
            q_rows += 2

        if bs_q:
            latest_q_label = quarter_label(bs_q[0]["date"])

        # ---------- ANNUAL ----------
        bs_a = fetch_balance_sheet(ticker, "annual")

        for row in bs_a:
            cash = row.get("cashAndCashEquivalents")
            debt = row.get("totalDebt")
            date_ = row.get("date")

            if cash is None or debt is None or not date_:
                continue

            year = date_[:4]

            records.extend([
                (stock_id, "Cash", cash, "Annual", year, "Cash & Debt"),
                (stock_id, "Debt", debt, "Annual", year, "Cash & Debt"),
            ])
            a_rows += 2

        # ---------- TTM ----------
        bs_ttm = fetch_balance_sheet_ttm(ticker)

        if bs_ttm and latest_q_label:
            cash = bs_ttm[0].get("cashAndCashEquivalents")
            debt = bs_ttm[0].get("totalDebt")

            if cash is not None and debt is not None:
                records.extend([
                    (stock_id, "Cash", cash, "Quarterly - TTM", latest_q_label, "Cash & Debt"),
                    (stock_id, "Debt", debt, "Quarterly - TTM", latest_q_label, "Cash & Debt"),
                ])
                ttm_rows = 2

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0 and ttm_rows == 0:
            print("  ⚠ No Cash & Debt data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  TTM rows       : {ttm_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} Cash & Debt rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Cash & Debt ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING CASH & DEBT (Q / A / TTM)")
    print("======================================\n")
    fetch_and_load_cash_debt()


if __name__ == "__main__":
    main()
