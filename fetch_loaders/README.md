# FMP/Tiingo Data Fetch Loaders

This directory contains Python scripts to fetch data from FMP (Financial Modeling Prep) and Tiingo APIs and populate SQLite tables.

## Overview

**Purpose:** Load data from external APIs into SQLite database tables at `misc/portfolio.db`

**API Sources:**
- FMP API (Financial Modeling Prep) - Stock data, prices, fundamentals, earnings, forex
- Tiingo API - News articles with sentiment data

## Tables Populated (13 tables)

1. **stocks** - Basic stock information
2. **company_profile** - Detailed company profiles
3. **stocks_price_data** - Historical OHLCV price data (10 years)
4. **stocks_fundamentals** - Financial metrics and ratios
5. **stocks_earnings_calendar** - Historical earnings releases
6. **stocks_upcoming_earnings** - Analyst earnings estimates
7. **stocks_market_news** - News articles from both APIs
8. **forex_rates** - Currency exchange rates
9. **instruments** - Benchmark/index definitions
10. **instrument_prices** - Historical benchmark prices
11. **benchmark_history** - Benchmark valuation history
12. **stocks_benchmark_mapping** - Stock-to-benchmark relationships
13. **stocks_flags** - Data quality flags

## Scripts

### Individual Scripts

| Script | Tables | Description |
|--------|--------|-------------|
| `fetch_stocks.py` | stocks, company_profile | Company info and profiles |
| `fetch_benchmarks.py` | instruments, instrument_prices, benchmark_history | Benchmark/index data |
| `fetch_mappings.py` | stocks_benchmark_mapping, stocks_flags | Mappings and data quality flags |
| `fetch_price_data.py` | stocks_price_data | 10 years of daily stock prices |
| `fetch_fundamentals.py` | stocks_fundamentals | Financial ratios and metrics |
| `fetch_earnings.py` | stocks_earnings_calendar, stocks_upcoming_earnings | Earnings data |
| `fetch_news.py` | stocks_market_news | News from FMP + Tiingo |
| `fetch_forex.py` | forex_rates | Currency exchange rates |

### Master Orchestrator

**`run_fetch_all.py`** - Runs all scripts in the correct dependency order

## Usage

### Run All Scripts (Recommended)

```bash
# From the ingestion/ directory
python run_fetch_all.py
```

### Run Individual Scripts

```bash
# From the ingestion/ directory
python fetch_loaders/fetch_stocks.py
python fetch_loaders/fetch_price_data.py
python fetch_loaders/fetch_news.py
# etc...
```

### Command Line Options

```bash
# Show what would be executed without running
python run_fetch_all.py --dry-run

# List all available scripts
python run_fetch_all.py --list

# Run only a specific script
python run_fetch_all.py --only stocks
python run_fetch_all.py --only news

# Skip a specific script
python run_fetch_all.py --skip fundamentals
```

## Execution Order

Scripts run in this dependency order:

1. **fetch_stocks.py** - Base tables (stocks must exist first)
2. **fetch_benchmarks.py** - Instruments must exist before mappings
3. **fetch_mappings.py** - Uses stocks and benchmarks
4. **fetch_price_data.py** - Historical price data (takes longest)
5. **fetch_fundamentals.py** - Financial metrics
6. **fetch_earnings.py** - Earnings data
7. **fetch_news.py** - News articles
8. **fetch_forex.py** - Forex rates

## Configuration

### API Keys

Located in `.env` file:
```
FMP_API_KEY=your_fmp_key_here
TIINGO_API_KEY=your_tiingo_key_here
```

### Data Fetch Settings

Located in `config.py`:
```python
DATA_FETCH_CONFIG = {
    'historical_years': 10,      # Years of historical data
    'start_date': '2015-01-01',  # Start date for historical data
    'end_date': '2025-01-01',    # End date
    'news_limit': 100,           # News articles per stock
    'earnings_history_years': 5, # Years of earnings history
    'batch_size': 1000,          # Batch insert size
    'rate_limit_delay': 0.3,     # Seconds between API calls
}
```

### Stock Universe

Configured in `config.py`:
```python
TICKER_MAPPINGS = {
    '0853.HK': '0853.HK',   # Hong Kong stocks
    '6887.HK': '6887.HK',
    '9618.HK': '9618.HK',
    '008930.KS': '008930.KS', # Korean stocks
    '068270.KS': '068270.KS',
    '032350.KS': '032350.KS',
    '5216.T': '5216.T',     # Japanese stocks
    '6098.T': '6098.T',
    'CS.SW': 'CS.ST',       # Swiss/European stocks
    'NB2.DE': 'NB2.DE',
}
```

## Expected Results

After a full run, you should have:

| Table | Expected Rows | Notes |
|-------|---------------|-------|
| stocks | 10 | One per ticker |
| company_profile | 10 | One per ticker |
| stocks_price_data | ~25,000 | 10 stocks × 2,500 trading days |
| stocks_fundamentals | ~500 | 10 stocks × ~50 metrics |
| stocks_market_news | ~1,000 | 10 stocks × 100 news articles |
| instruments | 5 | Benchmark indices |
| benchmark_history | ~12,500 | 5 indices × 2,500 days |
| instrument_prices | ~12,500 | Same as benchmark_history |
| forex_rates | 6 | Latest rates for 6 pairs |
| stocks_benchmark_mapping | 10 | One per stock |
| stocks_earnings_calendar | Varies | Historical earnings |
| stocks_upcoming_earnings | Varies | Analyst estimates |
| stocks_flags | Varies | Data quality issues |

## Estimated Runtime

- **Full run:** ~3-5 minutes
- **API calls:** ~121 total
- **Rate limiting:** 0.3 seconds between calls
- **Longest script:** fetch_price_data.py (10 years of data)

## Error Handling

- **Per-symbol errors:** Continue with next symbol
- **Rate limiting:** 0.3s delay between requests
- **Duplicates:** INSERT OR IGNORE prevents duplicates
- **Failed script:** Prompts user to continue or abort

## Data Quality

The `fetch_mappings.py` script auto-generates flags for:
- Missing logo URLs
- Missing sector information
- Missing market cap category

Check `stocks_flags` table after running.

## Troubleshooting

### No data fetched
- Check API keys in `.env`
- Verify API limits not exceeded
- Check ticker symbols in `TICKER_MAPPINGS`

### Duplicate key errors
- Scripts use INSERT OR IGNORE
- Safe to re-run without clearing tables

### Rate limit errors
- Increase `rate_limit_delay` in config
- Run scripts individually with delays

### Missing stock_id foreign key errors
- Ensure `fetch_stocks.py` runs first
- Check stocks table has data

## Notes

- Scripts are idempotent (safe to re-run)
- Uses INSERT OR IGNORE for upsert behavior
- Deduplicates news by URL
- Historical data: 10 years by default
- All timestamps in ISO format
