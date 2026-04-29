#!/bin/bash

# Database connection details
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="equities_first_dev_db"
DB_USER="ef_dev_user_rw"
DB_PASSWORD="ef_dev_user_rw@123!"

echo "Checking database data..."
echo "================================"

# Check stocks count
echo -e "\n1. Stocks count:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_stocks FROM ingest_db.stocks;"

# Check latest stocks
echo -e "\n2. Latest stocks:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT ticker, exchange, company_name, created_at FROM ingest_db.stocks ORDER BY created_at DESC LIMIT 5;"

# Check stocks_price_data count
echo -e "\n3. Stock price data count:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_price_records FROM ingest_db.stocks_price_data;"

# Check latest price data
echo -e "\n4. Latest price data (last 5 records):"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT s.ticker, spd.close_price, spd.volume, spd.captured_at FROM ingest_db.stocks_price_data spd JOIN ingest_db.stocks s ON spd.stock_id = s.stock_id ORDER BY spd.captured_at DESC LIMIT 5;"

# Check benchmark data count
echo -e "\n5. Benchmark history count:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_benchmark_records FROM ingest_db.benchmark_history;"

# Check latest benchmark data
echo -e "\n6. Latest benchmark data:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT b.benchmark_name, bh.close_price, bh.captured_at FROM ingest_db.benchmark_history bh JOIN ingest_db.benchmarks b ON bh.benchmark_id = b.benchmark_id ORDER BY bh.captured_at DESC LIMIT 5;"

# Check instruments price data
echo -e "\n7. Instrument price data count:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_instrument_prices FROM ingest_db.instruments_price_data;"

# Check company profiles
echo -e "\n8. Company profiles count:"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) as total_company_profiles FROM ingest_db.company_profile;"

echo -e "\n================================"
echo "Database check complete!"
