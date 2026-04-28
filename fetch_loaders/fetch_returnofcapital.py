# """
# Fetch Return of Capital (ROA, ROE, ROCE)
# --------------------------------------
# Data Source:
#  - Key Metrics → FMP

# Populates:
#  - ingest_db.stocks_fundamentals
# """

# # --------------------------------------------------
# # PATH FIX (CRITICAL)
# # --------------------------------------------------
# import sys
# from pathlib import Path

# sys.path.insert(0, str(Path(__file__).parent.parent))

# # --------------------------------------------------
# # IMPORTS
# # --------------------------------------------------
# import time
# import requests
# from datetime import datetime

# from utils import get_connection
# from config import TICKER_MAPPINGS, FMP_API_KEY, DATA_FETCH_CONFIG

# BASE_URL = "https://financialmodelingprep.com/stable"

# # --------------------------------------------------
# # HELPERS
# # --------------------------------------------------
# def quarter_label(date_str: str) -> str:
#     d = datetime.strptime(date_str, "%Y-%m-%d")
#     q = (d.month - 1) // 3 + 1
#     return f"{d.year}-Q{q}"


# def fetch_key_metrics(symbol: str, period: str):
#     try:
#         r = requests.get(
#             f"{BASE_URL}/key-metrics",
#             params={"symbol": symbol, "period": period, "apikey": FMP_API_KEY},
#             timeout=30,
#         )
#         r.raise_for_status()
#         return r.json() or []
#     except Exception as e:
#         print(f"    ✗ Key metrics error ({period}) for {symbol}: {e}")
#         return []


# def fetch_key_metrics_ttm(symbol: str):
#     try:
#         r = requests.get(
#             f"{BASE_URL}/key-metrics-ttm",
#             params={"symbol": symbol, "apikey": FMP_API_KEY},
#             timeout=30,
#         )
#         r.raise_for_status()
#         return r.json() or []
#     except Exception as e:
#         print(f"    ✗ Key metrics TTM error for {symbol}: {e}")
#         return []


# # --------------------------------------------------
# # CORE LOGIC
# # --------------------------------------------------
# def fetch_and_load_return_of_capital():
#     conn = get_connection()
#     cur = conn.cursor()

#     # ----------------------------------------------
#     # Load stocks from DB (filtered by config tickers)
#     # ----------------------------------------------
#     tickers = list(set(TICKER_MAPPINGS.values()))

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
#         print("❌ No matching stocks found in DB")
#         return

#     # ----------------------------------------------
#     # INSERT SQL
#     # ----------------------------------------------
#     insert_sql = """
#         INSERT INTO ingest_db.stocks_fundamentals
#         (
#             stock_id,
#             metric_type,
#             metric_value,
#             period_type,
#             period_label,
#             metric_category
#         )
#         VALUES (%s,%s,%s,%s,%s,%s)
#         ON CONFLICT DO NOTHING;
#     """

#     records = []

#     print(f"\nProcessing {len(stocks)} stocks (Return of Capital)...\n")

#     # ----------------------------------------------
#     # Process each stock
#     # ----------------------------------------------
#     for stock_id, ticker in stocks:
#         print(f"Processing {ticker}...")

#         q_rows = 0
#         a_rows = 0
#         ttm_rows = 0
#         latest_q_label = None

#         # ---------- QUARTERLY ----------
#         q_data = fetch_key_metrics(ticker, "quarter")

#         for row in q_data:
#             date_ = row.get("date")
#             if not date_:
#                 continue

#             label = quarter_label(date_)

#             if row.get("returnOnAssets") is not None:
#                 records.append(
#                     (stock_id, "Return On Assets", row["returnOnAssets"], "Quarterly", label, "Return of Capital")
#                 )
#                 q_rows += 1

#             if row.get("returnOnEquity") is not None:
#                 records.append(
#                     (stock_id, "Return On Equity", row["returnOnEquity"], "Quarterly", label, "Return of Capital")
#                 )
#                 q_rows += 1

#             if row.get("returnOnCapitalEmployed") is not None:
#                 records.append(
#                     (stock_id, "Return on capital employed", row["returnOnCapitalEmployed"], "Quarterly", label, "Return of Capital")
#                 )
#                 q_rows += 1

#         if q_data:
#             latest_q_label = quarter_label(q_data[0]["date"])

#         # ---------- ANNUAL ----------
#         a_data = fetch_key_metrics(ticker, "annual")

#         for row in a_data:
#             date_ = row.get("date")
#             if not date_:
#                 continue

#             year = date_[:4]

#             if row.get("returnOnAssets") is not None:
#                 records.append(
#                     (stock_id, "Return On Assets", row["returnOnAssets"], "Annual", year, "Return of Capital")
#                 )
#                 a_rows += 1

#             if row.get("returnOnEquity") is not None:
#                 records.append(
#                     (stock_id, "Return On Equity", row["returnOnEquity"], "Annual", year, "Return of Capital")
#                 )
#                 a_rows += 1

#             if row.get("returnOnCapitalEmployed") is not None:
#                 records.append(
#                     (stock_id, "Return on capital employed", row["returnOnCapitalEmployed"], "Annual", year, "Return of Capital")
#                 )
#                 a_rows += 1

#         # ---------- TTM ----------
#         ttm = fetch_key_metrics_ttm(ticker)

#         if ttm and latest_q_label:
#             row = ttm[0]

#             if row.get("returnOnAssetsTTM") is not None:
#                 records.append(
#                     (stock_id, "Return On Assets", row["returnOnAssetsTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital")
#                 )
#                 ttm_rows += 1

#             if row.get("returnOnEquityTTM") is not None:
#                 records.append(
#                     (stock_id, "Return On Equity", row["returnOnEquityTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital")
#                 )
#                 ttm_rows += 1

#             if row.get("returnOnCapitalEmployedTTM") is not None:
#                 records.append(
#                     (stock_id, "Return on capital employed", row["returnOnCapitalEmployedTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital")
#                 )
#                 ttm_rows += 1

#         # ---------- PRINT SUMMARY ----------
#         if q_rows == 0 and a_rows == 0 and ttm_rows == 0:
#             print("  ⚠ No Return of Capital data fetched")
#         else:
#             print(f"  Quarterly rows : {q_rows}")
#             print(f"  Annual rows    : {a_rows}")
#             print(f"  TTM rows       : {ttm_rows}")
#             print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     # ----------------------------------------------
#     # BULK INSERT
#     # ----------------------------------------------
#     print(f"\nInserting {len(records)} Return of Capital rows...")
#     cur.executemany(insert_sql, records)
#     conn.commit()

#     print("✔ Return of Capital ingestion completed")

#     cur.close()
#     conn.close()


# # --------------------------------------------------
# # ENTRY POINT
# # --------------------------------------------------
# def main():
#     print("\n======================================")
#     print(" FETCHING RETURN OF CAPITAL (ROA / ROE / ROCE)")
#     print("======================================\n")
#     fetch_and_load_return_of_capital()


# if __name__ == "__main__":
#     main()














# """
# Fetch Return of Capital
# -----------------------
# ROA, ROE, ROCE (Quarterly, Annual, TTM)

# Data Sources:
#  - Key Metrics → FMP

# Populates:
#  - ingest_db.stocks_fundamentals
# """

# # --------------------------------------------------
# # PATH FIX (CRITICAL)
# # --------------------------------------------------
# import sys
# from pathlib import Path

# sys.path.insert(0, str(Path(__file__).parent.parent))

# # --------------------------------------------------
# # IMPORTS
# # --------------------------------------------------
# import time
# import requests
# from datetime import datetime

# from utils import get_connection
# from config import TICKER_MAPPINGS, FMP_API_KEY, DATA_FETCH_CONFIG

# BASE_URL = "https://financialmodelingprep.com/stable"

# # --------------------------------------------------
# # HELPERS
# # --------------------------------------------------
# def quarter_label(date_str: str) -> str:
#     d = datetime.strptime(date_str, "%Y-%m-%d")
#     q = (d.month - 1) // 3 + 1
#     return f"{d.year}-Q{q}"


# def fetch_key_metrics(symbol: str, period: str):
#     try:
#         r = requests.get(
#             f"{BASE_URL}/key-metrics",
#             params={
#                 "symbol": symbol,
#                 "period": period,
#                 "apikey": FMP_API_KEY
#             },
#             timeout=30,
#         )
#         r.raise_for_status()
#         return r.json() or []
#     except Exception as e:
#         print(f"    ✗ Key metrics error ({period}) for {symbol}: {e}")
#         return []


# def fetch_key_metrics_ttm(symbol: str):
#     try:
#         r = requests.get(
#             f"{BASE_URL}/key-metrics-ttm",
#             params={
#                 "symbol": symbol,
#                 "apikey": FMP_API_KEY
#             },
#             timeout=30,
#         )
#         r.raise_for_status()
#         return r.json() or []
#     except Exception as e:
#         print(f"    ✗ Key metrics TTM error for {symbol}: {e}")
#         return []


# # --------------------------------------------------
# # CORE LOGIC
# # --------------------------------------------------
# def fetch_and_load_return_of_capital():
#     conn = get_connection()
#     cur = conn.cursor()

#     # ----------------------------------------------
#     # Load stocks from TICKER_MAPPINGS
#     # ----------------------------------------------
#     tickers = list(set(TICKER_MAPPINGS.values()))

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
#         print("❌ No matching stocks found for given tickers")
#         cur.close()
#         conn.close()
#         return

#     # ----------------------------------------------
#     # INSERT SQL
#     # ----------------------------------------------
#     insert_sql = """
#         INSERT INTO ingest_db.stocks_fundamentals
#         (
#             stock_id,
#             metric_type,
#             metric_value,
#             period_type,
#             period_label,
#             metric_category
#         )
#         VALUES (%s,%s,%s,%s,%s,%s)
#         ON CONFLICT DO NOTHING;
#     """

#     records = []

#     print(f"\nProcessing {len(stocks)} stocks (Return of Capital)...\n")

#     # ----------------------------------------------
#     # PROCESS EACH STOCK
#     # ----------------------------------------------
#     for stock_id, ticker in stocks:
#         print(f"Processing {ticker}...")

#         q_rows = 0
#         a_rows = 0
#         ttm_rows = 0
#         latest_q_label = None

#         # ---------- QUARTERLY ----------
#         q_data = fetch_key_metrics(ticker, "quarter")

#         for r in q_data:
#             date_ = r.get("date")
#             if not date_:
#                 continue

#             label = quarter_label(date_)

#             if r.get("returnOnAssets") is not None:
#                 records.append((stock_id, "Return On Assets", r["returnOnAssets"], "Quarterly", label, "Return of Capital"))
#                 q_rows += 1

#             if r.get("returnOnEquity") is not None:
#                 records.append((stock_id, "Return On Equity", r["returnOnEquity"], "Quarterly", label, "Return of Capital"))
#                 q_rows += 1

#             if r.get("returnOnCapitalEmployed") is not None:
#                 records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployed"], "Quarterly", label, "Return of Capital"))
#                 q_rows += 1

#         if q_data:
#             latest_q_label = quarter_label(q_data[0]["date"])

#         # ---------- ANNUAL ----------
#         a_data = fetch_key_metrics(ticker, "annual")

#         for r in a_data:
#             date_ = r.get("date")
#             if not date_:
#                 continue

#             year = date_[:4]

#             if r.get("returnOnAssets") is not None:
#                 records.append((stock_id, "Return On Assets", r["returnOnAssets"], "Annual", year, "Return of Capital"))
#                 a_rows += 1

#             if r.get("returnOnEquity") is not None:
#                 records.append((stock_id, "Return On Equity", r["returnOnEquity"], "Annual", year, "Return of Capital"))
#                 a_rows += 1

#             if r.get("returnOnCapitalEmployed") is not None:
#                 records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployed"], "Annual", year, "Return of Capital"))
#                 a_rows += 1

#         # ---------- TTM ----------
#         ttm = fetch_key_metrics_ttm(ticker)

#         if ttm and latest_q_label:
#             r = ttm[0]

#             if r.get("returnOnAssetsTTM") is not None:
#                 records.append((stock_id, "Return On Assets", r["returnOnAssetsTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital"))
#                 ttm_rows += 1

#             if r.get("returnOnEquityTTM") is not None:
#                 records.append((stock_id, "Return On Equity", r["returnOnEquityTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital"))
#                 ttm_rows += 1

#             if r.get("returnOnCapitalEmployedTTM") is not None:
#                 records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployedTTM"], "Quarterly - TTM", latest_q_label, "Return of Capital"))
#                 ttm_rows += 1

#         # ---------- SUMMARY ----------
#         print(f"  Quarterly rows : {q_rows}")
#         print(f"  Annual rows    : {a_rows}")
#         print(f"  TTM rows       : {ttm_rows}")
#         print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

#         time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

#     # ----------------------------------------------
#     # BULK INSERT
#     # ----------------------------------------------
#     print(f"\nInserting {len(records)} Return of Capital rows...")
#     cur.executemany(insert_sql, records)
#     conn.commit()

#     print("✔ Return of Capital ingestion completed")

#     cur.close()
#     conn.close()


# # --------------------------------------------------
# # METRIC CATEGORY UPDATE
# # --------------------------------------------------
# def update_metric_category():
#     conn = get_connection()
#     cur = conn.cursor()

#     cur.execute(
#         """
#         UPDATE ingest_db.stocks_fundamentals
#         SET metric_category = 'Ratios'
#         WHERE metric_type = 'Return on capital employed'
#           AND metric_category = 'Return of Capital';
#         """
#     )

#     conn.commit()
#     print(f"✔ Rows updated: {cur.rowcount}")

#     cur.close()
#     conn.close()


# # --------------------------------------------------
# # ENTRY POINT
# # --------------------------------------------------
# def main():
#     print("\n======================================")
#     print(" FETCHING RETURN OF CAPITAL (ROA, ROE)")
#     print("======================================\n")

#     fetch_and_load_return_of_capital()
#     update_metric_category()


# if __name__ == "__main__":
#     main()


























"""
Fetch Return of Capital
-----------------------
ROA, ROE, ROCE (Quarterly, Annual, TTM)

Data Sources:
 - Key Metrics → FMP

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


def fetch_key_metrics(symbol: str, period: str):
    try:
        r = requests.get(
            f"{BASE_URL}/key-metrics",
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
        print(f"✗ Key metrics error ({period}) for {symbol}: {e}")
        return []


def fetch_key_metrics_ttm(symbol: str):
    try:
        r = requests.get(
            f"{BASE_URL}/key-metrics-ttm",
            params={
                "symbol": symbol,
                "apikey": FMP_API_KEY
            },
            timeout=30,
        )
        r.raise_for_status()
        return r.json() or []
    except Exception as e:
        print(f"✗ Key metrics TTM error for {symbol}: {e}")
        return []

# --------------------------------------------------
# CORE LOGIC
# --------------------------------------------------
def fetch_and_load_return_of_capital():
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
        print("❌ No matching stocks found")
        cur.close()
        conn.close()
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

    print(f"\nProcessing {len(stocks)} stocks (Return of Capital)\n")

    for stock_id, ticker in stocks:
        print(f"Processing {ticker}...")

        q_rows = a_rows = ttm_rows = 0
        latest_q_label = None

        # ---------- QUARTERLY ----------
        q_data = fetch_key_metrics(ticker, "quarter")

        for r in q_data:
            date_ = r.get("date")
            if not date_:
                continue

            label = quarter_label(date_)

            if r.get("returnOnAssets") is not None:
                records.append((stock_id, "Return On Assets", r["returnOnAssets"], "Quarterly", label, "Ratios"))
                q_rows += 1

            if r.get("returnOnEquity") is not None:
                records.append((stock_id, "Return On Equity", r["returnOnEquity"], "Quarterly", label, "Ratios"))
                q_rows += 1

            if r.get("returnOnCapitalEmployed") is not None:
                records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployed"], "Quarterly", label, "Ratios"))
                q_rows += 1

        if q_data:
            latest_q_label = quarter_label(q_data[0]["date"])

        # ---------- ANNUAL ----------
        a_data = fetch_key_metrics(ticker, "annual")

        for r in a_data:
            date_ = r.get("date")
            if not date_:
                continue

            year = date_[:4]

            if r.get("returnOnAssets") is not None:
                records.append((stock_id, "Return On Assets", r["returnOnAssets"], "Annual", year, "Ratios"))
                a_rows += 1

            if r.get("returnOnEquity") is not None:
                records.append((stock_id, "Return On Equity", r["returnOnEquity"], "Annual", year, "Ratios"))
                a_rows += 1

            if r.get("returnOnCapitalEmployed") is not None:
                records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployed"], "Annual", year, "Ratios"))
                a_rows += 1

        # ---------- TTM ----------
        ttm = fetch_key_metrics_ttm(ticker)

        if ttm and latest_q_label:
            r = ttm[0]

            if r.get("returnOnAssetsTTM") is not None:
                records.append((stock_id, "Return On Assets", r["returnOnAssetsTTM"], "Quarterly - TTM", latest_q_label, "Ratios"))
                ttm_rows += 1

            if r.get("returnOnEquityTTM") is not None:
                records.append((stock_id, "Return On Equity", r["returnOnEquityTTM"], "Quarterly - TTM", latest_q_label, "Ratios"))
                ttm_rows += 1

            if r.get("returnOnCapitalEmployedTTM") is not None:
                records.append((stock_id, "Return on capital employed", r["returnOnCapitalEmployedTTM"], "Quarterly - TTM", latest_q_label, "Ratios"))
                ttm_rows += 1

        print(f"  Quarterly rows : {q_rows}")
        print(f"  Annual rows    : {a_rows}")
        print(f"  TTM rows       : {ttm_rows}")
        print(f"  ➜ Total rows   : {q_rows + a_rows + ttm_rows}")

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    print(f"\nInserting {len(records)} Return of Capital rows...")
    cur.executemany(insert_sql, records)
    conn.commit()

    print("✔ Return of Capital ingestion completed")

    cur.close()
    conn.close()

# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    print("\n======================================")
    print(" FETCHING RETURN OF CAPITAL (ROA, ROE)")
    print("======================================\n")

    fetch_and_load_return_of_capital()

if __name__ == "__main__":
    main()

