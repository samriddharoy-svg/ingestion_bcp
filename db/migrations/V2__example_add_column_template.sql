-- V2: Example migration — replace this with your actual DDL change.
-- File naming rule: V{number}__{description}.sql  (two underscores)
-- This file is just a template. Delete or replace it with a real change.

-- Example: add a column to stocks table
-- ALTER TABLE ingest_db.stocks ADD COLUMN market_cap BIGINT;

-- Example: create a new table
-- CREATE TABLE ingest_db.market_events (
--     event_id   SERIAL PRIMARY KEY,
--     ticker     VARCHAR(20) NOT NULL,
--     event_date DATE NOT NULL,
--     event_type VARCHAR(50),
--     created_at TIMESTAMP DEFAULT NOW()
-- );

-- Example: add an index
-- CREATE INDEX idx_market_events_ticker ON ingest_db.market_events(ticker);
