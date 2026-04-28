"""
Fetch stock fundamentals data from FMP API
Populates: stocks_fundamentals table
Uses EAV (Entity-Attribute-Value) model to store various metrics
"""
import sys
from pathlib import Path
import time

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request, smart_batch_insert, get_connection
from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG


def fetch_ratios_ttm(ticker):
    """Fetch TTM ratios for a stock."""
    try:
        data = fmp_request(f"/stable/ratios-ttm", {'symbol': ticker})
        return data[0] if data and len(data) > 0 else {}
    except Exception as e:
        print(f"      Error fetching ratios: {e}")
        return {}


def fetch_key_metrics_ttm(ticker):
    """Fetch TTM key metrics for a stock."""
    try:
        data = fmp_request(f"/stable/key-metrics-ttm", {'symbol': ticker})
        return data[0] if data and len(data) > 0 else {}
    except Exception as e:
        print(f"      Error fetching key metrics: {e}")
        return {}


def fetch_income_statement(ticker):
    """Fetch annual income statements (last 5 years)."""
    try:
        data = fmp_request(f"/stable/income-statement", {'symbol': ticker, 'period': 'annual', 'limit': 5})
        return data if data else []
    except Exception as e:
        print(f"      Error fetching income statement: {e}")
        return []


def fetch_balance_sheet(ticker):
    """Fetch annual balance sheets (last 5 years)."""
    try:
        data = fmp_request(f"/stable/balance-sheet-statement", {'symbol': ticker, 'period': 'annual', 'limit': 5})
        return data if data else []
    except Exception as e:
        print(f"      Error fetching balance sheet: {e}")
        return []


def fetch_cash_flow(ticker):
    """Fetch annual cash flow statements (last 5 years)."""
    try:
        data = fmp_request(f"/stable/cash-flow-statement", {'symbol': ticker, 'period': 'annual', 'limit': 5})
        return data if data else []
    except Exception as e:
        print(f"      Error fetching cash flow: {e}")
        return []


def extract_metrics_from_ratios(ratios, fiscal_date='TTM'):
    """Extract key metrics from ratios data."""
    metrics = []

    metric_fields = [
        'priceToSalesRatioTTM', 'priceToBookRatioTTM', 'priceEarningsRatioTTM',
        'returnOnEquityTTM', 'returnOnAssetsTTM', 'debtRatioTTM',
        'currentRatioTTM', 'quickRatioTTM', 'cashRatioTTM',
        'grossProfitMarginTTM', 'operatingProfitMarginTTM', 'netProfitMarginTTM'
    ]

    for field in metric_fields:
        if field in ratios and ratios[field] is not None:
            metrics.append((field, ratios[field], fiscal_date))

    return metrics


def extract_metrics_from_key_metrics(key_metrics, fiscal_date='TTM'):
    """Extract key metrics from key metrics data."""
    metrics = []

    metric_fields = [
        'marketCapTTM', 'peRatioTTM', 'priceToSalesRatioTTM',
        'enterpriseValueTTM', 'evToSalesTTM', 'evToEbitdaTTM',
        'freeCashFlowPerShareTTM', 'freeCashFlowYieldTTM',
        'dividendYieldTTM', 'payoutRatioTTM'
    ]

    for field in metric_fields:
        if field in key_metrics and key_metrics[field] is not None:
            metrics.append((field, key_metrics[field], fiscal_date))

    return metrics


def extract_metrics_from_income(income_data):
    """Extract metrics from income statements."""
    metrics = []

    metric_fields = [
        'revenue', 'costOfRevenue', 'grossProfit', 'operatingIncome',
        'netIncome', 'ebitda', 'eps', 'epsdiluted'
    ]

    for statement in income_data:
        fiscal_date = statement.get('date', statement.get('calendarYear'))
        for field in metric_fields:
            if field in statement and statement[field] is not None:
                metrics.append((field, statement[field], fiscal_date))

    return metrics


def extract_metrics_from_balance(balance_data):
    """Extract metrics from balance sheets."""
    metrics = []

    metric_fields = [
        'cashAndCashEquivalents', 'totalAssets', 'totalLiabilities',
        'totalDebt', 'totalEquity', 'totalCurrentAssets', 'totalCurrentLiabilities'
    ]

    for statement in balance_data:
        fiscal_date = statement.get('date', statement.get('calendarYear'))
        for field in metric_fields:
            if field in statement and statement[field] is not None:
                metrics.append((field, statement[field], fiscal_date))

    return metrics


def extract_metrics_from_cashflow(cashflow_data):
    """Extract metrics from cash flow statements."""
    metrics = []

    metric_fields = [
        'operatingCashFlow', 'capitalExpenditure', 'freeCashFlow',
        'dividendsPaid', 'netCashProvidedByOperatingActivities'
    ]

    for statement in cashflow_data:
        fiscal_date = statement.get('date', statement.get('calendarYear'))
        for field in metric_fields:
            if field in statement and statement[field] is not None:
                metrics.append((field, statement[field], fiscal_date))

    return metrics


def fetch_all_fundamentals():
    """Fetch all fundamental data for all stocks."""
    tickers = list(set(TICKER_MAPPINGS.values()))

    # Get stock mapping
    conn = get_connection()
    cur = conn.cursor()

    from config import USE_RDS_DIRECT
    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker, currency_code FROM ingest_db.stocks")
    else:
        cur.execute("SELECT stock_id, ticker, currency_code FROM stocks")

    stock_map = {ticker: (stock_id, currency) for stock_id, ticker, currency in cur.fetchall()}
    conn.close()

    all_fundamentals = []

    print(f"\nFetching fundamentals for {len(tickers)} stocks...")

    for ticker in tickers:
        if ticker not in stock_map:
            continue

        stock_id, currency = stock_map[ticker]
        print(f"  Fetching {ticker}...")

        try:
            # Fetch all data types
            ratios = fetch_ratios_ttm(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            key_metrics = fetch_key_metrics_ttm(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            income = fetch_income_statement(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            balance = fetch_balance_sheet(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            cashflow = fetch_cash_flow(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            # Extract metrics
            metrics = []
            metrics.extend(extract_metrics_from_ratios(ratios))
            metrics.extend(extract_metrics_from_key_metrics(key_metrics))
            metrics.extend(extract_metrics_from_income(income))
            metrics.extend(extract_metrics_from_balance(balance))
            metrics.extend(extract_metrics_from_cashflow(cashflow))

            # Add stock_id and currency to each metric
            for metric_name, metric_value, fiscal_date in metrics:
                all_fundamentals.append((
                    stock_id,
                    fiscal_date,
                    metric_name,
                    metric_value,
                    currency
                ))

            print(f"    ✓ Extracted {len(metrics)} metrics")

        except Exception as e:
            print(f"    ✗ Error fetching {ticker}: {e}")
            continue

    return all_fundamentals


def main():
    """Main fetch function."""
    print("\n" + "=" * 60)
    print("FETCHING: Stock Fundamentals from FMP")
    print("=" * 60)

    # Fetch
    print("\n[1/2] Fetching fundamental data from FMP API...")
    fundamentals_data = fetch_all_fundamentals()

    if not fundamentals_data:
        print("No fundamental data fetched. Exiting.")
        return

    # Load using consistent schema
    print("\n[2/2] Loading to database...")
    columns = ['stock_id', 'fiscal_date', 'metric_name', 'metric_value', 'currency_code']
    inserted = smart_batch_insert('stocks_fundamentals', columns, fundamentals_data)

    # Summary
    print("\nSummary:")
    print(f"  Fundamental metrics inserted: {inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
