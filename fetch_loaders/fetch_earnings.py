"""
Fetch earnings data from FMP API
Populates: stocks_earnings_calendar, stocks_upcoming_earnings tables
"""
import sys
from pathlib import Path
import time
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request, smart_batch_insert, get_connection
from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG


def fetch_historical_earnings(ticker):
    """Fetch historical earnings calendar for a stock."""
    try:
        data = fmp_request(f"/stable/historical/earning_calendar", {'symbol': ticker})
        return data if data else []
    except Exception as e:
        print(f"      Error fetching earnings: {e}")
        return []


def fetch_analyst_estimates(ticker):
    """Fetch analyst estimates for future earnings."""
    try:
        data = fmp_request(f"/stable/analyst-estimates", {'symbol': ticker, 'period': 'annual', 'limit': 4})
        return data if data else []
    except Exception as e:
        print(f"      Error fetching estimates: {e}")
        return []


def fetch_all_earnings():
    """Fetch earnings data for all stocks."""
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

    earnings_calendar = []
    upcoming_earnings = []

    print(f"\nFetching earnings data for {len(tickers)} stocks...")

    for ticker in tickers:
        if ticker not in stock_map:
            continue

        stock_id, currency = stock_map[ticker]
        print(f"  Fetching {ticker}...")

        try:
            # Fetch historical earnings
            historical = fetch_historical_earnings(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            for earning in historical:
                earnings_calendar.append((
                    stock_id,
                    ticker,
                    earning.get('date'),
                    earning.get('epsEstimated'),
                    earning.get('eps'),
                    currency
                ))

            print(f"    ✓ Historical earnings: {len(historical)}")

            # Fetch analyst estimates (future earnings)
            estimates = fetch_analyst_estimates(ticker)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            for estimate in estimates:
                # Get market cap from profile if available
                market_cap = estimate.get('marketCap', 0)

                upcoming_earnings.append((
                    stock_id,
                    ticker,
                    market_cap,
                    estimate.get('date'),
                    estimate.get('estimatedEpsAvg'),
                    None,  # actual_eps (future, so NULL)
                    currency
                ))

            print(f"    ✓ Analyst estimates: {len(estimates)}")

        except Exception as e:
            print(f"    ✗ Error fetching {ticker}: {e}")
            continue

    return earnings_calendar, upcoming_earnings


def main():
    """Main fetch function."""
    print("\n" + "=" * 60)
    print("FETCHING: Earnings Data from FMP")
    print("=" * 60)

    # Fetch
    print("\n[1/3] Fetching earnings data from FMP API...")
    earnings_calendar, upcoming_earnings = fetch_all_earnings()

    # Load earnings calendar
    print("\n[2/3] Loading stocks_earnings_calendar...")
    if earnings_calendar:
        columns = ['stock_id', 'ticker', 'earnings_date', 'estimated_eps', 'actual_eps', 'currency_code']
        calendar_inserted = smart_batch_insert('stocks_earnings_calendar', columns, earnings_calendar)
    else:
        print("  No historical earnings data to load")
        calendar_inserted = 0

    # Load upcoming earnings
    print("\n[3/3] Loading stocks_upcoming_earnings...")
    if upcoming_earnings:
        columns = ['stock_id', 'ticker', 'market_cap', 'earnings_date', 'estimated_eps', 'actual_eps', 'currency_code']
        upcoming_inserted = smart_batch_insert('stocks_upcoming_earnings', columns, upcoming_earnings)
    else:
        print("  No upcoming earnings data to load")
        upcoming_inserted = 0

    # Summary
    print("\nSummary:")
    print(f"  Earnings calendar records inserted: {calendar_inserted}")
    print(f"  Upcoming earnings records inserted: {upcoming_inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
