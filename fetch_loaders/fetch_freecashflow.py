"""
Fetch Free Cash Flow Metrics (Quarterly, Annual, TTM)
----------------------------------------------------
Data Sources:
 - Cash Flow Statement → FMP
 - Income Statement   → FMP (for shares outstanding)

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


def fetch_cash_flow_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/cash-flow-statement-ttm",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Cash flow TTM error for {symbol}: {e}")
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
def fetch_and_load_free_cash_flow():
    conn = get_connection()
    cur = conn.cursor()

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

    print(f"\nProcessing {len(stocks)} stocks (Free Cash Flow)...\n")

    # --------------------------------------------------
    # PROCESS EACH STOCK
    # --------------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0
        ttm_rows = 0

        # ---------- SHARES (Quarterly) ----------
        income_q = fetch_income_statement(ticker, "quarter")
        latest_shares = None
        latest_q_label = None

        if income_q:
            latest_shares = income_q[0].get("weightedAverageShsOut")
            latest_q_label = quarter_label(income_q[0]["date"])

        # ---------- QUARTERLY ----------
        cf_q = fetch_cash_flow(ticker, "quarter")

        for row in cf_q:
            fcf = row.get("freeCashFlow")
            sbc = row.get("stockBasedCompensation")
            date_ = row.get("date")

            if fcf is None or sbc is None or not date_:
                continue

            label = quarter_label(date_)

            shares = next(
                (
                    r.get("weightedAverageShsOut")
                    for r in income_q
                    if quarter_label(r["date"]) == label
                ),
                None,
            )

            if not shares or shares == 0:
                continue

            records.extend([
                (stock_id, "Free Cash Flow", fcf, "Quarterly", label, "Free Cash Flow"),
                (stock_id, "FCF Per Share", fcf / shares, "Quarterly", label, "Free Cash Flow"),
                (stock_id, "FCF & SBC", sbc, "Quarterly", label, "Free Cash Flow"),
                (stock_id, "SBC Adj. FCF", fcf - sbc, "Quarterly", label, "Free Cash Flow"),
                (stock_id, "SBC Adj. FCF Per Share", (fcf - sbc) / shares, "Quarterly", label, "Free Cash Flow"),
            ])
            q_rows += 5

        # ---------- ANNUAL ----------
        cf_a = fetch_cash_flow(ticker, "annual")
        income_a = fetch_income_statement(ticker, "annual")

        for row in cf_a:
            fcf = row.get("freeCashFlow")
            sbc = row.get("stockBasedCompensation")
            date_ = row.get("date")

            if fcf is None or sbc is None or not date_:
                continue

            year = date_[:4]

            shares = next(
                (r.get("weightedAverageShsOut") for r in income_a if r["date"].startswith(year)),
                None,
            )

            if not shares or shares == 0:
                continue

            records.extend([
                (stock_id, "Free Cash Flow", fcf, "Annual", year, "Free Cash Flow"),
                (stock_id, "FCF Per Share", fcf / shares, "Annual", year, "Free Cash Flow"),
                (stock_id, "FCF & SBC", sbc, "Annual", year, "Free Cash Flow"),
                (stock_id, "SBC Adj. FCF", fcf - sbc, "Annual", year, "Free Cash Flow"),
                (stock_id, "SBC Adj. FCF Per Share", (fcf - sbc) / shares, "Annual", year, "Free Cash Flow"),
            ])
            a_rows += 5

        # ---------- TTM ----------
        cf_ttm = fetch_cash_flow_ttm(ticker)

        if cf_ttm and latest_shares and latest_q_label:
            fcf = cf_ttm[0].get("freeCashFlow")
            sbc = cf_ttm[0].get("stockBasedCompensation")

            if fcf is not None and sbc is not None and latest_shares != 0:
                records.extend([
                    (stock_id, "Free Cash Flow", fcf, "Quarterly - TTM", latest_q_label, "Free Cash Flow"),
                    (stock_id, "FCF Per Share", fcf / latest_shares, "Quarterly - TTM", latest_q_label, "Free Cash Flow"),
                    (stock_id, "FCF & SBC", sbc, "Quarterly - TTM", latest_q_label, "Free Cash Flow"),
                    (stock_id, "SBC Adj. FCF", fcf - sbc, "Quarterly - TTM", latest_q_label, "Free Cash Flow"),
                    (stock_id, "SBC Adj. FCF Per Share", (fcf - sbc) / latest_shares, "Quarterly - TTM", latest_q_label, "Free Cash Flow"),
                ])
                ttm_rows = 5

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0 and ttm_rows == 0:
            print("  ⚠ No Free Cash Flow data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  TTM rows       : {ttm_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # --------------------------------------------------
    # BULK INSERT
    # --------------------------------------------------
    print(f"\nInserting {len(records)} Free Cash Flow rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Free Cash Flow ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING FREE CASH FLOW METRICS ")
    print("======================================\n")
    fetch_and_load_free_cash_flow()


if __name__ == "__main__":
    main()
