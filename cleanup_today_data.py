#!/usr/bin/env python3
"""
Cleanup today's data from RDS tables
This script removes any data with today's date, ensuring only yesterday or earlier data remains
"""
import psycopg2
from datetime import datetime, timedelta
from config import AWS_RDS

def cleanup_today_data():
    """Remove today's data from price tables."""
    print("\n🧹 CLEANING UP TODAY'S DATA FROM RDS")
    print("=" * 80)

    today = datetime.now().date()
    yesterday = (datetime.now() - timedelta(days=1)).date()

    print(f"\nToday: {today}")
    print(f"Yesterday: {yesterday}")
    print(f"\nRemoving all records with date >= {today}\n")

    conn = psycopg2.connect(
        host=AWS_RDS['host'],
        port=AWS_RDS['port'],
        database=AWS_RDS['database'],
        user=AWS_RDS['user'],
        password=AWS_RDS['password'],
        sslmode=AWS_RDS['sslmode']
    )
    cursor = conn.cursor()

    tables_to_clean = [
        ('stocks_price_data', 'captured_at', 'date'),
        ('instrument_prices', 'price_date', 'date'),
        ('benchmark_history', 'captured_at', 'timestamp'),
    ]

    total_deleted = 0

    for table, date_column, column_type in tables_to_clean:
        try:
            # Count records with today's date
            if column_type == 'date':
                cursor.execute(f"""
                    SELECT COUNT(*)
                    FROM ingest_db.{table}
                    WHERE {date_column} = %s
                """, (today,))
            else:  # timestamp
                cursor.execute(f"""
                    SELECT COUNT(*)
                    FROM ingest_db.{table}
                    WHERE {date_column}::date = %s
                """, (today,))

            count_before = cursor.fetchone()[0]

            if count_before == 0:
                print(f"✓ {table:30s}: No today's data found")
                continue

            # Delete today's records
            if column_type == 'date':
                cursor.execute(f"""
                    DELETE FROM ingest_db.{table}
                    WHERE {date_column} = %s
                """, (today,))
            else:  # timestamp
                cursor.execute(f"""
                    DELETE FROM ingest_db.{table}
                    WHERE {date_column}::date = %s
                """, (today,))

            conn.commit()
            deleted = cursor.rowcount
            total_deleted += deleted

            print(f"🗑️  {table:30s}: Deleted {deleted:,} records with today's date")

        except Exception as e:
            conn.rollback()
            print(f"❌ {table:30s}: Error - {str(e)[:50]}")

    # Show summary
    print("\n" + "=" * 80)
    print(f"✅ CLEANUP COMPLETE")
    print(f"   Total records deleted: {total_deleted:,}")
    print("=" * 80)

    # Verify - show latest dates now
    print("\n📊 VERIFICATION - Latest dates after cleanup:")
    print("-" * 80)

    verification_queries = [
        ('stocks_price_data', "SELECT MAX(captured_at::date) FROM ingest_db.stocks_price_data"),
        ('instrument_prices', "SELECT MAX(price_date) FROM ingest_db.instrument_prices"),
        ('benchmark_history', "SELECT MAX(captured_at::date) FROM ingest_db.benchmark_history"),
    ]

    for table_name, query in verification_queries:
        try:
            cursor.execute(query)
            max_date = cursor.fetchone()[0]
            status = "✅ GOOD (yesterday or earlier)" if max_date and max_date <= yesterday else "⚠️  NEEDS ATTENTION"
            print(f"  {table_name:30s}: {max_date} {status}")
        except Exception as e:
            print(f"  {table_name:30s}: Error - {str(e)[:50]}")

    conn.close()
    print("\n")


if __name__ == '__main__':
    cleanup_today_data()
