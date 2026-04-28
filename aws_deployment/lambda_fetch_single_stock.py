"""
Lambda Function: FetchSingleStockData
Purpose: Fetch data for a SINGLE stock from APIs to SQLite (called in parallel by Map state)
Runtime: Python 3.11
Timeout: 5 minutes (300 seconds)
Memory: 1024 MB
"""

import json
import os
import sys
import sqlite3
import boto3
from datetime import datetime

# Add /opt/python to path for Lambda Layer
sys.path.insert(0, '/opt/python')

import yfinance as yf
import requests

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager')

def get_api_keys():
    """Retrieve API keys from Secrets Manager (cached)."""
    if not hasattr(get_api_keys, 'cache'):
        secret_name = "stock-api-keys"
        response = secrets_client.get_secret_value(SecretId=secret_name)
        get_api_keys.cache = json.loads(response['SecretString'])
    return get_api_keys.cache

def fetch_stock_metadata(ticker):
    """Fetch stock metadata from Yahoo Finance."""
    try:
        ticker_obj = yf.Ticker(ticker)
        info = ticker_obj.info

        if info and 'symbol' in info:
            return {
                'ticker': ticker,
                'company_name': info.get('longName', info.get('shortName', '')),
                'sector': info.get('sector'),
                'industry': info.get('industry'),
                'currency': info.get('currency', 'USD'),
                'country': info.get('country'),
                'exchange': info.get('exchange', ''),
                'market_cap': info.get('marketCap', 0),
                'description': info.get('longBusinessSummary', ''),
                'website': info.get('website')
            }
    except Exception as e:
        print(f"Error fetching metadata for {ticker}: {str(e)}")
        return None

def fetch_historical_prices(ticker, start_date='2015-01-01', end_date='2025-01-01'):
    """Fetch historical prices from Yahoo Finance."""
    try:
        ticker_obj = yf.Ticker(ticker)
        hist = ticker_obj.history(start=start_date, end=end_date)

        if not hist.empty:
            prices = []
            for date, row in hist.iterrows():
                prices.append({
                    'date': date.strftime('%Y-%m-%d'),
                    'open': float(row['Open']),
                    'high': float(row['High']),
                    'low': float(row['Low']),
                    'close': float(row['Close']),
                    'volume': int(row['Volume']) if row['Volume'] > 0 else 0
                })
            return prices
    except Exception as e:
        print(f"Error fetching prices for {ticker}: {str(e)}")
        return []

def fetch_live_price_fmp(ticker):
    """Fetch current live price from FMP stable/quote-short."""
    try:
        secrets = get_api_keys()
        fmp_key = secrets.get('FMP_API_KEY')

        url = f"https://financialmodelingprep.com/stable/quote-short?symbol={ticker}&apikey={fmp_key}"
        response = requests.get(url, timeout=10)

        if response.status_code == 200:
            data = response.json()
            if data and len(data) > 0:
                return {
                    'price': data[0].get('price'),
                    'volume': data[0].get('volume'),
                    'timestamp': datetime.utcnow().isoformat()
                }
    except Exception as e:
        print(f"Error fetching live price for {ticker}: {str(e)}")
        return None

def categorize_market_cap(market_cap):
    """Categorize market cap."""
    if not market_cap or market_cap == 0:
        return None
    cap_billions = market_cap / 1_000_000_000
    if cap_billions >= 200:
        return "Mega Cap"
    elif cap_billions >= 10:
        return "Large Cap"
    elif cap_billions >= 2:
        return "Mid Cap"
    elif cap_billions >= 0.3:
        return "Small Cap"
    else:
        return "Micro Cap"

def save_to_sqlite(ticker, metadata, prices, live_price, db_path):
    """Save stock data to SQLite."""
    try:
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # Insert stock
        market_cap_category = categorize_market_cap(metadata.get('market_cap', 0))

        cur.execute("""
            INSERT OR IGNORE INTO stocks
            (ticker, exchange, company_name, sector, currency_code, country, market_cap_category_name)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            ticker,
            metadata.get('exchange', ''),
            metadata.get('company_name', ''),
            metadata.get('sector'),
            metadata.get('currency', 'USD'),
            metadata.get('country'),
            market_cap_category
        ))

        # Get stock_id
        cur.execute("SELECT stock_id FROM stocks WHERE ticker = ?", (ticker,))
        row = cur.fetchone()
        if not row:
            conn.close()
            return {'stocks': 0, 'prices': 0}

        stock_id = row[0]

        # Insert company profile
        cur.execute("""
            INSERT OR IGNORE INTO company_profile
            (stock_id, ticker, company_name, description, industry, sector, website, country)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            stock_id,
            ticker,
            metadata.get('company_name', ''),
            metadata.get('description', ''),
            metadata.get('industry'),
            metadata.get('sector'),
            metadata.get('website'),
            metadata.get('country')
        ))

        # Insert historical prices
        prices_inserted = 0
        for price in prices:
            opening = price.get('open', 0)
            closing = price.get('close', 0)
            change = closing - opening
            change_pct = (change / opening * 100) if opening else 0

            cur.execute("""
                INSERT OR IGNORE INTO stocks_price_data
                (stock_id, price, opening_price, closing_price, day_price_change,
                 currency_code, day_price_change_pct, volume, captured_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                stock_id,
                closing,
                opening,
                closing,
                change,
                metadata.get('currency', 'USD'),
                change_pct,
                price.get('volume', 0),
                price.get('date')
            ))
            if cur.rowcount > 0:
                prices_inserted += 1

        # Insert live price if available
        if live_price:
            cur.execute("""
                INSERT OR IGNORE INTO stocks_price_data
                (stock_id, price, closing_price, volume, currency_code, captured_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                stock_id,
                live_price.get('price'),
                live_price.get('price'),
                live_price.get('volume', 0),
                metadata.get('currency', 'USD'),
                live_price.get('timestamp')
            ))
            if cur.rowcount > 0:
                prices_inserted += 1

        conn.commit()
        conn.close()

        return {'stocks': 1, 'prices': prices_inserted}

    except Exception as e:
        print(f"Error saving to SQLite for {ticker}: {str(e)}")
        return {'stocks': 0, 'prices': 0}

def lambda_handler(event, context):
    """
    Fetch data for a single stock.

    Args:
        event: {'ticker': '0853.HK', 'name': 'MICROPORT'}

    Returns:
        dict: Execution status and counts
    """
    start_time = datetime.utcnow()
    ticker = event.get('ticker')
    stock_name = event.get('name', ticker)

    print(f"=== Processing stock: {ticker} ({stock_name}) ===")

    try:
        # Set up paths
        efs_mount = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
        db_path = f"{efs_mount}/portfolio.db"

        # Fetch metadata
        print(f"Fetching metadata for {ticker}...")
        metadata = fetch_stock_metadata(ticker)
        if not metadata:
            raise Exception(f"Failed to fetch metadata for {ticker}")
        print(f"✓ Metadata fetched")

        # Fetch historical prices
        print(f"Fetching historical prices for {ticker}...")
        prices = fetch_historical_prices(ticker)
        print(f"✓ Fetched {len(prices)} historical prices")

        # Fetch live price from FMP
        print(f"Fetching live price for {ticker}...")
        live_price = fetch_live_price_fmp(ticker)
        if live_price:
            print(f"✓ Live price: {live_price.get('price')}")

        # Save to SQLite
        print(f"Saving {ticker} to SQLite...")
        counts = save_to_sqlite(ticker, metadata, prices, live_price, db_path)
        print(f"✓ Saved: {counts['stocks']} stocks, {counts['prices']} prices")

        duration = (datetime.utcnow() - start_time).total_seconds()

        return {
            'status': 'SUCCESS',
            'ticker': ticker,
            'name': stock_name,
            'stocks_count': counts['stocks'],
            'prices_count': counts['prices'],
            'execution_time': duration,
            'timestamp': datetime.utcnow().isoformat()
        }

    except Exception as e:
        duration = (datetime.utcnow() - start_time).total_seconds()
        error_msg = str(e)
        print(f"✗ Failed to process {ticker}: {error_msg}")

        return {
            'status': 'FAILED',
            'ticker': ticker,
            'name': stock_name,
            'error': error_msg,
            'execution_time': duration,
            'timestamp': datetime.utcnow().isoformat()
        }
