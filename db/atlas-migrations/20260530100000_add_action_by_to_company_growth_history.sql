-- Add action_by column to ingest_db.company_growth_history
-- Tracks which user/process inserted or last modified the row.

ALTER TABLE ingest_db.company_growth_history
    ADD COLUMN IF NOT EXISTS action_by VARCHAR(255) DEFAULT NULL;
