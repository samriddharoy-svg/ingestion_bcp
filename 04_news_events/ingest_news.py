"""
Ingest stock news from SQLite to AWS RDS
Table: ingest_db.news
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, get_aws_connection,
    execute_batch_insert, get_row_count, table_exists
)
from config import TABLES


def extract_from_sqlite():
    """Extract news data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            news_id,
            stock_id,
            published_date,
            title,
            text,
            url,
            symbol,
            site
        FROM stock_news
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} news articles from SQLite")
    return rows


def transform_data(rows):
    """
    Transform data for AWS RDS format.
    
    SQLite columns → AWS RDS columns:
    news_id → news_id
    stock_id → stock_id
    published_date → published_date
    title → title
    text → content (renamed)
    url → url
    symbol → symbol
    site → source (renamed)
    
    NEW AWS columns not in SQLite:
    - image_url (set NULL)
    - sentiment_score (set NULL)
    - sentiment_label (set NULL)
    """
    transformed = []
    
    for row in rows:
        (news_id, stock_id, published_date, title, 
         text, url, symbol, site) = row
        
        transformed.append((
            news_id,
            stock_id,
            published_date,
            title,
            text,           # → content
            url,
            None,           # image_url (not in SQLite)
            symbol,
            site,           # → source
            None,           # sentiment_score (not in SQLite)
            None            # sentiment_label (not in SQLite)
        ))
    
    return transformed


def load_to_aws(data, batch_size=100):
    """Load data into AWS RDS."""
    table = TABLES['news']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'news_id', 'stock_id', 'published_date', 'title',
        'content', 'url', 'image_url', 'symbol', 'source',
        'sentiment_score', 'sentiment_label'
    ]
    
    # Process in batches (news articles can be large)
    total_inserted = 0
    for i in range(0, len(data), batch_size):
        batch = data[i:i + batch_size]
        rows_inserted = execute_batch_insert(table, columns, batch)
        total_inserted += rows_inserted
    
    return total_inserted


def get_news_stats():
    """Get news statistics from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            s.symbol,
            COUNT(*) as article_count,
            MIN(sn.published_date) as earliest,
            MAX(sn.published_date) as latest
        FROM stock_news sn
        JOIN stocks s ON sn.stock_id = s.stock_id
        GROUP BY s.symbol
        ORDER BY article_count DESC
    """)
    
    stats = cur.fetchall()
    conn.close()
    return stats


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.news")
    print("=" * 60)
    
    # Check current state
    table = TABLES['news']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show news stats
    print("\nNews article count by stock:")
    stats = get_news_stats()
    for symbol, count, earliest, latest in stats:
        print(f"  {symbol}: {count} articles ({earliest} to {latest})")
    
    # Extract
    print("\n[1/3] Extracting from SQLite...")
    raw_data = extract_from_sqlite()
    
    if not raw_data:
        print("No data to ingest")
        return
    
    # Transform
    print("\n[2/3] Transforming data...")
    transformed_data = transform_data(raw_data)
    
    # Load
    print("\n[3/3] Loading to AWS RDS...")
    rows_inserted = load_to_aws(transformed_data)
    
    # Verify
    new_count = get_row_count(table)
    print(f"\nFinal rows in {table}: {new_count}")
    print("=" * 60)


if __name__ == "__main__":
    main()
