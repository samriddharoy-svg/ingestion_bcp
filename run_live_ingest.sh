#!/bin/bash
cd /Users/samriddha/Downloads/ingestion || exit 1

# Activate Python virtual environment
source venv/bin/activate

# Run the live ingestion script and append logs
python3 live_ingest_stock_prices.py >> live_ingest.log 2>&1
