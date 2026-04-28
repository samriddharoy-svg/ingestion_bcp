"""
Fetch news data from FMP API
Populates: stocks_market_news table
"""
import sys
from pathlib import Path
import time

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import fmp_request, smart_batch_insert, get_connection
from config import TICKER_MAPPINGS, DATA_FETCH_CONFIG


def fetch_fmp_news(ticker, limit=50):
    """Fetch news from FMP API using /stable/stock_news endpoint."""
    try:
        data = fmp_request(f"/stable/stock_news", {'tickers': ticker, 'limit': limit})
        return data if data else []
    except Exception as e:
        print(f"      FMP Error: {e}")
        return []


def fetch_all_news():
    """Fetch news from FMP for all stocks."""
    tickers = list(set(TICKER_MAPPINGS.values()))

    # Get stock mapping
    conn = get_connection()
    cur = conn.cursor()

    from config import USE_]_DIRECT
    if USE_RDS_DIRECT:
        cur.execute("SELECT stock_id, ticker FROM ingest_db.stocks")
    else:
        cur.execute("SELECT stock_id, ticker FROM stocks")

    stock_map = {ticker: stock_id for stock_id, ticker in cur.fetchall()}
    conn.close()

    all_news = []
    seen_urls = set()  # Deduplicate by URL

    news_limit = DATA_FETCH_CONFIG.get('news_limit', 50)

    print(f"\nFetching news for {len(tickers)} stocks from FMP...")

    for ticker in tickers:
        if ticker not in stock_map:
            continue

        stock_id = stock_map[ticker]
        print(f"  Fetching {ticker}...")

        try:
            # Fetch from FMP
            fmp_news = fetch_fmp_news(ticker, news_limit)
            time.sleep(DATA_FETCH_CONFIG['rate_limit_delay'])

            for article in fmp_news:
                url = article.get('url', '')
                if url and url not in seen_urls:
                    seen_urls.add(url)
                    all_news.append((
                        stock_id,
                        ticker,
                        article.get('title', ''),
                        article.get('text', ''),  # FMP uses 'text' instead of 'description'
                        article.get('site', ''),  # FMP uses 'site' instead of 'source'
                        article.get('publishedDate', ''),
                        url,
                        ticker,
                        None,  # sentiment_score
                        None   # sentiment_label
                    ))

            print(f"    ✓ FMP news: {len(fmp_news)}")

        except Exception as e:
            print(f"    ✗ Error fetching {ticker}: {e}")
            continue

    print(f"\n✓ Total unique news articles: {len(all_news)}")
    return all_news


def main():
    """Main fetch function."""
    print("\n" + "=" * 60)
    print("FETCHING: News from FMP")
    print("=" * 60)

    # Fetch
    print("\n[1/2] Fetching news from FMP API...")
    news_data = fetch_all_news()

    if not news_data:
        print("No news data fetched. Exiting.")
        return

    # Load
    print("\n[2/2] Loading to database...")
    columns = [
        'stock_id', 'stock_symbol', 'headline', 'description',
        'source', 'published_date', 'url', 'related_company',
        'sentiment_score', 'sentiment_label'
    ]
    inserted = smart_batch_insert('stocks_market_news', columns, news_data)

    # Summary
    print("\nSummary:")
    print(f"  News articles inserted: {inserted}")
    print("=" * 60)


if __name__ == "__main__":
    main()
