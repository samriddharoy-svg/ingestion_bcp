-- PostgreSQL Schema for Stock Data Ingestion Pipeline
-- Schema: ingest_db
-- ==========================

-- Create schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS ingest_db;

-- Set search path
SET search_path TO ingest_db, public;

-- ==========================
-- ingest_db tables (ordered by dependencies)
-- ==========================

-- PARENT TABLES FIRST (no foreign keys to other ingest_db tables)

-- 1) stocks (MUST BE FIRST - referenced by many tables)
CREATE TABLE IF NOT EXISTS ingest_db.stocks (
    stock_id SERIAL PRIMARY KEY,
    ticker VARCHAR(20) NOT NULL,
    exchange VARCHAR(50),
    company_name TEXT,
    sector VARCHAR(255),
    currency_code VARCHAR(10) NOT NULL,
    country VARCHAR(100),
    market_cap_category_name VARCHAR(50),
    logo_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_stocks_ticker_exchange ON ingest_db.stocks(ticker, exchange);
CREATE INDEX IF NOT EXISTS idx_stocks_sector ON ingest_db.stocks(sector);

-- 2) portfolio
CREATE TABLE IF NOT EXISTS ingest_db.portfolio (
    portfolio_id SERIAL PRIMARY KEY,
    portfolio_name VARCHAR(255) NOT NULL,
    owner_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3) instruments
CREATE TABLE IF NOT EXISTS ingest_db.instruments (
    instrument_id SERIAL PRIMARY KEY,
    instrument_code VARCHAR(50),
    instrument_name VARCHAR(255),
    currency_code VARCHAR(10),
    exchange VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_instruments_code ON ingest_db.instruments(instrument_code);

-- 4) benchmark_history (no foreign keys)
CREATE TABLE IF NOT EXISTS ingest_db.benchmark_history (
    benchmark_id SERIAL PRIMARY KEY,
    benchmark_name VARCHAR(255) NOT NULL,
    valuation_date DATE NOT NULL,
    benchmark_value NUMERIC(20, 6) NOT NULL,
    currency_code VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_benchmark_history_name_date ON ingest_db.benchmark_history(benchmark_name, valuation_date);

-- 5) forex_rates (no foreign keys)
CREATE TABLE IF NOT EXISTS ingest_db.forex_rates (
    forex_id SERIAL PRIMARY KEY,
    source_currency VARCHAR(10) NOT NULL,
    target_currency VARCHAR(10) NOT NULL,
    exchange_rate NUMERIC(20, 10) NOT NULL,
    rate_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_forex_rates_src_tgt_date ON ingest_db.forex_rates(source_currency, target_currency, rate_date);
CREATE INDEX IF NOT EXISTS idx_forex_latest ON ingest_db.forex_rates(source_currency, target_currency, rate_date DESC);

-- CHILD TABLES (reference stocks, portfolio, instruments)

-- 6) company_profile (references stocks optionally)
CREATE TABLE IF NOT EXISTS ingest_db.company_profile (
    company_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    ticker VARCHAR(20),
    company_name TEXT,
    description TEXT,
    industry VARCHAR(255),
    sector VARCHAR(255),
    website VARCHAR(500),
    country VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_company_profile_ticker ON ingest_db.company_profile(ticker);

-- 7) portfolio_stocks (junction - references both portfolio and stocks)
CREATE TABLE IF NOT EXISTS ingest_db.portfolio_stocks (
    portfolio_stock_id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL,
    stock_id INTEGER NOT NULL,
    quantity NUMERIC(20, 6) NOT NULL,
    avg_buy_price NUMERIC(20, 6) NOT NULL,
    currency_code VARCHAR(10) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(portfolio_id) REFERENCES ingest_db.portfolio(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_portfolio_stocks_portfolio ON ingest_db.portfolio_stocks(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_stocks_stock ON ingest_db.portfolio_stocks(stock_id);

-- 8) instrument_prices (references instruments)
CREATE TABLE IF NOT EXISTS ingest_db.instrument_prices (
    instrument_price_id SERIAL PRIMARY KEY,
    instrument_id INTEGER,
    price NUMERIC(20, 6),
    currency_code VARCHAR(10),
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_instrument_prices_inst_time ON ingest_db.instrument_prices(instrument_id, captured_at DESC);

-- 9) stocks_benchmark_mapping (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_benchmark_mapping (
    mapping_id SERIAL PRIMARY KEY,
    stock_id INTEGER NOT NULL,
    benchmark_name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stocks_benchmark_stock ON ingest_db.stocks_benchmark_mapping(stock_id);

-- 10) stocks_earnings_calendar (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_earnings_calendar (
    earnings_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    ticker VARCHAR(20),
    earnings_date DATE NOT NULL,
    estimated_eps NUMERIC(20, 6),
    actual_eps NUMERIC(20, 6),
    currency_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_earnings_date ON ingest_db.stocks_earnings_calendar(earnings_date);

-- 11) stocks_flags (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_flags (
    flag_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    flag_type VARCHAR(100),
    flag_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stocks_flags_stock ON ingest_db.stocks_flags(stock_id);

-- 12) stocks_fundamentals (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_fundamentals (
    fundamentals_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    fiscal_date DATE,
    metric_name VARCHAR(255),
    metric_value NUMERIC(30, 6),
    currency_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fundamentals_stock ON ingest_db.stocks_fundamentals(stock_id);

-- 13) stocks_market_alerts (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_market_alerts (
    alert_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    stock_symbol VARCHAR(20),
    alert_type VARCHAR(100),
    description TEXT,
    source VARCHAR(255),
    alert_date DATE,
    severity VARCHAR(50),
    url TEXT,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_market_alerts_stock ON ingest_db.stocks_market_alerts(stock_id);
CREATE INDEX IF NOT EXISTS idx_market_alerts_date ON ingest_db.stocks_market_alerts(alert_date);

-- 14) stocks_market_news (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_market_news (
    news_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    stock_symbol VARCHAR(20),
    headline TEXT NOT NULL,
    description TEXT,
    source VARCHAR(255),
    published_date TIMESTAMP NOT NULL,
    url TEXT,
    related_company VARCHAR(255),
    sentiment_score NUMERIC(5, 2),
    sentiment_label VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_market_news_published_date ON ingest_db.stocks_market_news(published_date);

-- 15) stocks_price_data (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_price_data (
    market_data_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    price NUMERIC(20, 6),
    opening_price NUMERIC(20, 6),
    closing_price NUMERIC(20, 6),
    day_price_change NUMERIC(20, 6),
    currency_code VARCHAR(10) NOT NULL,
    day_price_change_pct NUMERIC(10, 4),
    volume BIGINT,
    volume_30d BIGINT,
    market_cap NUMERIC(30, 2),
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_price_data_stock_time ON ingest_db.stocks_price_data(stock_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_price_data_captured_at ON ingest_db.stocks_price_data(captured_at DESC);

-- 16) stocks_upcoming_earnings (references stocks)
CREATE TABLE IF NOT EXISTS ingest_db.stocks_upcoming_earnings (
    upcoming_earnings_id SERIAL PRIMARY KEY,
    stock_id INTEGER,
    ticker VARCHAR(20) NOT NULL,
    market_cap NUMERIC(30, 2),
    earnings_date DATE NOT NULL,
    estimated_eps NUMERIC(20, 6),
    actual_eps NUMERIC(20, 6),
    currency_code VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_upcoming_earnings_date ON ingest_db.stocks_upcoming_earnings(earnings_date);
