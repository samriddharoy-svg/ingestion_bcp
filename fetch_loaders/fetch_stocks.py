# """
# Fetch stocks and company_profile data using FMP API with yfinance fallback
# Populates: stocks, company_profile tables
# """
# import sys
# from pathlib import Path
# import time

# # Add parent directory to path
# sys.path.insert(0, str(Path(__file__).parent.parent))

# from utils import fmp_request, smart_batch_insert, get_connection
# from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG, USE_RDS_DIRECT

# try:
#     import yfinance as yf
#     YFINANCE_AVAILABLE = True
# except ImportError:
#     YFINANCE_AVAILABLE = False
#     print("⚠️  yfinance not available. Install with: pip install yfinance")


# def fetch_from_yfinance(ticker, max_retries=3):
#     """Fetch stock data from yfinance as fallback with retry logic."""
#     if not YFINANCE_AVAILABLE:
#         return None

#     for attempt in range(max_retries):
#         try:
#             if attempt > 0:
#                 delay = 10 * (attempt + 1)  # 10s, 20s, 30s delays
#                 print(f" (retry {attempt + 1}/{max_retries} after {delay}s)", end="")
#                 time.sleep(delay)

#             stock = yf.Ticker(ticker)
#             info = stock.info

#             # Check if we got valid data
#             if not info or len(info) < 5:
#                 if attempt < max_retries - 1:
#                     continue
#                 return None

#             # Map yfinance fields to FMP-like structure
#             profile = {
#                 'ticker': ticker,
#                 'symbol': ticker,
#                 'companyName': info.get('longName') or info.get('shortName', ticker),
#                 'exchangeShortName': info.get('exchange', ''),
#                 'exchange': info.get('exchange', ''),
#                 'sector': info.get('sector'),
#                 'industry': info.get('industry'),
#                 'currency': info.get('currency', 'USD'),
#                 'country': info.get('country'),
#                 'mktCap': info.get('marketCap', 0),
#                 'image': info.get('logo_url'),
#                 'website': info.get('website'),
#                 'description': info.get('longBusinessSummary', ''),
#                 'source': 'yfinance'
#             }
#             return profile

#         except Exception as e:
#             error_msg = str(e)
#             if '429' in error_msg or 'Too Many Requests' in error_msg:
#                 if attempt < max_retries - 1:
#                     print(f" (rate limit)", end="")
#                     continue
#                 else:
#                     print(f" ✗ Rate limit exceeded")
#                     return None
#             else:
#                 print(f" ✗ Error: {error_msg[:50]}")
#                 return None

#     return None


# def fetch_stock_metadata():
#     """Fetch stock metadata using FMP API with yfinance fallback."""
#     tickers = list(set(TICKER_MAPPINGS.values()))
#     profiles = []
#     failed_tickers = []

#     print(f"\nFetching metadata for {len(tickers)} stocks using FMP API...")
#     print(f"⏱️  Rate limit delay: {DATA_FETCH_CONFIG['rate_limit_delay']}s between requests\n")

#     for idx, ticker in enumerate(tickers, 1):
#         try:
#             print(f"[{idx}/{len(tickers)}] Fetching {ticker}...", end=" ")

#             # Try FMP first
#             data = fmp_request(f"/stable/profile", {'symbol': ticker})

#             # Check if we got valid data
#             if data and len(data) > 0:
#                 profile = data[0]
#                 profile['ticker'] = ticker
#                 profile['source'] = 'fmp'
#                 profiles.append(profile)

#                 company_name = profile.get('companyName', 'N/A')
#                 print(f"✓ {company_name} (FMP)")
#             else:
#                 print(f"✗ No FMP data", end="")
#                 failed_tickers.append(ticker)
#                 print()

#             # Rate limit delay (only if not the last ticker)
#             if idx < len(tickers):
#                 time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

#         except Exception as e:
#             print(f"✗ Error: {str(e)[:80]}")
#             failed_tickers.append(ticker)
#             continue

#     # Try yfinance for failed tickers
#     if failed_tickers and YFINANCE_AVAILABLE:
#         print(f"\n⚠️  Retrying {len(failed_tickers)} failed ticker(s) with yfinance...")
#         for ticker in failed_tickers:
#             print(f"  Fetching {ticker} from yfinance...", end=" ")
#             profile = fetch_from_yfinance(ticker)
#             if profile:
#                 profiles.append(profile)
#                 company_name = profile.get('companyName', 'N/A')
#                 print(f"✓ {company_name} (yfinance)")
#             else:
#                 print(f"✗ Failed")

#     print(f"\n✓ Successfully fetched {len(profiles)} of {len(tickers)} profiles")
#     return profiles


# def categorize_market_cap(market_cap):
#     """Categorize market cap into size categories."""
#     if not market_cap or market_cap == 0:
#         return None

#     # Convert to billions for easier categorization
#     cap_billions = market_cap / 1_000_000_000

#     if cap_billions >= 200:
#         return "Mega Cap"
#     elif cap_billions >= 10:
#         return "Large Cap"
#     elif cap_billions >= 2:
#         return "Mid Cap"
#     elif cap_billions >= 0.3:
#         return "Small Cap"
#     else:
#         return "Micro Cap"


# def transform_to_stocks(profiles):
#     """Transform FMP data to stocks table format."""
#     stocks_data = []

#     for profile in profiles:
#         ticker = profile.get('ticker', profile.get('symbol', ''))
#         exchange = profile.get('exchangeShortName', profile.get('exchange', ''))
#         company_name = profile.get('companyName', '')
#         sector = profile.get('sector')
#         currency = profile.get('currency', 'USD')
#         country = profile.get('country')
#         # FMP uses 'marketCap', yfinance uses 'mktCap'
#         market_cap = profile.get('marketCap', profile.get('mktCap', 0))
#         market_cap_category = categorize_market_cap(market_cap)
#         logo_url = profile.get('image')

#         stocks_data.append((
#             ticker,
#             exchange,
#             company_name,
#             sector,
#             currency,
#             country,
#             market_cap_category,
#             logo_url
#         ))

#     return stocks_data


# def transform_to_company_profile(profiles):
#     """Transform FMP data to company_profile table format."""
#     # First, get stock_id mapping from stocks table
#     conn = get_connection()
#     cur = conn.cursor()

#     if USE_RDS_DIRECT:
#         cur.execute("SELECT stock_id, ticker FROM ingest_db.stocks")
#     else:
#         cur.execute("SELECT stock_id, ticker FROM stocks")

#     stock_id_map = {ticker: stock_id for stock_id, ticker in cur.fetchall()}
#     conn.close()

#     company_data = []

#     for profile in profiles:
#         ticker = profile.get('ticker', profile.get('symbol', ''))
#         stock_id = stock_id_map.get(ticker)

#         if not stock_id:
#             print(f"  ⚠️  Stock ID not found for {ticker}, skipping company_profile insert")
#             continue

#         company_name = profile.get('companyName', '')
#         description = profile.get('description', '')
#         industry = profile.get('industry')
#         sector = profile.get('sector')
#         website = profile.get('website')
#         country = profile.get('country')

#         company_data.append((
#             stock_id,
#             ticker,
#             company_name,
#             description,
#             industry,
#             sector,
#             website,
#             country
#         ))

#     return company_data


# def load_stocks(stocks_data):
#     """Load stocks data into database."""
#     columns = [
#         'ticker', 'exchange', 'company_name', 'sector',
#         'currency_code', 'country', 'market_cap_category_name', 'logo_url'
#     ]

#     return smart_batch_insert('stocks', columns, stocks_data, conflict_columns=['ticker', 'exchange'])


# def load_company_profile(company_data):
#     """Load company_profile data into database."""
#     columns = [
#         'stock_id', 'ticker', 'company_name', 'description',
#         'industry', 'sector', 'website', 'country'
#     ]

#     # Don't specify conflict_columns since there's no unique constraint
#     return smart_batch_insert('company_profile', columns, company_data)


# def main():
#     """Main fetch function."""
#     print("\n" + "=" * 60)
#     print("FETCHING: Stocks & Company Profile from FMP API")
#     print("=" * 60)

#     # Fetch
#     print("\n[1/4] Fetching stock metadata...")
#     profiles = fetch_stock_metadata()

#     if not profiles:
#         print("\n❌ No profiles fetched. Check your API key or network connection.")
#         return

#     # Transform and load stocks
#     print("\n[2/4] Transforming and loading stocks...")
#     stocks_data = transform_to_stocks(profiles)
#     stocks_inserted = load_stocks(stocks_data)

#     # Transform and load company_profile
#     print("\n[3/4] Transforming and loading company_profile...")
#     company_data = transform_to_company_profile(profiles)
#     company_inserted = load_company_profile(company_data)

#     # Summary
#     print("\n[4/4] Summary:")
#     print(f"  Stocks inserted: {stocks_inserted}")
#     print(f"  Company profiles inserted: {company_inserted}")
#     print("=" * 60)


# if __name__ == "__main__":
#     main()


























"""
Fetch stocks & company profiles using FMP API + yfinance fallback.
Populates:
- ingest_db.stocks
- ingest_db.company_profile

STANDARDS:
- stocks table: UPSERT on (ticker, exchange)
- company_profile table: UPSERT on (stock_symbol)
- No duplicates ever
"""

import sys
from pathlib import Path
import time

sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request, get_connection
from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG, USE_RDS_DIRECT

# yfinance fallback
try:
    import yfinance as yf
    YFINANCE_AVAILABLE = True
except Exception:
    YFINANCE_AVAILABLE = False


# -------------------------------------------------------------------
# YFINANCE FALLBACK
# -------------------------------------------------------------------
def fetch_from_yfinance(ticker, retries=3):
    if not YFINANCE_AVAILABLE:
        return None

    for attempt in range(retries):
        try:
            if attempt > 0:
                delay = 5 * (attempt + 1)
                print(f" (retry {attempt}/{retries} after {delay}s)", end="")
                time.sleep(delay)

            stock = yf.Ticker(ticker)
            info = stock.info

            if not info:
                continue

            return {
                "ticker": ticker,
                "symbol": ticker,
                "companyName": info.get("longName") or info.get("shortName") or ticker,
                "exchangeShortName": info.get("exchange"),
                "sector": info.get("sector"),
                "industry": info.get("industry"),
                "currency": info.get("currency", "USD"),
                "country": info.get("country"),
                "marketCap": info.get("marketCap"),
                "image": info.get("logo_url"),
                "website": info.get("website"),
                "description": info.get("longBusinessSummary"),
                "ceo": info.get("companyOfficers", [{}])[0].get("name"),
                "fullTimeEmployees": info.get("fullTimeEmployees"),
                "beta": info.get("beta"),
                "financialScore": None,
                "source": "yfinance",
            }

        except Exception:
            continue

    return None


# -------------------------------------------------------------------
# FMP METADATA FETCH
# -------------------------------------------------------------------
def fetch_stock_metadata():
    tickers = list(set(TICKER_MAPPINGS.values()))
    profiles = []
    missing = []

    print(f"\nFetching metadata for {len(tickers)} stocks...\n")

    for idx, ticker in enumerate(tickers, 1):
        print(f"[{idx}/{len(tickers)}] Fetching {ticker}...", end=" ")

        data = fmp_request("/stable/profile", {"symbol": ticker})

        if data and len(data) > 0:
            profile = data[0]
            profile["ticker"] = ticker
            profile["source"] = "fmp"
            profiles.append(profile)
            print("✓ FMP")
        else:
            print("✗ FMP failed")
            missing.append(ticker)

        time.sleep(DATA_FETCH_CONFIG["rate_limit_delay"])

    # fallback to yfinance
    if missing:
        print(f"\nRetrying {len(missing)} missing tickers with yfinance...")

        for ticker in missing:
            print(f"  - {ticker}...", end=" ")
            profile = fetch_from_yfinance(ticker)

            if profile:
                profiles.append(profile)
                print("✓ yfinance")
            else:
                print("✗ failed")

    print(f"\n✓ {len(profiles)} profiles successfully retrieved")
    return profiles


# -------------------------------------------------------------------
# MARKET CAP CATEGORY
# -------------------------------------------------------------------
def market_cap_category(market_cap):
    if not market_cap:
        return None

    b = market_cap / 1_000_000_000

    if b >= 200:
        return "Mega Cap"
    if b >= 10:
        return "Large Cap"
    if b >= 2:
        return "Mid Cap"
    if b >= 0.3:
        return "Small Cap"
    return "Micro Cap"


# -------------------------------------------------------------------
# TRANSFORM PROFILES → STOCKS INSERT DATA
# -------------------------------------------------------------------
def to_stock_rows(profiles):
    rows = []

    for p in profiles:
        ticker = p.get("ticker") or p.get("symbol")
        exchange = p.get("exchangeShortName") or p.get("exchange", "")
        name = p.get("companyName")
        sector = p.get("sector")
        currency = p.get("currency", "USD")
        country = p.get("country")
        cap = p.get("marketCap")
        cap_cat = market_cap_category(cap)
        logo = p.get("image")

        rows.append(
            (
                ticker,
                exchange,
                name,
                sector,
                currency,
                country,
                cap_cat,
                logo,
            )
        )

    return rows


# -------------------------------------------------------------------
# TRANSFORM PROFILES → COMPANY PROFILE INSERT DATA
# -------------------------------------------------------------------
def to_company_rows(profiles, stock_id_map):
    rows = []

    for p in profiles:
        ticker = p.get("ticker") or p.get("symbol")
        stock_id = stock_id_map.get(ticker)

        if not stock_id:
            print(f"⚠️ Stock ID not found for {ticker}, skipping company_profile insert")
            continue

        rows.append(
            (
                stock_id,
                ticker,
                p.get("companyName"),
                p.get("description"),
                p.get("industry"),
                p.get("sector"),
                p.get("website"),
                p.get("country"),
            )
        )

    return rows


# -------------------------------------------------------------------
# UPSERT STOCKS
# -------------------------------------------------------------------
def load_stocks(stock_rows):
    conn = get_connection()
    cur = conn.cursor()

    sql = """
        INSERT INTO ingest_db.stocks (
            ticker, exchange, company_name, sector,
            currency_code, country, market_cap_category_name, logo_url
        )
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (ticker, exchange)
        DO UPDATE SET
            company_name = EXCLUDED.company_name,
            sector = EXCLUDED.sector,
            currency_code = EXCLUDED.currency_code,
            country = EXCLUDED.country,
            market_cap_category_name = EXCLUDED.market_cap_category_name,
            logo_url = EXCLUDED.logo_url;
    """

    for row in stock_rows:
        cur.execute(sql, row)

    conn.commit()

    # Load new mapping
    cur.execute("SELECT stock_id, ticker FROM ingest_db.stocks")
    mapping = {t: i for i, t in cur.fetchall()}

    cur.close()
    conn.close()
    return mapping


# -------------------------------------------------------------------
# UPSERT COMPANY PROFILE
# -------------------------------------------------------------------
def load_company_profile(rows):
    conn = get_connection()
    cur = conn.cursor()

    delete_sql = """
        DELETE FROM ingest_db.company_profile
        WHERE stock_id = %s;
    """

    insert_sql = """
        INSERT INTO ingest_db.company_profile (
            stock_id, ticker, company_name, description,
            industry, sector, website, country
        )
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s);
    """

    for row in rows:
        # Delete existing record if any
        cur.execute(delete_sql, (row[0],))
        # Insert new record
        cur.execute(insert_sql, row)

    conn.commit()
    cur.close()
    conn.close()


# -------------------------------------------------------------------
# MAIN
# -------------------------------------------------------------------
def main():
    print("\n===============================")
    print(" FETCHING STOCK METADATA")
    print("===============================\n")

    profiles = fetch_stock_metadata()
    if not profiles:
        print("❌ No profiles fetched.")
        return

    print("\nTransforming → stocks...")
    stock_rows = to_stock_rows(profiles)

    print("Loading → stocks (UPSERT)...")
    stock_id_map = load_stocks(stock_rows)

    print("\nTransforming → company_profile...")
    comp_rows = to_company_rows(profiles, stock_id_map)

    print("Loading → company_profile (UPSERT)...")
    load_company_profile(comp_rows)

    print("\n===============================")
    print(" ✓ COMPLETED: STOCK INGESTION")
    print("===============================\n")


if __name__ == "__main__":
    main()
