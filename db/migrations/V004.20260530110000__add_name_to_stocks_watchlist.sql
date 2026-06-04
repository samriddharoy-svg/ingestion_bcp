-- Add name column to ingest_db.stocks_watchlist

ALTER TABLE ingest_db.stocks_watchlist
    ADD COLUMN IF NOT EXISTS name VARCHAR(255) DEFAULT NULL;
