# """
# Fetch Daily Cash Flow Snapshot Metrics
# --------------------------------------
# Data Sources:
#  - Key Metrics      → FMP: /stable/key-metrics
#  - Cash Flow        → FMP: /stable/cash-flow-statement
#  - Prices           → FMP: /stable/historical-price-eod/full
#  - Shares Outstanding → FMP: /stable/income-statement (quarterly)

# Populates:
#  - ingest_db.stocks_fundamentals

# DDL Matches:
# - metric_category : 'Cash Flow'
# - period_type     : 'Daily'
# - period_label    : NULL
# - captured_date   : CURRENT_DATE

# Duplicate Protection:
# - UNIQUE(stock_id, metric_category, metric_type, period_type, period_label, captured_date)
# - ON CONFLICT DO NOTHING
# """

# import sys
# from pathlib import Path
# import time
# import requests
# from datetime import date

# # -------------------------------------------------
# # Project root
# # -------------------------------------------------
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import get_connection
# from config import FMP_API_KEY, TICKER_MAPPINGS, DATA_FETCH_CONFIG


# TODAY = date.today()

# # -------------------------------------------------
# # API Helpers
# # -------------------------------------------------
# def fetch_json(url, params):
#     r = requests.get(url, params=params, timeout=30)
#     r.raise_for_status()
#     data = r.json()
#     return data[0] if isinstance(data, list) and data else None


# def fetch_key_metrics(symbol):
#     return fetch_json(
#         "https://financialmodelingprep.com/stable/key-metrics",
#         {"symbol": symbol, "apikey": FMP_API_KEY},
#     )


# def fetch_cashflow(symbol):
#     return fetch_json(
#         "https://financialmodelingprep.com/stable/cash-flow-statement",
#         {"symbol": symbol, "apikey": FMP_API_KEY},
#     )


# def fetch_price(symbol):
#     data = fetch_json(
#         "https://financialmodelingprep.com/stable/historical-price-eod/full",
#         {"symbol": symbol, "apikey": FMP_API_KEY},
#     )
#     return data.get("close") if data else None


# def fetch_shares(symbol):
#     q = fetch_json(
#         "https://financialmodelingprep.com/stable/income-statement",
#         {"symbol": symbol, "period": "quarter", "apikey": FMP_API_KEY},
#     )
#     return q.get("weightedAverageShsOut") if q else None


# # -------------------------------------------------
# # Main Loader
# # -------------------------------------------------
# def fetch_and_load_daily_cashflow():

#     conn = get_connection()
#     cur = conn.cursor()

#     # Load ONLY configured tickers
#     tickers = list(TICKER_MAPPINGS.values())

#     cur.execute(
#         """
#         SELECT stock_id, ticker
#         FROM ingest_db.stocks
#         WHERE ticker = ANY(%s)
#         ORDER BY stock_id;
#         """,
#         (tickers,),
#     )

#     stocks = cur.fetchall()

#     if not stocks:
#         print("❌ No matching stocks found.")
#         return

#     insert_sql = """
#         INSERT INTO ingest_db.stocks_fundamentals
#         (
#             stock_id,
#             metric_type,
#             metric_value,
#             period_type,
#             period_label,
#             captured_date,
#             metric_category
#         )
#         VALUES (%s, %s, %s, 'Daily', NULL, %s, 'Cash Flow')
#         ON CONFLICT DO NOTHING;
#     """

#     records = []

#     print(f"\nProcessing {len(stocks)} stocks (Daily Cash Flow)...\n")

#     for stock_id, ticker in stocks:
#         print(f"Processing {ticker}...")

#         km = fetch_key_metrics(ticker)
#         cf = fetch_cashflow(ticker)
#         price = fetch_price(ticker)
#         shares = fetch_shares(ticker)

#         if not km or not cf or not price or not shares or shares == 0:
#             print("  ⚠ Skipped (missing data)")
#             continue

#         fcf = cf.get("freeCashFlow", 0)
#         sbc = cf.get("stockBasedCompensation", 0)
#         market_cap = km.get("marketCap") or 0
#         fcf_yield = km.get("freeCashFlowYield", 0)

#         if price <= 0:
#             continue

#         # -------- Calculations --------
#         fcf_per_share_price = (fcf / shares) / price
#         sbc_adj_fcf = fcf - sbc
#         sbc_adj_fcf_per_share_price = (sbc_adj_fcf / shares) / price

#         sbc_adj_fcf_yield = (
#             sbc_adj_fcf / abs(market_cap)
#             if market_cap != 0
#             else 0
#         )

#         sbc_impact = abs(sbc / fcf) if fcf != 0 else 0

#         # -------- Metrics --------
#         records.extend([
#             (stock_id, "Free Cash Flow Yield", fcf_yield, TODAY),
#             (stock_id, "FCF Per Share / Price", fcf_per_share_price, TODAY),
#             (stock_id, "SBC Adj. Free Cash Flow Yield", sbc_adj_fcf_yield, TODAY),
#             (stock_id, "Adj. FCF Per Share / Price", sbc_adj_fcf_per_share_price, TODAY),
#             (stock_id, "SBC Impact", sbc_impact, TODAY),
#         ])

#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     # -------------------------------------------------
#     # Bulk Insert
#     # -------------------------------------------------
#     if records:
#         print(f"\nInserting {len(records)} rows...")
#         cur.executemany(insert_sql, records)
#         conn.commit()
#         print("✔ Daily Cash Flow snapshot ingestion complete")

#     cur.close()
#     conn.close()


# # -------------------------------------------------
# # Entry Point
# # -------------------------------------------------
# def main():
#     print("\n=====================================")
#     print(" FETCHING DAILY CASH FLOW SNAPSHOT ")
#     print("=====================================\n")
#     fetch_and_load_daily_cashflow()


# if __name__ == "__main__":
#     main()























"""
Fetch Daily Cash Flow Snapshot
------------------------------
Data Sources:
 - Key Metrics        → FMP: /stable/key-metrics
 - Cash Flow          → FMP: /stable/cash-flow-statement
 - Income Statement   → FMP: /stable/income-statement
 - Price (EOD)        → FMP: /stable/historical-price-eod/full

Populates:
 - ingest_db.stocks_fundamentals

Rules:
- period_type  = 'Daily'
- period_label = NULL
- captured_date = CURRENT_DATE
- metric_category = 'Cash Flow'
- ON CONFLICT DO NOTHING
"""

import sys
from pathlib import Path
import time
import requests
from datetime import date

# -------------------------------------------------
# Project root
# -------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection
from config import (
    FMP_API_KEY,
    TICKER_MAPPINGS,
    DATA_FETCH_CONFIG
)

TODAY = date.today()

# -------------------------------------------------
# API Helpers
# -------------------------------------------------
def fetch_key_metrics(symbol):
    try:
        r = requests.get(
            "https://financialmodelingprep.com/stable/key-metrics",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0] if data else {}
    except Exception as e:
        print(f"    ✗ Key metrics error for {symbol}: {e}")
        return {}


def fetch_cashflow(symbol):
    try:
        r = requests.get(
            "https://financialmodelingprep.com/stable/cash-flow-statement",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0] if data else {}
    except Exception as e:
        print(f"    ✗ Cash flow error for {symbol}: {e}")
        return {}


def fetch_price(symbol):
    try:
        r = requests.get(
            "https://financialmodelingprep.com/stable/historical-price-eod/full",
            params={"symbol": symbol, "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0] if data else {}
    except Exception as e:
        print(f"    ✗ Price error for {symbol}: {e}")
        return {}


def fetch_shares(symbol):
    try:
        r = requests.get(
            "https://financialmodelingprep.com/stable/income-statement",
            params={"symbol": symbol, "period": "quarter", "apikey": FMP_API_KEY},
            timeout=30
        )
        r.raise_for_status()
        data = r.json() or []
        return data[0].get("weightedAverageShsOut") if data else None
    except Exception as e:
        print(f"    ✗ Shares error for {symbol}: {e}")
        return None


# -------------------------------------------------
# Main Loader
# -------------------------------------------------
def fetch_and_load_daily_cashflow():

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
        VALUES (%s, %s, %s, 'NULL', 'NULL', %s, 'Cash Flow')
        ON CONFLICT DO NOTHING;
    """

    records = []

    print(f"\nProcessing {len(stocks)} stocks (Daily Cash Flow)...\n")

    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        km = fetch_key_metrics(ticker)
        cf = fetch_cashflow(ticker)
        price_data = fetch_price(ticker)
        shares = fetch_shares(ticker)

        if not km or not cf or not price_data or not shares or shares == 0:
            print("  ⚠ Skipping due to missing data")
            continue

        price = price_data.get("close", 0)
        if price <= 0:
            continue

        fcf = cf.get("freeCashFlow", 0)
        sbc = cf.get("stockBasedCompensation", 0)
        market_cap = km.get("marketCap", 0)

        fcf_yield = km.get("freeCashFlowYield", 0)

        fcf_per_share_price = (fcf / shares) / price
        sbc_adj_fcf = fcf - sbc
        sbc_adj_fcf_per_share_price = (sbc_adj_fcf / shares) / price

        sbc_adj_fcf_yield = (
            sbc_adj_fcf / abs(market_cap)
            if market_cap not in (None, 0)
            else 0
        )

        sbc_impact = abs(sbc / fcf) if fcf != 0 else 0

        records.extend([
            (stock_id, "Free Cash Flow Yield", fcf_yield, TODAY),
            (stock_id, "FCF Per Share / Price", fcf_per_share_price, TODAY),
            (stock_id, "SBC Adj. Free Cash Flow Yield", sbc_adj_fcf_yield, TODAY),
            (stock_id, "Adj. FCF Per Share / Price", sbc_adj_fcf_per_share_price, TODAY),
            (stock_id, "SBC Impact", sbc_impact, TODAY),
        ])

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    print(f"\nInserting {len(records)} daily cash flow rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Daily Cash Flow snapshot ingestion complete")

    cur.close()
    conn.close()


# -------------------------------------------------
# Entry Point
# -------------------------------------------------
def main():
    print("\n=====================================")
    print(" FETCHING DAILY CASH FLOW SNAPSHOT ")
    print("=====================================\n")
    fetch_and_load_daily_cashflow()


if __name__ == "__main__":
    main()
