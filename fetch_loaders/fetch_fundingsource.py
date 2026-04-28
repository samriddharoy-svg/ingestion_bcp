#!/usr/bin/env python3


import requests
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime
import argparse
import sys
from typing import Dict, List, Optional, Tuple
import yfinance as yf
import pandas as pd

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from config import AWS_RDS, FMP_API_KEY as _FMP_API_KEY

FMP_API_KEY = _FMP_API_KEY
FMP_BASE_URL = "https://financialmodelingprep.com/stable"

DB_CONFIG = {
    'host': AWS_RDS['host'],
    'port': AWS_RDS['port'],
    'dbname': AWS_RDS['database'],
    'user': AWS_RDS['user'],
    'password': AWS_RDS['password'],
    'sslmode': AWS_RDS['sslmode'],
}

# Tickers that require yfinance fallback (FMP has no data)
_YFINANCE_TICKERS = {"6887.HK"}

def _fetch_stocks():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        cur.execute("""
            SELECT stock_id, ticker, company_name
            FROM ingest_db.stocks
            WHERE is_peer = false
            ORDER BY stock_id
        """)
        result = {
            row[0]: {
                'db_ticker': row[1],
                'fmp_ticker': row[1],
                'name': row[2],
                'data_source': 'yfinance' if row[1] in _YFINANCE_TICKERS else 'fmp'
            }
            for row in cur.fetchall()
        }
        cur.close()
        conn.close()
        print(f"[fetch_fundingsource] Loaded {len(result)} stocks from DB")
        return result
    except Exception as e:
        print(f"[fetch_fundingsource] Warning: Could not fetch stocks from DB: {e}")
        return {}

STOCKS = _fetch_stocks()


FUNDING_METRICS_FMP = {
    # Cash Position - PRIMARY (client requirement: "cash levels")
    'cashAtEndOfPeriod': ('Cash at Period End', 'End of period cash balance'),
    
    # Free Cash Flow - PRIMARY (client requirement: "FCF")
    'freeCashFlow': ('Free Cash Flow', 'Operating cash flow minus CapEx'),
    
    # Debt Funding Sources - PRIMARY (client requirement: "new debt raises")
    'netDebtIssuance': ('Net Debt Change', 'Net debt change (+ = raised, - = repaid)'),
    
    # Equity Funding Sources - PRIMARY (client requirement: "new equity offerings")
    'commonStockIssuance': ('Equity Issued', 'New common stock issued (+ = issued)'),
    'commonStockRepurchased': ('Stock Buybacks', 'Common stock repurchased (- = bought back)'),
    'netCommonStockIssuance': ('Net Equity Change', 'Net equity change (issuance - buybacks)'),
}

# Mapping from yfinance field names to our metric types
# yfinance uses different field names than FMP
FUNDING_METRICS_YFINANCE = {
    'End Cash Position': ('Cash at Period End', 'End of period cash balance'),
    'Free Cash Flow': ('Free Cash Flow', 'Operating cash flow minus CapEx'),
    'Net Issuance Payments Of Debt': ('Net Debt Change', 'Net debt change (+ = raised, - = repaid)'),
    'Common Stock Issuance': ('Equity Issued', 'New common stock issued (+ = issued)'),
    # Note: yfinance doesn't have separate buyback field, it's included in Net Common Stock Issuance
    'Net Common Stock Issuance': ('Net Equity Change', 'Net equity change (issuance - buybacks)'),
}

METRIC_CATEGORY = 'Funding Sources'


def fetch_cash_flow_data(ticker: str, period: str = 'quarter', limit: int = 20) -> List[dict]:
    """
    Fetch cash flow statement data from FMP API.
    
    Args:
        ticker: FMP stock ticker symbol
        period: 'quarter' or 'annual'
        limit: Number of periods to fetch
        
    Returns:
        List of cash flow statement records (newest first)
    """
    url = f"{FMP_BASE_URL}/cash-flow-statement"
    params = {
        'symbol': ticker,
        'period': period,
        'apikey': FMP_API_KEY
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        if isinstance(data, list):
            return data[:limit]
        return []
        
    except requests.exceptions.RequestException as e:
        print(f"    ⚠️  API Error for {ticker}: {e}")
        return []


def parse_period_label(date_str: str, period_type: str) -> str:
    """
    Convert date to our period_label format.
    
    Args:
        date_str: Date string like '2024-06-30'
        period_type: 'Annual' or 'Quarterly'
        
    Returns:
        Period label like '2024' (Annual) or '2024-Q2' (Quarterly)
    """
    try:
        date = datetime.strptime(date_str, '%Y-%m-%d')
        
        if period_type == 'Annual':
            # Format: YYYY (e.g., 2024)
            return str(date.year)
        else:
            # Format: YYYY-Q1, YYYY-Q2, etc.
            quarter = (date.month - 1) // 3 + 1
            return f"{date.year}-Q{quarter}"
    except ValueError:
        return date_str


def extract_metrics_fmp(cash_flow_data: List[dict], period_type: str) -> List[dict]:
    """
    Extract funding metrics from FMP cash flow data.
    
    Args:
        cash_flow_data: List of cash flow records from FMP API
        period_type: 'Annual' or 'Quarterly'
        
    Returns:
        List of metric dicts ready for DB insertion
    """
    all_metrics = []
    
    for record in cash_flow_data:
        date_str = record.get('date', '')
        if not date_str:
            continue
            
        period_label = parse_period_label(date_str, period_type)
        
        for fmp_field, (metric_type, _) in FUNDING_METRICS_FMP.items():
            value = record.get(fmp_field)
            
            if value is not None:
                # Keep natural signs - no transformation needed
                # Positive = cash inflow, Negative = cash outflow
                all_metrics.append({
                    'metric_type': metric_type,
                    'period_type': period_type,
                    'period_label': period_label,
                    'metric_value': float(value),
                    'date': date_str
                })
    
    return all_metrics


def fetch_yfinance_cash_flow(ticker: str) -> Tuple[List[dict], List[dict]]:
    """
    Fetch cash flow data from yfinance.
    
    Args:
        ticker: Stock ticker symbol (e.g., '6887.HK')
        
    Returns:
        Tuple of (annual_data, quarterly_data) - each is a list of dicts
        Note: yfinance may only have annual data for some stocks
    """
    try:
        yf_ticker = yf.Ticker(ticker)
        
        annual_data = []
        quarterly_data = []
        
        # Get annual cash flow
        cf_annual = yf_ticker.cashflow
        if cf_annual is not None and not cf_annual.empty:
            for col in cf_annual.columns:
                date_str = col.strftime('%Y-%m-%d')
                record = {'date': date_str}
                for yf_field, (metric_type, _) in FUNDING_METRICS_YFINANCE.items():
                    if yf_field in cf_annual.index:
                        val = cf_annual.loc[yf_field, col]
                        if pd.notna(val):
                            record[yf_field] = float(val)
                annual_data.append(record)
        
        # Get quarterly cash flow (may be empty for some stocks)
        cf_quarterly = yf_ticker.quarterly_cashflow
        if cf_quarterly is not None and not cf_quarterly.empty:
            for col in cf_quarterly.columns:
                date_str = col.strftime('%Y-%m-%d')
                record = {'date': date_str}
                for yf_field, (metric_type, _) in FUNDING_METRICS_YFINANCE.items():
                    if yf_field in cf_quarterly.index:
                        val = cf_quarterly.loc[yf_field, col]
                        if pd.notna(val):
                            record[yf_field] = float(val)
                quarterly_data.append(record)
        
        return annual_data, quarterly_data
        
    except Exception as e:
        print(f"    ⚠️  yfinance Error for {ticker}: {e}")
        return [], []


def extract_metrics_yfinance(cash_flow_data: List[dict], period_type: str) -> List[dict]:

    all_metrics = []
    
    for record in cash_flow_data:
        date_str = record.get('date', '')
        if not date_str:
            continue
            
        period_label = parse_period_label(date_str, period_type)
        
        for yf_field, (metric_type, _) in FUNDING_METRICS_YFINANCE.items():
            value = record.get(yf_field)
            
            if value is not None:
                # Keep natural signs - no transformation needed
                all_metrics.append({
                    'metric_type': metric_type,
                    'period_type': period_type,
                    'period_label': period_label,
                    'metric_value': float(value),
                    'date': date_str
                })
    
    return all_metrics



def get_db_connection():
    """Get database connection."""
    return psycopg2.connect(**DB_CONFIG)


def get_existing_records(cur, stock_id: int) -> set:
    """
    Get existing records to prevent duplicates.
    
    Returns:
        Set of (metric_type, period_type, period_label) tuples
    """
    cur.execute("""
        SELECT DISTINCT metric_type, period_type, period_label
        FROM ingest_db.stocks_fundamentals
        WHERE stock_id = %s AND metric_category = %s
    """, (stock_id, METRIC_CATEGORY))
    
    return {(row[0], row[1], row[2]) for row in cur.fetchall()}


def insert_metrics(cur, stock_id: int, metrics: List[dict], dry_run: bool = False) -> Tuple[int, int]:
    """
    Insert metrics into database, skipping duplicates.
    
    Returns:
        Tuple of (new_count, skipped_count)
    """
    if not metrics:
        return 0, 0
    
    # Get existing records
    existing = get_existing_records(cur, stock_id)
    
    # Filter out duplicates
    new_metrics = []
    skipped = 0
    
    for m in metrics:
        key = (m['metric_type'], m['period_type'], m['period_label'])
        if key in existing:
            skipped += 1
        else:
            new_metrics.append(m)
            existing.add(key)  # Prevent duplicates within same batch
    
    if not new_metrics:
        return 0, skipped
    
    if dry_run:
        print(f"    [DRY RUN] Would insert {len(new_metrics)} new records (skipping {skipped} duplicates)")
        # Show sample of what would be inserted
        for m in new_metrics[:3]:
            print(f"      → {m['metric_type']}: {m['period_label']} = {m['metric_value']:,.0f}")
        if len(new_metrics) > 3:
            print(f"      ... and {len(new_metrics) - 3} more")
        return len(new_metrics), skipped
    
    # Prepare values for insertion
    values = [
        (
            stock_id,
            METRIC_CATEGORY,
            m['metric_type'],
            m['period_type'],
            m['period_label'],
            m['metric_value']
        )
        for m in new_metrics
    ]
    
    # Insert with ON CONFLICT to handle any race conditions
    insert_sql = """
        INSERT INTO ingest_db.stocks_fundamentals 
        (stock_id, metric_category, metric_type, period_type, period_label, metric_value)
        VALUES %s
        ON CONFLICT DO NOTHING
    """
    
    execute_values(cur, insert_sql, values)
    
    return len(new_metrics), skipped



def process_stock_fmp(stock_id: int, stock_info: dict, cur, dry_run: bool = False) -> dict:
    """
    Process a single stock using FMP API: fetch data and insert metrics.
    
    Returns:
        Dict with processing results
    """
    db_ticker = stock_info['db_ticker']
    fmp_ticker = stock_info['fmp_ticker']
    name = stock_info['name']
    
    print(f"\n{'─' * 70}")
    print(f"📊 Stock {stock_id}: {name}")
    print(f"   DB Ticker: {db_ticker} | FMP Ticker: {fmp_ticker} | Source: FMP API")
    print(f"{'─' * 70}")
    
    results = {
        'stock_id': stock_id,
        'ticker': db_ticker,
        'name': name,
        'data_source': 'FMP',
        'quarterly_new': 0,
        'quarterly_skipped': 0,
        'annual_new': 0,
        'annual_skipped': 0,
        'has_data': False
    }
    
    # Fetch and process QUARTERLY data
    print("  📅 Fetching quarterly data from FMP...")
    quarterly_data = fetch_cash_flow_data(fmp_ticker, period='quarter', limit=20)
    
    if quarterly_data:
        print(f"     Found {len(quarterly_data)} quarters of data")
        quarterly_metrics = extract_metrics_fmp(quarterly_data, 'Quarterly')
        print(f"     Extracted {len(quarterly_metrics)} metric values")
        
        new, skipped = insert_metrics(cur, stock_id, quarterly_metrics, dry_run)
        results['quarterly_new'] = new
        results['quarterly_skipped'] = skipped
        results['has_data'] = True
        
        if not dry_run:
            print(f"     ✅ Inserted {new} new records (skipped {skipped} duplicates)")
    else:
        print("     ⚠️  No quarterly data available from FMP")
    
    # Fetch and process ANNUAL data
    print("  📅 Fetching annual data from FMP...")
    annual_data = fetch_cash_flow_data(fmp_ticker, period='annual', limit=10)
    
    if annual_data:
        print(f"     Found {len(annual_data)} years of data")
        annual_metrics = extract_metrics_fmp(annual_data, 'Annual')
        print(f"     Extracted {len(annual_metrics)} metric values")
        
        new, skipped = insert_metrics(cur, stock_id, annual_metrics, dry_run)
        results['annual_new'] = new
        results['annual_skipped'] = skipped
        results['has_data'] = True
        
        if not dry_run:
            print(f"     ✅ Inserted {new} new records (skipped {skipped} duplicates)")
    else:
        print("     ⚠️  No annual data available from FMP")
    
    return results


def process_stock_yfinance(stock_id: int, stock_info: dict, cur, dry_run: bool = False) -> dict:
    """
    Process a single stock using yfinance: fetch data and insert metrics.
    Used as fallback when FMP has no data (e.g., 6887.HK).
    
    Returns:
        Dict with processing results
    """
    db_ticker = stock_info['db_ticker']
    name = stock_info['name']
    
    print(f"\n{'─' * 70}")
    print(f"📊 Stock {stock_id}: {name}")
    print(f"   DB Ticker: {db_ticker} | Source: yfinance (FMP fallback)")
    print(f"{'─' * 70}")
    
    results = {
        'stock_id': stock_id,
        'ticker': db_ticker,
        'name': name,
        'data_source': 'yfinance',
        'quarterly_new': 0,
        'quarterly_skipped': 0,
        'annual_new': 0,
        'annual_skipped': 0,
        'has_data': False
    }
    
    # Fetch data from yfinance
    print("  📅 Fetching data from yfinance...")
    annual_data, quarterly_data = fetch_yfinance_cash_flow(db_ticker)
    
    # Process QUARTERLY data (may be empty for some stocks)
    if quarterly_data:
        print(f"     Found {len(quarterly_data)} quarters of data")
        quarterly_metrics = extract_metrics_yfinance(quarterly_data, 'Quarterly')
        print(f"     Extracted {len(quarterly_metrics)} metric values")
        
        new, skipped = insert_metrics(cur, stock_id, quarterly_metrics, dry_run)
        results['quarterly_new'] = new
        results['quarterly_skipped'] = skipped
        results['has_data'] = True
        
        if not dry_run:
            print(f"     ✅ Inserted {new} new records (skipped {skipped} duplicates)")
    else:
        print("     ⚠️  No quarterly data available from yfinance")
    
    # Process ANNUAL data
    if annual_data:
        print(f"  📅 Found {len(annual_data)} years of annual data")
        annual_metrics = extract_metrics_yfinance(annual_data, 'Annual')
        print(f"     Extracted {len(annual_metrics)} metric values")
        
        new, skipped = insert_metrics(cur, stock_id, annual_metrics, dry_run)
        results['annual_new'] = new
        results['annual_skipped'] = skipped
        results['has_data'] = True
        
        if not dry_run:
            print(f"     ✅ Inserted {new} new records (skipped {skipped} duplicates)")
    else:
        print("     ⚠️  No annual data available from yfinance")
    
    return results


def process_stock(stock_id: int, stock_info: dict, cur, dry_run: bool = False) -> dict:
    """
    Process a single stock: routes to appropriate data source (FMP or yfinance).
    
    Returns:
        Dict with processing results
    """
    data_source = stock_info.get('data_source', 'fmp')
    
    if data_source == 'yfinance':
        return process_stock_yfinance(stock_id, stock_info, cur, dry_run)
    else:
        return process_stock_fmp(stock_id, stock_info, cur, dry_run)


def verify_data(cur):
    """Verify existing data in the database."""
    print("\n" + "=" * 70)
    print("🔍 VERIFYING EXISTING FUNDING SOURCES DATA")
    print("=" * 70)
    
    # Count by stock
    cur.execute("""
        SELECT 
            sf.stock_id,
            s.ticker,
            sf.period_type,
            COUNT(DISTINCT sf.metric_type) as metric_types,
            COUNT(*) as total_records,
            MIN(sf.period_label) as oldest_period,
            MAX(sf.period_label) as newest_period
        FROM ingest_db.stocks_fundamentals sf
        JOIN ingest_db.stocks s ON sf.stock_id = s.stock_id
        WHERE sf.metric_category = %s
        GROUP BY sf.stock_id, s.ticker, sf.period_type
        ORDER BY sf.stock_id, sf.period_type
    """, (METRIC_CATEGORY,))
    
    results = cur.fetchall()
    
    if not results:
        print("\n⚠️  No funding sources data found in database.")
        print("   Run without --verify to fetch and insert data.")
        return
    
    print(f"\n{'Stock ID':<10} {'Ticker':<12} {'Period Type':<12} {'Metrics':<10} {'Records':<10} {'Range'}")
    print("-" * 80)
    
    current_stock = None
    for row in results:
        stock_id, ticker, period_type, metric_types, total, oldest, newest = row
        if current_stock != stock_id:
            if current_stock is not None:
                print()
            current_stock = stock_id
        print(f"{stock_id:<10} {ticker:<12} {period_type:<12} {metric_types:<10} {total:<10} {oldest} → {newest}")
    
    # Show sample data
    print("\n" + "-" * 80)
    print("📊 Sample Data (latest quarter for each stock):")
    
    cur.execute("""
        WITH ranked AS (
            SELECT 
                sf.stock_id,
                s.ticker,
                sf.metric_type,
                sf.period_label,
                sf.metric_value,
                ROW_NUMBER() OVER (PARTITION BY sf.stock_id, sf.metric_type ORDER BY sf.period_label DESC) as rn
            FROM ingest_db.stocks_fundamentals sf
            JOIN ingest_db.stocks s ON sf.stock_id = s.stock_id
            WHERE sf.metric_category = %s AND sf.period_type = 'Quarterly'
        )
        SELECT stock_id, ticker, metric_type, period_label, metric_value
        FROM ranked
        WHERE rn = 1 AND metric_type IN ('Cash at Period End', 'Free Cash Flow', 'Net Debt Change')
        ORDER BY stock_id, metric_type
    """, (METRIC_CATEGORY,))
    
    for row in cur.fetchall():
        stock_id, ticker, metric_type, period_label, value = row
        print(f"  {ticker:<12} {period_label:<10} {metric_type:<25} {value:>15,.0f}")


def main():
    parser = argparse.ArgumentParser(
        description='Fetch and insert funding sources data from FMP API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python fetch_funding_sources_v2.py                  # Process all stocks
  python fetch_funding_sources_v2.py --dry-run        # Preview without inserting
  python fetch_funding_sources_v2.py --stock-id 1     # Process only MicroPort
  python fetch_funding_sources_v2.py --verify         # Check existing data
        """
    )
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be inserted without actually inserting')
    parser.add_argument('--stock-id', type=int, choices=range(1, 11), metavar='N',
                        help='Process only a specific stock ID (1-10)')
    parser.add_argument('--verify', action='store_true',
                        help='Verify existing data in database')
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("🏦 FUNDING SOURCES DATA INGESTION")
    print(f"   Target: ingest_db.stocks_fundamentals (metric_category='{METRIC_CATEGORY}')")
    print(f"   View: semantic_db.vw_stocks_funding_sources_analysis")
    print("=" * 70)
    
    if args.dry_run:
        print("\n⚠️  DRY RUN MODE - No data will be inserted\n")
    
    # Connect to database
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        print("✅ Connected to database")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        sys.exit(1)
    
    try:
        # Verify mode
        if args.verify:
            verify_data(cur)
            return
        
        # Determine which stocks to process
        if args.stock_id:
            stocks_to_process = {args.stock_id: STOCKS[args.stock_id]}
        else:
            stocks_to_process = STOCKS
        
        # Process each stock
        all_results = []
        for stock_id, stock_info in stocks_to_process.items():
            result = process_stock(stock_id, stock_info, cur, args.dry_run)
            all_results.append(result)
        
        # Commit if not dry run
        if not args.dry_run:
            conn.commit()
        
        # Print summary
        print("\n" + "=" * 70)
        print("📈 SUMMARY")
        print("=" * 70)
        
        total_new = sum(r['quarterly_new'] + r['annual_new'] for r in all_results)
        total_skipped = sum(r['quarterly_skipped'] + r['annual_skipped'] for r in all_results)
        stocks_with_data = sum(1 for r in all_results if r['has_data'])
        stocks_no_data = [r for r in all_results if not r['has_data']]
        
        print(f"\n{'Stock':<35} {'Quarterly':<15} {'Annual':<15} {'Total'}")
        print("-" * 80)
        
        for r in all_results:
            q_str = f"{r['quarterly_new']} new" if r['quarterly_new'] else "—"
            a_str = f"{r['annual_new']} new" if r['annual_new'] else "—"
            total = r['quarterly_new'] + r['annual_new']
            status = "✅" if r['has_data'] else "⚠️"
            print(f"{status} {r['ticker']:<10} {r['name'][:22]:<22} {q_str:<15} {a_str:<15} {total}")
        
        print("-" * 80)
        
        if args.dry_run:
            print(f"🔍 DRY RUN: Would insert {total_new} new records (skip {total_skipped} duplicates)")
        else:
            print(f"✅ COMPLETE: Inserted {total_new} new records (skipped {total_skipped} duplicates)")
        
        print(f"   Stocks with data: {stocks_with_data}/{len(all_results)}")
        
        if stocks_no_data:
            print(f"\n⚠️  Stocks without FMP data:")
            for r in stocks_no_data:
                print(f"   - {r['ticker']} ({r['name']})")
        
    except Exception as e:
        conn.rollback()
        print(f"\n❌ ERROR: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == '__main__':
    main()
