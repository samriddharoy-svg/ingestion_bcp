"""
Generate AI Market Summary (Quality + Risk sections) — PER MARKET.
Populates:
- ingest_db.market
- transform_db.market_summary

Rules:
- Markets are built from ingest_db.stocks where is_peer = false
- Market classification is ticker-suffix first, country_name fallback
- GLOBAL market always contains all non-peer stocks
- Summaries are generated once per market universe and inserted for every
  user who currently has at least one portfolio

STANDARDS:
- sys.path.insert BEFORE all project imports
- Uses get_connection() from utils.py
- No module-level DB calls
"""

from __future__ import annotations

import sys
import os
import json
import logging
import argparse
import concurrent.futures
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal
from statistics import median

from openai import OpenAI
from psycopg2.extras import RealDictCursor

sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger(__name__)

MODEL = "gpt-4o-mini"
GLOBAL_MARKET_NAME = "GLOBAL"
GLOBAL_MARKET_EXCHANGE = "ALL"

SUFFIX_MARKET_MAP = {
    ".AX": "Australia",
    ".HK": "China",
    ".KS": "South Korea",
    ".KQ": "South Korea",
    ".T": "Japan",
    ".DE": "Germany",
    ".ST": "Sweden",
    ".SW": "Switzerland",
    ".L": "United Kingdom",
    ".SS": "China",
    ".SZ": "China",
    ".TO": "Canada",
    ".V": "Canada",
    ".NE": "Canada",
    ".SA": "Brazil",
    ".MX": "Mexico",
    ".TA": "Israel",
    ".NS": "India",
    ".BO": "India",
    ".TW": "Taiwan",
    ".TWO": "Taiwan",
    ".SI": "Singapore",
    ".NZ": "New Zealand",
    ".OL": "Norway",
    ".CO": "Denmark",
    ".PA": "France",
    ".AS": "Netherlands",
    ".MI": "Italy",
    ".MC": "Spain",
    ".HE": "Finland",
    ".BR": "Belgium",
    ".LS": "Portugal",
    ".WA": "Poland",
    ".VI": "Austria",
    ".JK": "Indonesia",
    ".BK": "Thailand",
    ".KL": "Malaysia",
    ".VN": "Vietnam",
}

QUERIES = {
    "stock_details": """
        SELECT s.stock_id,
               s.ticker,
               s.company_name,
               s.sector,
               s.exchange,
               s.country_name,
               md.local_currency,
               md.price_local_curr AS last_price_local_curr,
               md.price_usd AS last_price_usd,
               md.day_price_change_local_curr,
               md.day_price_change_usd,
               md.day_price_change_pct,
               md.volume,
               md.volume_30d,
               sl.sentiment_score,
               sl.sentiment_label,
               sf.flag_type,
               sf.flag_description,
               md.price_date
        FROM ingest_db.stocks s
        LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON s.stock_id = md.stock_id
        LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON s.stock_id = sl.stock_id
        LEFT JOIN (
            SELECT DISTINCT ON (stock_id)
                   stock_id, flag_type, flag_description, created_at
            FROM semantic_db.vw_stocks_flags
            WHERE stock_id = ANY(%s)
            ORDER BY stock_id, created_at DESC
        ) sf ON s.stock_id = sf.stock_id
        WHERE s.stock_id = ANY(%s)
        ORDER BY s.stock_id
    """,
    "company_profile": """
        SELECT stock_id, stock_symbol, country, ceo, website, sector, industry,
               full_time_employees, description, beta, financial_score
        FROM semantic_db.vw_company_profile
        WHERE stock_id = ANY(%s)
    """,
    "price_latest": """
        SELECT stock_id, local_currency, price_local_curr, price_usd,
               opening_price_local_curr, closing_price_local_curr,
               day_price_change_pct, volume, volume_30d,
               market_cap_local_curr, market_cap_usd, price_date
        FROM semantic_db.vw_stocks_price_data_latest
        WHERE stock_id = ANY(%s)
    """,
    "revenue_annual": """
        SELECT DISTINCT stock_id, ticker, revenue, period_label
        FROM semantic_db.vw_stocks_revenue_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "revenue_quarterly": """
        SELECT DISTINCT stock_id, ticker, revenue, period_label
        FROM semantic_db.vw_stocks_revenue_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Quarterly'
        ORDER BY stock_id, period_label DESC
    """,
    "ebitda_annual": """
        SELECT DISTINCT stock_id, ticker, ebitda, period_label
        FROM semantic_db.vw_stocks_ebitda_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "eps_annual": """
        SELECT DISTINCT stock_id, ticker, eps, period_label
        FROM semantic_db.vw_stocks_eps_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "fcf_annual": """
        SELECT DISTINCT stock_id, ticker, free_cash_flow, period_label
        FROM semantic_db.vw_stocks_free_cash_flow_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "cash_debt": """
        SELECT stock_id, ticker, metric_type, metric_value, period_label
        FROM semantic_db.vw_stocks_cash_debt_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "return_of_capital": """
        SELECT stock_id, ticker, metric_type, return_of_capital, period_label
        FROM semantic_db.vw_stocks_return_of_capital_trend_analysis
        WHERE stock_id = ANY(%s) AND period_type = 'Annual'
        ORDER BY stock_id, period_label DESC
    """,
    "valuation": """
        SELECT stock_id, ticker, metric_type, metric_value
        FROM semantic_db.vw_stocks_fundamentals_valuation
        WHERE stock_id = ANY(%s)
    """,
    "indicators": """
        SELECT stock_id, ticker, indicator_name, value, recorded_at
        FROM semantic_db.vw_stocks_indicators
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, recorded_at DESC
    """,
    "flags": """
        SELECT stock_id, flag_type, flag_description, created_at
        FROM semantic_db.vw_stocks_flags
        WHERE stock_id = ANY(%s)
        ORDER BY created_at DESC
    """,
    "market_alerts": """
        SELECT stock_id, stock_symbol, alert_type, description, severity, alert_date, url
        FROM semantic_db.vw_stocks_market_alerts
        WHERE stock_id = ANY(%s)
        ORDER BY alert_date DESC
        LIMIT 100
    """,
    "events": """
        SELECT stock_id, event_type, event_description, expected_event_time
        FROM semantic_db.vw_stocks_upcoming_events
        WHERE stock_id = ANY(%s) AND expected_event_time >= CURRENT_DATE
        ORDER BY expected_event_time
    """,
    "earnings_outlook": """
        SELECT stock_id, ticker, period, num_estimates, avg_estimate,
               low_estimate, high_estimate, metric_type, recorded_at
        FROM semantic_db.vw_stocks_earnings_outlook
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, recorded_at DESC
    """,
    "sentiment": """
        SELECT stock_id, sentiment_score, sentiment_label, analysis_description,
               total_messages, positive_count, neutral_count, negative_count,
               sentiment_reasons
        FROM semantic_db.vw_stocks_sentiment_latest
        WHERE stock_id = ANY(%s)
    """,
    "driver_analysis": """
        SELECT stock_id, driver_name, analysis_text, impact_score, analysis_period
        FROM semantic_db.vw_stocks_driver_analysis
        WHERE stock_id = ANY(%s)
        ORDER BY stock_id, analyzed_date DESC
    """,
    "margin_growth": """
        SELECT stock_id, ticker, metric_type, metric_value
        FROM semantic_db.vw_stocks_fundamentals_margin_growth
        WHERE stock_id = ANY(%s)
    """,
    "price_history": """
        SELECT stock_id, price_date, closing_price_usd, price_usd
        FROM semantic_db.vw_stocks_price_data_history
        WHERE stock_id = ANY(%s)
          AND price_date >= CURRENT_DATE - INTERVAL '180 days'
        ORDER BY stock_id, price_date
    """,
}

SYSTEM_PROMPT = """You are a professional buy-side equity analyst writing a daily market brief for institutional investors.

Your analysis must be:
- Data-driven: reference specific numbers, percentages, and stock examples
- Comparative: explain which stocks are leading or lagging and why
- Balanced: present both opportunities and risks objectively
- Professional: use formal financial language, no marketing speak

Output format must be EXACTLY as specified."""

USER_PROMPT_TEMPLATE = """
Analyze this market universe and generate a structured brief.

MARKET DATA (JSON):
{market_json}

═══════════════════════════════════════════════════════════════════════════════
REQUIRED OUTPUT FORMAT - Follow this EXACTLY:
═══════════════════════════════════════════════════════════════════════════════

### — Market Qualities

**Market Leadership**
- [2-3 bullet points about leading stocks, stronger sectors, relative winners]

**Positive Momentum & Technical Signals**
- [2-3 bullet points about stocks with positive trends, above moving averages, constructive RSI]

**Strong Fundamentals**
- [2-3 bullet points about revenue growth, margins, cash flow, returns on capital]

**Valuation Support**
- [1-2 bullet points about attractively valued stocks or segments]

**Cross-Stock Patterns & Catalysts**
- [1-2 bullet points about common drivers, correlations, sentiment, alerts, upcoming events]

**Key Takeaway:** [One sentence summary of the market's strengths]

---

### — Market Risks

**Lagging Stocks & Technical Warnings**
- [2-3 bullet points about weaker stocks, negative momentum, or technical deterioration]

**Fundamental Concerns**
- [2-3 bullet points about slowing revenue, margin pressure, weak cash flow, leverage]

**Valuation Risks**
- [1-2 bullet points about expensive names or expectation risk]

**Balance Sheet & Liquidity Issues**
- [1-2 bullet points about debt, funding pressure, or fragile balance sheets]

**Correlation, Concentration & Macro Risks**
- [1-2 bullet points about sector concentration, common drivers, event clustering, macro sensitivity]

**Key Takeaway:** [One sentence summary of the market's main risks]

═══════════════════════════════════════════════════════════════════════════════
RULES:
1. Use ONLY the data provided - do NOT invent facts or numbers
2. Reference specific stock tickers when discussing individual names
3. Include actual numbers where available
4. Keep total response under 1500 words
5. Maintain professional, analytical tone throughout
6. Focus on the market universe, not user portfolios
"""


def decimal_to_float(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {k: decimal_to_float(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [decimal_to_float(i) for i in obj]
    if isinstance(obj, datetime):
        return obj.isoformat()
    return obj


def safe_query(cursor, query_name: str, query: str, params: tuple) -> list:
    try:
        cursor.execute(query, params)
        return [decimal_to_float(dict(row)) for row in cursor.fetchall()]
    except Exception as exc:
        log.warning("Query '%s' failed: %s", query_name, exc)
        cursor.connection.rollback()
        return []


def detect_suffix(ticker: str | None) -> str | None:
    if not ticker or "." not in ticker:
        return None
    return "." + ticker.rsplit(".", 1)[-1].upper()


def classify_market_name(ticker: str | None, country_name: str | None) -> str:
    suffix = detect_suffix(ticker)
    if suffix and suffix in SUFFIX_MARKET_MAP:
        return SUFFIX_MARKET_MAP[suffix]
    country = (country_name or "").strip()
    return country or "Unknown"


def get_non_peer_stocks() -> list[dict]:
    conn = get_connection()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    cursor.execute(
        """
        SELECT stock_id, ticker, company_name, country_name, exchange
        FROM ingest_db.stocks
        WHERE is_peer = false
        ORDER BY stock_id
        """
    )
    rows = [dict(row) for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return rows


def get_recipient_user_ids(user_id: int | None = None) -> list[int]:
    conn = get_connection()
    cursor = conn.cursor()
    if user_id is not None:
        cursor.execute(
            """
            SELECT DISTINCT p.user_id
            FROM ingest_db.portfolio p
            WHERE p.user_id = %s
            ORDER BY p.user_id
            """,
            (user_id,),
        )
    else:
        cursor.execute(
            """
            SELECT DISTINCT p.user_id
            FROM ingest_db.portfolio p
            ORDER BY p.user_id
            """
        )
    ids = [row[0] for row in cursor.fetchall()]
    cursor.close()
    conn.close()
    return ids


def sync_market_dimension() -> dict[int, dict]:
    stocks = get_non_peer_stocks()
    markets: dict[str, dict] = {}

    for stock in stocks:
        market_name = classify_market_name(stock.get("ticker"), stock.get("country_name"))
        market = markets.setdefault(
            market_name,
            {
                "market_name": market_name,
                "market_exchange_set": set(),
                "stock_ids": [],
            },
        )
        exchange = (stock.get("exchange") or "").strip()
        if exchange:
            market["market_exchange_set"].add(exchange)
        market["stock_ids"].append(stock["stock_id"])

    markets[GLOBAL_MARKET_NAME] = {
        "market_name": GLOBAL_MARKET_NAME,
        "market_exchange_set": {GLOBAL_MARKET_EXCHANGE},
        "stock_ids": [stock["stock_id"] for stock in stocks],
    }

    ordered = sorted(
        markets.values(),
        key=lambda item: (item["market_name"] != GLOBAL_MARKET_NAME, item["market_name"]),
    )

    conn = get_connection()
    conn.autocommit = True
    cursor = conn.cursor(cursor_factory=RealDictCursor)

    for market in ordered:
        market_exchange = ", ".join(sorted(market["market_exchange_set"])) or "Unknown"
        cursor.execute(
            """
            SELECT market_id
            FROM ingest_db.market
            WHERE market_name = %s
            ORDER BY market_id
            LIMIT 1
            """,
            (market["market_name"],),
        )
        existing = cursor.fetchone()
        if existing:
            cursor.execute(
                """
                UPDATE ingest_db.market
                SET market_exchange = %s
                WHERE market_id = %s
                """,
                (market_exchange, existing["market_id"]),
            )
            market_id = existing["market_id"]
        else:
            cursor.execute(
                """
                INSERT INTO ingest_db.market (market_name, market_exchange)
                VALUES (%s, %s)
                RETURNING market_id
                """,
                (market["market_name"], market_exchange),
            )
            market_id = cursor.fetchone()["market_id"]

        market["market_id"] = market_id
        market["market_exchange"] = market_exchange

    cursor.close()
    conn.close()

    return {market["market_id"]: market for market in ordered}


def get_market_map() -> dict[int, dict]:
    synced = sync_market_dimension()
    log.info("Synced %s markets into ingest_db.market", len(synced))
    return synced


def fetch_all_market_data(stock_ids: list[int]) -> dict:
    conn = get_connection()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    all_data = {}

    for query_name, query in QUERIES.items():
        if query_name == "stock_details":
            result = safe_query(cursor, query_name, query, (stock_ids, stock_ids))
        else:
            result = safe_query(cursor, query_name, query, (stock_ids,))
        all_data[query_name] = result
        log.info("  %s: %s rows", query_name, len(result))

    cursor.close()
    conn.close()
    return all_data


def calculate_market_correlations(price_history_rows: list[dict]) -> dict:
    grouped: dict[int, list[tuple]] = {}
    for row in price_history_rows:
        stock_id = row.get("stock_id")
        price_date = row.get("price_date")
        close_price = row.get("closing_price_usd") or row.get("price_usd")
        if stock_id is None or price_date is None or close_price in (None, 0):
            continue
        grouped.setdefault(stock_id, []).append((price_date, float(close_price)))

    returns_by_stock: dict[int, dict] = {}
    for stock_id, series in grouped.items():
        ordered = sorted(series, key=lambda item: item[0])
        if len(ordered) < 6:
            continue
        prev_close = None
        returns = {}
        for price_date, close_price in ordered:
            if prev_close and prev_close != 0:
                returns[price_date] = (close_price / prev_close) - 1.0
            prev_close = close_price
        if len(returns) >= 5:
            returns_by_stock[stock_id] = returns

    stock_ids = sorted(returns_by_stock.keys())
    if len(stock_ids) < 2:
        return {"pair_count": 0, "leaders": [], "laggards": []}

    def pearson(values_a: list[float], values_b: list[float]) -> float | None:
        n = len(values_a)
        if n < 5:
            return None
        mean_a = sum(values_a) / n
        mean_b = sum(values_b) / n
        cov = sum((a - mean_a) * (b - mean_b) for a, b in zip(values_a, values_b))
        var_a = sum((a - mean_a) ** 2 for a in values_a)
        var_b = sum((b - mean_b) ** 2 for b in values_b)
        if var_a <= 0 or var_b <= 0:
            return None
        return cov / (var_a ** 0.5 * var_b ** 0.5)

    pairs = []
    for index, stock_a in enumerate(stock_ids):
        for stock_b in stock_ids[index + 1:]:
            common_dates = sorted(set(returns_by_stock[stock_a]) & set(returns_by_stock[stock_b]))
            if len(common_dates) < 5:
                continue
            values_a = [returns_by_stock[stock_a][date] for date in common_dates]
            values_b = [returns_by_stock[stock_b][date] for date in common_dates]
            corr = pearson(values_a, values_b)
            if corr is None:
                continue
            pairs.append(
                {
                    "stock_id_a": stock_a,
                    "stock_id_b": stock_b,
                    "correlation": round(corr, 3),
                    "observations": len(common_dates),
                }
            )

    pairs_sorted = sorted(pairs, key=lambda item: item["correlation"], reverse=True)
    negative_sorted = sorted(pairs, key=lambda item: item["correlation"])

    return {
        "pair_count": len(pairs),
        "leaders": pairs_sorted[:3],
        "laggards": [pair for pair in negative_sorted[:3] if pair["correlation"] < 0],
    }


def build_market_object(raw_data: dict, stock_ids: list[int], market_info: dict) -> dict:
    stock_details = {row["stock_id"]: row for row in raw_data.get("stock_details", [])}
    company_profile = {row["stock_id"]: row for row in raw_data.get("company_profile", [])}
    price_latest = {row["stock_id"]: row for row in raw_data.get("price_latest", [])}
    sentiment = {row["stock_id"]: row for row in raw_data.get("sentiment", [])}

    def group_by_stock(data: list[dict]) -> dict[int, list[dict]]:
        grouped: dict[int, list[dict]] = {}
        for row in data:
            stock_id = row.get("stock_id")
            grouped.setdefault(stock_id, []).append(row)
        return grouped

    revenue_annual = group_by_stock(raw_data.get("revenue_annual", []))
    revenue_quarterly = group_by_stock(raw_data.get("revenue_quarterly", []))
    ebitda_annual = group_by_stock(raw_data.get("ebitda_annual", []))
    eps_annual = group_by_stock(raw_data.get("eps_annual", []))
    fcf_annual = group_by_stock(raw_data.get("fcf_annual", []))
    cash_debt = group_by_stock(raw_data.get("cash_debt", []))
    return_of_capital = group_by_stock(raw_data.get("return_of_capital", []))
    valuation = group_by_stock(raw_data.get("valuation", []))
    indicators = group_by_stock(raw_data.get("indicators", []))
    margin_growth = group_by_stock(raw_data.get("margin_growth", []))
    flags = group_by_stock(raw_data.get("flags", []))
    alerts = group_by_stock(raw_data.get("market_alerts", []))
    events = group_by_stock(raw_data.get("events", []))
    earnings = group_by_stock(raw_data.get("earnings_outlook", []))
    drivers = group_by_stock(raw_data.get("driver_analysis", []))

    def get_indicators_dict(grouped: dict[int, list[dict]], stock_id: int) -> dict:
        return {item.get("indicator_name"): item.get("value") for item in grouped.get(stock_id, [])}

    def get_metrics_dict(grouped: dict[int, list[dict]], stock_id: int, value_key: str = "metric_value") -> dict:
        return {item.get("metric_type"): item.get(value_key) for item in grouped.get(stock_id, [])}

    market = {
        "report_date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "market_id": market_info["market_id"],
        "market_name": market_info["market_name"],
        "market_exchange": market_info["market_exchange"],
        "total_stocks": len(stock_ids),
        "stocks": [],
    }

    sectors: dict[str, int] = {}
    sentiments = []
    positive_day_change = 0
    negative_day_change = 0
    market_caps = []
    countries: dict[str, int] = {}

    for stock_id in stock_ids:
        sd = stock_details.get(stock_id, {})
        cp = company_profile.get(stock_id, {})
        pl = price_latest.get(stock_id, {})
        sent = sentiment.get(stock_id, {})

        rev_hist = revenue_annual.get(stock_id, [])[:3]
        rev_q_hist = revenue_quarterly.get(stock_id, [])[:4]
        ebitda_hist = ebitda_annual.get(stock_id, [])[:3]
        eps_hist = eps_annual.get(stock_id, [])[:3]
        fcf_hist = fcf_annual.get(stock_id, [])[:3]

        ind = get_indicators_dict(indicators, stock_id)
        val = get_metrics_dict(valuation, stock_id)
        margins = get_metrics_dict(margin_growth, stock_id)

        cash_metrics = {}
        for item in cash_debt.get(stock_id, []):
            metric_type = item.get("metric_type")
            if metric_type not in cash_metrics:
                cash_metrics[metric_type] = item.get("metric_value")

        roc_metrics = {}
        for item in return_of_capital.get(stock_id, []):
            metric_type = item.get("metric_type")
            if metric_type not in roc_metrics:
                roc_metrics[metric_type] = item.get("return_of_capital")

        ticker = sd.get("ticker", f"STOCK_{stock_id}")
        sector = sd.get("sector") or cp.get("sector") or "Unknown"
        country = cp.get("country") or sd.get("country_name") or "Unknown"

        stock_obj = {
            "stock_id": stock_id,
            "ticker": ticker,
            "name": sd.get("company_name", ""),
            "sector": sector,
            "industry": cp.get("industry", ""),
            "country": country,
            "exchange": sd.get("exchange"),
            "currency": sd.get("local_currency") or pl.get("local_currency", ""),
            "description": (cp.get("description", "") or "")[:200],
            "price": {
                "current": sd.get("last_price_local_curr"),
                "current_usd": sd.get("last_price_usd"),
                "change_1d_pct": sd.get("day_price_change_pct"),
                "volume": sd.get("volume"),
                "volume_30d_avg": sd.get("volume_30d"),
                "price_date": str(sd.get("price_date")) if sd.get("price_date") else None,
            },
            "technicals": {
                "rsi_14": ind.get("RSI_14") or ind.get("RSI"),
                "macd": ind.get("MACD"),
                "sma_50": ind.get("SMA_50"),
                "sma_200": ind.get("SMA_200"),
                "beta": cp.get("beta"),
            },
            "valuation": {
                "pe_ratio": val.get("P/E Ratio"),
                "pb_ratio": val.get("P/B Ratio"),
                "ps_ratio": val.get("P/S Ratio"),
                "ev_ebitda": val.get("EV/EBITDA"),
                "market_cap": pl.get("market_cap_usd"),
            },
            "revenue": {
                "latest_annual": rev_hist[0].get("revenue") if rev_hist else None,
                "latest_period": rev_hist[0].get("period_label") if rev_hist else None,
                "history": [{"period": row.get("period_label"), "value": row.get("revenue")} for row in rev_hist],
                "latest_quarterly": rev_q_hist[0].get("revenue") if rev_q_hist else None,
            },
            "profitability": {
                "ebitda_latest": ebitda_hist[0].get("ebitda") if ebitda_hist else None,
                "eps_latest": eps_hist[0].get("eps") if eps_hist else None,
                "gross_margin": margins.get("Gross Margin"),
                "operating_margin": margins.get("Operating Margin"),
                "net_margin": margins.get("Net Margin"),
            },
            "cash_flow": {
                "fcf_latest": fcf_hist[0].get("free_cash_flow") if fcf_hist else None,
                "fcf_history": [{"period": row.get("period_label"), "value": row.get("free_cash_flow")} for row in fcf_hist],
            },
            "balance_sheet": {
                "cash": cash_metrics.get("Cash"),
                "total_debt": cash_metrics.get("Total Debt"),
                "net_debt": cash_metrics.get("Net Debt"),
            },
            "returns": {
                "roe": roc_metrics.get("ROE"),
                "roa": roc_metrics.get("ROA"),
                "roic": roc_metrics.get("ROIC"),
            },
            "sentiment": {
                "score": sent.get("sentiment_score"),
                "label": sent.get("sentiment_label"),
                "total_messages": sent.get("total_messages"),
            },
            "current_flag": {
                "type": sd.get("flag_type"),
                "description": sd.get("flag_description"),
            },
            "flags": [{"type": row.get("flag_type"), "description": row.get("flag_description")} for row in flags.get(stock_id, [])[:5]],
            "alerts": [{"type": row.get("alert_type"), "message": (row.get("description", "") or "")[:150], "severity": row.get("severity"), "date": str(row.get("alert_date")) if row.get("alert_date") else None} for row in alerts.get(stock_id, [])[:5]],
            "upcoming_events": [{"type": row.get("event_type"), "description": (row.get("event_description", "") or "")[:100], "date": str(row.get("expected_event_time")) if row.get("expected_event_time") else None} for row in events.get(stock_id, [])[:3]],
            "earnings_outlook": {
                "estimates": [{"period": row.get("period"), "metric": row.get("metric_type"), "avg_estimate": row.get("avg_estimate"), "num_analysts": row.get("num_estimates")} for row in earnings.get(stock_id, [])[:4]]
            },
            "drivers": [{"name": row.get("driver_name"), "analysis": (row.get("analysis_text", "") or "")[:200], "impact_score": row.get("impact_score")} for row in drivers.get(stock_id, [])[:3]],
        }
        market["stocks"].append(stock_obj)

        sectors[sector] = sectors.get(sector, 0) + 1
        countries[country] = countries.get(country, 0) + 1

        sentiment_score = sent.get("sentiment_score")
        if sentiment_score is not None:
            sentiments.append(float(sentiment_score))

        day_change = sd.get("day_price_change_pct")
        if day_change is not None:
            if float(day_change) > 0:
                positive_day_change += 1
            elif float(day_change) < 0:
                negative_day_change += 1

        market_cap = pl.get("market_cap_usd")
        if market_cap is not None:
            market_caps.append(float(market_cap))

    correlations = calculate_market_correlations(raw_data.get("price_history", []))
    ticker_lookup = {stock["stock_id"]: stock["ticker"] for stock in market["stocks"]}
    for key in ("leaders", "laggards"):
        enriched = []
        for pair in correlations.get(key, []):
            enriched.append(
                {
                    "ticker_a": ticker_lookup.get(pair["stock_id_a"], str(pair["stock_id_a"])),
                    "ticker_b": ticker_lookup.get(pair["stock_id_b"], str(pair["stock_id_b"])),
                    "correlation": pair["correlation"],
                    "observations": pair["observations"],
                }
            )
        correlations[key] = enriched

    average_sentiment = round(sum(sentiments) / len(sentiments), 2) if sentiments else None
    market["market_summary"] = {
        "average_sentiment_score": average_sentiment,
        "stocks_up_today": positive_day_change,
        "stocks_down_today": negative_day_change,
        "sector_mix": dict(sorted(sectors.items(), key=lambda item: (-item[1], item[0]))),
        "country_mix": dict(sorted(countries.items(), key=lambda item: (-item[1], item[0]))),
        "market_cap_total_usd": round(sum(market_caps), 2) if market_caps else None,
        "market_cap_median_usd": round(median(market_caps), 2) if market_caps else None,
        "correlations": correlations,
    }

    return market


def generate_ai_summary(market: dict) -> str:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    client = OpenAI(api_key=api_key)
    market_json = json.dumps(market, indent=2, default=str)
    user_prompt = USER_PROMPT_TEMPLATE.format(market_json=market_json)
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.3,
        max_tokens=3000,
    )
    return response.choices[0].message.content


def split_sections(text: str):
    quality_markers = ["Market Qualities", "— Market Qualities"]
    risk_markers = ["Market Risks", "— Market Risks"]

    quality_start = next((text.find(marker) for marker in quality_markers if text.find(marker) != -1), -1)
    risk_start = next((text.find(marker) for marker in risk_markers if text.find(marker) != -1), -1)
    if quality_start == -1 or risk_start == -1:
        raise ValueError("Could not find Quality/Risk sections in AI output")

    quality_text = text[quality_start:risk_start].strip()
    risk_text = text[risk_start:].strip()

    for marker in quality_markers:
        quality_text = quality_text.replace(f"### {marker}", "").replace(marker, "").strip()
    for marker in risk_markers:
        risk_text = risk_text.replace(f"### {marker}", "").replace(marker, "").strip()

    return quality_text.lstrip("-").strip(), risk_text.lstrip("-").strip()


def insert_to_database(
    quality_text: str,
    risk_text: str,
    market_id: int,
    user_ids: list[int],
    dry_run: bool = False,
):
    if dry_run:
        log.info("[DRY RUN] Market %s — Quality preview: %s", market_id, quality_text[:300])
        log.info("[DRY RUN] Market %s — Risk preview: %s", market_id, risk_text[:300])
        return

    conn = get_connection()
    conn.autocommit = True
    cursor = conn.cursor()

    try:
        for user_id in user_ids:
            cursor.execute(
                """
                DELETE FROM transform_db.market_summary
                WHERE market_id = %s
                  AND user_id = %s
                  AND analysis_category IN ('Quality', 'Risk')
                  AND DATE(created_at) = CURRENT_DATE
                """,
                (market_id, user_id),
            )
            cursor.execute(
                """
                INSERT INTO transform_db.market_summary
                (market_id, analysis_category, analysis_text, generated_by, user_id)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (market_id, "Quality", quality_text, MODEL, user_id),
            )
            cursor.execute(
                """
                INSERT INTO transform_db.market_summary
                (market_id, analysis_category, analysis_text, generated_by, user_id)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (market_id, "Risk", risk_text, MODEL, user_id),
            )
        log.info("Market %s AI analysis saved for %s users", market_id, len(user_ids))
    finally:
        cursor.close()
        conn.close()


def process_single_market(market_info: dict, recipient_user_ids: list[int], args) -> bool:
    market_id = market_info["market_id"]
    stock_ids = sorted(market_info["stock_ids"])

    if not stock_ids:
        log.warning("Market %s has no non-peer stocks, skipping", market_info["market_name"])
        return False

    log.info("-" * 40)
    log.info("Processing market_id=%s market_name=%s with %s stocks", market_id, market_info["market_name"], len(stock_ids))

    raw_data = fetch_all_market_data(stock_ids)
    market_payload = build_market_object(raw_data, stock_ids, market_info)

    if args.save_json and not getattr(args, "_saved_json_once", False):
        with open(args.save_json, "w") as handle:
            json.dump(market_payload, handle, indent=2, default=str)
        args._saved_json_once = True
        log.info("Saved market data to %s", args.save_json)

    summary_text = generate_ai_summary(market_payload)
    quality_text, risk_text = split_sections(summary_text)
    insert_to_database(quality_text, risk_text, market_id, recipient_user_ids, dry_run=args.dry_run)
    return True


def main():
    parser = argparse.ArgumentParser(description="Generate AI Market Summary (per-market)")
    parser.add_argument("--dry-run", action="store_true", help="Preview without inserting")
    parser.add_argument("--save-json", type=str, help="Save first processed market payload to JSON")
    parser.add_argument("--market-id", type=int, help="Process only this market_id")
    parser.add_argument("--user-id", type=int, help="Insert only for this user_id if they have a portfolio")
    args = parser.parse_args()

    log.info("=" * 60)
    log.info("FETCHING: AI Market Summary (Concurrent per-market)")
    log.info("=" * 60)

    market_map = get_market_map()
    if args.market_id:
        if args.market_id not in market_map:
            raise ValueError(f"Unknown market_id: {args.market_id}")
        markets = [market_map[args.market_id]]
    else:
        markets = list(market_map.values())

    recipient_user_ids = get_recipient_user_ids(args.user_id)
    if not recipient_user_ids:
        log.warning("No eligible recipient users found, nothing to do")
        return {"status": "success", "markets_processed": 0, "users": 0}

    args._saved_json_once = False
    processed = 0
    max_workers = min(5, len(markets)) or 1

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {
            executor.submit(process_single_market, market_info, recipient_user_ids, args): market_info
            for market_info in markets
        }
        for future in concurrent.futures.as_completed(futures):
            market_info = futures[future]
            try:
                if future.result():
                    processed += 1
            except Exception as exc:
                log.error("Market %s failed: %s", market_info["market_name"], exc, exc_info=True)

    log.info("=" * 60)
    log.info("COMPLETED: AI Market Summary — %s/%s markets processed", processed, len(markets))
    log.info("=" * 60)
    return {"status": "success", "markets_processed": processed, "users": len(recipient_user_ids)}


def lambda_handler(event, context):
    market_id = event.get("market_id")
    user_id = event.get("user_id")
    job_id = event.get("job_id")

    sys.argv = ["fetch_ai_summary_market.py"]
    if market_id:
        sys.argv.extend(["--market-id", str(market_id)])
    if user_id:
        sys.argv.extend(["--user-id", str(user_id)])
    if event.get("dry_run"):
        sys.argv.append("--dry-run")

    if job_id:
        os.environ["JOB_ID"] = str(job_id)

    result = main()
    return {
        **(result or {}),
        "market_id": market_id,
        "user_id": user_id,
        "job_id": job_id,
    }


if __name__ == "__main__":
    main()
