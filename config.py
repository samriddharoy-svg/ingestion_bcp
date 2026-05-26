"""
Configuration for AWS RDS Ingestion Scripts
"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# =============================================================================
# AWS RDS Configuration
# Read from environment variables in Docker/Fargate, fallback to defaults for local dev
# =============================================================================
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")

AWS_RDS = {
    'host': os.getenv('RDS_HOST', ''),
    'port': int(os.getenv('RDS_PORT', '5432')),
    'database': os.getenv('RDS_DATABASE', ''),
    'user': os.getenv('RDS_USER', ''),
    'password': os.getenv('RDS_PASSWORD', ''),
    'sslmode': os.getenv('RDS_SSL_MODE', 'require')
}

# =============================================================================
# Local SQLite Configuration
# =============================================================================
SQLITE_DB_PATH = os.getenv('SQLITE_DB_PATH', 'misc/portfolio.db')

# =============================================================================
# Storage Mode Configuration
# Set USE_RDS_DIRECT=true to write directly to RDS (skip SQLite intermediate step)
# =============================================================================
USE_RDS_DIRECT = os.getenv('USE_RDS_DIRECT', 'false').lower() == 'true'

# =============================================================================
# FMP API Configuration
# =============================================================================
FMP_API_KEY = os.getenv('FMP_API_KEY', '')
FMP_BASE_URL = 'https://financialmodelingprep.com'

# =============================================================================
# Tiingo API Configuration
# =============================================================================
TIINGO_API_KEY = os.getenv('TIINGO_API_KEY', '')
TIINGO_BASE_URL = 'https://api.tiingo.com'

# =============================================================================
# Stock Ticker Mappings & Benchmark Maps — loaded dynamically from DB
# =============================================================================
def _fetch_stock_mappings():
    """
    Fetch TICKER_MAPPINGS and STOCK_BENCHMARK_MAP from ingest_db.stocks
    and ingest_db.stocks_benchmark_mapping at runtime.
    Only includes is_peer = false stocks.
    Falls back to empty dicts if DB is unreachable.
    """
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=AWS_RDS['host'],
            port=AWS_RDS['port'],
            database=AWS_RDS['database'],
            user=AWS_RDS['user'],
            password=AWS_RDS['password'],
            sslmode=AWS_RDS['sslmode']
        )
        cur = conn.cursor()

        cur.execute("""
            SELECT s.ticker, i.symbol
            FROM ingest_db.stocks s
            LEFT JOIN ingest_db.stocks_benchmark_mapping sbm
                ON s.stock_id = sbm.stock_id AND sbm.ranking_order = 1
            LEFT JOIN ingest_db.instruments i
                ON sbm.instrument_id = i.instrument_id
            WHERE s.is_peer = false
        """)

        ticker_mappings = {}
        stock_benchmark_map = {}

        for ticker, benchmark_code in cur.fetchall():
            ticker_mappings[ticker] = ticker
            if benchmark_code:
                stock_benchmark_map[ticker] = benchmark_code

        cur.close()
        conn.close()
        return ticker_mappings, stock_benchmark_map

    except Exception as e:
        print(f"[config] Warning: Could not fetch stock mappings from DB: {e}")
        return {}, {}


TICKER_MAPPINGS, STOCK_BENCHMARK_MAP = _fetch_stock_mappings()

# =============================================================================
# Benchmark/Instrument Mappings
# =============================================================================
BENCHMARK_MAPPINGS = {
    '^KS11':      {'name': 'KOSPI',                       'currency': 'KRW', 'country': 'South Korea'},
    '^HSI':       {'name': 'Hang Seng Index',              'currency': 'HKD', 'country': 'Hong Kong'},
    '^N225':      {'name': 'Nikkei 225',                   'currency': 'JPY', 'country': 'Japan'},
    '^SSMI':      {'name': 'Swiss Market Index',           'currency': 'CHF', 'country': 'Switzerland'},
    '^GDAXI':     {'name': 'DAX',                          'currency': 'EUR', 'country': 'Germany'},
    '^AXJO':      {'name': 'S&P/ASX 200',                  'currency': 'AUD', 'country': 'Australia'},
    '^IXIC':      {'name': 'NASDAQ Composite',             'currency': 'USD', 'country': 'United States'},
    '^DJI':       {'name': 'Dow Jones Industrial Average', 'currency': 'USD', 'country': 'United States'},
    '^GSPC':      {'name': 'S&P 500',                      'currency': 'USD', 'country': 'United States'},
    '^FTSE':      {'name': 'FTSE 100',                     'currency': 'GBP', 'country': 'United Kingdom'},
    '^GSPTSE':    {'name': 'S&P/TSX Composite',            'currency': 'CAD', 'country': 'Canada'},
    '^FTMIB':     {'name': 'FTSE MIB',                     'currency': 'EUR', 'country': 'Italy'},
    '^GD.AT':     {'name': 'Athens General',               'currency': 'EUR', 'country': 'Greece'},
    '000001.SS':  {'name': 'SSE Composite',                'currency': 'CNY', 'country': 'China'},
    '^FCHI':      {'name': 'CAC 40',                       'currency': 'EUR', 'country': 'France'},
    '^OMX':       {'name': 'OMX Stockholm 30',             'currency': 'SEK', 'country': 'Sweden'},
    '^NSEI':      {'name': 'Nifty 50',                     'currency': 'INR', 'country': 'India'},
}

# =============================================================================
# Data Fetch Settings
# =============================================================================
HISTORICAL_YEARS = 10  # Fetch 10 years of data
DEFAULT_START_DATE = '2015-01-01'
DEFAULT_END_DATE = '2025-11-28'

# =============================================================================
# Schema Names
# =============================================================================
SCHEMAS = {
    'ingest': 'ingest_db',
    'transform': 'transform_db',
    'semantic': 'semantic_db'
}

# =============================================================================
# Table Names
# =============================================================================
TABLES = {
    # Ingest schema
    'portfolio': f"{SCHEMAS['ingest']}.portfolio",
    'stocks': f"{SCHEMAS['ingest']}.stocks",
    'portfolio_stocks': f"{SCHEMAS['ingest']}.portfolio_stocks",
    'stocks_price_data': f"{SCHEMAS['ingest']}.stocks_price_data",
    'forex_rates': f"{SCHEMAS['ingest']}.forex_rates",
    'instruments': f"{SCHEMAS['ingest']}.instruments",
    'instrument_prices': f"{SCHEMAS['ingest']}.instrument_prices",
    'benchmark_history': f"{SCHEMAS['ingest']}.benchmark_history",
    'stocks_market_news': f"{SCHEMAS['ingest']}.stocks_market_news",
    'stocks_upcoming_earnings': f"{SCHEMAS['ingest']}.stocks_upcoming_earnings",
    'stocks_market_alerts': f"{SCHEMAS['ingest']}.stocks_market_alerts",
    'stocks_events': f"{SCHEMAS['ingest']}.stocks_events",
    'stocks_flags': f"{SCHEMAS['ingest']}.stocks_flags",

    # Transform schema
    'stocks_sentiment_analysis': f"{SCHEMAS['transform']}.stocks_sentiment_analysis",
}

# =============================================================================
# Data Fetch Configuration
# =============================================================================
DATA_FETCH_CONFIG = {
    'historical_years': 10,
    'start_date': '2015-01-01',
    'end_date': '2025-01-01',
    'news_limit': 100,
    'earnings_history_years': 5,
    'batch_size': 1000,
    'rate_limit_delay': 5,  # 5 seconds between requests to avoid Yahoo 429 errors
    'use_batch_download': True,  # Use yf.download() for batch fetching
}
