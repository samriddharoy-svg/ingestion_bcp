"""
Fetch Valuation Ratios (P/E, P/S, FCF Yield)
--------------------------------------------
Data Sources:
 - Ratios        → FMP
 - Key Metrics   → FMP

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


def safe_append(records, row):
    # row[2] == metric_value
    if row[2] is not None:
        records.append(row)


def fetch_ratios(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/ratios",
            params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Ratios error ({period}) for {symbol}: {e}")
        return []


def fetch_ratios_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/ratios-ttm",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Ratios TTM error for {symbol}: {e}")
        return []


def fetch_key_metrics(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/key-metrics",
            params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Key metrics error ({period}) for {symbol}: {e}")
        return []


def fetch_key_metrics_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/key-metrics-ttm",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"    ✗ Key metrics TTM error for {symbol}: {e}")
        return []


# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_price_ratios():
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

    print(f"\nProcessing {len(stocks)} stocks (Price Ratios)...\n")

    # ----------------------------------------------
    # PROCESS EACH STOCK
    # ----------------------------------------------
    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = 0
        a_rows = 0
        ttm_rows = 0

        # ---------- QUARTERLY ----------
        ratios_q = fetch_ratios(ticker, "quarter")
        key_q = fetch_key_metrics(ticker, "quarter")
        key_q_map = {r.get("date"): r for r in key_q}

        for r in ratios_q:
            date_ = r.get("date")
            if not date_:
                continue

            label = quarter_label(date_)
            key_row = key_q_map.get(date_, {})

            safe_append(records, (
                stock_id, "Price to Earning",
                r.get("priceToEarningsRatio"),
                "Quarterly", label, "Price To Earning"
            ))

            safe_append(records, (
                stock_id, "Price to Sales",
                r.get("priceToSalesRatio"),
                "Quarterly", label, "Price To Earning"
            ))

            safe_append(records, (
                stock_id, "Free Cash Flow Yield",
                key_row.get("freeCashFlowYield"),
                "Quarterly", label, "Price To Earning"
            ))

            q_rows += 3

        # ---------- ANNUAL ----------
        ratios_a = fetch_ratios(ticker, "annual")
        key_a = fetch_key_metrics(ticker, "annual")
        key_a_map = {r.get("date"): r for r in key_a}

        for r in ratios_a:
            date_ = r.get("date")
            if not date_:
                continue

            year = date_[:4]
            key_row = key_a_map.get(date_, {})

            safe_append(records, (
                stock_id, "Price to Earning",
                r.get("priceToEarningsRatio"),
                "Annual", year, "Price To Earning"
            ))

            safe_append(records, (
                stock_id, "Price to Sales",
                r.get("priceToSalesRatio"),
                "Annual", year, "Price To Earning"
            ))

            safe_append(records, (
                stock_id, "Free Cash Flow Yield",
                key_row.get("freeCashFlowYield"),
                "Annual", year, "Price To Earning"
            ))

            a_rows += 3

        # ---------- TTM ----------
        ratios_ttm = fetch_ratios_ttm(ticker)
        key_ttm = fetch_key_metrics_ttm(ticker)

        if ratios_ttm and ratios_q:
            label = quarter_label(ratios_q[0]["date"])

            safe_append(records, (
                stock_id, "Price to Earning",
                ratios_ttm[0].get("priceToEarningsRatioTTM"),
                "Quarterly - TTM", label, "Price To Earning"
            ))

            safe_append(records, (
                stock_id, "Price to Sales",
                ratios_ttm[0].get("priceToSalesRatioTTM"),
                "Quarterly - TTM", label, "Price To Earning"
            ))

            if key_ttm:
                safe_append(records, (
                    stock_id, "Free Cash Flow Yield",
                    key_ttm[0].get("freeCashFlowYield"),
                    "Quarterly - TTM", label, "Price To Earning"
                ))

            ttm_rows = 3

        # ---------- PRINT SUMMARY ----------
        if q_rows == 0 and a_rows == 0 and ttm_rows == 0:
            print("  ⚠ No price ratio data fetched")
        else:
            print(f"  Quarterly rows : {q_rows}")
            print(f"  Annual rows    : {a_rows}")
            print(f"  TTM rows       : {ttm_rows}")
            print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # ----------------------------------------------
    # BULK INSERT
    # ----------------------------------------------
    print(f"\nInserting {len(records)} price ratio rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Price ratio ingestion completed")

    cur.close()
    conn.close()


# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING PRICE RATIOS (P/E, P/S, FCF)")
    print("======================================\n")
    fetch_and_load_price_ratios()


if __name__ == "__main__":
    main()
