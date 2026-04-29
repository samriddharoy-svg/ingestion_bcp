#!/usr/bin/env python3
"""
Verify fundamentals data in database
"""
import sys
from pathlib import Path
from tabulate import tabulate

sys.path.insert(0, str(Path(__file__).parent))

from utils import get_connection
from config import USE_RDS_DIRECT

conn = get_connection()
cur = conn.cursor()

print("\n" + "=" * 80)
print("FUNDAMENTALS DATA VERIFICATION")
print("=" * 80)

# Check by stock and metric type
print("\n📊 Records by Stock and Metric Type:")
print("-" * 80)

cur.execute("""
    SELECT
        s.ticker,
        f.metric_type,
        COUNT(*) as records,
        MIN(f.captured_date) as earliest,
        MAX(f.captured_date) as latest
    FROM ingest_db.stocks_fundamentals f
    JOIN ingest_db.stocks s ON f.stock_id = s.stock_id
    WHERE f.metric_category = 'Valuation'
    GROUP BY s.ticker, f.metric_type
    ORDER BY s.ticker, f.metric_type;
""")

results = cur.fetchall()
print(tabulate(results,
               headers=['Ticker', 'Metric Type', 'Records', 'Earliest Date', 'Latest Date'],
               tablefmt='grid'))

# Summary
print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)

cur.execute("""
    SELECT
        metric_type,
        COUNT(*) as total_records,
        COUNT(DISTINCT stock_id) as stocks
    FROM ingest_db.stocks_fundamentals
    WHERE metric_category = 'Valuation'
    GROUP BY metric_type
    ORDER BY metric_type;
""")

summary = cur.fetchall()
print(tabulate(summary,
               headers=['Metric Type', 'Total Records', 'Stocks'],
               tablefmt='simple'))

# Sample data
print("\n" + "=" * 80)
print("SAMPLE DATA (Latest 10 records)")
print("=" * 80)

cur.execute("""
    SELECT
        s.ticker,
        f.metric_type,
        f.metric_value,
        f.period_label,
        f.captured_date,
        f.created_at
    FROM ingest_db.stocks_fundamentals f
    JOIN ingest_db.stocks s ON f.stock_id = s.stock_id
    WHERE f.metric_category = 'Valuation'
    ORDER BY f.created_at DESC
    LIMIT 10;
""")

sample = cur.fetchall()
sample_display = []
for row in sample:
    sample_display.append([
        row[0],  # ticker
        row[1],  # metric_type
        f"{row[2]:.2f}",  # metric_value
        row[3],  # period_label
        row[4],  # captured_date
        row[5].strftime('%Y-%m-%d %H:%M:%S') if row[5] else None  # created_at
    ])

print(tabulate(sample_display,
               headers=['Ticker', 'Metric', 'Value', 'Year', 'Captured Date', 'Created At'],
               tablefmt='grid'))

cur.close()
conn.close()

print()
