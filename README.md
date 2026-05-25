# AWS RDS Data Ingestion Scripts

This folder contains organized ETL scripts for ingesting data from the local SQLite database to AWS RDS PostgreSQL.

## Folder Structure

```
ingestion/
├── config.py              # Centralized configuration
├── utils.py               # Common utility functions
├── run_all.py             # Master runner script
├── README.md              # This file
│
├── 01_portfolio/          # Portfolio-related tables
│   ├── ingest_portfolio.py
│   ├── ingest_stocks.py
│   └── ingest_portfolio_stocks.py
│
├── 02_prices/             # Price data tables
│   ├── ingest_instruments.py
│   ├── ingest_instrument_prices.py
│   └── ingest_stocks_price_data.py  # NOTE: Target table MISSING!
│
├── 03_forex/              # Currency exchange rates
│   └── ingest_forex_rates.py
│
└── 04_news_events/        # News and events
    ├── ingest_news.py
    ├── ingest_earnings_calendar.py
    └── ingest_stock_alerts.py
```

## Prerequisites

1. **Python packages:**
   ```bash
   pip install psycopg2-binary requests
   ```

2. **Environment variables (optional):**
   ```bash
   export FMP_API_KEY="your_api_key"
   ```

3. **Network access to AWS RDS**

## Usage

### Run All Scripts
```bash
python run_all.py
```

### Dry Run (check what will run)
```bash
python run_all.py --dry-run
```

### List Scripts
```bash
python run_all.py --list
```

### Run Individual Script
```bash
cd 01_portfolio
python ingest_portfolio.py
```

## Execution Order

Scripts must run in this order due to foreign key dependencies:

| Level | Scripts | Dependencies |
|-------|---------|--------------|
| 1 | `ingest_portfolio.py` | None |
| 1 | `ingest_stocks.py` | None |
| 1 | `ingest_instruments.py` | None |
| 1 | `ingest_forex_rates.py` | None |
| 2 | `ingest_portfolio_stocks.py` | portfolio, stocks |
| 2 | `ingest_stocks_price_data.py` | stocks |
| 2 | `ingest_instrument_prices.py` | instruments |
| 3 | `ingest_news.py` | stocks |
| 3 | `ingest_earnings_calendar.py` | stocks |
| 3 | `ingest_stock_alerts.py` | stocks |

## ⚠️ Known Issues

### Missing Table: `ingest_db.stocks_price_data`

The `stocks_price_data` table does not exist in AWS RDS. The ingestion script (`02_prices/ingest_stocks_price_data.py`) will:
1. Detect the missing table
2. Generate a `CREATE TABLE` SQL statement
3. Save it to `02_prices/CREATE_stocks_price_data.sql`

**Action Required:** Share the generated SQL with your DBA to create the table.

## Data Mapping Summary

| Source (SQLite) | Target (AWS RDS) | Rows |
|-----------------|------------------|------|
| portfolios | ingest_db.portfolio | 1 |
| stocks | ingest_db.stocks | 10 |
| portfolio_stock | ingest_db.portfolio_stocks | 10 |
| stock_price_history | ingest_db.stocks_price_data | ~11,000 |
| instruments | ingest_db.instruments | 5 |
| instrument_prices | ingest_db.instrument_prices | ~6,200 |
| forex_rates | ingest_db.forex_rates | ~138 |
| stock_news | ingest_db.news | varies |
| earnings_calendar | ingest_db.earnings_calendar | varies |
| stock_alerts | ingest_db.stock_alerts | varies |

## Configuration

Edit `config.py` to modify:
- AWS RDS connection details
- SQLite database path
- FMP API key
- Table name mappings
- Ticker/benchmark symbol mappings

## Extending Historical Data

Current data range: **5 years** (2020-11-26 to 2025-11-25)

To extend to 10 years:
1. Update the date range in `misc/fetch_data.py`
2. Re-fetch from FMP API
3. Run ingestion scripts again

## Troubleshooting

### Connection Issues
- Verify AWS RDS endpoint is accessible
- Check credentials in `config.py`
- Ensure PostgreSQL port 5432 is open

### Foreign Key Violations
- Run scripts in the correct order
- Ensure parent tables have data before child tables

### Data Type Mismatches
- Check column mappings in each script's `transform_data()` function
- Verify SQLite data types match PostgreSQL expectations
