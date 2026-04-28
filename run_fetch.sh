#!/bin/bash

# Set environment variables
export USE_RDS_DIRECT=true
export FMP_API_KEY=your_fmp_api_key
export TIINGO_API_KEY=your_tiingo_api_key
export RDS_HOST=localhost
export RDS_PORT=5432
export RDS_DATABASE=equities_first_dev_db
export RDS_USER=ef_dev_user_rw
export RDS_PASSWORD='ef_dev_user_rw@123!'
export RDS_SSL_MODE=disable

echo "Running fetch scripts..."

# Run scripts in order
echo "1. Fetching benchmarks..."
python fetch_loaders/fetch_benchmarks.py

echo "2. Fetching stocks..."
python fetch_loaders/fetch_stocks.py

echo "3. Fetching live prices..."
python fetch_loaders/fetch_live_prices.py

echo "4. Fetching instrument prices..."
python fetch_loaders/fetch_instrument_prices.py

echo "Done!"
