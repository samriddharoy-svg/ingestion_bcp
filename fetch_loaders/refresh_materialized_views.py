






"""
Safe refresh of materialized views

✔ Uses advisory lock
✔ Uses statement_timeout (no infinite block)
✔ Skips refresh if blocked
✔ ECS / Step Functions safe
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection

ADVISORY_LOCK_ID = 999999

REFRESH_QUERIES = [
    (
        "mv_instrument_price_volatility",
        "SELECT semantic_db.refresh_mv_concurrently('semantic_db','mv_instrument_price_volatility');"
    ),
    (
        "mv_stocks_price_volatility",
        "SELECT semantic_db.refresh_mv_concurrently('semantic_db','mv_stocks_price_volatility');"
    ),
    (
        "mv_stocks_price_data_latest",
        "SELECT semantic_db.refresh_mv_concurrently('semantic_db','mv_stocks_price_data_latest');"
    ),
    
]

def refresh_materialized_views():
    print("\n========================================")
    print("REFRESHING MATERIALIZED VIEWS")
    print("========================================")

    conn = get_connection()
    cur = conn.cursor()

    try:
        # 1️⃣ Acquire advisory lock
        cur.execute("SELECT pg_try_advisory_lock(%s);", (ADVISORY_LOCK_ID,))
        if not cur.fetchone()[0]:
            print("⚠️ Another refresh already running. Exiting.")
            return

        print("🔒 Advisory lock acquired")

        # 2️⃣ Set timeout (VERY IMPORTANT)
        cur.execute("SET statement_timeout = '5min';")

        for view_name, query in REFRESH_QUERIES:
            print(f"Refreshing: {view_name} ...", end=" ", flush=True)
            try:
                cur.execute(query)
                print("✓")
            except Exception as e:
                print("⚠️ SKIPPED (locked or timeout)")
                conn.rollback()
                break

        conn.commit()
        print("\n✅ Refresh cycle finished")

    finally:
        # 3️⃣ Always release lock
        try:
            cur.execute("SELECT pg_advisory_unlock(%s);", (ADVISORY_LOCK_ID,))
            conn.commit()
            print("🔓 Advisory lock released")
        except Exception:
            pass

        cur.close()
        conn.close()

def main():
    refresh_materialized_views()

if __name__ == "__main__":
    main()
