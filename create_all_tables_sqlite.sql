PRAGMA foreign_keys = ON;

-- ==========================
-- ingest_db equivalent tables
-- ==========================

-- 1) benchmark_history
CREATE TABLE IF NOT EXISTS benchmark_history (
    benchmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
    benchmark_name TEXT NOT NULL,
    valuation_date TEXT NOT NULL, -- ISO date string YYYY-MM-DD
    benchmark_value REAL NOT NULL,
    currency_code TEXT NOT NULL,
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE INDEX IF NOT EXISTS idx_benchmark_history_name_date ON benchmark_history(benchmark_name, valuation_date);

-- 2) company_profile
CREATE TABLE IF NOT EXISTS company_profile (
    company_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER, -- optional FK to stocks.stock_id
    ticker TEXT,
    company_name TEXT,
    description TEXT,
    industry TEXT,
    sector TEXT,
    website TEXT,
    country TEXT,
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE INDEX IF NOT EXISTS idx_company_profile_ticker ON company_profile(ticker);

-- 3) forex_rates
CREATE TABLE IF NOT EXISTS forex_rates (
    forex_id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_currency TEXT NOT NULL,
    target_currency TEXT NOT NULL,
    exchange_rate REAL NOT NULL,
    rate_date TEXT DEFAULT (DATETIME('now')),
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_forex_rates_src_tgt_date ON forex_rates(source_currency, target_currency, rate_date);
CREATE INDEX IF NOT EXISTS idx_forex_latest ON forex_rates(source_currency, target_currency, rate_date DESC);

-- 4) instrument_prices
CREATE TABLE IF NOT EXISTS instrument_prices (
    instrument_price_id INTEGER PRIMARY KEY AUTOINCREMENT,
    instrument_id INTEGER,
    price REAL,
    currency_code TEXT,
    captured_at TEXT DEFAULT (DATETIME('now')),
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE INDEX IF NOT EXISTS idx_instrument_prices_inst_time ON instrument_prices(instrument_id, captured_at DESC);

-- 5) instruments
CREATE TABLE IF NOT EXISTS instruments (
    instrument_id INTEGER PRIMARY KEY AUTOINCREMENT,
    instrument_code TEXT,
    instrument_name TEXT,
    currency_code TEXT,
    exchange TEXT,
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_instruments_code ON instruments(instrument_code);

-- 6) portfolio
CREATE TABLE IF NOT EXISTS portfolio (
    portfolio_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_name TEXT NOT NULL,
    owner_id TEXT,
    created_at TEXT DEFAULT (DATETIME('now'))
);

-- 7) portfolio_stocks (junction)
CREATE TABLE IF NOT EXISTS portfolio_stocks (
    portfolio_stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
    portfolio_id INTEGER NOT NULL,
    stock_id INTEGER NOT NULL,
    quantity REAL NOT NULL,
    avg_buy_price REAL NOT NULL,
    currency_code TEXT NOT NULL,
    last_updated TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(portfolio_id) REFERENCES portfolio(portfolio_id) ON DELETE CASCADE,
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_portfolio_stocks_portfolio ON portfolio_stocks(portfolio_id);
CREATE INDEX IF NOT EXISTS idx_portfolio_stocks_stock ON portfolio_stocks(stock_id);

-- 8) stocks
CREATE TABLE IF NOT EXISTS stocks (
    stock_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker TEXT NOT NULL,
    exchange TEXT,
    company_name TEXT,
    sector TEXT,
    currency_code TEXT NOT NULL,
    country TEXT,
    market_cap_category_name TEXT,
    logo_url TEXT,
    created_at TEXT DEFAULT (DATETIME('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_stocks_ticker_exchange ON stocks(ticker, exchange);
CREATE INDEX IF NOT EXISTS idx_stocks_sector ON stocks(sector);

-- 9) stocks_benchmark_mapping
CREATE TABLE IF NOT EXISTS stocks_benchmark_mapping (
    mapping_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER NOT NULL,
    benchmark_name TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stocks_benchmark_stock ON stocks_benchmark_mapping(stock_id);

-- 10) stocks_earnings_calendar
CREATE TABLE IF NOT EXISTS stocks_earnings_calendar (
    earnings_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    ticker TEXT,
    earnings_date TEXT NOT NULL,
    estimated_eps REAL,
    actual_eps REAL,
    currency_code TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_earnings_date ON stocks_earnings_calendar(earnings_date);

-- 11) stocks_flags
CREATE TABLE IF NOT EXISTS stocks_flags (
    flag_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    flag_type TEXT,
    flag_description TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stocks_flags_stock ON stocks_flags(stock_id);

-- 12) stocks_fundamentals
CREATE TABLE IF NOT EXISTS stocks_fundamentals (
    fundamentals_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    fiscal_date TEXT,
    metric_name TEXT,
    metric_value REAL,
    currency_code TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fundamentals_stock ON stocks_fundamentals(stock_id);

-- 13) stocks_market_alerts
CREATE TABLE IF NOT EXISTS stocks_market_alerts (
    alert_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    stock_symbol TEXT,
    alert_type TEXT,
    description TEXT,
    source TEXT,
    alert_date TEXT,
    severity TEXT,
    url TEXT,
    status TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_market_alerts_stock ON stocks_market_alerts(stock_id);
CREATE INDEX IF NOT EXISTS idx_market_alerts_date ON stocks_market_alerts(alert_date);

-- 14) stocks_market_news
CREATE TABLE IF NOT EXISTS stocks_market_news (
    news_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    stock_symbol TEXT,
    headline TEXT NOT NULL,
    description TEXT,
    source TEXT,
    published_date TEXT NOT NULL,
    url TEXT,
    related_company TEXT,
    sentiment_score REAL,
    sentiment_label TEXT,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_market_news_published_date ON stocks_market_news(published_date);

-- 15) stocks_price_data (history)
CREATE TABLE IF NOT EXISTS stocks_price_data (
    market_data_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    price REAL,
    opening_price REAL,
    closing_price REAL,
    day_price_change REAL,
    currency_code TEXT NOT NULL,
    day_price_change_pct REAL,
    volume INTEGER,
    volume_30d INTEGER,
    market_cap REAL,
    captured_at TEXT DEFAULT (DATETIME('now')),
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_price_data_stock_time ON stocks_price_data(stock_id, captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_price_data_captured_at ON stocks_price_data(captured_at DESC);

-- 16) stocks_upcoming_earnings
CREATE TABLE IF NOT EXISTS stocks_upcoming_earnings (
    upcoming_earnings_id INTEGER PRIMARY KEY AUTOINCREMENT,
    stock_id INTEGER,
    ticker TEXT NOT NULL,
    market_cap REAL,
    earnings_date TEXT NOT NULL,
    estimated_eps REAL,
    actual_eps REAL,
    currency_code TEXT NOT NULL,
    created_at TEXT DEFAULT (DATETIME('now')),
    FOREIGN KEY(stock_id) REFERENCES stocks(stock_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_upcoming_earnings_date ON stocks_upcoming_earnings(earnings_date);
