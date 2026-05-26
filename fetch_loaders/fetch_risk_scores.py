import argparse
import concurrent.futures
import json
import logging
import os
import sys
import time
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path

import requests
from psycopg2.extras import execute_values
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import DATA_FETCH_CONFIG, FMP_API_KEY
from utils import get_connection

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)

BASE_URL = "https://financialmodelingprep.com/stable"
METRIC_CATEGORY = "Risk & Score"
DEFAULT_WORKERS = int(os.environ.get("RISK_SCORE_MAX_WORKERS", "8"))
SESSION = None


def get_session():
    global SESSION
    if SESSION is not None:
        return SESSION
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
    SESSION = session
    return SESSION


def fmp_key():
    return os.environ.get("FMP_API_KEY") or FMP_API_KEY


def normalize_symbol(symbol):
    return (symbol or "").strip().upper()


def decimal_or_none(value):
    if value is None:
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None


def get_target_tickers():
    raw = os.environ.get("TARGET_TICKERS")
    if not raw:
        return None
    parsed = json.loads(raw)
    return {normalize_symbol(item) for item in parsed if item}


def load_non_peer_stocks(limit=None, tickers=None):
    conn = get_connection()
    cur = conn.cursor()
    params = []
    where = ["COALESCE(is_peer, false) = false"]
    target_tickers = tickers or get_target_tickers()
    if target_tickers:
        where.append("(upper(ticker) = ANY(%s) OR upper(canonical_ticker) = ANY(%s))")
        ticker_list = sorted(target_tickers)
        params.extend([ticker_list, ticker_list])
    sql = f"""
        SELECT stock_id, ticker, canonical_ticker, company_name
        FROM ingest_db.stocks
        WHERE {' AND '.join(where)}
        ORDER BY stock_id
    """
    if limit:
        sql += " LIMIT %s"
        params.append(limit)
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "stock_id": row[0],
            "ticker": row[1],
            "canonical_ticker": row[2],
            "company_name": row[3],
        }
        for row in rows
    ]


def fetch_json(endpoint, ticker):
    response = get_session().get(
        f"{BASE_URL}/{endpoint}",
        params={"symbol": ticker, "apikey": fmp_key()},
        timeout=30,
    )
    response.raise_for_status()
    data = response.json()
    return data if isinstance(data, list) else []


def first_verified_row(endpoint, ticker):
    data = fetch_json(endpoint, ticker)
    if not data:
        return None
    row = data[0]
    returned_symbol = normalize_symbol(row.get("symbol"))
    if not returned_symbol or returned_symbol != normalize_symbol(ticker):
        return None
    return row


def fetch_scores(stock):
    ticker = stock["ticker"]
    result = {
        **stock,
        "beta": None,
        "piotroski_score": None,
        "profile_ok": False,
        "financial_scores_ok": False,
        "errors": [],
    }
    try:
        profile = first_verified_row("profile", ticker)
        if profile:
            result["profile_ok"] = True
            result["beta"] = decimal_or_none(profile.get("beta"))
    except Exception as exc:
        result["errors"].append(f"profile: {exc}")
    time.sleep(float(os.environ.get("RISK_SCORE_REQUEST_DELAY", DATA_FETCH_CONFIG.get("rate_limit_delay", 0.3))))
    try:
        scores = first_verified_row("financial-scores", ticker)
        if scores:
            result["financial_scores_ok"] = True
            result["piotroski_score"] = decimal_or_none(scores.get("piotroskiScore"))
    except Exception as exc:
        result["errors"].append(f"financial-scores: {exc}")
    return result


def build_records(results, captured_date):
    records = []
    for item in results:
        stock_id = item["stock_id"]
        beta = item.get("beta")
        piotroski_score = item.get("piotroski_score")
        if beta is not None:
            records.append((stock_id, "Beta", beta, "Daily", captured_date.isoformat(), captured_date, METRIC_CATEGORY))
            records.append((stock_id, "Beta", beta, "TTM", "TTM", captured_date, METRIC_CATEGORY))
        if piotroski_score is not None:
            records.append((stock_id, "Piotroski Score", piotroski_score, "Daily", captured_date.isoformat(), captured_date, METRIC_CATEGORY))
            records.append((stock_id, "Piotroski Score", piotroski_score, "TTM", "TTM", captured_date, METRIC_CATEGORY))
    return records


def upsert_records(records):
    if not records:
        return 0
    conn = get_connection()
    cur = conn.cursor()
    sql = """
        INSERT INTO ingest_db.stocks_fundamentals (
            stock_id,
            metric_type,
            metric_value,
            period_type,
            period_label,
            captured_date,
            metric_category
        )
        VALUES %s
        ON CONFLICT (stock_id, metric_category, metric_type, period_type, period_label, captured_date)
        DO UPDATE SET
            metric_value = EXCLUDED.metric_value,
            created_at = CURRENT_TIMESTAMP;
    """
    execute_values(cur, sql, records, page_size=1000)
    conn.commit()
    cur.close()
    conn.close()
    return len(records)


def fetch_all(stocks, workers):
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, min(workers, len(stocks) or 1))) as executor:
        futures = {executor.submit(fetch_scores, stock): stock for stock in stocks}
        for index, future in enumerate(concurrent.futures.as_completed(futures), 1):
            stock = futures[future]
            try:
                item = future.result()
            except Exception as exc:
                item = {**stock, "beta": None, "piotroski_score": None, "profile_ok": False, "financial_scores_ok": False, "errors": [str(exc)]}
            results.append(item)
            log.info(
                "[%s/%s] %s beta=%s piotroski=%s errors=%s",
                index,
                len(stocks),
                item["ticker"],
                item.get("beta"),
                item.get("piotroski_score"),
                len(item.get("errors") or []),
            )
    return sorted(results, key=lambda item: item["stock_id"])


def summarize(results, records, dry_run):
    beta_count = sum(1 for item in results if item.get("beta") is not None)
    piotroski_count = sum(1 for item in results if item.get("piotroski_score") is not None)
    missing_beta = [item["ticker"] for item in results if item.get("beta") is None]
    missing_piotroski = [item["ticker"] for item in results if item.get("piotroski_score") is None]
    errors = {item["ticker"]: item["errors"] for item in results if item.get("errors")}
    return {
        "status": "success",
        "dry_run": dry_run,
        "stocks_processed": len(results),
        "stocks_with_beta": beta_count,
        "stocks_with_piotroski_score": piotroski_count,
        "records_ready": len(records),
        "missing_beta": missing_beta,
        "missing_piotroski_score": missing_piotroski,
        "errors": errors,
    }


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--workers", type=int, default=DEFAULT_WORKERS)
    parser.add_argument("--tickers", nargs="*")
    return parser.parse_args()


def main():
    args = parse_args()
    requested = {normalize_symbol(ticker) for ticker in args.tickers} if args.tickers else None
    stocks = load_non_peer_stocks(limit=args.limit, tickers=requested)
    if not stocks:
        summary = {"status": "success", "dry_run": args.dry_run, "stocks_processed": 0, "records_ready": 0}
        print(json.dumps(summary, indent=2, default=str))
        return summary
    log.info("Fetching risk scores for %s non-peer stocks", len(stocks))
    results = fetch_all(stocks, args.workers)
    records = build_records(results, date.today())
    inserted = 0 if args.dry_run else upsert_records(records)
    summary = summarize(results, records, args.dry_run)
    summary["records_inserted"] = inserted
    print(json.dumps(summary, indent=2, default=str))
    return summary


if __name__ == "__main__":
    main()
