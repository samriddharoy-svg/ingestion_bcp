# -*- coding: utf-8 -*-
"""
Correlation Matrix Calculator
==============================
Calculates 5x5 correlation matrix for each stock vs its related entities:
- Stock itself
- Peer stock
- Benchmark index
- Forex pair A
- Forex pair B

Uses 1 year of daily closing price returns (Pearson correlation on daily % returns).
Excludes current day - uses data up to previous trading day.

Usage:
    python correlation_matrix.py              # Normal run (inserts to DB)
    python correlation_matrix.py --dry-run    # Preview only, no DB insert
    python correlation_matrix.py --stock 1    # Run for specific stock_id only
"""

import requests
import yfinance as yf
import pandas as pd
import numpy as np
import psycopg2
from psycopg2.extras import execute_batch
from datetime import datetime, timedelta
import argparse
import warnings

warnings.filterwarnings('ignore')

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

# from config import AWS_RDS, FMP_API_KEY, FMP_BASE_URL


# ✅ IMPORT FROM YOUR CONFIG
from config import AWS_RDS, FMP_API_KEY, FMP_BASE_URL
FMP_BASE_URL = "https://financialmodelingprep.com/stable/historical-price-eod/full"

# -------------------------------------------------------
# DB CONFIG from config.py
# -------------------------------------------------------
DB_CONFIG = {
    'host': AWS_RDS['host'],
    'port': AWS_RDS['port'],
    'database': AWS_RDS['database'],
    'user': AWS_RDS['user'],
    'password': AWS_RDS['password'],
    'sslmode': AWS_RDS['sslmode']
}

LOOKBACK_DAYS = 365


def fetch_stock_config_from_db():
    """
    Build STOCK_CONFIG dynamically from DB for ALL non-peer stocks.
    Joins stock_peers for peer ticker and stocks_benchmark_mapping + instruments
    for benchmark symbol. Derives forex pairs from currency_code.
    Falls back to _FALLBACK_STOCK_CONFIG on DB error.
    """
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        cur.execute("""
            SELECT
                s.stock_id,
                s.ticker,
                s.currency_code,
                sp.peer_symbol,
                i.instrument_code AS benchmark_code
            FROM ingest_db.stocks s
            LEFT JOIN (
                SELECT DISTINCT ON (stock_id) stock_id, peer_symbol
                FROM ingest_db.stock_peers
                ORDER BY stock_id, id
            ) sp ON s.stock_id = sp.stock_id
            LEFT JOIN ingest_db.stocks_benchmark_mapping sbm
                ON s.stock_id = sbm.stock_id AND sbm.ranking_order = 1
            LEFT JOIN ingest_db.instruments i
                ON sbm.instrument_id = i.instrument_id
            WHERE s.is_peer = false
            ORDER BY s.stock_id
        """)

        rows = cur.fetchall()
        cur.close()
        conn.close()

        stock_config = {}
        for stock_id, ticker, currency_code, peer_symbol, benchmark_code in rows:
            ticker = ticker.strip()
            currency = (currency_code or 'USD').strip().upper()

            if currency != 'USD':
                forex_a = f"{currency}USD"
                forex_b = f"USD{currency}"
            else:
                forex_a = ''
                forex_b = ''

            benchmark_display = benchmark_code.lstrip('^') if benchmark_code else ''

            stock_config[stock_id] = {
                'stock_id': stock_id,
                'ticker': ticker,
                'display_ticker': ticker,
                'peer': peer_symbol or '',
                'peer_display': peer_symbol or '',
                'benchmark': benchmark_code or '',
                'benchmark_display': benchmark_display,
                'forex_a': forex_a,
                'forex_a_display': forex_a,
                'forex_b': forex_b,
                'forex_b_display': forex_b,
                'source': 'fmp',
            }

        print(f"[DB] Loaded {len(stock_config)} stocks for correlation matrix")
        return stock_config

    except Exception as e:
        print(f"[DB] Warning: Could not fetch stock config: {e}")
        print("[DB] Falling back to hardcoded config")
        return _FALLBACK_STOCK_CONFIG


_FALLBACK_STOCK_CONFIG = {
    1: {
        'stock_id': 1,
        'ticker': '0853.HK',
        'display_ticker': '0853.HK',
        'peer': 'MDT',
        'peer_display': 'MDT',
        'benchmark': '^HSI',
        'benchmark_display': 'HSI',
        'forex_a': 'HKDUSD',
        'forex_a_display': 'HKDUSD',
        'forex_b': 'USDHKD',
        'forex_b_display': 'USDHKD',
        'source': 'fmp'
    },
    2: {
        'stock_id': 2,
        'ticker': '6887.HK',
        'display_ticker': '6887.HK',
        'peer': '1093.HK',
        'peer_display': '1093.HK',
        'benchmark': '^HSI',
        'benchmark_display': 'HSI',
        'forex_a': 'HKDUSD',
        'forex_a_display': 'HKDUSD',
        'forex_b': 'USDHKD',
        'forex_b_display': 'USDHKD',
        'source': 'yfinance'
    },
    3: {
        'stock_id': 3,
        'ticker': '9618.HK',
        'display_ticker': '9618.HK',
        'peer': '3690.HK',
        'peer_display': '3690.HK',
        'benchmark': '^HSI',
        'benchmark_display': 'HSI',
        'forex_a': 'HKDUSD',
        'forex_a_display': 'HKDUSD',
        'forex_b': 'USDHKD',
        'forex_b_display': 'USDHKD',
        'source': 'fmp'
    },
    4: {
        'stock_id': 4,
        'ticker': '008930.KS',
        'display_ticker': '008930.KS',
        'peer': '000100.KS',
        'peer_display': '000100.KS',
        'benchmark': '^KS11',
        'benchmark_display': 'KS11',
        'forex_a': 'KRWUSD',
        'forex_a_display': 'KRWUSD',
        'forex_b': 'USDKRW',
        'forex_b_display': 'USDKRW',
        'source': 'fmp'
    },
    5: {
        'stock_id': 5,
        'ticker': '068270.KS',
        'display_ticker': '068270.KS',
        'peer': '207940.KS',
        'peer_display': '207940.KS',
        'benchmark': '^KS11',
        'benchmark_display': 'KS11',
        'forex_a': 'KRWUSD',
        'forex_a_display': 'KRWUSD',
        'forex_b': 'USDKRW',
        'forex_b_display': 'USDKRW',
        'source': 'fmp'
    },
    6: {
        'stock_id': 6,
        'ticker': '032350.KS',
        'display_ticker': '032350.KS',
        'peer': '114090.KS',
        'peer_display': '114090.KS',
        'benchmark': '^KS11',
        'benchmark_display': 'KS11',
        'forex_a': 'KRWUSD',
        'forex_a_display': 'KRWUSD',
        'forex_b': 'USDKRW',
        'forex_b_display': 'USDKRW',
        'source': 'fmp'
    },
    7: {
        'stock_id': 7,
        'ticker': '5216.T',
        'display_ticker': '5216.T',
        'peer': '5214.T',
        'peer_display': '5214.T',
        'benchmark': '^N225',
        'benchmark_display': 'N225',
        'forex_a': 'JPYUSD',
        'forex_a_display': 'JPYUSD',
        'forex_b': 'USDJPY',
        'forex_b_display': 'USDJPY',
        'source': 'fmp'
    },
    8: {
        'stock_id': 8,
        'ticker': '6098.T',
        'display_ticker': '6098.T',
        'peer': '2181.T',
        'peer_display': '2181.T',
        'benchmark': '^N225',
        'benchmark_display': 'N225',
        'forex_a': 'JPYUSD',
        'forex_a_display': 'JPYUSD',
        'forex_b': 'USDJPY',
        'forex_b_display': 'USDJPY',
        'source': 'fmp'
    },
    9: {
        'stock_id': 9,
        'ticker': 'CS.ST',
        'display_ticker': 'CS.ST',
        'peer': 'COIN',
        'peer_display': 'COIN',
        'benchmark': '^OMXS30',
        'benchmark_display': 'OMXS30',
        'forex_a': 'SEKUSD',
        'forex_a_display': 'SEKUSD',
        'forex_b': 'USDSEK',
        'forex_b_display': 'USDSEK',
        'source': 'fmp'
    },
    10: {
        'stock_id': 10,
        'ticker': 'NB2.DE',
        'display_ticker': 'NB2.DE',
        'peer': 'EQIX',
        'peer_display': 'EQIX',
        'benchmark': '^GDAXI',
        'benchmark_display': 'GDAXI',
        'forex_a': 'EURUSD',
        'forex_a_display': 'EURUSD',
        'forex_b': 'USDEUR',
        'forex_b_display': 'USDEUR',
        'source': 'fmp'
    },
}
def fetch_fmp_prices(symbol, days=400):
    """Fetch historical prices from FMP API"""
    try:
        r = requests.get(
            FMP_BASE_URL,
            params={'symbol': symbol, 'apikey': FMP_API_KEY},
            timeout=30
        )
        
        if r.status_code != 200:
            print(f"    ⚠ FMP API error for {symbol}: {r.status_code}")
            return None
        
        data = r.json()
        
        if not isinstance(data, list) or len(data) == 0:
            print(f"    ⚠ No FMP data for {symbol}")
            return None
        
        df = pd.DataFrame(data)
        df['date'] = pd.to_datetime(df['date'])
        df = df.sort_values('date').reset_index(drop=True)
        
        df = df[['date', 'close']].copy()
        df = df.dropna()
        
        cutoff = datetime.now() - timedelta(days=days)
        df = df[df['date'] >= cutoff]
        
        return df
        
    except Exception as e:
        print(f"    ⚠ Error fetching FMP {symbol}: {e}")
        return None


def fetch_yfinance_prices(symbol, days=400):
    """Fetch historical prices from yfinance"""
    try:
        ticker = yf.Ticker(symbol)
        df = ticker.history(period="2y")
        
        if df.empty:
            print(f"    ⚠ No yfinance data for {symbol}")
            return None
        
        df = df.reset_index()
        df.columns = df.columns.str.lower()
        df = df.rename(columns={'date': 'date', 'close': 'close'})
        
        if df['date'].dt.tz is not None:
            df['date'] = df['date'].dt.tz_localize(None)
        
        df = df[['date', 'close']].copy()
        df = df.dropna()
        df = df.sort_values('date').reset_index(drop=True)
        
        cutoff = datetime.now() - timedelta(days=days)
        df = df[df['date'] >= cutoff]
        
        return df
        
    except Exception as e:
        print(f"    ⚠ Error fetching yfinance {symbol}: {e}")
        return None


def fetch_prices(symbol, source='fmp', days=400):
    """Fetch prices from appropriate source"""
    if source == 'yfinance':
        return fetch_yfinance_prices(symbol, days)
    else:
        df = fetch_fmp_prices(symbol, days)
        if df is None or df.empty:
            # Fallback to yfinance
            print(f"    → Trying yfinance fallback for {symbol}")
            return fetch_yfinance_prices(symbol, days)
        return df



def calculate_daily_returns(df):
    """Calculate daily percentage returns from close prices"""
    df = df.copy()
    df['return'] = df['close'].pct_change()
    df = df.dropna()
    return df


def align_dataframes(dfs_dict, exclude_today=True):
    """
    Align multiple dataframes on common dates.
    Returns a dict of aligned dataframes with daily returns.
    """
    today = pd.Timestamp(datetime.now().date())
    
    returns_dict = {}
    for name, df in dfs_dict.items():
        if df is None or df.empty:
            continue
        
        df = df.copy()
        
        if exclude_today:
            df = df[df['date'] < today]
        
        df = calculate_daily_returns(df)
        
        if not df.empty:
            returns_dict[name] = df
    
    if len(returns_dict) < 2:
        return None
    
    date_sets = [set(df['date'].tolist()) for df in returns_dict.values()]
    common_dates = set.intersection(*date_sets)
    
    if len(common_dates) < 30:  
        return None
    
    aligned = {}
    for name, df in returns_dict.items():
        df_aligned = df[df['date'].isin(common_dates)].copy()
        df_aligned = df_aligned.sort_values('date').reset_index(drop=True)
        aligned[name] = df_aligned
    
    return aligned


def calculate_correlation_matrix(aligned_returns):
    """
    Calculate Pearson correlation matrix from aligned returns.
    Returns a dict of (entity_a, entity_b) -> correlation_value
    """
    if aligned_returns is None:
        return None
    
    returns_df = pd.DataFrame()
    for name, df in aligned_returns.items():
        returns_df[name] = df['return'].values
    
    corr_matrix = returns_df.corr(method='pearson')
    
    correlations = {}
    entities = list(corr_matrix.columns)
    
    for entity_a in entities:
        for entity_b in entities:
            corr_val = corr_matrix.loc[entity_a, entity_b]
            correlations[(entity_a, entity_b)] = round(float(corr_val), 2)
    
    return correlations



def process_stock(config, lookback_days=LOOKBACK_DAYS):
    """Process a single stock and calculate its 5x5 correlation matrix"""
    
    stock_id = config['stock_id']
    ticker = config['ticker']
    display_ticker = config['display_ticker']
    source = config['source']
    
    print(f"\n{'='*60}")
    print(f"Processing stock_id={stock_id}: {ticker}")
    print(f"{'='*60}")
    
    entities = {
        'stock': (ticker, display_ticker, source),
        'peer': (config['peer'], config['peer_display'], 'fmp'),
        'benchmark': (config['benchmark'], config['benchmark_display'], 'fmp'),
        'forex_a': (config['forex_a'], config['forex_a_display'], 'fmp'),
        'forex_b': (config['forex_b'], config['forex_b_display'], 'fmp'),
    }
    
    print(f"→ Fetching price data (last {lookback_days} days)...")
    
    price_data = {}
    for entity_type, (symbol, display_name, src) in entities.items():
        print(f"  Fetching {entity_type}: {symbol}...", end=" ")
        
        fetch_source = src
        if entity_type == 'stock' and source == 'yfinance':
            fetch_source = 'yfinance'
        
        df = fetch_prices(symbol, fetch_source, days=lookback_days + 50)
        
        if df is not None and not df.empty:
            price_data[display_name] = df
            print(f"✓ ({len(df)} days)")
        else:
            print("✗ No data")
    
    if len(price_data) < 2:
        print("  ✗ Insufficient data for correlation calculation")
        return None
    
    # Align data and calculate correlations
    print(f"→ Aligning data and calculating correlations...")
    
    aligned = align_dataframes(price_data, exclude_today=True)
    
    if aligned is None:
        print("  ✗ Could not align data (insufficient common dates)")
        return None
    
    first_entity = list(aligned.keys())[0]
    date_count = len(aligned[first_entity])
    date_range = f"{aligned[first_entity]['date'].min().date()} to {aligned[first_entity]['date'].max().date()}"
    print(f"  ✓ Aligned {len(aligned)} entities on {date_count} common trading days")
    print(f"  ✓ Date range: {date_range}")
    
    correlations = calculate_correlation_matrix(aligned)
    
    if correlations is None:
        print("  ✗ Correlation calculation failed")
        return None
    
    
    records = []
    calculated_at = datetime.now()
    
    entity_order = [
        display_ticker,  # Stock itself
        config['peer_display'],
        config['benchmark_display'],
        config['forex_a_display'],
        config['forex_b_display']
    ]
    
    print(f"→ Building 5x5 matrix ({len(entity_order)}x{len(entity_order)} = {len(entity_order)**2} entries)...")
    
    for entity_a_display in entity_order:
        for entity_b_display in entity_order:
            if (entity_a_display, entity_b_display) not in correlations:
                continue
            
            corr_val = correlations[(entity_a_display, entity_b_display)]
            
            entity_a_name = f"{display_ticker}_{entity_a_display}"
            entity_b_name = f"{display_ticker}_{entity_b_display}"
            
            records.append({
                'entity_a': entity_a_name,
                'entity_b': entity_b_name,
                'correlation_value': corr_val,
                'calculated_at': calculated_at
            })
    
    print(f"  ✓ Generated {len(records)} correlation entries")
    
    print(f"\n→ Sample correlations:")
    stock_name = f"{display_ticker}_{display_ticker}"
    for rec in records[:5]:
        if rec['entity_a'] == stock_name:
            print(f"  {rec['entity_a'][:25]:25} vs {rec['entity_b'][:25]:25} = {rec['correlation_value']:6.2f}")
    
    return records


def check_existing_correlations(cursor, calculated_date):
    """Check if correlations already exist for a given date"""
    cursor.execute("""
        SELECT COUNT(DISTINCT SPLIT_PART(entity_a, '_', 1))
        FROM transform_db.instrument_correlation_matrix
        WHERE DATE(calculated_at) = %s
    """, (calculated_date,))
    
    return cursor.fetchone()[0]


def push_to_database(all_records, dry_run=True):
    """Push correlation records to database"""
    
    if not all_records:
        print("\n✗ No records to push")
        return
    
    print(f"\n{'='*60}")
    print(f"DATABASE PUSH" + (" (DRY RUN)" if dry_run else ""))
    print(f"{'='*60}")
    print(f"Total records to insert: {len(all_records)}")
    
    if dry_run:
        print("\n⚠ DRY RUN MODE - No data will be inserted")
        print("\nSample records:")
        for rec in all_records[:10]:
            print(f"  {rec['entity_a']:30} | {rec['entity_b']:30} | {rec['correlation_value']:6.2f}")
        print(f"\n💡 To actually insert, run without --dry-run")
        return
    
    conn = None
    try:
        print("\n→ Connecting to database...")
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("  ✓ Connected")
        
        # Check for existing data today
        today = datetime.now().date()
        existing_count = check_existing_correlations(cursor, today)
        
        if existing_count > 0:
            print(f"\n⚠ Found existing correlations for {today} ({existing_count} stocks)")
            print("  Deleting existing records for today...")
            
            cursor.execute("""
                DELETE FROM transform_db.instrument_correlation_matrix
                WHERE DATE(calculated_at) = %s
            """, (today,))
            
            deleted = cursor.rowcount
            print(f"  ✓ Deleted {deleted} existing records")
        
        # Insert new records
        print("\n→ Inserting new records...")
        
        insert_query = """
            INSERT INTO transform_db.instrument_correlation_matrix
            (entity_a, entity_b, correlation_value, calculated_at)
            VALUES (%s, %s, %s, %s)
        """
        
        records_tuples = [
            (rec['entity_a'], rec['entity_b'], rec['correlation_value'], rec['calculated_at'])
            for rec in all_records
        ]
        
        execute_batch(cursor, insert_query, records_tuples, page_size=100)
        conn.commit()
        
        print(f"  ✓ Inserted {len(all_records)} records")
        
        # Verify
        cursor.execute("""
            SELECT COUNT(*) FROM transform_db.instrument_correlation_matrix
            WHERE DATE(calculated_at) = %s
        """, (today,))
        
        final_count = cursor.fetchone()[0]
        print(f"\n✅ Total records for {today}: {final_count}")
        
    except Exception as e:
        print(f"\n✗ Database error: {e}")
        if conn:
            conn.rollback()
    finally:
        if conn:
            conn.close()
            print("  ✓ Connection closed")



def main():
    parser = argparse.ArgumentParser(
        description='Calculate 5x5 correlation matrix for stocks',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview only, do not insert to database')
    parser.add_argument('--stock', type=int,
                       help='Process only specific stock_id')
    parser.add_argument('--lookback', type=int, default=LOOKBACK_DAYS,
                       help=f'Days of historical data to use (default: {LOOKBACK_DAYS})')

    args = parser.parse_args()

    print("\n" + "="*60)
    print("CORRELATION MATRIX CALCULATOR")
    print("="*60)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Lookback: {args.lookback} days")
    print(f"Matrix size: 5x5 (25 entries per stock)")
    print(f"Dry run: {args.dry_run}")
    print("="*60)

    # Load all stock configs dynamically from DB
    STOCK_CONFIG = fetch_stock_config_from_db()

    # Determine which stocks to process
    if args.stock:
        if args.stock not in STOCK_CONFIG:
            print(f"\n✗ Invalid stock_id: {args.stock}")
            print(f"Valid stock_ids: {list(STOCK_CONFIG.keys())}")
            return
        stocks_to_process = {args.stock: STOCK_CONFIG[args.stock]}
    else:
        stocks_to_process = STOCK_CONFIG
    
    print(f"Stocks to process: {len(stocks_to_process)}")
    
    # Process each stock
    all_records = []
    
    for stock_id, config in stocks_to_process.items():
        try:
            records = process_stock(config, lookback_days=args.lookback)
            if records:
                all_records.extend(records)
        except Exception as e:
            print(f"\n✗ Error processing stock_id={stock_id}: {e}")
            continue
    
    # Summary
    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Total correlation records: {len(all_records)}")
    print(f"Expected per stock: 25 (5x5 matrix)")
    print(f"Stocks processed: {len(all_records) // 25 if all_records else 0}")
    
    # Push to database
    push_to_database(all_records, dry_run=args.dry_run)
    
    print(f"\n{'='*60}")
    print("COMPLETE")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
