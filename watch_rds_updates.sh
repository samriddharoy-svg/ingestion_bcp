#!/bin/bash
# Watch RDS updates in real-time
# Usage: ./watch_rds_updates.sh

echo "🔄 Watching RDS for new data (press Ctrl+C to stop)..."
echo "======================================================================"

while true; do
    clear
    echo "🕐 Last check: $(date)"
    echo "======================================================================"

    python3 -c "
import psycopg2
from config import AWS_RDS
from datetime import datetime

conn = psycopg2.connect(**AWS_RDS)
cursor = conn.cursor()

# Check most recently updated records
tables = [
    ('stocks_price_data', 'captured_at'),
    ('stocks_market_alerts', 'created_at'),
    ('stocks_market_news', 'created_at'),
]

print('\n📊 Most Recent Updates:\n')
for table, ts_col in tables:
    cursor.execute(f'''
        SELECT COUNT(*) as count,
               MAX({ts_col}) as latest,
               COUNT(*) FILTER (WHERE {ts_col} >= NOW() - INTERVAL '1 hour') as last_hour,
               COUNT(*) FILTER (WHERE {ts_col} >= NOW() - INTERVAL '1 day') as last_day
        FROM ingest_db.{table}
    ''')
    total, latest, last_hour, last_day = cursor.fetchone()
    age = (datetime.now() - latest).total_seconds() / 60 if latest else 999999
    status = '🟢' if age < 60 else '🟡' if age < 1440 else '🔴'
    print(f'{status} {table:25s}: {total:6,} total | {last_hour:3} in last 1h | {last_day:4} in last 24h | Latest: {latest}')

conn.close()
" 2>/dev/null || echo "❌ Connection error"

    echo ""
    echo "======================================================================"
    echo "Refreshing in 30 seconds..."
    sleep 30
done
