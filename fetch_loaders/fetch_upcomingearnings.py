# """
# Fetch upcoming earnings for stocks
# Populates: ingest_db.stocks_upcoming_earnings

# ✔ Uses Yahoo Finance for earnings dates
# ✔ Uses FMP → fallback to Yahoo for market cap
# ✔ ECS / Docker / Step Functions compatible
# """

# import sys
# from pathlib import Path
# from datetime import datetime
# import requests
# import yfinance as yf
# import pandas as pd

# # --------------------------------------------------
# # Path setup
# # --------------------------------------------------
# sys.path.insert(0, str(Path(__file__).parent.parent))

# # --------------------------------------------------
# # Imports
# # --------------------------------------------------
# from utils import get_connection
# from config import (
#     FMP_API_KEY,
#     TICKER_MAPPINGS,
# )

# # --------------------------------------------------
# # Helpers
# # --------------------------------------------------
# def fetch_market_cap_fmp(ticker: str):
#     try:
#         r = requests.get(
#             "https://financialmodelingprep.com/stable/market-capitalization",
#             params={"symbol": ticker, "apikey": FMP_API_KEY},
#             timeout=20
#         )
#         r.raise_for_status()
#         data = r.json()
#         return data[0]["marketCap"] if data else None
#     except Exception:
#         return None


# def fetch_market_cap_yf(ticker: str):
#     try:
#         return yf.Ticker(ticker).info.get("marketCap")
#     except Exception:
#         return None


# # --------------------------------------------------
# # Fetch earnings data
# # --------------------------------------------------
# def fetch_upcoming_earnings():
#     tickers = list(TICKER_MAPPINGS.keys())
#     rows = []

#     print(f"\n📊 Fetching upcoming earnings for {len(tickers)} stocks\n")

#     for idx, ticker in enumerate(tickers, 1):
#         print(f"[{idx}/{len(tickers)}] {ticker}", end=" ")

#         try:
#             t = yf.Ticker(ticker)
#             df = t.get_earnings_dates(limit=10)

#             if df is None or df.empty:
#                 print("⚠️ No earnings data")
#                 continue

#             df = df.reset_index()

#             # Prefer future earnings, fallback to latest
#             future = df[df["Earnings Date"] >= pd.Timestamp.utcnow()]
#             row = future.iloc[0] if not future.empty else df.iloc[0]

#             earnings_date = pd.to_datetime(row["Earnings Date"]).date()
#             eps_est = row.get("EPS Estimate")
#             eps_rep = row.get("Reported EPS")

#             rows.append({
#                 "ticker": ticker,
#                 "earnings_date": earnings_date,
#                 "estimated_eps": round(eps_est, 2) if pd.notna(eps_est) else None,
#                 "actual_eps": round(eps_rep, 2) if pd.notna(eps_rep) else None,
#             })

#             print(f"✓ {earnings_date}")

#         except Exception as e:
#             print(f"✗ Error: {str(e)[:80]}")

#     return rows


# # --------------------------------------------------
# # Transform + Load
# # --------------------------------------------------
# def transform_and_load(earnings_rows):
#     if not earnings_rows:
#         print("\n⚠️ No earnings data fetched")
#         return 0

#     conn = get_connection()
#     cur = conn.cursor()

#     # Fetch stock_id + currency from DB (authoritative)
#     cur.execute("""
#         SELECT stock_id, ticker, currency_code
#         FROM ingest_db.stocks
#     """)
#     stock_map = {
#         ticker: (stock_id, currency)
#         for stock_id, ticker, currency in cur.fetchall()
#     }

#     records = []

#     for row in earnings_rows:
#         ticker = row["ticker"]

#         if ticker not in stock_map:
#             print(f"⚠️ Skipping {ticker} (not in stocks table)")
#             continue

#         stock_id, currency = stock_map[ticker]

#         market_cap = fetch_market_cap_fmp(ticker)
#         if market_cap is None:
#             market_cap = fetch_market_cap_yf(ticker)

#         records.append((
#             stock_id,
#             ticker,
#             market_cap,
#             row["earnings_date"],
#             row["estimated_eps"],
#             row["actual_eps"],
#             currency
#         ))

#     if not records:
#         print("\n⚠️ No valid rows to insert")
#         return 0

#     print(f"\n📥 Inserting {len(records)} rows into ingest_db.stocks_upcoming_earnings")

#     insert_sql = """
#         INSERT INTO ingest_db.stocks_upcoming_earnings (
#             stock_id,
#             ticker,
#             market_cap,
#             earnings_date,
#             estimated_eps,
#             actual_eps,
#             currency_code
#         )
#         VALUES (%s, %s, %s, %s, %s, %s, %s)
#         ON CONFLICT DO NOTHING
#     """

#     cur.executemany(insert_sql, records)
#     conn.commit()

#     cur.close()
#     conn.close()

#     return len(records)


# # --------------------------------------------------
# # Main
# # --------------------------------------------------
# def main():
#     print("\n" + "=" * 60)
#     print("FETCHING: Upcoming Earnings")
#     print("=" * 60)

#     earnings = fetch_upcoming_earnings()
#     inserted = transform_and_load(earnings)

#     print("\n✅ DONE")
#     print(f"   Rows processed: {inserted}")
#     print("=" * 60)


# # --------------------------------------------------
# if __name__ == "__main__":
#     main()







"""
Fetch earnings calendar data from FMP with Yahoo fallback.
Populates:
- ingest_db.stocks_earnings_calendar
- ingest_db.stocks_upcoming_earnings
"""

import concurrent.futures
import json
import logging
import os
import sys
import time
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pandas as pd
import requests
import yfinance as yf
from psycopg2.extras import execute_values
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import DATA_FETCH_CONFIG, FMP_API_KEY
from utils import get_connection

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)

BASE_URL = "https://financialmodelingprep.com/stable"
EARNINGS_MAX_WORKERS = int(os.environ.get("FMP_EARNINGS_MAX_WORKERS", "10"))
LOOKAHEAD_DAYS = int(os.environ.get("EARNINGS_LOOKAHEAD_DAYS", "365"))
FMP_SESSION = None


def get_tickers() -> list[str]:
    env_val = os.environ.get("TARGET_TICKERS")
    if env_val:
        return json.loads(env_val)
    from config import TICKER_MAPPINGS
    return list(TICKER_MAPPINGS.values())


def is_peer_run() -> bool:
    return os.environ.get("IS_PEER_RUN", "false").lower() == "true"


def get_session():
    global FMP_SESSION
    if FMP_SESSION is not None:
        return FMP_SESSION
    session = requests.Session()
    retry = Retry(
        total=3,
        backoff_factor=0.4,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(pool_connections=100, pool_maxsize=100, max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    FMP_SESSION = session
    return FMP_SESSION


def fmp_key():
    return os.environ.get("FMP_API_KEY") or FMP_API_KEY


def normalize_symbol(value):
    return (value or "").strip().upper()


def as_date(value):
    if value is None:
        return None
    try:
        return pd.to_datetime(value).date()
    except Exception:
        return None


def clean_number(value):
    if value is None:
        return None
    try:
        if pd.isna(value):
            return None
        return float(value)
    except Exception:
        return None


def is_fiscal_period_like(value):
    return value is not None and value.month == 12 and value.day == 31


def is_credible_upcoming_date(value, today, max_date):
    if value is None:
        return False
    if value < today or value > max_date:
        return False
    if is_fiscal_period_like(value):
        return False
    return True


def load_target_stocks(tickers):
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT stock_id, ticker, currency_code, canonical_ticker
        FROM ingest_db.stocks
        WHERE ticker = ANY(%s)
        ORDER BY stock_id
        """,
        (tickers,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "stock_id": row[0],
            "ticker": row[1],
            "currency_code": row[2],
            "canonical_ticker": row[3],
        }
        for row in rows
    ]


def fetch_fmp_calendar_rows(start_date, end_date):
    try:
        response = get_session().get(
            f"{BASE_URL}/earnings-calendar",
            params={
                "from": start_date.isoformat(),
                "to": end_date.isoformat(),
                "apikey": fmp_key(),
            },
            timeout=45,
        )
        response.raise_for_status()
        data = response.json()
        return data if isinstance(data, list) else []
    except Exception as exc:
        log.warning("FMP earnings calendar fetch failed: %s", exc)
        return []


def index_fmp_calendar(rows, today, max_date):
    by_symbol = defaultdict(list)
    for row in rows:
        symbol = normalize_symbol(row.get("symbol"))
        event_date = as_date(row.get("date"))
        if not symbol or not is_credible_upcoming_date(event_date, today, max_date):
            continue
        by_symbol[symbol].append(
            {
                "date": event_date,
                "estimated_eps": clean_number(row.get("epsEstimated")),
                "actual_eps": clean_number(row.get("epsActual")),
                "source": "fmp_earnings_calendar",
            }
        )
    for symbol in by_symbol:
        by_symbol[symbol].sort(key=lambda item: item["date"])
    return by_symbol


def fetch_yahoo_earnings(stock, today, max_date):
    ticker = stock["ticker"]
    try:
        df = yf.Ticker(ticker).get_earnings_dates(limit=12)
        if df is None or df.empty:
            return None
        df = df.reset_index()
        candidates = []
        for _, row in df.iterrows():
            event_date = as_date(row.get("Earnings Date"))
            if not is_credible_upcoming_date(event_date, today, max_date):
                continue
            candidates.append(
                {
                    "date": event_date,
                    "estimated_eps": clean_number(row.get("EPS Estimate")),
                    "actual_eps": clean_number(row.get("Reported EPS")),
                    "source": "yfinance_earnings_dates",
                }
            )
        if not candidates:
            return None
        candidates.sort(key=lambda item: item["date"])
        return candidates[0]
    except Exception as exc:
        log.warning("Yahoo earnings fetch failed for %s: %s", ticker, exc)
        return None


def fetch_fmp_market_cap(ticker):
    try:
        response = get_session().get(
            f"{BASE_URL}/profile",
            params={"symbol": ticker, "apikey": fmp_key()},
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, list) or not data:
            return None
        row = data[0]
        if normalize_symbol(row.get("symbol")) != normalize_symbol(ticker):
            return None
        return clean_number(row.get("marketCap"))
    except Exception:
        return None


def fetch_yahoo_market_cap(ticker):
    try:
        return clean_number(yf.Ticker(ticker).info.get("marketCap"))
    except Exception:
        return None


def fetch_market_cap(ticker):
    market_cap = fetch_fmp_market_cap(ticker)
    if market_cap is not None:
        return market_cap
    return fetch_yahoo_market_cap(ticker)


def resolve_stock_earnings(stock, fmp_index, today, max_date):
    symbol = normalize_symbol(stock["ticker"])
    fmp_match = (fmp_index.get(symbol) or [None])[0]
    yahoo_match = None if fmp_match else fetch_yahoo_earnings(stock, today, max_date)
    chosen = fmp_match or yahoo_match
    if not chosen:
        return {
            **stock,
            "source": "not_inserted",
            "earnings_date": None,
            "estimated_eps": None,
            "actual_eps": None,
            "market_cap": None,
            "reason_not_inserted": "no_upcoming_earnings_date_from_fmp_or_yahoo",
        }
    return {
        **stock,
        "source": chosen["source"],
        "earnings_date": chosen["date"],
        "estimated_eps": chosen["estimated_eps"],
        "actual_eps": chosen["actual_eps"],
        "market_cap": fetch_market_cap(stock["ticker"]),
        "reason_not_inserted": None,
    }


def resolve_all_earnings(stocks, fmp_index, today, max_date):
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(EARNINGS_MAX_WORKERS, max(1, len(stocks)))) as executor:
        futures = {executor.submit(resolve_stock_earnings, stock, fmp_index, today, max_date): stock for stock in stocks}
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            stock = futures[future]
            try:
                row = future.result()
            except Exception as exc:
                row = {
                    **stock,
                    "source": "not_inserted",
                    "earnings_date": None,
                    "estimated_eps": None,
                    "actual_eps": None,
                    "market_cap": None,
                    "reason_not_inserted": str(exc),
                }
            results.append(row)
            log.info(
                "[%s/%s] %s source=%s date=%s eps=%s",
                index,
                len(stocks),
                row["ticker"],
                row["source"],
                row["earnings_date"],
                row["estimated_eps"],
            )
            time.sleep(float(DATA_FETCH_CONFIG.get("rate_limit_delay", 0.3)) / max(1, EARNINGS_MAX_WORKERS))
    return sorted(results, key=lambda item: item["stock_id"])


def build_rows(results):
    upcoming_rows = []
    calendar_rows = []
    for row in results:
        if not row.get("earnings_date"):
            continue
        upcoming_rows.append(
            (
                row["stock_id"],
                row["ticker"],
                row["market_cap"],
                row["earnings_date"],
                row["estimated_eps"],
                row["actual_eps"],
                row["currency_code"],
                row["canonical_ticker"],
            )
        )
        calendar_rows.append((row["stock_id"], row["earnings_date"], row["source"]))
    return calendar_rows, upcoming_rows


def load_earnings_rows(stock_ids, calendar_rows, upcoming_rows, dry_run=False):
    if dry_run:
        return {"calendar_inserted": 0, "upcoming_deleted": 0, "upcoming_upserted": 0}
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "DELETE FROM ingest_db.stocks_upcoming_earnings WHERE stock_id = ANY(%s)",
            (stock_ids,),
        )
        deleted = cur.rowcount
        calendar_inserted = 0
        if calendar_rows:
            cur.executemany(
                """
                INSERT INTO ingest_db.stocks_earnings_calendar (
                    stock_id, earnings_date, session_type
                )
                SELECT %s, %s, %s
                WHERE NOT EXISTS (
                    SELECT 1
                    FROM ingest_db.stocks_earnings_calendar
                    WHERE stock_id = %s AND earnings_date = %s
                )
                """,
                [(sid, dt, source, sid, dt) for sid, dt, source in calendar_rows],
            )
            calendar_inserted = cur.rowcount
        if upcoming_rows:
            execute_values(
                cur,
                """
                INSERT INTO ingest_db.stocks_upcoming_earnings (
                    stock_id,
                    ticker,
                    market_cap,
                    earnings_date,
                    estimated_eps,
                    actual_eps,
                    currency_code,
                    canonical_ticker
                )
                VALUES %s
                ON CONFLICT (stock_id, earnings_date) DO UPDATE SET
                    ticker = EXCLUDED.ticker,
                    market_cap = EXCLUDED.market_cap,
                    estimated_eps = EXCLUDED.estimated_eps,
                    actual_eps = EXCLUDED.actual_eps,
                    currency_code = EXCLUDED.currency_code,
                    canonical_ticker = EXCLUDED.canonical_ticker
                """,
                upcoming_rows,
                page_size=1000,
            )
        conn.commit()
        return {
            "calendar_inserted": calendar_inserted,
            "upcoming_deleted": deleted,
            "upcoming_upserted": len(upcoming_rows),
        }
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


def main():
    started = time.perf_counter()
    today = datetime.now(timezone.utc).date()
    max_date = today + timedelta(days=LOOKAHEAD_DAYS)
    tickers = get_tickers()
    stocks = load_target_stocks(tickers)
    if not stocks:
        return {"status": "success", "tickers_processed": 0, "records_inserted": 0}
    log.info("Fetching earnings for %s stocks from %s to %s", len(stocks), today, max_date)
    fmp_rows = fetch_fmp_calendar_rows(today, max_date)
    fmp_index = index_fmp_calendar(fmp_rows, today, max_date)
    results = resolve_all_earnings(stocks, fmp_index, today, max_date)
    calendar_rows, upcoming_rows = build_rows(results)
    dry_run = os.environ.get("DRY_RUN", "false").lower() == "true"
    load_result = load_earnings_rows(
        [stock["stock_id"] for stock in stocks],
        calendar_rows,
        upcoming_rows,
        dry_run=dry_run,
    )
    source_counts = Counter(row["source"] for row in results)
    summary = {
        "status": "success",
        "dry_run": dry_run,
        "tickers_processed": len(stocks),
        "provider_source_counts": dict(source_counts),
        "calendar_rows_ready": len(calendar_rows),
        "upcoming_rows_ready": len(upcoming_rows),
        "rows_with_estimated_eps": sum(1 for row in upcoming_rows if row[4] is not None),
        "rows_without_estimated_eps": sum(1 for row in upcoming_rows if row[4] is None),
        "elapsed_seconds": round(time.perf_counter() - started, 2),
        **load_result,
    }
    log.info("Earnings ingestion summary: %s", json.dumps(summary, default=str))
    return summary


if __name__ == "__main__":
    print(json.dumps(main(), indent=2, default=str))


def lambda_handler(event, context):
    tickers = event.get("tickers")
    if tickers:
        os.environ["TARGET_TICKERS"] = json.dumps(tickers)
    if event.get("is_peer_run"):
        os.environ["IS_PEER_RUN"] = "true"
    job_id = event.get("job_id")
    if job_id:
        os.environ["JOB_ID"] = str(job_id)
    result = main()
    return {
        **(result or {}),
        "tickers": tickers,
        "job_id": job_id,
        "portfolio_id": event.get("portfolio_id"),
    }
