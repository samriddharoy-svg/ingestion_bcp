"""
Fetch Net Income (Quarterly, Annual, TTM)
----------------------------------------
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
        print(f"    ✗ TTM income error for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_net_income():
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

    print(f"\nProcessing {len(stocks)} stocks (Net Income)...\n")

    # ----------------------------------------------
    # Process each stock
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_count = 0
        a_count = 0
        ttm_count = 0

        # ---------- QUARTERLY ----------
        q_data = fetch_income_statement(ticker, "quarter")
        latest_q_label = None

        for row in q_data:
            net_income = row.get("netIncome")
            date_ = row.get("date")

            if net_income is None or not date_:
                continue

            records.append(
                (
                    stock_id,
                    "Net Income",
                    net_income,
                    "Quarterly",
                    quarter_label(date_),
                    "Net Income",
                )
            )
            q_count += 1

        if q_data:
            latest_q_label = quarter_label(q_data[0]["date"])

        # ---------- ANNUAL ----------
        a_data = fetch_income_statement(ticker, "annual")

        for row in a_data:
            net_income = row.get("netIncome")
            date_ = row.get("date")

            if net_income is None or not date_:
                continue

            records.append(
                (
                    stock_id,
                    "Net Income",
                    net_income,
                    "Annual",
                    date_[:4],
                    "Net Income",
                )
            )
            a_count += 1

        # ---------- TTM ----------
        ttm_data = fetch_income_statement_ttm(ticker)

        if ttm_data and latest_q_label:
            net_income_ttm = ttm_data[0].get("netIncome")
            if net_income_ttm is not None:
                records.append(
                    (
                        stock_id,
                        "Net Income",
                        net_income_ttm,
                        "Quarterly - TTM",
                        latest_q_label,
                        "Net Income",
                    )
                )
                ttm_count = 1

        # ---------- PER-STOCK SUMMARY ----------
        if q_count == 0 and a_count == 0 and ttm_count == 0:
            print("  ⚠ No Net Income data fetched")
        else:
            print(f"  Quarterly rows : {q_count}")
            print(f"  Annual rows    : {a_count}")
            print(f"  TTM row        : {'YES' if ttm_count else 'NO'}")
            print(f"  ➜ Total rows   : {q_count + a_count + ttm_count}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} Net Income rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Net Income ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING NET INCOME (Quarterly / Annual / TTM)")
    print("======================================\n")
    fetch_and_load_net_income()


if __name__ == "__main__":
    main()
