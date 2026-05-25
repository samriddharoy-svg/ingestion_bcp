#!/bin/bash

# Run fetch scripts locally (on Mac) while connecting to Docker PostgreSQL
# This works because yfinance works on your Mac but not in Docker

echo "======================================================================"
echo "          RUNNING FETCH SCRIPTS LOCALLY (OUTSIDE DOCKER)"
echo "======================================================================"
echo ""
echo "This script runs fetch scripts on your Mac (where yfinance works)"
echo "and connects to the PostgreSQL container running in Docker."
echo ""

# Check if PostgreSQL container is running
if ! docker ps | grep -q "stock-data-postgres"; then
    echo "❌ Error: PostgreSQL container is not running!"
    echo "Start it with: docker-compose -f docker-compose-rds.yml up postgres -d"
    exit 1
fi

echo "✅ PostgreSQL container is running"
echo ""

# Set environment variables to connect to Docker PostgreSQL
export USE_RDS_DIRECT=true
export RDS_HOST=localhost
export RDS_PORT=5433  # Mapped port from docker-compose
export RDS_DATABASE=equities_first_dev_db
export RDS_USER=ef_dev_user_rw
export RDS_PASSWORD='ef_dev_user_rw@123!'
export RDS_SSL_MODE=disable

# Load API keys from .env if exists
if [ -f .env ]; then
    echo "📄 Loading API keys from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  No .env file found. FMP and Tiingo APIs will not work."
fi

echo ""
echo "🔗 Connection settings:"
echo "  Host: localhost:5433"
echo "  Database: equities_first_dev_db"
echo "  User: ef_dev_user_rw"
echo ""

# Check if Python 3 and required packages are available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 not found!"
    echo "Install Python 3 first"
    exit 1
fi

echo "🐍 Checking Python dependencies..."
python3 -c "import yfinance, psycopg2, requests, pandas" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Some dependencies are missing. Installing..."
    pip3 install -r requirements.txt
fi

echo ""
echo "======================================================================"
echo "                    STARTING DATA FETCH"
echo "======================================================================"
echo ""

# Run fetch scripts in order (skip the ones that don't work without FMP)
echo "[1/3] Fetching stocks & company profiles..."
python3 fetch_loaders/fetch_stocks.py
STOCKS_EXIT=$?

if [ $STOCKS_EXIT -eq 0 ]; then
    echo ""
    echo "[2/3] Fetching benchmarks/instruments..."
    python3 fetch_loaders/fetch_benchmarks.py

    echo ""
    echo "[3/3] Fetching historical prices (batch download)..."
    python3 fetch_loaders/fetch_price_data.py
else
    echo ""
    echo "❌ Stocks fetch failed. Skipping dependent steps."
fi

echo ""
echo "======================================================================"
echo "                         COMPLETED"
echo "======================================================================"
echo ""
echo "📊 Check results:"
echo "  ./verify_infrastructure.sh"
echo ""
echo "Or query directly:"
echo "  docker exec stock-data-postgres psql -U ef_dev_user_rw -d equities_first_dev_db -c 'SELECT COUNT(*) FROM ingest_db.stocks;'"
echo ""
