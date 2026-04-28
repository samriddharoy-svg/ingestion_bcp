#!/bin/bash
# Run fetch scripts in RDS-only mode (no SQLite)

export USE_RDS_DIRECT=true

echo "================================================================================================"
echo "RUNNING FETCH SCRIPTS - RDS MODE"
echo "================================================================================================"
echo ""
echo "Target Database: RDS PostgreSQL (ingest_db schema)"
echo "Host: equities-first-dev-db.craa4kqs0ndo.ap-south-1.rds.amazonaws.com"
echo ""
echo "================================================================================================"

# Run fetch scripts in order
echo ""
echo "[1/6] Fetching stocks and company profiles..."
python3 fetch_loaders/fetch_stocks.py

echo ""
echo "[2/6] Fetching fundamentals..."
python3 fetch_loaders/fetch_fundamentals.py

echo ""
echo "[3/6] Fetching price data..."
python3 fetch_loaders/fetch_price_data.py

echo ""
echo "[4/6] Fetching earnings data..."
python3 fetch_loaders/fetch_earnings.py

echo ""
echo "[5/6] Fetching benchmarks..."
python3 fetch_loaders/fetch_benchmarks.py

echo ""
echo "[6/6] Fetching forex rates..."
python3 fetch_loaders/fetch_forex.py

echo ""
echo "================================================================================================"
echo "ALL FETCH SCRIPTS COMPLETED!"
echo "================================================================================================"
echo ""
echo "To check the data in RDS, run:"
echo "  USE_RDS_DIRECT=true python3 check_tables.py"
