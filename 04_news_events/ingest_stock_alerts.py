"""
Ingest stock alerts from SQLite to AWS RDS
Table: ingest_db.stock_alerts
"""
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import (
    get_sqlite_connection, execute_batch_insert, 
    get_row_count, table_exists
)
from config import TABLES


def extract_from_sqlite():
    """Extract stock alerts data from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            alert_id,
            stock_id,
            alert_type,
            title,
            description,
            url,
            alert_date,
            is_read,
            severity,
            category
        FROM stock_alerts
    """)
    
    rows = cur.fetchall()
    conn.close()
    
    print(f"Extracted {len(rows)} stock alerts from SQLite")
    return rows


def transform_data(rows):
    """
    Transform data for AWS RDS format.
    
    SQLite columns → AWS RDS columns:
    alert_id → alert_id
    stock_id → stock_id
    alert_type → alert_type
    title → title
    description → description
    url → url
    alert_date → alert_date
    is_read → is_read
    severity → severity
    category → category
    """
    # Direct mapping - no transformation needed
    return rows


def load_to_aws(data):
    """Load data into AWS RDS."""
    table = TABLES['stock_alerts']
    
    if not table_exists(table):
        print(f"✗ Table {table} does not exist!")
        return 0
    
    columns = [
        'alert_id', 'stock_id', 'alert_type', 'title',
        'description', 'url', 'alert_date', 'is_read',
        'severity', 'category'
    ]
    
    return execute_batch_insert(table, columns, data)


def get_alert_stats():
    """Get alert statistics from SQLite."""
    conn = get_sqlite_connection()
    cur = conn.cursor()
    
    cur.execute("""
        SELECT 
            s.symbol,
            COUNT(*) as alert_count,
            SUM(CASE WHEN sa.severity = 'high' THEN 1 ELSE 0 END) as high_severity,
            SUM(CASE WHEN sa.severity = 'medium' THEN 1 ELSE 0 END) as medium_severity,
            SUM(CASE WHEN sa.severity = 'low' THEN 1 ELSE 0 END) as low_severity
        FROM stock_alerts sa
        JOIN stocks s ON sa.stock_id = s.stock_id
        GROUP BY s.symbol
        ORDER BY alert_count DESC
    """)
    
    stats = cur.fetchall()
    conn.close()
    return stats


def main():
    """Main ingestion function."""
    print("\n" + "=" * 60)
    print("INGESTING: ingest_db.stock_alerts")
    print("=" * 60)
    
    # Check current state
    table = TABLES['stock_alerts']
    current_count = get_row_count(table)
    print(f"Current rows in {table}: {current_count}")
    
    # Show alert stats
    print("\nAlert count by stock:")
    stats = get_alert_stats()
    if stats:
        for symbol, count, high, medium, low in stats:
            print(f"  {symbol}: {count} alerts (H:{high} M:{medium} L:{low})")
    else:
        print("  No alerts in SQLite")
    
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
