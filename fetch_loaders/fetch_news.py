"""
Fetch stock market news from Google RSS
OUTPUT GUARANTEED IDENTICAL TO SCRIPT 1
Populates: ingest_db.stocks_market_news
"""

import sys
from pathlib import Path
from datetime import datetime, timedelta
import feedparser
from psycopg2.extras import execute_batch

# --------------------------------------------------
# Add parent directory
# --------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection

# --------------------------------------------------
# CONFIG (MATCH SCRIPT 1)
# --------------------------------------------------
LOOKBACK_DAYS = 365
DRY_RUN = False

# --------------------------------------------------
# FETCH STOCK METADATA DYNAMICALLY FROM DB
# --------------------------------------------------
def _fetch_stock_meta():
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT stock_id, ticker, company_name
            FROM ingest_db.stocks
            WHERE is_peer = false
            ORDER BY stock_id
        """)
        result = {row[0]: {"ticker": row[1], "company": row[2]} for row in cur.fetchall()}
        cur.close()
        conn.close()
        print(f"[fetch_news] Loaded {len(result)} stocks from DB")
        return result
    except Exception as e:
        print(f"[fetch_news] Warning: Could not fetch stocks from DB: {e}")
        return {}

STOCK_META = _fetch_stock_meta()

# --------------------------------------------------
# SAFE TRUNCATION (MATCH SCRIPT 1)
# --------------------------------------------------
def safe_truncate(value, max_len):
    if value is None:
        return None
    value = str(value)
    return value if len(value) <= max_len else value[:max_len - 3] + "..."

# --------------------------------------------------
# GOOGLE RSS FETCH (IDENTICAL TO SCRIPT 1)
# --------------------------------------------------
def fetch_google_news(company_name, lookback_days):
    query = company_name.replace(" ", "%20")
    url = f"https://news.google.com/rss/search?q={query}&hl=en-US&gl=US&ceid=US:en"

    feed = feedparser.parse(url)
    cutoff = datetime.utcnow() - timedelta(days=lookback_days)

    results = []

    for entry in feed.entries:
        try:
            published = datetime(*entry.published_parsed[:6])
            if published < cutoff:
                continue

            title = entry.title
            source = "Unknown"
            if " - " in title:
                title, source = title.rsplit(" - ", 1)

            results.append({
                "headline": title.strip(),
                "source": source.strip(),
                "url": entry.link,
                "published_date": published.date(),
                "description": None,
            })
        except Exception:
            continue

    return results

# --------------------------------------------------
# MAIN INGESTION LOGIC (NOW IDENTICAL)
# --------------------------------------------------
def fetch_and_load_market_news():
    records = []

    print("\n======================================")
    print("FETCHING: Stock Market News")
    print("======================================\n")

    # 🔒 SAME ITERATION ORDER AS SCRIPT 1
    for stock_id, meta in STOCK_META.items():
        ticker = meta["ticker"]
        company = meta["company"]

        print(f"Fetching news for {company} ({ticker})...")
        items = fetch_google_news(company, LOOKBACK_DAYS)

        for n in items:
            records.append((
                stock_id,
                ticker,
                safe_truncate(n["headline"], 500),
                n["description"],
                safe_truncate(n["source"], 100),
                n["published_date"],
                safe_truncate(n["url"], 500),
                company,
                None,
                None,
                "google_link",
            ))

    print(f"\nPrepared {len(records)} news records")

    # --------------------------------------------------
    # DATABASE OPERATIONS (IDENTICAL DUPLICATE LOGIC)
    # --------------------------------------------------
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        print("\n✓ Connected to database")

        if DRY_RUN:
            print("\n⚠ DRY RUN MODE — NO DB CHANGES")
            for r in records[:5]:
                print(r)
            conn.rollback()
            return

        cur.execute("""
            SELECT stock_id, url, published_date
            FROM ingest_db.stocks_market_news
        """)
        existing_keys = set(cur.fetchall())
        print(f"Found {len(existing_keys)} existing records")

        records_to_insert = []
        duplicates = 0

        for r in records:
            key = (r[0], r[6], r[5])
            if key not in existing_keys:
                records_to_insert.append(r)
            else:
                duplicates += 1

        print(
            f"→ Inserting {len(records_to_insert)} new rows "
            f"(skipping {duplicates} duplicates)"
        )

        if records_to_insert:
            execute_batch(
                cur,
                """
                INSERT INTO ingest_db.stocks_market_news (
                    stock_id,
                    stock_symbol,
                    headline,
                    description,
                    source,
                    published_date,
                    url,
                    stock_company,
                    sentiment_score,
                    sentiment_label,
                    news_type
                )
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                """,
                records_to_insert,
                page_size=100,
            )
            conn.commit()
            print("✓ News ingestion completed")
        else:
            print("✓ No new records to insert")

    except Exception as e:
        print(f"\n✗ ERROR — rolled back: {e}")
        if conn:
            conn.rollback()

    finally:
        if conn:
            conn.close()
            print("✓ Connection closed")

# --------------------------------------------------
# ENTRY POINT
# --------------------------------------------------
def main():
    fetch_and_load_market_news()

if __name__ == "__main__":
    main()
