#!/usr/bin/env python3
"""
Monitor RDS table updates - shows recent changes
"""
import psycopg2
from datetime import datetime, timedelta
from config import AWS_RDS
from tabulate import tabulate

def check_recent_updates():
    """Check which tables have been updated recently"""
    print("\n📊 CHECKING RECENT RDS TABLE UPDATES")
    print("=" * 80)

    try:
        conn = psycopg2.connect(
            host=AWS_RDS['host'],
            port=AWS_RDS['port'],
            database=AWS_RDS['database'],
            user=AWS_RDS['user'],
            password=AWS_RDS['password'],
            sslmode=AWS_RDS['sslmode']
        )
        cursor = conn.cursor()

        # Tables with timestamp columns
        tables_with_timestamps = {
            'stocks': 'created_at',
            'company_profile': 'created_at',
            'stocks_price_data': 'captured_at',
            'stocks_fundamentals': 'captured_at',
            'stocks_market_news': 'created_at',
            'stocks_market_alerts': 'created_at',
            'stocks_earnings_calendar': 'created_at',
            'stocks_upcoming_earnings': 'created_at',
            'benchmark_history': 'captured_at',
            'instrument_prices': 'captured_at',
            'instruments': 'created_at',
            'forex_rates': 'captured_at',
            'stocks_benchmark_mapping': 'created_at',
            'stocks_flags': 'created_at',
            'stocks_events': 'created_at',
            'chatroom_stocks_news_chat': 'created_at',
            'stocks_word_cloud_metrics': 'created_at',
        }

        now = datetime.now()
        recent_updates = []

        print(f"\nCurrent time: {now}\n")
        print("Checking tables for recent updates...")
        print("-" * 80)

        for table, timestamp_col in tables_with_timestamps.items():
            try:
                # Get total count and latest timestamp
                cursor.execute(f"""
                    SELECT
                        COUNT(*) as total_count,
                        MAX({timestamp_col}) as latest_update,
                        MIN({timestamp_col}) as earliest_update
                    FROM ingest_db.{table}
                """)
                result = cursor.fetchone()
                total_count, latest_update, earliest_update = result

                if total_count > 0 and latest_update:
                    time_diff = now - latest_update
                    hours_ago = time_diff.total_seconds() / 3600

                    # Count records from last 24 hours
                    cursor.execute(f"""
                        SELECT COUNT(*)
                        FROM ingest_db.{table}
                        WHERE {timestamp_col} >= NOW() - INTERVAL '24 hours'
                    """)
                    recent_count = cursor.fetchone()[0]

                    # Count records from last hour
                    cursor.execute(f"""
                        SELECT COUNT(*)
                        FROM ingest_db.{table}
                        WHERE {timestamp_col} >= NOW() - INTERVAL '1 hour'
                    """)
                    last_hour_count = cursor.fetchone()[0]

                    status = "🟢 FRESH" if hours_ago < 24 else "🟡 OLD" if hours_ago < 168 else "🔴 STALE"

                    recent_updates.append([
                        table,
                        f"{total_count:,}",
                        f"{last_hour_count:,}",
                        f"{recent_count:,}",
                        latest_update.strftime('%Y-%m-%d %H:%M:%S'),
                        f"{hours_ago:.1f}h ago",
                        status
                    ])

            except Exception as e:
                pass  # Skip tables that don't exist or have issues

        # Sort by latest update (most recent first)
        recent_updates.sort(key=lambda x: x[4], reverse=True)

        # Print results
        headers = ['Table', 'Total Rows', 'Last 1h', 'Last 24h', 'Latest Update', 'Age', 'Status']
        print(tabulate(recent_updates, headers=headers, tablefmt='grid'))

        # Summary statistics
        print("\n" + "=" * 80)
        print("📈 SUMMARY")
        print("=" * 80)

        fresh_count = sum(1 for x in recent_updates if '🟢' in x[6])
        old_count = sum(1 for x in recent_updates if '🟡' in x[6])
        stale_count = sum(1 for x in recent_updates if '🔴' in x[6])

        print(f"🟢 Fresh (< 24h):  {fresh_count} tables")
        print(f"🟡 Old (1-7 days): {old_count} tables")
        print(f"🔴 Stale (> 7d):   {stale_count} tables")

        conn.close()

    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    check_recent_updates()
