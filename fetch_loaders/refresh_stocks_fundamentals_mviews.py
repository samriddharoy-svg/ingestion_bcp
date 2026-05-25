"""
Refresh stock fundamentals related materialized views
Runs AFTER:
- ingest_db.stocks
- ingest_db.stocks_fundamentals

Uses:
SELECT semantic_db.refresh_mv_concurrently(schema, view_name);
"""

import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection


VIEWS_TO_REFRESH = [
    "mv_stocks_fundamentals_latest",
    "mv_stocks_dividend_trend_summary",
    "mv_stocks_ebitda_trend_summary",
    "mv_stocks_eps_trend_summary",
    "mv_stocks_free_cash_flow_trend_summary",
    "mv_stocks_price_trend_summary",
    "mv_stocks_return_of_capital_trend_summary",
    "mv_stocks_revenue_trend_summary",
    "mv_stocks_shares_outstanding_trend_summary",
]


def refresh_materialized_views():
    conn = get_connection()
    conn.autocommit = True  # REQUIRED for REFRESH CONCURRENTLY
    cur = conn.cursor()

    for view in VIEWS_TO_REFRESH:
        try:
            print(f"Refreshing: {view} ... ", end="", flush=True)

            cur.execute(
                "SELECT semantic_db.refresh_mv_concurrently(%s, %s);",
                ("semantic_db", view)
            )

            print("✓")

        except Exception as e:
            print("✗")
            print(f"❌ Failed to refresh {view}")
            raise e

    cur.close()
    conn.close()


def main():
    print("\n" + "=" * 50)
    print("REFRESHING STOCK FUNDAMENTALS MATERIALIZED VIEWS")
    print("=" * 50)

    refresh_materialized_views()

    print("\n✅ All stock fundamentals materialized views refreshed successfully\n")


if __name__ == "__main__":
    main()
