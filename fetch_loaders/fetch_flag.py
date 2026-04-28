"""
Detect Volume Spike flags for selected stocks
OUTPUT IDENTICAL to Aditya's script if same stocks are used
Populates: ingest_db.stocks_flags
"""

import sys
from pathlib import Path
import requests
import numpy as np
import yfinance as yf

# --------------------------------------------------
# Add parent directory to path
# --------------------------------------------------
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils import get_connection
from config import TICKER_MAPPINGS, FMP_API_KEY

# --------------------------------------------------
# Helpers (IDENTICAL)
# --------------------------------------------------
def classify_volume_zscore(today, mean_30d, std_30d):
    if std_30d == 0 or np.isnan(std_30d):
        return "Medium"

    z = (today - mean_30d) / std_30d

    if z < -1.0:
        return "Low"
    elif z <= 1.0:
        return "Medium"
    else:
        return "High"


def fetch_fmp_volumes(symbol):
    url = (
        "https://financialmodelingprep.com/stable/"
        f"historical-price-eod/full?symbol={symbol}&apikey={FMP_API_KEY}"
    )
    r = requests.get(url, timeout=15)
    r.raise_for_status()
    data = r.json() or []

    # EXACT MATCH — no filtering
    return [d["volume"] for d in data[:31]]


def fetch_yfinance_volumes(symbol):
    df = yf.download(symbol, period="2mo", progress=False)
    vols = df["Volume"].dropna().tolist()
    return vols[-31:]


def fetch_existing_flags(cursor, stock_ids):
    if not stock_ids:
        return set()

    placeholders = ",".join(["%s"] * len(stock_ids))
    cursor.execute(
        f"""
        SELECT stock_id, flag_type, flag_description
        FROM ingest_db.stocks_flags
        WHERE stock_id IN ({placeholders})
        """,
        tuple(stock_ids),
    )
    return {(r[0], r[1], r[2]) for r in cursor.fetchall()}


# --------------------------------------------------
# Main Logic (OUTPUT-COMPATIBLE)
# --------------------------------------------------
def fetch_and_load_volume_spike_flags():
    conn = get_connection()
    cur = conn.cursor()

    # --------------------------------------------------
    # Load stocks from DB using TICKER_MAPPINGS
    # --------------------------------------------------
    tickers = list(set(TICKER_MAPPINGS.values()))
    placeholders = ",".join(["%s"] * len(tickers))

    cur.execute(
        f"""
        SELECT stock_id, ticker
        FROM ingest_db.stocks
        WHERE ticker IN ({placeholders})
        """,
        tuple(tickers),
    )

    # Build STOCKS list EXACTLY like Aditya
    STOCKS = []
    for stock_id, ticker in cur.fetchall():
        source = "yfinance" if ticker == "6887.HK" else "fmp"
        STOCKS.append({
            "stock_id": stock_id,
            "symbol": ticker,
            "source": source
        })

    existing_flags = fetch_existing_flags(
        cur, [s["stock_id"] for s in STOCKS]
    )

    records = []
    skipped_duplicates = 0

    print("\n======================================")
    print("FETCHING: Volume Spike Flags")
    print("======================================\n")

    # --------------------------------------------------
    # MAIN LOOP (IDENTICAL + LOGGING)
    # --------------------------------------------------
    for stock in STOCKS:
        print(f"Processing {stock['symbol']}...")  # ✅ ADDED LINE

        try:
            if stock["source"] == "fmp":
                volumes = fetch_fmp_volumes(stock["symbol"])
            else:
                volumes = fetch_yfinance_volumes(stock["symbol"])

            if len(volumes) < 10:
                flag = "Low"  # EXACT MATCH
            else:
                today_vol = volumes[0]
                hist_vols = volumes[1:31]

                mean_30d = np.mean(hist_vols)
                std_30d = np.std(hist_vols, ddof=1)

                flag = classify_volume_zscore(
                    today_vol, mean_30d, std_30d
                )

            candidate = (stock["stock_id"], "Volume Spike", flag)

            if candidate in existing_flags:
                skipped_duplicates += 1
                continue

            existing_flags.add(candidate)
            records.append(candidate)

        except Exception as e:
            print(f"  ⚠ Failed for {stock['symbol']}: {e}")

            candidate = (stock["stock_id"], "Volume Spike", "Medium")
            if candidate in existing_flags:
                skipped_duplicates += 1
                continue

            existing_flags.add(candidate)
            records.append(candidate)

    # --------------------------------------------------
    # INSERT (IDENTICAL)
    # --------------------------------------------------
    if records:
        cur.executemany(
            """
            INSERT INTO ingest_db.stocks_flags (
                stock_id, flag_type, flag_description
            )
            VALUES (%s, %s, %s)
            ON CONFLICT DO NOTHING;
            """,
            records,
        )
        conn.commit()

        print(
            f"\nInserted {len(records)} new Volume Spike flags "
            f"(skipped {skipped_duplicates} duplicates)"
        )
    else:
        print(
            f"\nNo new Volume Spike flags to insert "
            f"(skipped {skipped_duplicates} duplicates)"
        )

    cur.close()
    conn.close()


# --------------------------------------------------
# Entry Point
# --------------------------------------------------
def main():
    fetch_and_load_volume_spike_flags()


if __name__ == "__main__":
    main()
