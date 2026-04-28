"""
Fetch forex rates from FMP API
Populates: forex_rates table
"""
import sys
from pathlib import Path
import time
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request, smart_batch_insert
from config import DATA_FETCH_CONFIG


def fetch_forex_rate(pair):
    """Fetch forex rate for a currency pair."""
    try:
        data = fmp_request(f"/stable/fx", {'symbol': pair})
        return data[0] if data and len(data) > 0 else None
    except Exception as e:
        print(f"      Error fetching {pair}: {e}")
        return None


def fetch_all_forex_rates():
    """Fetch forex rates for all required currency pairs."""
    # Currency pairs to fetch (all to USD)
    forex_pairs = [
        ('HKD', 'USD', 'HKDUSD'),
        ('KRW', 'USD', 'KRWUSD'),
        ('JPY', 'USD', 'JPYUSD'),
        ('EUR', 'USD', 'EURUSD'),
        ('SEK', 'USD', 'SEKUSD'),
        ('CHF', 'USD', 'CHFUSD')
    ]

    forex_data = []

    print(f"\nFetching forex rates for {len(forex_pairs)} currency pairs...")

    for source_currency, target_currency, pair in forex_pairs:
        try:
            print(f"  Fetching {pair}...")
            rate_data = fetch_forex_rate(pair)

            if rate_data:
                # Use bid price as the exchange rate
                exchange_rate = rate_data.get('bid', rate_data.get('ask', 0))

                # Parse date
                rate_date = rate_data.get('date', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))

                forex_data.append((
                    source_currency,
                    target_currency,
                    exchange_rate,
                    rate_date
                ))

                print(f"    ✓ Rate: {exchange_rate}")
            else:
                print(f"    ✗ No data found for {pair}")

            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

        except Exception as e:
            print(f"    ✗ Error fetching {pair}: {e}")
            continue

    return forex_data


def main():
    """Main fetch function."""
    print("\n" + "=" * 60)
    print("FETCHING: Forex Rates from FMP")
    print("=" * 60)

    # Fetch
    print("\n[1/2] Fetching forex rates from FMP API...")
    forex_data = fetch_all_forex_rates()

    if not forex_data:
        print("No forex data fetched. Exiting.")
        return

    # Load
    print("\n[2/2] Loading to SQLite...")
    columns = ['source_currency', 'target_currency', 'exchange_rate', 'rate_date']
    inserted = smart_batch_insert('forex_rates', columns, forex_data)

    # Summary
    print("\nSummary:")
    print(f"  Forex rates inserted: {inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
