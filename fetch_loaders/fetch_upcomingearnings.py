"""
Fetch earnings calendar data from FMP with Yahoo fallback.
Populates:
- ingest_db.stocks_earnings_calendar
- ingest_db.stocks_upcoming_earnings
"""

import concurrent.futures
import csv
import json
import logging
import os
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
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
WINDOW_DAYS = int(os.environ.get("EARNINGS_WINDOW_DAYS", "7"))
FMP_SESSION = None


def get_tickers() -> list:
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
        backoff_factor=0.5,
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


def upcoming_currency_code(currency_code: str) -> str:
    """Normalize GBX → GBP; return as-is otherwise."""
    currency = (currency_code or "").strip().upper()
    if currency in {"GBP", "GBX"}:
        return "GBP"
    return currency_code or ""


def is_credible_upcoming_date(value, today, max_date):
    if value is None:
        return False
    if value < today or value > max_date:
        return False
    if value.month == 12 and value.day == 31:
        return False
    return True


def load_target_stocks(tickers=None):
    conn = get_connection()
    cur = conn.cursor()
    if tickers:
        cur.execute(
            """
            SELECT stock_id, ticker, currency_code, canonical_ticker
            FROM ingest_db.stocks
            WHERE ticker = ANY(%s)
            ORDER BY stock_id
            """,
            (tickers,),
        )
    else:
        # TICKER_MAPPINGS may be empty if the config DB connection failed at import
        # time; fall back to loading all non-peer stocks directly from the DB.
        log.info("TICKER_MAPPINGS empty — loading all non-peer stocks from DB directly")
        cur.execute(
            """
            SELECT stock_id, ticker, currency_code, canonical_ticker
            FROM ingest_db.stocks
            WHERE COALESCE(is_peer, false) = false
              AND ticker IS NOT NULL
              AND BTRIM(ticker) <> ''
            ORDER BY stock_id
            """
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


def build_symbol_map(stocks):
    """Map normalized symbols to stocks via ticker + canonical_ticker; skip ambiguous symbols."""
    candidates = defaultdict(list)
    for stock in stocks:
        for symbol in (stock["ticker"], stock.get("canonical_ticker")):
            normalized = normalize_symbol(symbol)
            if not normalized:
                continue
            candidates[normalized].append(stock)
    return {
        symbol: stock_list[0]
        for symbol, stock_list in candidates.items()
        if len({s["stock_id"] for s in stock_list}) == 1
    }


# ---------------------------------------------------------------------------
# FMP calendar fetch — windowed + auto-bisect + deduplication
# ---------------------------------------------------------------------------

def _fetch_fmp_window(start_date, end_date):
    try:
        response = get_session().get(
            f"{BASE_URL}/earnings-calendar",
            params={
                "from": start_date.isoformat(),
                "to": end_date.isoformat(),
                "apikey": fmp_key(),
            },
            timeout=60,
        )
        response.raise_for_status()
        data = response.json()
        if not isinstance(data, list):
            raise ValueError("FMP earnings-calendar response was not a JSON list")
        return data
    except Exception as exc:
        log.warning("FMP earnings calendar fetch failed for %s..%s: %s", start_date, end_date, exc)
        return []


def fetch_fmp_calendar_rows(start_date, end_date, window_days=7):
    """
    Fetch FMP earnings calendar in rolling windows.
    Auto-bisects any window that hits the 4 000-row cap to prevent silent truncation.
    Deduplicates rows across windows via a content-hash key.
    """
    rows = []
    seen: set = set()

    def add_rows(new_rows):
        for row in new_rows:
            key = (
                row.get("symbol"),
                row.get("date"),
                row.get("epsActual"),
                row.get("epsEstimated"),
                row.get("revenueActual"),
                row.get("revenueEstimated"),
                row.get("lastUpdated"),
            )
            if key not in seen:
                seen.add(key)
                rows.append(row)

    def fetch_range(range_start, range_end):
        window_rows = _fetch_fmp_window(range_start, range_end)
        if len(window_rows) >= 4000 and range_start < range_end:
            midpoint = range_start + ((range_end - range_start) // 2)
            log.warning(
                "FMP returned %d rows for %s..%s — splitting at %s",
                len(window_rows), range_start, range_end, midpoint,
            )
            fetch_range(range_start, midpoint)
            fetch_range(midpoint + timedelta(days=1), range_end)
            return
        if len(window_rows) >= 4000:
            log.warning(
                "FMP returned %d rows for single-day window %s — response may still be capped",
                len(window_rows), range_start,
            )
        add_rows(window_rows)
        log.info(
            "FMP: %d row(s) for %s..%s — cumulative unique=%d",
            len(window_rows), range_start, range_end, len(rows),
        )

    cursor = start_date
    while cursor <= end_date:
        window_end = min(cursor + timedelta(days=window_days - 1), end_date)
        fetch_range(cursor, window_end)
        cursor = window_end + timedelta(days=1)
    return rows


def index_fmp_calendar(fmp_rows, symbol_map, today, max_date):
    """
    Match FMP rows to stocks via symbol_map (ticker + canonical_ticker).
    Returns dict[stock_id -> earliest credible upcoming entry].
    """
    best: dict = {}
    for row in fmp_rows:
        symbol = normalize_symbol(row.get("symbol"))
        stock = symbol_map.get(symbol)
        if not stock:
            continue
        event_date = as_date(row.get("date"))
        if not is_credible_upcoming_date(event_date, today, max_date):
            continue
        sid = stock["stock_id"]
        entry = {
            "stock": stock,
            "date": event_date,
            "estimated_eps": clean_number(row.get("epsEstimated")),
            "actual_eps": clean_number(row.get("epsActual")),
            "source": "fmp_earnings_calendar",
        }
        current = best.get(sid)
        if current is None or entry["date"] < current["date"]:
            best[sid] = entry
    return best


# ---------------------------------------------------------------------------
# Yahoo fallback (per-ticker, only when FMP has no match)
# ---------------------------------------------------------------------------

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
            candidates.append({
                "stock": stock,
                "date": event_date,
                "estimated_eps": clean_number(row.get("EPS Estimate")),
                "actual_eps": clean_number(row.get("Reported EPS")),
                "source": "yfinance_earnings_dates",
            })
        if not candidates:
            return None
        candidates.sort(key=lambda item: item["date"])
        return candidates[0]
    except Exception as exc:
        log.warning("Yahoo earnings fetch failed for %s: %s", ticker, exc)
        return None


# ---------------------------------------------------------------------------
# Market cap — FMP /profile with cache, Yahoo fallback
# ---------------------------------------------------------------------------

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


def enrich_market_caps(results):
    """
    Fetch market caps sequentially with a shared cache.
    Tries ticker then canonical_ticker via FMP; falls back to Yahoo.
    """
    cache: dict = {}
    counters: Counter = Counter()
    enriched = []
    for row in results:
        if not row.get("earnings_date"):
            enriched.append(row)
            continue
        market_cap = None
        ticker = row["ticker"]
        canonical = row.get("canonical_ticker")
        for symbol in filter(None, [ticker, canonical]):
            key = normalize_symbol(symbol)
            if key not in cache:
                cache[key] = fetch_fmp_market_cap(symbol)
            if cache[key] is not None:
                market_cap = cache[key]
                break
        if market_cap is None:
            market_cap = fetch_yahoo_market_cap(ticker)
            if market_cap is not None:
                counters["market_cap_from_yahoo"] += 1
            else:
                counters["market_cap_missing"] += 1
        else:
            counters["market_cap_from_fmp"] += 1
        enriched.append({**row, "market_cap": market_cap})
    counters["market_cap_profile_requests"] = len(cache)
    return enriched, counters


# ---------------------------------------------------------------------------
# Concurrent earnings resolution (Yahoo fallback only when FMP misses)
# ---------------------------------------------------------------------------

def resolve_stock_earnings(stock, fmp_best, today, max_date):
    sid = stock["stock_id"]
    chosen = fmp_best.get(sid)
    if not chosen:
        chosen = fetch_yahoo_earnings(stock, today, max_date)
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
        "market_cap": None,
        "reason_not_inserted": None,
    }


def resolve_all_earnings(stocks, fmp_best, today, max_date):
    results = []
    workers = min(EARNINGS_MAX_WORKERS, max(1, len(stocks)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(resolve_stock_earnings, stock, fmp_best, today, max_date): stock
            for stock in stocks
        }
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
                index, len(stocks),
                row["ticker"], row["source"],
                row["earnings_date"], row["estimated_eps"],
            )
            time.sleep(float(DATA_FETCH_CONFIG.get("rate_limit_delay", 0.3)) / max(1, workers))
    return sorted(results, key=lambda item: item["stock_id"])


# ---------------------------------------------------------------------------
# DB rows builder
# ---------------------------------------------------------------------------

def build_rows(results):
    upcoming_rows = []
    calendar_rows = []
    for row in results:
        if not row.get("earnings_date"):
            continue
        upcoming_rows.append((
            row["stock_id"],
            row["ticker"],
            row["market_cap"],
            row["earnings_date"],
            row["estimated_eps"],
            row["actual_eps"],
            upcoming_currency_code(row.get("currency_code", "")),
            row.get("canonical_ticker"),
        ))
        calendar_rows.append((row["stock_id"], row["earnings_date"], row["source"]))
    return calendar_rows, upcoming_rows


# ---------------------------------------------------------------------------
# Audit CSV output
# ---------------------------------------------------------------------------

def write_audit_files(audit_dir: Path, results, summary):
    audit_dir.mkdir(parents=True, exist_ok=True)

    matched_fields = [
        "stock_id", "ticker", "canonical_ticker", "currency_code",
        "source", "earnings_date", "estimated_eps", "actual_eps", "market_cap",
    ]
    with (audit_dir / "matched_upcoming_earnings.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=matched_fields)
        writer.writeheader()
        writer.writerows([
            {k: row.get(k) for k in matched_fields}
            for row in results if row.get("earnings_date")
        ])

    missing_fields = ["stock_id", "ticker", "canonical_ticker", "reason_not_inserted"]
    with (audit_dir / "stocks_without_earnings.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=missing_fields)
        writer.writeheader()
        writer.writerows([
            {k: row.get(k) for k in missing_fields}
            for row in results if not row.get("earnings_date")
        ])

    (audit_dir / "summary.json").write_text(json.dumps(summary, indent=2, default=str) + "\n")
    log.info("Audit files written to %s", audit_dir)


# ---------------------------------------------------------------------------
# DB load
# ---------------------------------------------------------------------------

def _connect_with_retry(max_attempts=3, delay=3):
    for attempt in range(1, max_attempts + 1):
        try:
            return get_connection()
        except Exception as exc:
            if attempt == max_attempts:
                raise
            log.warning("DB connection attempt %d/%d failed: %s — retrying in %ds", attempt, max_attempts, exc, delay)
            time.sleep(delay)


def load_earnings_rows(stock_ids, calendar_rows, upcoming_rows):
    conn = _connect_with_retry()
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


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    started = time.perf_counter()
    today = datetime.now(timezone.utc).date()
    max_date = today + timedelta(days=LOOKAHEAD_DAYS)

    tickers = get_tickers()
    stocks = load_target_stocks(tickers or None)
    if not stocks:
        return {"status": "success", "tickers_processed": 0, "records_inserted": 0}

    log.info("Fetching earnings for %s stocks from %s to %s", len(stocks), today, max_date)

    symbol_map = build_symbol_map(stocks)
    fmp_rows = fetch_fmp_calendar_rows(today, max_date, window_days=WINDOW_DAYS)
    log.info("Fetched %d FMP earnings-calendar row(s) total", len(fmp_rows))

    allow_empty = os.environ.get("ALLOW_EMPTY_FMP", "false").lower() == "true"
    if not fmp_rows and not allow_empty:
        log.warning("FMP returned zero rows — aborting to avoid wiping existing upcoming earnings")
        return {"status": "aborted", "reason": "fmp_returned_zero_rows"}

    fmp_best = index_fmp_calendar(fmp_rows, symbol_map, today, max_date)

    results = resolve_all_earnings(stocks, fmp_best, today, max_date)
    results, market_cap_counters = enrich_market_caps(results)

    calendar_rows, upcoming_rows = build_rows(results)

    load_result = load_earnings_rows(
        [stock["stock_id"] for stock in stocks],
        calendar_rows,
        upcoming_rows,
    )

    source_counts = Counter(row["source"] for row in results)
    summary = {
        "status": "success",
        "tickers_processed": len(stocks),
        "provider_source_counts": dict(source_counts),
        "market_cap_counters": dict(market_cap_counters),
        "calendar_rows_ready": len(calendar_rows),
        "upcoming_rows_ready": len(upcoming_rows),
        "rows_with_estimated_eps": sum(1 for row in upcoming_rows if row[4] is not None),
        "rows_without_estimated_eps": sum(1 for row in upcoming_rows if row[4] is None),
        "elapsed_seconds": round(time.perf_counter() - started, 2),
        **load_result,
    }

    audit_dir = Path(
        os.environ.get("EARNINGS_AUDIT_DIR")
        or f"output/earnings_refresh/run_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    )
    write_audit_files(audit_dir, results, summary)
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
