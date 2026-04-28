# """
# Fetch balance sheet metrics from FMP API
# Populates: ingest_db.stocks_fundamentals table

# Metrics fetched:
# - Cash (from balance sheet: cashAndCashEquivalents)
# - Debt (from balance sheet: totalDebt)
# - Net (from balance sheet: netDebt)
# - Profit (from income statement: netIncome)

# Rules:
# - period_type: "Daily" (hardcoded)
# - period_label: Year from market date (e.g., "2025")
# - captured_date: Market date (date of data)
# - metric_category: "Balance" (hardcoded)
# - Latest data only (most recent quarter)
# """

# import sys
# from pathlib import Path
# import time
# import requests

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import get_connection
# from utils_date import is_date_valid_for_ingestion
# from config import (
#     TICKER_MAPPINGS,
#     DATA_FETCH_CONFIG,
#     FMP_API_KEY,
#     USE_RDS_DIRECT
# )


# # --------------------------------------------------
# # Fetch balance sheet statement
# # --------------------------------------------------
# def fetch_balance_sheet(ticker):
#     """Fetch latest quarterly balance sheet data (only most recent)."""
#     try:
#         url = (
#             f"https://financialmodelingprep.com/stable/"
#             f"balance-sheet-statement?symbol={ticker}&period=quarter&limit=1&apikey={FMP_API_KEY}"
#         )
#         response = requests.get(url, timeout=30)
#         response.raise_for_status()
#         data = response.json() or []
#         # Return only the first (latest) record
#         return [data[0]] if data else []
#     except Exception as e:
#         print(f"    ✗ Balance sheet error for {ticker}: {e}")
#         return []


# # --------------------------------------------------
# # Fetch income statement (for Profit)
# # --------------------------------------------------
# def fetch_income_statement(ticker):
#     """Fetch latest quarterly income statement data (only most recent)."""
#     try:
#         url = (
#             f"https://financialmodelingprep.com/stable/"
#             f"income-statement?symbol={ticker}&period=quarter&limit=1&apikey={FMP_API_KEY}"
#         )
#         response = requests.get(url, timeout=30)
#         response.raise_for_status()
#         data = response.json() or []
#         # Return only the first (latest) record
#         return [data[0]] if data else []
#     except Exception as e:
#         print(f"    ✗ Income statement error for {ticker}: {e}")
#         return []


# # --------------------------------------------------
# # Main fetch + load logic
# # --------------------------------------------------
# def fetch_and_load_balance():
#     tickers = list(set(TICKER_MAPPINGS.values()))

#     conn = get_connection()
#     cur = conn.cursor()

#     # Load stock mapping
#     if USE_RDS_DIRECT:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
#     else:
#         cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

#     stock_map = {
#         ticker: (stock_id, currency)
#         for stock_id, ticker, currency in cur.fetchall()
#     }

#     if not stock_map:
#         print("❌ No stocks found in DB")
#         cur.close()
#         conn.close()
#         return

#     # Delete and insert SQL
#     delete_sql = """
#         DELETE FROM ingest_db.stocks_fundamentals
#         WHERE stock_id = %s
#         AND metric_type = %s
#         AND fiscal_date = %s;
#     """

#     insert_sql = """
#         INSERT INTO ingest_db.stocks_fundamentals (
#             stock_id,
#             metric_type,
#             metric_value,
#             fiscal_date,
#             currency_code
#         )
#         VALUES (%s, %s, %s, %s, %s);
#     """

#     total_rows = 0

#     print(f"\nFetching balance sheet data for {len(tickers)} stocks...\n")

#     for ticker in tickers:
#         stock_info = stock_map.get(ticker)
#         if not stock_info:
#             print(f"⚠️  {ticker} not in database, skipping")
#             continue

#         stock_id, currency = stock_info
#         print(f"Fetching {ticker}...")

#         # --------------------------------------------------
#         # 1. Fetch Balance Sheet (Cash, Debt, Net)
#         # --------------------------------------------------
#         balance_data = fetch_balance_sheet(ticker)
#         cash_count = 0
#         debt_count = 0
#         net_count = 0

#         for record in balance_data:
#             date_str = record.get("date")

#             if not date_str:
#                 continue

#             # Skip today's data
#             if not is_date_valid_for_ingestion(date_str):
#                 continue

#             # Cash (cashAndCashEquivalents)
#             cash = record.get("cashAndCashEquivalents")
#             if cash is not None:
#                 cur.execute(delete_sql, (stock_id, "Cash", date_str))
#                 cur.execute(
#                     insert_sql,
#                     (
#                         stock_id,
#                         "Cash",
#                         cash,
#                         date_str,
#                         currency
#                     )
#                 )
#                 cash_count += 1
#                 total_rows += 1

#             # Debt (totalDebt)
#             debt = record.get("totalDebt")
#             if debt is not None:
#                 cur.execute(delete_sql, (stock_id, "Debt", date_str))
#                 cur.execute(
#                     insert_sql,
#                     (
#                         stock_id,
#                         "Debt",
#                         debt,
#                         date_str,
#                         currency
#                     )
#                 )
#                 debt_count += 1
#                 total_rows += 1

#             # Net (netDebt)
#             net_debt = record.get("netDebt")
#             if net_debt is not None:
#                 cur.execute(delete_sql, (stock_id, "Net", date_str))
#                 cur.execute(
#                     insert_sql,
#                     (
#                         stock_id,
#                         "Net",
#                         net_debt,
#                         date_str,
#                         currency
#                     )
#                 )
#                 net_count += 1
#                 total_rows += 1

#         print(f"  ✓ Cash: {cash_count} records")
#         print(f"  ✓ Debt: {debt_count} records")
#         print(f"  ✓ Net: {net_count} records")

#         # Rate limit
#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#         # --------------------------------------------------
#         # 2. Fetch Income Statement (Profit)
#         # --------------------------------------------------
#         income_data = fetch_income_statement(ticker)
#         profit_count = 0

#         for record in income_data:
#             date_str = record.get("date")

#             if not date_str:
#                 continue

#             # Skip today's data
#             if not is_date_valid_for_ingestion(date_str):
#                 continue

#             # Profit (netIncome)
#             net_income = record.get("netIncome")
#             if net_income is not None:
#                 cur.execute(delete_sql, (stock_id, "Profit", date_str))
#                 cur.execute(
#                     insert_sql,
#                     (
#                         stock_id,
#                         "Profit",
#                         net_income,
#                         date_str,
#                         currency
#                     )
#                 )
#                 profit_count += 1
#                 total_rows += 1

#         print(f"  ✓ Profit: {profit_count} records")

#         # Rate limit
#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     conn.commit()
#     cur.close()
#     conn.close()

#     print("\n======================================")
#     print(f"✓ Total rows inserted/updated: {total_rows}")
#     print("======================================\n")


# # --------------------------------------------------
# # Entry point
# # --------------------------------------------------
# def main():
#     print("\n======================================")
#     print("FETCHING: Balance Sheet Metrics")
#     print("======================================")
#     print("\nMetrics:")
#     print("  - Cash (cashAndCashEquivalents)")
#     print("  - Debt (totalDebt)")
#     print("  - Net (netDebt)")
#     print("  - Profit (netIncome)")
#     print("\nConfiguration:")
#     print("  - Period Type: Daily")
#     print("  - Metric Category: Balance")
#     print("  - Data: Latest values only (most recent quarter)")
#     print("  - Date Filter: Yesterday or earlier (excludes today)")
#     print()

#     fetch_and_load_balance()


# if __name__ == "__main__":
#     main()












"""
Fetch balance sheet & income metrics from FMP API
Populates: ingest_db.stocks_fundamentals
"""

import sys
from pathlib import Path
import time
import requests

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

# -------------------------------
# API Fetch Functions
# -------------------------------
def fetch_balance_sheet(ticker):
    try:
        url = (
            f"https://financialmodelingprep.com/stable/"
            f"balance-sheet-statement?symbol={ticker}&period=quarter&limit=1&apikey={FMP_API_KEY}"
        )
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json() or []
        return [data[0]] if data else []
    except Exception as e:
        print(f"    ✗ Balance sheet error for {ticker}: {e}")
        return []


def fetch_income_statement(ticker):
    try:
        url = (
            f"https://financialmodelingprep.com/stable/"
            f"income-statement?symbol={ticker}&period=quarter&limit=1&apikey={FMP_API_KEY}"
        )
        r = requests.get(url, timeout=30)
        r.raise_for_status()
        data = r.json() or []
        return [data[0]] if data else []
    except Exception as e:
        print(f"    ✗ Income statement error for {ticker}: {e}")
        return []


# -------------------------------
# Main Logic
# -------------------------------
def fetch_and_load_balance():
    tickers = list(set(TICKER_MAPPINGS.values()))

    conn = get_connection()
    cur = conn.cursor()

    # Load stock mapping
    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
    else:
        cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

    stock_map = {t: (sid, curcy) for sid, t, curcy in cur.fetchall()}

    if not stock_map:
        print("❌ No stocks found in DB")
        return

    # DELETE & INSERT SQL
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

    total_rows = 0

    print(f"\nFetching balance sheet data for {len(tickers)} stocks...\n")

    for ticker in tickers:
        stock_info = stock_map.get(ticker)
        if not stock_info:
            continue

        stock_id, currency = stock_info
        print(f"Fetching {ticker}...")

        # -----------------------------
        # BALANCE SHEET (Cash, Debt, Net)
        # -----------------------------
        balance_data = fetch_balance_sheet(ticker)
        for row in balance_data:
            date = row.get("date")
            if not date or not is_date_valid_for_ingestion(date):
                continue

            metrics = {
                "Cash": row.get("cashAndCashEquivalents"),
                "Debt": row.get("totalDebt"),
                "Net": row.get("netDebt"),
            }

            for metric_type, value in metrics.items():
                if value is None:
                    continue

                # Delete old record if exists
                cur.execute(delete_sql, (stock_id, metric_type, date))

                # Insert new record
                cur.execute(
                    insert_sql,
                    (
                        stock_id,
                        metric_type,
                        value,
                        "Daily",
                        date[:4],        # period_label = year
                        date,            # captured_date
                        "Balance"
                    )
                )
                total_rows += 1

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

        # -----------------------------
        # INCOME STATEMENT (Profit)
        # -----------------------------
        income_data = fetch_income_statement(ticker)
        for row in income_data:
            date = row.get("date")
            if not date or not is_date_valid_for_ingestion(date):
                continue

            profit = row.get("netIncome")
            if profit is None:
                continue

            cur.execute(delete_sql, (stock_id, "Profit", date))

            cur.execute(
                insert_sql,
                (
                    stock_id,
                    "Profit",
                    profit,
                    "Daily",
                    date[:4],
                    date,
                    "Balance"
                )
            )
            total_rows += 1

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    conn.commit()
    cur.close()
    conn.close()

    print("\n======================================")
    print(f"✓ Total records inserted: {total_rows}")
    print("======================================\n")


def main():
    print("\n======================================")
    print("FETCHING: Balance Sheet Metrics")
    print("======================================")
    fetch_and_load_balance()


if __name__ == "__main__":
    main()




