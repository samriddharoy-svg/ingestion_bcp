--
-- PostgreSQL database dump
--

\restrict zd9204sNeatcb6Xm0WliN9Nan7R5ZyjCRa8zPFNyA730UP1abaPOVrrx3J88h1k

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: indexing_state; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA indexing_state;


--
-- Name: ingest_db; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ingest_db;


--
-- Name: semantic_db; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA semantic_db;


--
-- Name: transform_db; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA transform_db;


--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: notify_indexer(); Type: FUNCTION; Schema: indexing_state; Owner: -
--

CREATE FUNCTION indexing_state.notify_indexer() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    payload JSON;
    record_id TEXT;
BEGIN
    CASE
        WHEN TG_TABLE_NAME LIKE 'stocks_message_sentiments%'  THEN record_id := NEW.message_id::TEXT;
        WHEN TG_TABLE_NAME LIKE 'stocks_market_news%'         THEN record_id := NEW.news_id::TEXT;
        WHEN TG_TABLE_NAME LIKE 'stocks_events%'              THEN record_id := NEW.event_id::TEXT;
        WHEN TG_TABLE_NAME LIKE 'stocks_company_transcripts%' THEN record_id := NEW.transcript_id::TEXT;
        ELSE record_id := NEW.id::TEXT;
    END CASE;

    payload := json_build_object(
        'table', TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        'op',    TG_OP,
        'id',    record_id
    );

    PERFORM pg_notify('indexer_events', payload::text);
    RETURN NEW;
END;
$$;


--
-- Name: base_symbol_for_provider(text); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.base_symbol_for_provider(symbol_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN symbol_text IS NULL OR BTRIM(symbol_text) = '' THEN NULL
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.AD' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.AE' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.AX' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.TO' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.SS' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.SZ' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.DE' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.PA' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.HK' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.NS' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.BO' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.KS' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.KQ' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.AT' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.ST' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.L' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 2)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.T' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 2)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.V' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 2)
        WHEN UPPER(BTRIM(symbol_text)) LIKE '%.CN' THEN LEFT(UPPER(BTRIM(symbol_text)), LENGTH(BTRIM(symbol_text)) - 3)
        ELSE UPPER(BTRIM(symbol_text))
    END
$$;


--
-- Name: country_display_name_from_code(text); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.country_display_name_from_code(country_code text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE UPPER(TRIM(COALESCE(country_code, '')))
        WHEN '' THEN NULL
        WHEN 'AE' THEN 'United Arab Emirates'
        WHEN 'AU' THEN 'Australia'
        WHEN 'CA' THEN 'Canada'
        WHEN 'CN' THEN 'China'
        WHEN 'DE' THEN 'Germany'
        WHEN 'FR' THEN 'France'
        WHEN 'GB' THEN 'United Kingdom'
        WHEN 'GR' THEN 'Greece'
        WHEN 'HK' THEN 'Hong Kong'
        WHEN 'IN' THEN 'India'
        WHEN 'JP' THEN 'Japan'
        WHEN 'KR' THEN 'South Korea'
        WHEN 'SE' THEN 'Sweden'
        WHEN 'US' THEN 'United States'
        ELSE NULLIF(TRIM(country_code), '')
    END
$$;


--
-- Name: fill_canonical_ticker_from_stock(); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.fill_canonical_ticker_from_stock() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.stock_id IS NOT NULL THEN
        SELECT COALESCE(s.canonical_ticker, s.canonical_symbol, s.ticker)
          INTO NEW.canonical_ticker
        FROM ingest_db.stocks s
        WHERE s.stock_id = NEW.stock_id;
    END IF;

    NEW.canonical_ticker := COALESCE(NEW.canonical_ticker, NEW.ticker);
    RETURN NEW;
END;
$$;


--
-- Name: fn_enqueue_stock_ingestion_event_outbox(); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.fn_enqueue_stock_ingestion_event_outbox() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO ingest_db.stock_ingestion_event_outbox (
        event_id,
        publish_status,
        retry_count,
        next_retry_at,
        created_at,
        updated_at
    )
    VALUES (
        NEW.event_id,
        'pending',
        0,
        now(),
        now(),
        now()
    )
    ON CONFLICT (event_id) DO NOTHING;

    RETURN NEW;
END;
$$;


--
-- Name: market_code_for_symbol(text, text, text); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.market_code_for_symbol(symbol_text text, exchange_code_text text, country_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(
        CASE UPPER(TRIM(COALESCE(exchange_code_text, '')))
            WHEN 'ADX' THEN 'AE'
            WHEN 'DFM' THEN 'AE'
            WHEN 'ASX' THEN 'AU'
            WHEN 'TSX' THEN 'CA'
            WHEN 'TSXV' THEN 'CA'
            WHEN 'CNQ' THEN 'CA'
            WHEN 'NEO' THEN 'CA'
            WHEN 'SHH' THEN 'CN'
            WHEN 'SHZ' THEN 'CN'
            WHEN 'XETRA' THEN 'DE'
            WHEN 'PAR' THEN 'FR'
            WHEN 'LSE' THEN 'GB'
            WHEN 'HKSE' THEN 'HK'
            WHEN 'HKG' THEN 'HK'
            WHEN 'BSE' THEN 'IN'
            WHEN 'NSE' THEN 'IN'
            WHEN 'JPX' THEN 'JP'
            WHEN 'TSE' THEN 'JP'
            WHEN 'KOE' THEN 'KR'
            WHEN 'KSC' THEN 'KR'
            WHEN 'KRX' THEN 'KR'
            WHEN 'ATH' THEN 'GR'
            WHEN 'STO' THEN 'SE'
            WHEN 'NASDAQ' THEN 'US'
            WHEN 'NYSE' THEN 'US'
            WHEN 'OTC' THEN 'US'
            WHEN 'US' THEN 'US'
            ELSE NULL
        END,
        CASE
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.AD' THEN 'AE'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.AE' THEN 'AE'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.AX' THEN 'AU'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.TO' THEN 'CA'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.V' THEN 'CA'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.CN' THEN 'CA'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.SS' THEN 'CN'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.SZ' THEN 'CN'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.DE' THEN 'DE'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.PA' THEN 'FR'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.L' THEN 'GB'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.HK' THEN 'HK'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.NS' THEN 'IN'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.BO' THEN 'IN'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.T' THEN 'JP'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.KS' THEN 'KR'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.KQ' THEN 'KR'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.AT' THEN 'GR'
            WHEN UPPER(TRIM(COALESCE(symbol_text, ''))) LIKE '%.ST' THEN 'SE'
            ELSE NULL
        END,
        ingest_db.normalize_country_code(country_text)
    )
$$;


--
-- Name: normalize_country_code(text); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.normalize_country_code(country_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE UPPER(TRIM(COALESCE(country_text, '')))
        WHEN '' THEN NULL
        WHEN 'USA' THEN 'US'
        WHEN 'UNITED STATES' THEN 'US'
        WHEN 'US' THEN 'US'
        WHEN 'UK' THEN 'GB'
        WHEN 'UNITED KINGDOM' THEN 'GB'
        WHEN 'GB' THEN 'GB'
        WHEN 'UAE' THEN 'AE'
        WHEN 'UNITED ARAB EMIRATES' THEN 'AE'
        WHEN 'AE' THEN 'AE'
        WHEN 'JA' THEN 'JP'
        WHEN 'JAPAN' THEN 'JP'
        WHEN 'JP' THEN 'JP'
        WHEN 'HONG KONG' THEN 'HK'
        WHEN 'HK' THEN 'HK'
        WHEN 'SOUTH KOREA' THEN 'KR'
        WHEN 'KOREA' THEN 'KR'
        WHEN 'KR' THEN 'KR'
        WHEN 'CANADA' THEN 'CA'
        WHEN 'CA' THEN 'CA'
        WHEN 'CHINA' THEN 'CN'
        WHEN 'CN' THEN 'CN'
        WHEN 'INDIA' THEN 'IN'
        WHEN 'IN' THEN 'IN'
        WHEN 'AUSTRALIA' THEN 'AU'
        WHEN 'AU' THEN 'AU'
        WHEN 'GREECE' THEN 'GR'
        WHEN 'GR' THEN 'GR'
        WHEN 'GERMANY' THEN 'DE'
        WHEN 'DE' THEN 'DE'
        WHEN 'FRANCE' THEN 'FR'
        WHEN 'FR' THEN 'FR'
        WHEN 'SWEDEN' THEN 'SE'
        WHEN 'SE' THEN 'SE'
        ELSE CASE
            WHEN LENGTH(UPPER(TRIM(COALESCE(country_text, '')))) = 2 THEN UPPER(TRIM(country_text))
            ELSE NULL
        END
    END
$$;


--
-- Name: portfolio_stocks_fill_country_metadata(); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.portfolio_stocks_fill_country_metadata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.stock_id IS NOT NULL THEN
        SELECT
            COALESCE(s.currency_code, NEW.currency_code),
            COALESCE(s.country_name, NEW.country_name),
            COALESCE(s.country_name_display, NEW.country_name_display, s.country_name, NEW.country_name)
        INTO
            NEW.currency_code,
            NEW.country_name,
            NEW.country_name_display
        FROM ingest_db.stocks s
        WHERE s.stock_id = NEW.stock_id;
    END IF;

    NEW.country_name_display := COALESCE(NEW.country_name_display, NEW.country_name);
    RETURN NEW;
END;
$$;


--
-- Name: resolve_ticker_candidates(text); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.resolve_ticker_candidates(input_ticker text) RETURNS TABLE(input_value text, match_rank integer, matched_by text, canonical_symbol character varying, base_symbol character varying, symbol character varying, exchange_code character varying, company_name character varying, market_code character varying, country_code character varying, country_name_display character varying, provider_name character varying, provider_symbol character varying, provider_exchange_code character varying, stock_id integer, canonical_symbol_candidate_count bigint, base_symbol_candidate_count bigint, is_ambiguous boolean)
    LANGUAGE sql STABLE
    AS $$
    WITH normalized AS (
        SELECT UPPER(BTRIM(COALESCE(input_ticker, ''))) AS value
    ),
    matches AS (
        SELECT
            v.*,
            COUNT(*) OVER (PARTITION BY UPPER(v.symbol)) AS provider_symbol_candidate_count
        FROM semantic_db.vw_ticker_resolution_catalog v
    )
    SELECT
        normalized.value AS input_value,
        CASE
            WHEN matches.canonical_symbol = normalized.value THEN 1
            WHEN UPPER(matches.symbol) = normalized.value THEN 2
            WHEN UPPER(matches.base_symbol) = normalized.value THEN 3
            ELSE 9
        END AS match_rank,
        CASE
            WHEN matches.canonical_symbol = normalized.value THEN 'canonical_symbol'
            WHEN UPPER(matches.symbol) = normalized.value THEN 'provider_symbol'
            WHEN UPPER(matches.base_symbol) = normalized.value THEN 'base_symbol'
            ELSE 'search'
        END AS matched_by,
        matches.canonical_symbol,
        matches.base_symbol,
        matches.symbol,
        matches.exchange_code,
        matches.company_name,
        matches.market_code,
        matches.country_code,
        matches.country_name_display,
        matches.provider_name,
        matches.provider_symbol,
        matches.provider_exchange_code,
        matches.stock_id,
        matches.canonical_symbol_candidate_count,
        matches.base_symbol_candidate_count,
        CASE
            WHEN matches.canonical_symbol = normalized.value THEN matches.canonical_symbol_candidate_count > 1
            WHEN UPPER(matches.symbol) = normalized.value THEN matches.provider_symbol_candidate_count > 1
            WHEN UPPER(matches.base_symbol) = normalized.value THEN matches.base_symbol_candidate_count > 1
            ELSE matches.is_ambiguous
        END AS is_ambiguous
    FROM matches
    CROSS JOIN normalized
    WHERE normalized.value <> ''
      AND (
          matches.canonical_symbol = normalized.value
          OR UPPER(matches.symbol) = normalized.value
          OR UPPER(matches.base_symbol) = normalized.value
      )
    ORDER BY match_rank, matches.canonical_symbol, matches.symbol, matches.exchange_code;
$$;


--
-- Name: stocks_fill_canonical_columns(); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.stocks_fill_canonical_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.market_code := ingest_db.market_code_for_symbol(NEW.ticker, NEW.exchange, NEW.country_name);
    NEW.country_code := COALESCE(
        ingest_db.normalize_country_code(NEW.country_name),
        NEW.market_code
    );
    NEW.country_name_display := ingest_db.country_display_name_from_code(
        COALESCE(NEW.market_code, NEW.country_code)
    );
    NEW.canonical_symbol := CASE
        WHEN ingest_db.base_symbol_for_provider(NEW.ticker) IS NOT NULL AND NEW.market_code IS NOT NULL
        THEN ingest_db.base_symbol_for_provider(NEW.ticker) || '.' || NEW.market_code
        ELSE NULL
    END;
    NEW.canonical_ticker := COALESCE(NEW.canonical_symbol, NEW.canonical_ticker);
    RETURN NEW;
END;
$$;


--
-- Name: ticker_list_fill_canonical_columns(); Type: FUNCTION; Schema: ingest_db; Owner: -
--

CREATE FUNCTION ingest_db.ticker_list_fill_canonical_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.base_symbol := ingest_db.base_symbol_for_provider(NEW.symbol);
    NEW.market_code := ingest_db.market_code_for_symbol(NEW.symbol, NEW.exchange_code, NEW.country);
    NEW.country_code := COALESCE(
        ingest_db.normalize_country_code(NEW.country),
        NEW.market_code
    );
    NEW.country_name_display := ingest_db.country_display_name_from_code(
        COALESCE(NEW.market_code, NEW.country_code)
    );
    NEW.canonical_symbol := CASE
        WHEN NEW.base_symbol IS NOT NULL AND NEW.market_code IS NOT NULL
        THEN NEW.base_symbol || '.' || NEW.market_code
        ELSE NULL
    END;
    NEW.canonical_ticker := COALESCE(NEW.canonical_symbol, NEW.canonical_ticker);
    NEW.provider_name := COALESCE(NEW.provider_name, NEW.data_source);
    NEW.provider_symbol := COALESCE(NEW.provider_symbol, UPPER(BTRIM(NEW.symbol)));
    NEW.provider_exchange_code := COALESCE(NEW.provider_exchange_code, NULLIF(UPPER(BTRIM(NEW.exchange_code)), ''));
    NEW.alias_type := COALESCE(NEW.alias_type, 'provider_alias');
    NEW.is_active := COALESCE(NEW.is_active, TRUE);
    NEW.is_primary_resolution := COALESCE(NEW.is_primary_resolution, TRUE);
    RETURN NEW;
END;
$$;


--
-- Name: refresh_mv(text); Type: FUNCTION; Schema: semantic_db; Owner: -
--

CREATE FUNCTION semantic_db.refresh_mv(mv_name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    EXECUTE format('REFRESH MATERIALIZED VIEW %I', mv_name);
END;
$$;


--
-- Name: refresh_mv(text, text); Type: FUNCTION; Schema: semantic_db; Owner: -
--

CREATE FUNCTION semantic_db.refresh_mv(mv_schema text, mv_name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    EXECUTE format('REFRESH MATERIALIZED VIEW %I.%I', mv_schema,mv_name);
END;
$$;


--
-- Name: refresh_mv_concurrently(text, text); Type: FUNCTION; Schema: semantic_db; Owner: -
--

CREATE FUNCTION semantic_db.refresh_mv_concurrently(mv_schema text, mv_name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY %I.%I', mv_schema, mv_name);
END;
$$;


--
-- Name: truncate_and_restart_identity(text, text); Type: FUNCTION; Schema: semantic_db; Owner: -
--

CREATE FUNCTION semantic_db.truncate_and_restart_identity(schema_name text, table_name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    EXECUTE format('TRUNCATE TABLE %I.%I RESTART IDENTITY', schema_name,table_name);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: indexed_records; Type: TABLE; Schema: indexing_state; Owner: -
--

CREATE TABLE indexing_state.indexed_records (
    id bigint NOT NULL,
    source_type character varying(50) NOT NULL,
    source_id character varying(255) NOT NULL,
    stock_id integer NOT NULL,
    pinecone_namespace character varying(255) NOT NULL,
    vector_ids text[],
    content_hash character varying(64),
    indexed_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    status character varying(20) DEFAULT 'indexed'::character varying,
    error_message text,
    retry_count integer DEFAULT 0
);


--
-- Name: indexed_records_id_seq; Type: SEQUENCE; Schema: indexing_state; Owner: -
--

CREATE SEQUENCE indexing_state.indexed_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: indexed_records_id_seq; Type: SEQUENCE OWNED BY; Schema: indexing_state; Owner: -
--

ALTER SEQUENCE indexing_state.indexed_records_id_seq OWNED BY indexing_state.indexed_records.id;


--
-- Name: indexing_jobs; Type: TABLE; Schema: indexing_state; Owner: -
--

CREATE TABLE indexing_state.indexing_jobs (
    job_id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_type character varying(50) NOT NULL,
    source_type character varying(50),
    stock_id integer,
    started_at timestamp without time zone DEFAULT now(),
    completed_at timestamp without time zone,
    total_records integer,
    indexed_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    status character varying(20) DEFAULT 'running'::character varying
);


--
-- Name: benchmark_history; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.benchmark_history (
    benchmark_id integer NOT NULL,
    benchmark_name character varying(100) NOT NULL,
    valuation_date date NOT NULL,
    benchmark_value numeric(18,2) NOT NULL,
    currency_code character(3) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: benchmark_history_benchmark_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.benchmark_history ALTER COLUMN benchmark_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.benchmark_history_benchmark_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chatroom_ai_chat_interactions; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_ai_chat_interactions (
    chat_id uuid,
    user_id character varying(50),
    session_id uuid,
    conversation jsonb,
    stock_id integer,
    message_time timestamp without time zone NOT NULL,
    context jsonb,
    metadata jsonb
);


--
-- Name: chatroom_ai_chat_interactions_bkp_18jan2026; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_ai_chat_interactions_bkp_18jan2026 (
    chat_id integer,
    stock_id integer,
    sender_type character varying(20),
    user_id character varying(50),
    message_text text,
    message_time timestamp without time zone,
    context_topic character varying(100),
    metadata jsonb
);


--
-- Name: chatroom_stocks_news_chat; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
)
PARTITION BY HASH (stock_id);


--
-- Name: chatroom_stocks_news_chat_bkp_20260415; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_bkp_20260415 (
    message_id integer,
    stock_id integer,
    username character varying(100),
    message_text text,
    source character varying(100),
    message_time timestamp without time zone,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_bkp_20260418; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_bkp_20260418 (
    message_id integer,
    stock_id integer,
    username character varying(100),
    message_text text,
    source character varying(100),
    message_time timestamp without time zone,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_bkp_predups_20260427_194115; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_bkp_predups_20260427_194115 (
    message_id integer,
    stock_id integer,
    username character varying(100),
    message_text text,
    source character varying(100),
    message_time timestamp without time zone,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_message_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.chatroom_stocks_news_chat ALTER COLUMN message_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.chatroom_stocks_news_chat_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chatroom_stocks_news_chat_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p0 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p1 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p2 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p3 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p4 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p5 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p6 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p7 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p8 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: chatroom_stocks_news_chat_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.chatroom_stocks_news_chat_p9 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    username character varying(100),
    message_text text NOT NULL,
    source character varying(100),
    message_time timestamp without time zone NOT NULL,
    likes_count integer,
    dislikes_count integer,
    platform character varying(50),
    country character varying(20),
    source_url text,
    main_source_url text
);


--
-- Name: company_executive_summary; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.company_executive_summary (
    summary_id integer NOT NULL,
    stock_id integer,
    fiscal_year character varying(10) NOT NULL,
    total_revenue numeric(18,2),
    gross_profit numeric(18,2),
    operating_income numeric(18,2),
    net_income numeric(18,2),
    narrative text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: company_executive_summary_summary_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.company_executive_summary ALTER COLUMN summary_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.company_executive_summary_summary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: company_growth_history; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.company_growth_history (
    growth_id integer NOT NULL,
    stock_id integer,
    fiscal_year character varying(10) NOT NULL,
    growth_value numeric(18,2),
    metric_type character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: company_growth_history_growth_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.company_growth_history ALTER COLUMN growth_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.company_growth_history_growth_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: company_insider_trading; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.company_insider_trading (
    id integer NOT NULL,
    stock_id integer,
    stock_symbol character varying(10) NOT NULL,
    insider_name character varying(100),
    trade_date date,
    trade_type character varying(20),
    price numeric(18,4),
    quantity integer,
    value numeric(18,4),
    recorded_at date DEFAULT CURRENT_DATE
);


--
-- Name: company_insider_trading_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.company_insider_trading ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.company_insider_trading_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: company_profile; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.company_profile (
    stock_id integer,
    stock_symbol character varying(10) NOT NULL,
    country character varying(50),
    ceo character varying(100),
    website character varying(255),
    sector character varying(50),
    industry character varying(50),
    full_time_employees integer,
    description text,
    recorded_at date DEFAULT CURRENT_DATE,
    beta numeric(5,2),
    financial_score integer
);


--
-- Name: forex_rates; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.forex_rates (
    forex_id integer NOT NULL,
    source_currency character varying(10) NOT NULL,
    target_currency character varying(10) NOT NULL,
    exchange_rate numeric(12,6) NOT NULL,
    rate_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: forex_rates_forex_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.forex_rates ALTER COLUMN forex_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.forex_rates_forex_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: industry_average_metric_values; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.industry_average_metric_values (
    industry_ref_id integer NOT NULL,
    sector character varying(100) NOT NULL,
    metric_id integer,
    metric_value character varying(255),
    snapshot_timestamp timestamp without time zone DEFAULT now()
);


--
-- Name: industry_average_metric_values_industry_ref_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.industry_average_metric_values ALTER COLUMN industry_ref_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.industry_average_metric_values_industry_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: industry_metric_reference; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.industry_metric_reference (
    industry_ref_id integer NOT NULL,
    sector character varying(100) NOT NULL,
    metric_id integer,
    metric_value character varying(255),
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: industry_metric_reference_industry_ref_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.industry_metric_reference ALTER COLUMN industry_ref_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.industry_metric_reference_industry_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: instrument_prices; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
)
PARTITION BY HASH (instrument_id);


--
-- Name: instrument_prices_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices_p0 (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
);


--
-- Name: instrument_prices_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices_p1 (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
);


--
-- Name: instrument_prices_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices_p2 (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
);


--
-- Name: instrument_prices_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices_p3 (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
);


--
-- Name: instrument_prices_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instrument_prices_p4 (
    price_id integer NOT NULL,
    instrument_id integer NOT NULL,
    price_date date NOT NULL,
    price numeric(18,4) NOT NULL,
    open_price numeric(18,4),
    close_price numeric(18,4) NOT NULL,
    high_price numeric(18,4),
    low_price numeric(18,4),
    currency_code character(3) NOT NULL,
    volume bigint
);


--
-- Name: instrument_prices_price_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.instrument_prices ALTER COLUMN price_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.instrument_prices_price_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: instruments; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.instruments (
    instrument_id integer NOT NULL,
    symbol text NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    exchange text,
    sector character varying(100),
    currency_code character(3) NOT NULL,
    country character varying(50)
);


--
-- Name: instruments_instrument_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.instruments ALTER COLUMN instrument_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.instruments_instrument_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: market; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.market (
    market_id integer NOT NULL,
    market_name character varying(100) NOT NULL,
    market_exchange character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: market_indexes; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.market_indexes (
    index_id integer NOT NULL,
    index_name character varying(50) NOT NULL,
    change_percent numeric(5,2),
    recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: market_indexes_index_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.market_indexes ALTER COLUMN index_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.market_indexes_index_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: market_market_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.market ALTER COLUMN market_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.market_market_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: pipeline_exchange_hours; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_exchange_hours (
    exchange text NOT NULL,
    name text,
    timezone text NOT NULL,
    open_time time without time zone,
    close_time time without time zone NOT NULL,
    closing_additional time without time zone,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_ingestion_file_csv_ids; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_ingestion_file_csv_ids (
    filename text NOT NULL,
    csv_id bigint NOT NULL,
    stock_id integer NOT NULL
);


--
-- Name: pipeline_ingestion_files; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_ingestion_files (
    filename text NOT NULL,
    s3_key text NOT NULL,
    etag text NOT NULL,
    size_bytes bigint NOT NULL,
    last_modified timestamp with time zone,
    stock_id integer NOT NULL,
    rows_processed integer DEFAULT 0 NOT NULL,
    rows_inserted integer DEFAULT 0 NOT NULL,
    rows_skipped integer DEFAULT 0 NOT NULL,
    csv_ids_count integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'completed'::text NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_s3_trigger_files; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_s3_trigger_files (
    file_key text NOT NULL,
    etag text NOT NULL,
    size_bytes bigint NOT NULL,
    last_modified timestamp with time zone,
    processed_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_sentiment_dates; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_sentiment_dates (
    stock_id integer NOT NULL,
    date_str date NOT NULL,
    processed boolean DEFAULT true NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_sentiment_processed_ids; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_sentiment_processed_ids (
    stock_id integer NOT NULL,
    message_id bigint NOT NULL,
    processed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_stock_csv_map; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.pipeline_stock_csv_map (
    stock_id integer NOT NULL,
    ticker text NOT NULL,
    csv_filename text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: portfolio; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.portfolio (
    portfolio_id integer NOT NULL,
    portfolio_name character varying(100) NOT NULL,
    owner_id character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer NOT NULL,
    is_default boolean DEFAULT false
);


--
-- Name: portfolio_copilot_chat_history; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.portfolio_copilot_chat_history (
    chat_id uuid,
    user_id character varying(50),
    session_id uuid,
    conversation jsonb,
    message_time timestamp without time zone NOT NULL,
    context jsonb,
    metadata jsonb
);


--
-- Name: portfolio_copilot_chat_history_bkp_18jan2026; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.portfolio_copilot_chat_history_bkp_18jan2026 (
    chat_id integer,
    stock_id integer,
    sender_type character varying(20),
    user_id character varying(50),
    message_text text,
    message_time timestamp without time zone,
    context_topic character varying(100),
    metadata jsonb
);


--
-- Name: portfolio_portfolio_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.portfolio ALTER COLUMN portfolio_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.portfolio_portfolio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: portfolio_stocks; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.portfolio_stocks (
    portfolio_stock_id integer NOT NULL,
    portfolio_id integer,
    stock_id integer,
    quantity numeric(18,4) NOT NULL,
    avg_buy_price numeric(18,4) NOT NULL,
    currency_code character(3) NOT NULL,
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    country_name character varying(50),
    action character varying(20) DEFAULT 'Inactive'::character varying,
    priority integer,
    country_name_display character varying(120)
);


--
-- Name: portfolio_stocks_backup; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.portfolio_stocks_backup (
    portfolio_stock_id integer,
    portfolio_id integer,
    stock_id integer,
    quantity numeric(18,4),
    avg_buy_price numeric(18,4),
    currency_code character(3),
    last_updated timestamp without time zone,
    country_name character varying(50),
    action character varying(20),
    priority integer
);


--
-- Name: portfolio_stocks_portfolio_stock_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.portfolio_stocks ALTER COLUMN portfolio_stock_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.portfolio_stocks_portfolio_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: research_copilot_user_prompts; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.research_copilot_user_prompts (
    prompt_id integer NOT NULL,
    stock_id integer,
    user_id character varying(100),
    prompt_text text NOT NULL,
    last_updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: research_copilot_user_prompts_prompt_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.research_copilot_user_prompts ALTER COLUMN prompt_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.research_copilot_user_prompts_prompt_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stock_copilot_chat_history; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_copilot_chat_history (
    chat_id uuid,
    user_id character varying(50),
    session_id uuid,
    conversation jsonb,
    stock_id integer,
    message_time timestamp without time zone NOT NULL,
    context jsonb,
    metadata jsonb
);


--
-- Name: stock_copilot_chat_history_bkp_18jan2026; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_copilot_chat_history_bkp_18jan2026 (
    chat_id integer,
    stock_id integer,
    sender_type character varying(20),
    user_id character varying(50),
    message_text text,
    message_time timestamp without time zone,
    context_topic character varying(100),
    metadata jsonb
);


--
-- Name: stock_ingestion_event_outbox; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_ingestion_event_outbox (
    outbox_id bigint NOT NULL,
    event_id bigint NOT NULL,
    publish_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_error text,
    next_retry_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    published_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_outbox_publish_status CHECK (((publish_status)::text = ANY ((ARRAY['pending'::character varying, 'sent'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: stock_ingestion_event_outbox_outbox_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

CREATE SEQUENCE ingest_db.stock_ingestion_event_outbox_outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_ingestion_event_outbox_outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: ingest_db; Owner: -
--

ALTER SEQUENCE ingest_db.stock_ingestion_event_outbox_outbox_id_seq OWNED BY ingest_db.stock_ingestion_event_outbox.outbox_id;


--
-- Name: stock_ingestion_events; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_ingestion_events (
    event_id bigint NOT NULL,
    request_id bigint,
    job_id bigint,
    event_type character varying(80) NOT NULL,
    event_stage character varying(40),
    event_status character varying(40),
    event_message text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    source character varying(80),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: stock_ingestion_events_event_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

CREATE SEQUENCE ingest_db.stock_ingestion_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_ingestion_events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: ingest_db; Owner: -
--

ALTER SEQUENCE ingest_db.stock_ingestion_events_event_id_seq OWNED BY ingest_db.stock_ingestion_events.event_id;


--
-- Name: stock_ingestion_jobs; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_ingestion_jobs (
    job_id integer NOT NULL,
    tickers text[] NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    current_tier integer DEFAULT 0,
    step_fn_execution character varying(500),
    error_message text,
    requested_by character varying(100),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    core_status character varying(50),
    ai_status character varying(50),
    core_completed_at timestamp with time zone,
    ai_started_at timestamp with time zone,
    ai_completed_at timestamp with time zone,
    ai_error_message text,
    ai_step_fn_execution character varying(255),
    stage1_status character varying(20),
    stage2_status character varying(20),
    stage1_started_at timestamp with time zone,
    stage1_completed_at timestamp with time zone,
    stage2_started_at timestamp with time zone,
    stage2_completed_at timestamp with time zone,
    request_id bigint,
    chunk_index integer,
    chunks_total integer,
    chunk_size integer,
    queue_message_id character varying(255),
    attempt_count integer DEFAULT 0 NOT NULL,
    queued_at timestamp with time zone,
    dequeued_at timestamp with time zone,
    canonical_tickers text[],
    original_input_tickers text[],
    catalog_ids uuid[],
    CONSTRAINT chk_sij_chunk_index_positive CHECK (((chunk_index IS NULL) OR (chunk_index >= 1))),
    CONSTRAINT chk_sij_chunks_total_positive CHECK (((chunks_total IS NULL) OR (chunks_total >= 1)))
);


--
-- Name: stock_ingestion_jobs_job_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

CREATE SEQUENCE ingest_db.stock_ingestion_jobs_job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_ingestion_jobs_job_id_seq; Type: SEQUENCE OWNED BY; Schema: ingest_db; Owner: -
--

ALTER SEQUENCE ingest_db.stock_ingestion_jobs_job_id_seq OWNED BY ingest_db.stock_ingestion_jobs.job_id;


--
-- Name: stock_ingestion_requests; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_ingestion_requests (
    request_id bigint NOT NULL,
    portfolio_id integer NOT NULL,
    requested_by character varying(255) NOT NULL,
    requested_tickers text[] NOT NULL,
    chunk_size integer DEFAULT 5 NOT NULL,
    child_jobs_total integer DEFAULT 0 NOT NULL,
    child_jobs_started integer DEFAULT 0 NOT NULL,
    child_jobs_succeeded integer DEFAULT 0 NOT NULL,
    child_jobs_failed integer DEFAULT 0 NOT NULL,
    core_status character varying(50) DEFAULT 'running'::character varying NOT NULL,
    ai_status character varying(50) DEFAULT 'not_started'::character varying NOT NULL,
    overall_status character varying(50) DEFAULT 'running'::character varying NOT NULL,
    active_stage integer,
    progress_pct integer DEFAULT 0,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    ai_dispatch_status character varying(30) DEFAULT 'not_started'::character varying NOT NULL,
    ai_dispatched_at timestamp with time zone,
    ai_dispatched_by_job_id bigint,
    ai_execution_arn text,
    ai_error_message text,
    requested_canonical_tickers text[],
    original_input_tickers text[],
    requested_catalog_ids uuid[],
    CONSTRAINT chk_sir_ai_dispatch_status CHECK (((ai_dispatch_status)::text = ANY ((ARRAY['not_started'::character varying, 'running'::character varying, 'success'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: stock_ingestion_requests_request_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

CREATE SEQUENCE ingest_db.stock_ingestion_requests_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_ingestion_requests_request_id_seq; Type: SEQUENCE OWNED BY; Schema: ingest_db; Owner: -
--

ALTER SEQUENCE ingest_db.stock_ingestion_requests_request_id_seq OWNED BY ingest_db.stock_ingestion_requests.request_id;


--
-- Name: stock_peers; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stock_peers (
    id integer NOT NULL,
    stock_id integer NOT NULL,
    peer_stock_id integer NOT NULL,
    peer_symbol character varying(30),
    peer_company character varying(500),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: stock_peers_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

CREATE SEQUENCE ingest_db.stock_peers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_peers_id_seq; Type: SEQUENCE OWNED BY; Schema: ingest_db; Owner: -
--

ALTER SEQUENCE ingest_db.stock_peers_id_seq OWNED BY ingest_db.stock_peers.id;


--
-- Name: stocks; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks (
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    exchange character varying(20),
    company_name character varying(200),
    sector character varying(100),
    currency_code character(3) NOT NULL,
    country_name character varying(50),
    market_cap_category_name character varying(50) NOT NULL,
    logo_url text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_peer boolean DEFAULT false,
    canonical_symbol character varying(64),
    market_code character varying(16),
    country_code character varying(8),
    country_name_display character varying(120),
    canonical_ticker character varying(64)
);


--
-- Name: stocks_benchmark_mapping; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_benchmark_mapping (
    stock_id integer NOT NULL,
    instrument_id integer NOT NULL,
    ranking_order integer DEFAULT 1,
    last_updated_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_chatroom_filters; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_chatroom_filters (
    filter_id integer NOT NULL,
    filter_type character varying(50) NOT NULL,
    filter_value character varying(100) NOT NULL
);


--
-- Name: stocks_chatroom_filters_filter_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_chatroom_filters ALTER COLUMN filter_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_chatroom_filters_filter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_company_report_sections; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY HASH (report_id);


--
-- Name: stocks_company_report_sections_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p0 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p1 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p2 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p3 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p4 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p5 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p6 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p7 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p8 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_report_sections_p9 (
    section_id integer NOT NULL,
    report_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_report_sections_section_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_report_sections ALTER COLUMN section_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_company_report_sections_section_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_company_reports; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_company_reports_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p0 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p1 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p2 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p3 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p4 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p5 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p6 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p7 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p8 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_reports_p9 (
    report_id integer NOT NULL,
    stock_id integer NOT NULL,
    report_type character varying(50) NOT NULL,
    report_title character varying(255) NOT NULL,
    fiscal_year integer,
    file_url character varying(500) NOT NULL,
    preview_image_url character varying(500),
    page_count integer,
    ai_model_name character varying(100),
    ai_confidence_score numeric(4,3),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_reports_ai_confidence_score_check CHECK (((ai_confidence_score >= (0)::numeric) AND (ai_confidence_score <= (1)::numeric))),
    CONSTRAINT stocks_company_reports_fiscal_year_check CHECK ((fiscal_year >= 2000))
);


--
-- Name: stocks_company_reports_report_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_reports ALTER COLUMN report_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_company_reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_company_transcript_sections; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY HASH (transcript_id);


--
-- Name: stocks_company_transcript_sections_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p0 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p1 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p2 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p3 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p4 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p5 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p6 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p7 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p8 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_sections_p9 (
    section_id integer NOT NULL,
    transcript_id integer NOT NULL,
    section_title character varying(255) NOT NULL,
    content text NOT NULL,
    display_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_company_transcript_sections_section_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcript_sections ALTER COLUMN section_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_company_transcript_sections_section_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_company_transcript_source_documents; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_company_transcript_source_documen_source_document_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcript_source_documents ALTER COLUMN source_document_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_company_transcript_source_documen_source_document_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_company_transcript_source_documents_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p0 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p1 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p2 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p3 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p4 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p5 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p6 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p7 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p8 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcript_source_documents_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcript_source_documents_p9 (
    source_document_id integer NOT NULL,
    stock_id integer NOT NULL,
    transcript_id integer,
    source_system character varying(50) NOT NULL,
    asx_code character varying(20) NOT NULL,
    source_page_url text NOT NULL,
    source_pdf_url text NOT NULL,
    normalized_source_pdf_url text NOT NULL,
    source_pdf_id character varying(50) NOT NULL,
    headline text NOT NULL,
    announcement_type text,
    price_sensitive boolean,
    published_at timestamp without time zone NOT NULL,
    document_size_bytes bigint,
    document_url text,
    sha256 character varying(64),
    raw_row_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    document_category character varying(50) DEFAULT 'OTHER'::character varying NOT NULL,
    document_type character varying(100) DEFAULT 'OTHER'::character varying NOT NULL,
    reporting_period_type character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    reporting_period_label character varying(50),
    reporting_period_year integer,
    reporting_period_quarter smallint,
    reporting_period_half smallint,
    reporting_period_basis character varying(20) DEFAULT 'NONE'::character varying NOT NULL,
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_bas CHECK (((reporting_period_basis)::text = ANY ((ARRAY['NONE'::character varying, 'EXPLICIT'::character varying, 'HEURISTIC'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_reporting_period_typ CHECK (((reporting_period_type)::text = ANY ((ARRAY['NONE'::character varying, 'ANNUAL'::character varying, 'HALF_YEAR'::character varying, 'QUARTERLY'::character varying])::text[]))),
    CONSTRAINT stocks_company_transcript_source_documents_status_check CHECK (((status)::text = ANY ((ARRAY['DISCOVERED'::character varying, 'UPLOADED'::character varying, 'READY'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: stocks_company_transcripts; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_company_transcripts_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p0 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p1 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p2 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p3 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p4 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p5 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p6 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p7 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p8 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_company_transcripts_p9 (
    transcript_id integer NOT NULL,
    stock_id integer NOT NULL,
    title character varying(255) NOT NULL,
    quarter character varying(10) NOT NULL,
    fiscal_year integer NOT NULL,
    call_date date NOT NULL,
    duration interval,
    transcript_type character varying(50),
    audio_url character varying(500),
    document_url character varying(500),
    ai_model_name character varying(100),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT stocks_company_transcripts_fiscal_year_check CHECK ((fiscal_year >= 2000)),
    CONSTRAINT stocks_company_transcripts_quarter_check CHECK (((quarter)::text = ANY (ARRAY[('Q1'::character varying)::text, ('Q2'::character varying)::text, ('Q3'::character varying)::text, ('Q4'::character varying)::text])))
);


--
-- Name: stocks_company_transcripts_transcript_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcripts ALTER COLUMN transcript_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_company_transcripts_transcript_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_earnings_calendar; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_earnings_calendar (
    earnings_id integer NOT NULL,
    stock_id integer,
    earnings_date date NOT NULL,
    session_type character varying(50),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_earnings_calendar_earnings_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_earnings_calendar ALTER COLUMN earnings_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_earnings_calendar_earnings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_earnings_outlook; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_earnings_outlook (
    id integer NOT NULL,
    stock_id integer,
    ticker character varying(10) NOT NULL,
    period character varying(20) NOT NULL,
    num_estimates integer,
    avg_estimate numeric(18,4),
    low_estimate numeric(18,4),
    high_estimate numeric(18,4),
    metric_type character varying(10),
    recorded_at date DEFAULT CURRENT_DATE,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_earnings_outlook_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_earnings_outlook ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_earnings_outlook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_events; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_events_event_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_events ALTER COLUMN event_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_events_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p0 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p1 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p2 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p3 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p4 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p5 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p6 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p7 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p8 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_events_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_events_p9 (
    event_id integer NOT NULL,
    stock_id integer NOT NULL,
    ticker character varying(10) NOT NULL,
    event_time timestamp without time zone NOT NULL,
    event_type character varying(50) NOT NULL,
    event_description text,
    event_source text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_flags; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_flags (
    flag_id integer NOT NULL,
    stock_id integer,
    flag_type character varying(50),
    flag_description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_flags_flag_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_flags ALTER COLUMN flag_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_flags_flag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_fundamentals; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_fundamentals_fundamentals_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_fundamentals ALTER COLUMN fundamentals_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_fundamentals_fundamentals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_fundamentals_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p0 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p1 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p2 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p3 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p4 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p5 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p6 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p7 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p8 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_fundamentals_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_fundamentals_p9 (
    fundamentals_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_type character varying(50) NOT NULL,
    metric_value numeric(18,2) NOT NULL,
    period_type character varying(20),
    period_label character varying(10),
    captured_date date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    metric_category character varying(50)
);


--
-- Name: stocks_indicators; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_indicators (
    indicator_id integer NOT NULL,
    stock_id integer,
    ticker character varying(10) NOT NULL,
    indicator_name character varying(50) NOT NULL,
    value numeric(10,4),
    recorded_at timestamp without time zone NOT NULL,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_indicators_indicator_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_indicators ALTER COLUMN indicator_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_indicators_indicator_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_market_alerts; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_market_alerts_alert_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_market_alerts ALTER COLUMN alert_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_market_alerts_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_market_alerts_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p0 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p1 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p2 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p3 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p4 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p5 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p6 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p7 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p8 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_alerts_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_alerts_p9 (
    alert_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    alert_type character varying(100),
    description text,
    source character varying(100),
    alert_date date NOT NULL,
    severity character varying(20),
    url character varying(500),
    status character varying(10),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_market_news; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_market_news_news_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_market_news ALTER COLUMN news_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_market_news_news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_market_news_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p0 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p1 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p2 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p3 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p4 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p5 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p6 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p7 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p8 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_market_news_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_market_news_p9 (
    news_id integer NOT NULL,
    stock_id integer NOT NULL,
    stock_symbol character varying(10),
    headline character varying(500) NOT NULL,
    description text,
    source character varying(100),
    published_date date NOT NULL,
    url character varying(500),
    stock_company character varying(200),
    sentiment_score numeric(6,2),
    sentiment_label character varying(20),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    news_type text
);


--
-- Name: stocks_metric_types; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metric_types (
    metric_id integer NOT NULL,
    metric_name character varying(100) NOT NULL,
    metric_category character varying(100),
    metric_unit character varying(50),
    description text,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: stocks_metric_types_metric_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_metric_types ALTER COLUMN metric_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_metric_types_metric_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_metrics; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_metrics_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p0 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p1 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p2 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p3 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p4 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p5 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p6 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p7 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p8 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_metrics_p9 (
    stock_metric_id integer NOT NULL,
    stock_id integer NOT NULL,
    metric_id integer NOT NULL,
    metric_value numeric(10,4),
    snapshot_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_metrics_stock_metric_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_metrics ALTER COLUMN stock_metric_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_metrics_stock_metric_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_price_data; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
)
PARTITION BY HASH (stock_id);


--
-- Name: stocks_price_data_market_data_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_price_data ALTER COLUMN market_data_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_price_data_market_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_price_data_p0; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p0 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p1; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p1 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p2; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p2 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p3; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p3 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p4; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p4 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p5; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p5 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p6; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p6 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p7; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p7 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p8; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p8 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_price_data_p9; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_price_data_p9 (
    market_data_id integer NOT NULL,
    stock_id integer NOT NULL,
    price numeric(18,4),
    opening_price numeric(18,4),
    closing_price numeric(18,4),
    day_price_change numeric(18,4),
    currency_code character(3) NOT NULL,
    day_price_change_pct numeric(6,2),
    volume bigint,
    volume_30d bigint,
    market_cap numeric(18,4),
    captured_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    price_date date NOT NULL,
    off_market_price numeric(18,4),
    off_market_volume bigint,
    off_market_volume_30d bigint
);


--
-- Name: stocks_stock_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks ALTER COLUMN stock_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_upcoming_earnings; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_upcoming_earnings (
    earnings_id integer NOT NULL,
    stock_id integer,
    ticker character varying(10) NOT NULL,
    market_cap numeric(18,2),
    earnings_date date NOT NULL,
    estimated_eps numeric(10,2),
    actual_eps numeric(10,2),
    currency_code character(3) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    canonical_ticker character varying(64)
);


--
-- Name: stocks_upcoming_earnings_earnings_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_upcoming_earnings ALTER COLUMN earnings_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_upcoming_earnings_earnings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_upcoming_events; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_upcoming_events (
    event_id integer NOT NULL,
    stock_id integer,
    event_type character varying(100),
    event_description text,
    event_source character varying(100),
    expected_event_time timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_upcoming_events_event_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_upcoming_events ALTER COLUMN event_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_upcoming_events_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_watchlist; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_watchlist (
    watchlist_id integer NOT NULL,
    watchlist_name character varying(20) NOT NULL,
    user_id character varying(20) NOT NULL,
    stock_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: stocks_watchlist_watchlist_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_watchlist ALTER COLUMN watchlist_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_watchlist_watchlist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_word_cloud_metrics; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.stocks_word_cloud_metrics (
    word_id integer NOT NULL,
    stock_id integer,
    keyword character varying(100) NOT NULL,
    positive_reaction_percent numeric(5,2),
    negative_reaction_percent numeric(5,2),
    recorded_at timestamp without time zone NOT NULL
);


--
-- Name: stocks_word_cloud_metrics_word_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_word_cloud_metrics ALTER COLUMN word_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.stocks_word_cloud_metrics_word_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ticker_list; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.ticker_list (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    symbol character varying(30) NOT NULL,
    company_name character varying(500) NOT NULL,
    exchange_code character varying(20),
    currency character varying(10),
    country character varying(10),
    fmp_available boolean DEFAULT false NOT NULL,
    data_source character varying(30) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    canonical_symbol character varying(64),
    base_symbol character varying(64),
    market_code character varying(16),
    country_code character varying(8),
    country_name_display character varying(120),
    provider_name character varying(30),
    provider_symbol character varying(64),
    provider_exchange_code character varying(20),
    stock_id integer,
    is_primary_resolution boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    alias_type character varying(30),
    canonical_ticker character varying(64)
);


--
-- Name: users; Type: TABLE; Schema: ingest_db; Owner: -
--

CREATE TABLE ingest_db.users (
    user_id integer NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    role character varying(20)
);


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.users ALTER COLUMN user_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME ingest_db.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: vw_forex_rates; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_forex_rates AS
 WITH latest AS (
         SELECT forex_rates.source_currency,
            forex_rates.target_currency,
            max(forex_rates.rate_date) AS latest_rate_date
           FROM ingest_db.forex_rates
          GROUP BY forex_rates.source_currency, forex_rates.target_currency
        )
 SELECT a.source_currency,
    a.target_currency,
    a.exchange_rate,
    a.rate_date
   FROM ingest_db.forex_rates a,
    latest b
  WHERE (((a.source_currency)::text = (b.source_currency)::text) AND ((a.target_currency)::text = (b.target_currency)::text) AND (a.rate_date = b.latest_rate_date));


--
-- Name: vw_instrument_prices; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_instrument_prices AS
 SELECT ip.instrument_id,
    ip.price_date,
    ip.price AS price_local_curr,
        CASE
            WHEN (ip.currency_code = (fr.target_currency)::bpchar) THEN ip.price
            ELSE (ip.price * fr.exchange_rate)
        END AS price_usd,
    ip.close_price AS close_price_local_curr,
        CASE
            WHEN (ip.currency_code = (fr.target_currency)::bpchar) THEN ip.close_price
            ELSE (ip.close_price * fr.exchange_rate)
        END AS close_price_usd,
    ip.open_price AS open_price_local_curr,
        CASE
            WHEN (ip.currency_code = (fr.target_currency)::bpchar) THEN ip.open_price
            ELSE (ip.open_price * fr.exchange_rate)
        END AS open_price_usd,
    ip.currency_code AS local_currency,
    ip.volume
   FROM (ingest_db.instrument_prices ip
     JOIN semantic_db.vw_forex_rates fr ON (((ip.currency_code = (fr.source_currency)::bpchar) AND ((fr.target_currency)::text = 'USD'::text))));


--
-- Name: mv_instrument_price_volatility; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_instrument_price_volatility AS
 WITH base AS (
         SELECT vw_instrument_prices.instrument_id,
            vw_instrument_prices.price_date,
            vw_instrument_prices.close_price_local_curr AS close_price,
            vw_instrument_prices.local_currency,
            lag(vw_instrument_prices.close_price_local_curr) OVER (PARTITION BY vw_instrument_prices.instrument_id ORDER BY vw_instrument_prices.price_date) AS prev_close_price
           FROM semantic_db.vw_instrument_prices
          WHERE (vw_instrument_prices.price_date >= (CURRENT_DATE - '180 days'::interval))
        ), returns AS (
         SELECT base.instrument_id,
            base.price_date,
            base.local_currency,
                CASE
                    WHEN (base.prev_close_price IS NOT NULL) THEN ln((base.close_price / base.prev_close_price))
                    ELSE NULL::numeric
                END AS log_return
           FROM base
        )
 SELECT returns.instrument_id,
    returns.price_date AS calc_date,
    '1D'::text AS period,
    ((abs(returns.log_return))::double precision * sqrt((252)::double precision)) AS volatility,
    returns.local_currency AS currency
   FROM returns
  WHERE (returns.log_return IS NOT NULL)
UNION ALL
 SELECT returns.instrument_id,
    returns.price_date AS calc_date,
    '30D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w30)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.local_currency AS currency
   FROM returns
  WINDOW w30 AS (PARTITION BY returns.instrument_id ORDER BY returns.price_date RANGE BETWEEN '29 days'::interval PRECEDING AND CURRENT ROW)
UNION ALL
 SELECT returns.instrument_id,
    returns.price_date AS calc_date,
    '60D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w60)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.local_currency AS currency
   FROM returns
  WINDOW w60 AS (PARTITION BY returns.instrument_id ORDER BY returns.price_date RANGE BETWEEN '59 days'::interval PRECEDING AND CURRENT ROW)
UNION ALL
 SELECT returns.instrument_id,
    returns.price_date AS calc_date,
    '90D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w90)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.local_currency AS currency
   FROM returns
  WINDOW w90 AS (PARTITION BY returns.instrument_id ORDER BY returns.price_date RANGE BETWEEN '89 days'::interval PRECEDING AND CURRENT ROW)
  WITH NO DATA;


--
-- Name: mv_stocks_dividend_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_dividend_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS dividend_value,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'Dividend'::text) AND ((fh.metric_type)::text = 'Dividend'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    dividend_value AS latest_dividend_value,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((dividend_value - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  ORDER BY ticker, period_type
  WITH NO DATA;


--
-- Name: mv_stocks_ebitda_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_ebitda_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS ebitda,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'EBITDA'::text) AND ((fh.metric_type)::text = 'EBITDA'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    ebitda AS latest_ebitda,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((ebitda - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  ORDER BY ticker, period_type
  WITH NO DATA;


--
-- Name: mv_stocks_eps_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_eps_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS eps,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'EPS'::text) AND ((fh.metric_type)::text = 'EPS'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    eps AS latest_eps,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((eps - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  ORDER BY ticker, period_type
  WITH NO DATA;


--
-- Name: mv_stocks_free_cash_flow_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_free_cash_flow_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_type,
            fh.metric_value,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.metric_type, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.metric_type, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE ((fh.metric_category)::text = 'Free Cash Flow'::text)
        )
 SELECT ticker,
    stock_id,
    metric_type,
    period_type,
    metric_value AS latest_metric_value,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((metric_value - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  WITH NO DATA;


--
-- Name: mv_stocks_fundamentals_latest; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_fundamentals_latest AS
 WITH latest_data AS (
         SELECT stocks_fundamentals.stock_id,
            stocks_fundamentals.metric_category,
            stocks_fundamentals.metric_type,
            stocks_fundamentals.period_type,
            stocks_fundamentals.period_label,
            max(stocks_fundamentals.captured_date) AS latest_date
           FROM ingest_db.stocks_fundamentals
          GROUP BY stocks_fundamentals.stock_id, stocks_fundamentals.metric_category, stocks_fundamentals.metric_type, stocks_fundamentals.period_type, stocks_fundamentals.period_label
        )
 SELECT v1.fundamentals_id,
    v1.stock_id,
    v1.metric_category,
    v1.metric_type,
    v1.metric_value,
    v1.period_type,
    v1.period_label,
    v1.captured_date,
    v1.created_at
   FROM (ingest_db.stocks_fundamentals v1
     JOIN latest_data v2 ON (((v1.stock_id = v2.stock_id) AND (v1.captured_date = v2.latest_date) AND ((v1.metric_category)::text = (v2.metric_category)::text) AND ((v1.metric_type)::text = (v2.metric_type)::text) AND ((v1.period_type)::text = (v2.period_type)::text) AND ((v1.period_label)::text = (v2.period_label)::text))))
  WITH NO DATA;


--
-- Name: mv_stocks_price_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_price_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS price,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'Price'::text) AND ((fh.metric_type)::text = 'Price'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    price AS latest_amount,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((price - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  ORDER BY ticker, period_type
  WITH NO DATA;


--
-- Name: vw_stocks_price_data_history; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_price_data_history AS
 SELECT md.market_data_id,
    md.stock_id,
    md.currency_code AS local_currency,
    md.price AS price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.price
            ELSE (md.price * fr.exchange_rate)
        END AS price_usd,
    md.off_market_price AS off_market_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.off_market_price
            ELSE (md.off_market_price * fr.exchange_rate)
        END AS off_market_price_usd,
    md.opening_price AS opening_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.opening_price
            ELSE (md.opening_price * fr.exchange_rate)
        END AS opening_price_usd,
    md.closing_price AS closing_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.closing_price
            ELSE (md.closing_price * fr.exchange_rate)
        END AS closing_price_usd,
    md.day_price_change AS day_price_change_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.day_price_change
            ELSE (md.day_price_change * fr.exchange_rate)
        END AS day_price_change_usd,
    md.day_price_change_pct,
    md.volume,
    md.volume_30d,
    md.off_market_volume,
    md.off_market_volume_30d,
    md.market_cap AS market_cap_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.market_cap
            ELSE (md.market_cap * fr.exchange_rate)
        END AS market_cap_usd,
    md.price_date,
    md.captured_at
   FROM (ingest_db.stocks_price_data md
     JOIN semantic_db.vw_forex_rates fr ON (((md.currency_code = (fr.source_currency)::bpchar) AND ((fr.target_currency)::text = 'USD'::text))));


--
-- Name: mv_stocks_price_volatility; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_price_volatility AS
 WITH base AS (
         SELECT vw_stocks_price_data_history.stock_id,
            vw_stocks_price_data_history.price_date,
            vw_stocks_price_data_history.closing_price_local_curr AS close_price,
            vw_stocks_price_data_history.local_currency AS currency_code,
            lag(vw_stocks_price_data_history.closing_price_local_curr) OVER (PARTITION BY vw_stocks_price_data_history.stock_id ORDER BY vw_stocks_price_data_history.price_date) AS prev_close_price
           FROM semantic_db.vw_stocks_price_data_history
          WHERE (vw_stocks_price_data_history.price_date >= (CURRENT_DATE - '180 days'::interval))
        ), returns AS (
         SELECT base.stock_id,
            base.price_date,
            base.currency_code,
                CASE
                    WHEN (base.prev_close_price IS NOT NULL) THEN ln((base.close_price / base.prev_close_price))
                    ELSE NULL::numeric
                END AS log_return
           FROM base
        )
 SELECT returns.stock_id,
    returns.price_date AS calc_date,
    '1D'::text AS period,
    ((abs(returns.log_return))::double precision * sqrt((252)::double precision)) AS volatility,
    returns.currency_code
   FROM returns
  WHERE (returns.log_return IS NOT NULL)
UNION ALL
 SELECT returns.stock_id,
    returns.price_date AS calc_date,
    '30D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w30)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.currency_code
   FROM returns
  WINDOW w30 AS (PARTITION BY returns.stock_id ORDER BY returns.price_date RANGE BETWEEN '29 days'::interval PRECEDING AND CURRENT ROW)
UNION ALL
 SELECT returns.stock_id,
    returns.price_date AS calc_date,
    '60D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w60)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.currency_code
   FROM returns
  WINDOW w60 AS (PARTITION BY returns.stock_id ORDER BY returns.price_date RANGE BETWEEN '59 days'::interval PRECEDING AND CURRENT ROW)
UNION ALL
 SELECT returns.stock_id,
    returns.price_date AS calc_date,
    '90D'::text AS period,
    ((stddev_samp(returns.log_return) OVER w90)::double precision * sqrt((252)::double precision)) AS volatility,
    returns.currency_code
   FROM returns
  WINDOW w90 AS (PARTITION BY returns.stock_id ORDER BY returns.price_date RANGE BETWEEN '89 days'::interval PRECEDING AND CURRENT ROW)
  WITH NO DATA;


--
-- Name: mv_stocks_return_of_capital_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_return_of_capital_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS roc,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'Return of Capital'::text) AND ((fh.metric_type)::text = 'Return of Capital'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    roc AS latest_roc,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((roc - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  ORDER BY ticker, period_type
  WITH NO DATA;


--
-- Name: mv_stocks_revenue_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_revenue_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS revenue,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'Revenue'::text) AND ((fh.metric_type)::text = 'Revenue'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    revenue AS latest_revenue,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((revenue - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  WITH NO DATA;


--
-- Name: mv_stocks_shares_outstanding_trend_summary; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.mv_stocks_shares_outstanding_trend_summary AS
 WITH ranked AS (
         SELECT s.ticker,
            s.stock_id,
            fh.metric_value AS shares_outstanding,
            fh.period_type,
            fh.period_label,
            fh.captured_date,
            row_number() OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS rn,
            lag(fh.metric_value) OVER (PARTITION BY s.ticker, fh.period_type ORDER BY fh.captured_date DESC) AS prev_value
           FROM (ingest_db.stocks_fundamentals fh
             JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
          WHERE (((fh.metric_category)::text = 'Shares Outstanding'::text) AND ((fh.metric_type)::text = 'Shares Outstanding'::text))
        )
 SELECT ticker,
    stock_id,
    period_type,
    shares_outstanding AS latest_roc,
        CASE
            WHEN (prev_value IS NOT NULL) THEN round((((shares_outstanding - prev_value) / prev_value) * (100)::numeric), 2)
            ELSE NULL::numeric
        END AS percent_change,
    period_label,
    captured_date
   FROM ranked
  WHERE (rn = 1)
  WITH NO DATA;


--
-- Name: vw_stocks_price_data_latest; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_price_data_latest AS
 WITH latest_stock_dates AS (
         SELECT stocks_price_data.stock_id,
            max(stocks_price_data.price_date) AS latest_date
           FROM ingest_db.stocks_price_data
          GROUP BY stocks_price_data.stock_id
        ), stocks_price_data AS (
         SELECT v1.market_data_id,
            v1.stock_id,
            (upper((v1.currency_code)::text))::character(3) AS currency_code,
            v1.price,
            v1.off_market_price,
            v1.opening_price,
            v1.closing_price,
            v1.day_price_change,
            v1.day_price_change_pct,
            v1.volume,
            v1.volume_30d,
            v1.off_market_volume,
            v1.off_market_volume_30d,
            v1.market_cap,
            v1.price_date
           FROM (ingest_db.stocks_price_data v1
             JOIN latest_stock_dates v2 ON (((v2.stock_id = v1.stock_id) AND (v2.latest_date = v1.price_date))))
        )
 SELECT md.market_data_id,
    md.stock_id,
    md.currency_code AS local_currency,
    md.price AS price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.price
            ELSE (md.price * fr.exchange_rate)
        END AS price_usd,
    md.off_market_price AS off_market_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.off_market_price
            ELSE (md.off_market_price * fr.exchange_rate)
        END AS off_market_price_usd,
    md.opening_price AS opening_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.opening_price
            ELSE (md.opening_price * fr.exchange_rate)
        END AS opening_price_usd,
    md.closing_price AS closing_price_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.closing_price
            ELSE (md.closing_price * fr.exchange_rate)
        END AS closing_price_usd,
    md.day_price_change AS day_price_change_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.day_price_change
            ELSE (md.day_price_change * fr.exchange_rate)
        END AS day_price_change_usd,
    md.day_price_change_pct,
    md.currency_code,
    md.volume,
    md.volume_30d,
    md.off_market_volume,
    md.off_market_volume_30d,
    md.market_cap AS market_cap_local_curr,
        CASE
            WHEN (md.currency_code = (fr.target_currency)::bpchar) THEN md.market_cap
            ELSE (md.market_cap * fr.exchange_rate)
        END AS market_cap_usd,
    md.price_date
   FROM (stocks_price_data md
     JOIN semantic_db.vw_forex_rates fr ON (((md.currency_code = (upper((fr.source_currency)::text))::bpchar) AND ((fr.target_currency)::text = 'USD'::text))));


--
-- Name: test_stocks_price_latest_mv; Type: MATERIALIZED VIEW; Schema: semantic_db; Owner: -
--

CREATE MATERIALIZED VIEW semantic_db.test_stocks_price_latest_mv AS
 SELECT market_data_id,
    stock_id,
    local_currency,
    price_local_curr,
    price_usd,
    off_market_price_local_curr,
    off_market_price_usd,
    opening_price_local_curr,
    opening_price_usd,
    closing_price_local_curr,
    closing_price_usd,
    day_price_change_local_curr,
    day_price_change_usd,
    day_price_change_pct,
    currency_code,
    volume,
    volume_30d,
    off_market_volume,
    off_market_volume_30d,
    market_cap_local_curr,
    market_cap_usd,
    price_date
   FROM semantic_db.vw_stocks_price_data_latest
  WITH NO DATA;


--
-- Name: vw_benchmark_history; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_benchmark_history AS
 SELECT bh.benchmark_id,
    bh.benchmark_name,
    bh.valuation_date,
    bh.benchmark_value AS benchmark_value_local_curr,
        CASE
            WHEN (bh.currency_code = (fr.target_currency)::bpchar) THEN bh.benchmark_value
            ELSE (bh.benchmark_value * fr.exchange_rate)
        END AS benchmark_value_usd,
    bh.currency_code AS local_currency,
    bh.created_at
   FROM (ingest_db.benchmark_history bh
     JOIN semantic_db.vw_forex_rates fr ON (((bh.currency_code = (fr.source_currency)::bpchar) AND ((fr.target_currency)::text = 'USD'::text))));


--
-- Name: vw_chatroom_ai_chat_interactions; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_chatroom_ai_chat_interactions AS
 SELECT chat_id,
    user_id,
    session_id,
    conversation,
    stock_id,
    message_time,
    context,
    metadata
   FROM ingest_db.chatroom_ai_chat_interactions;


--
-- Name: stocks_message_sentiments; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
)
PARTITION BY HASH (stock_id);


--
-- Name: vw_chatroom_stocks_chat_sentiments; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_chatroom_stocks_chat_sentiments AS
 SELECT message_id,
    stock_id,
    analysis_id,
    source_name,
    source_url,
    source_message_id,
    message_author,
    message_text,
    llm_sentiment_score,
    llm_sentiment_label,
    sentiment_description,
    keywords,
    is_bullish,
    is_bearish,
    is_sarcasm,
    confidence_score,
    llm_explanation,
    count_likes,
    count_dislikes,
    count_shares,
    count_replies,
    analyzed_at,
    platform,
    country
   FROM transform_db.stocks_message_sentiments;


--
-- Name: vw_chatroom_stocks_news_alerts; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_chatroom_stocks_news_alerts AS
 SELECT alert_id,
    stock_id,
    stock_symbol,
    alert_type,
    description,
    source,
    alert_date,
    severity,
    url,
    status,
    created_at
   FROM ingest_db.stocks_market_alerts;


--
-- Name: vw_chatroom_stocks_news_chat; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_chatroom_stocks_news_chat AS
 SELECT message_id,
    stock_id,
    username,
    message_text,
    source,
    message_time,
    likes_count,
    dislikes_count
   FROM ingest_db.chatroom_stocks_news_chat;


--
-- Name: vw_company_executive_summary; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_company_executive_summary AS
 SELECT summary_id,
    stock_id,
    fiscal_year,
    total_revenue,
    gross_profit,
    operating_income,
    net_income,
    narrative,
    created_at
   FROM ingest_db.company_executive_summary v1
  WHERE (created_at = ( SELECT max(v2.created_at) AS max
           FROM ingest_db.company_executive_summary v2
          WHERE (v1.stock_id = v2.stock_id)));


--
-- Name: vw_company_growth_history; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_company_growth_history AS
 SELECT growth_id,
    stock_id,
    fiscal_year,
    growth_value,
    metric_type,
    created_at
   FROM ingest_db.company_growth_history v1
  WHERE (created_at = ( SELECT max(v2.created_at) AS max
           FROM ingest_db.company_growth_history v2
          WHERE ((v1.stock_id = v2.stock_id) AND ((v1.fiscal_year)::text = (v2.fiscal_year)::text) AND ((v1.metric_type)::text = (v2.metric_type)::text))));


--
-- Name: vw_company_insider_trading; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_company_insider_trading AS
 SELECT id,
    stock_id,
    stock_symbol,
    insider_name,
    trade_date,
    trade_type,
    price,
    quantity,
    value,
    recorded_at
   FROM ingest_db.company_insider_trading v1
  WHERE (recorded_at = ( SELECT max(v2.recorded_at) AS max
           FROM ingest_db.company_insider_trading v2
          WHERE (v2.stock_id = v1.stock_id)));


--
-- Name: vw_company_profile; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_company_profile AS
 SELECT stock_id,
    stock_symbol,
    country,
    ceo,
    website,
    sector,
    industry,
    full_time_employees,
    description,
    recorded_at,
    beta,
    financial_score
   FROM ingest_db.company_profile v1
  WHERE (recorded_at = ( SELECT max(v2.recorded_at) AS max
           FROM ingest_db.company_profile v2
          WHERE (v2.stock_id = v1.stock_id)));


--
-- Name: vw_portfolio_stocks; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks AS
 WITH latest_data AS (
         SELECT portfolio_stocks.portfolio_id,
            portfolio_stocks.stock_id,
            max(portfolio_stocks.last_updated) AS latest_date
           FROM ingest_db.portfolio_stocks
          GROUP BY portfolio_stocks.portfolio_id, portfolio_stocks.stock_id
        )
 SELECT ps.portfolio_stock_id,
    ps.portfolio_id,
    ps.stock_id,
    ps.quantity,
    ps.avg_buy_price AS avg_buy_price_local_curr,
        CASE
            WHEN (ps.currency_code = (fr.target_currency)::bpchar) THEN ps.avg_buy_price
            ELSE (ps.avg_buy_price * fr.exchange_rate)
        END AS avg_buy_price_usd,
    (upper((ps.currency_code)::text))::character(3) AS currency_code,
    ps.last_updated,
    ps.country_name,
    ps.action,
    ps.priority
   FROM ((ingest_db.portfolio_stocks ps
     JOIN latest_data ld ON (((ps.portfolio_id = ld.portfolio_id) AND (ps.stock_id = ld.stock_id) AND (ps.last_updated = ld.latest_date))))
     JOIN semantic_db.vw_forex_rates fr ON (((upper((ps.currency_code)::text) = ((upper((fr.source_currency)::text))::bpchar)::text) AND ((fr.target_currency)::text = 'USD'::text))));


--
-- Name: vw_global_stocks; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_global_stocks AS
 SELECT DISTINCT s.stock_id,
    s.ticker,
    s.exchange,
    s.company_name,
    s.sector,
    s.currency_code,
    s.country_name_display,
    s.market_cap_category_name,
    s.logo_url
   FROM (semantic_db.vw_portfolio_stocks ps
     JOIN ingest_db.stocks s ON ((ps.stock_id = s.stock_id)))
  WHERE ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text);


--
-- Name: vw_industry_average_metric_values; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_industry_average_metric_values AS
 WITH latest_data AS (
         SELECT industry_average_metric_values.sector,
            industry_average_metric_values.metric_id,
            max(industry_average_metric_values.snapshot_timestamp) AS latest_time
           FROM ingest_db.industry_average_metric_values
          GROUP BY industry_average_metric_values.sector, industry_average_metric_values.metric_id
        ), latest_data_with_metric_type AS (
         SELECT ld.sector,
            ld.metric_id,
            ld.latest_time,
            smt.metric_name,
            smt.metric_category,
            smt.metric_unit
           FROM latest_data ld,
            ingest_db.stocks_metric_types smt
          WHERE (ld.metric_id = smt.metric_id)
        )
 SELECT v1.industry_ref_id,
    v1.sector,
    v1.metric_id,
    v1.metric_value,
    v1.snapshot_timestamp,
    v2.metric_name,
    v2.metric_category,
    v2.metric_unit
   FROM (ingest_db.industry_average_metric_values v1
     JOIN latest_data_with_metric_type v2 ON ((((v1.sector)::text = (v2.sector)::text) AND (v1.metric_id = v2.metric_id) AND (v1.snapshot_timestamp = v2.latest_time))));


--
-- Name: instrument_correlation_matrix; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.instrument_correlation_matrix (
    correlation_id integer NOT NULL,
    entity_a character varying(50) NOT NULL,
    entity_b character varying(50) NOT NULL,
    correlation_value numeric(6,2) NOT NULL,
    calculated_at timestamp without time zone NOT NULL
);


--
-- Name: vw_instrument_correlation_matrix_latest; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_instrument_correlation_matrix_latest AS
 WITH latest_data AS (
         SELECT instrument_correlation_matrix.entity_a,
            instrument_correlation_matrix.entity_b,
            max(instrument_correlation_matrix.calculated_at) AS latest_date
           FROM transform_db.instrument_correlation_matrix
          GROUP BY instrument_correlation_matrix.entity_a, instrument_correlation_matrix.entity_b
        )
 SELECT a.correlation_id,
    a.entity_a,
    a.entity_b,
    a.correlation_value,
    a.calculated_at
   FROM transform_db.instrument_correlation_matrix a,
    latest_data b
  WHERE (((a.entity_a)::text = (b.entity_a)::text) AND ((a.entity_b)::text = (b.entity_b)::text) AND (a.calculated_at = b.latest_date));


--
-- Name: market_summary; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.market_summary (
    id integer NOT NULL,
    market_id integer NOT NULL,
    analysis_category character varying(50) NOT NULL,
    analysis_text text NOT NULL,
    generated_by character varying(50) DEFAULT 'AI'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer NOT NULL
);


--
-- Name: vw_market_ai_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_market_ai_analysis AS
 SELECT DISTINCT ON (ms.user_id, ms.market_id, ms.analysis_category) ms.user_id,
    ms.market_id,
    m.market_name,
    ms.analysis_category,
    ms.analysis_text,
    ms.created_at
   FROM (transform_db.market_summary ms
     JOIN ingest_db.market m ON ((ms.market_id = m.market_id)))
  ORDER BY ms.user_id, ms.market_id, ms.analysis_category, ms.created_at DESC;


--
-- Name: vw_market_ai_analysis_bkp_02may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_market_ai_analysis_bkp_02may2026 AS
 SELECT DISTINCT ON (ms.user_id, ms.market_id, ms.analysis_category) ms.user_id,
    ms.market_id,
    m.market_name,
    ms.analysis_category,
    ms.analysis_text,
    ms.created_at
   FROM (transform_db.market_summary ms
     JOIN ingest_db.market m ON ((ms.market_id = m.market_id)))
  ORDER BY ms.user_id, ms.market_id, ms.analysis_category, ms.created_at DESC;


--
-- Name: vw_market_indexes; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_market_indexes AS
 SELECT index_id,
    index_name,
    change_percent,
    recorded_at
   FROM ingest_db.market_indexes v1
  WHERE (recorded_at = ( SELECT max(v2.recorded_at) AS max
           FROM ingest_db.market_indexes v2
          WHERE (v2.index_id = v1.index_id)));


--
-- Name: stocks_sentiment_analysis; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
PARTITION BY HASH (stock_id);


--
-- Name: vw_stocks_sentiment_latest; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_sentiment_latest AS
 SELECT DISTINCT ON (stock_id) analysis_id,
    stock_id,
    sentiment_score,
    sentiment_label,
    analysis_description,
    analyzed_by,
    analyzed_at,
    total_messages,
    positive_count,
    neutral_count,
    flags,
    sentiment_reasons,
    negative_count,
    platform,
    country
   FROM transform_db.stocks_sentiment_analysis
  ORDER BY stock_id, analyzed_at DESC;


--
-- Name: user_to_market_mapping; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.user_to_market_mapping (
    user_id integer,
    market_name character varying,
    last_updated_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: vw_user_to_market_mapping; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_user_to_market_mapping AS
 WITH latest_data AS (
         SELECT user_to_market_mapping.user_id,
            max(user_to_market_mapping.last_updated_date) AS latest_date
           FROM transform_db.user_to_market_mapping
          GROUP BY user_to_market_mapping.user_id
        )
 SELECT v1.user_id,
    v1.market_name,
    v1.last_updated_date
   FROM (transform_db.user_to_market_mapping v1
     JOIN latest_data v2 ON (((v2.user_id = v1.user_id) AND (v2.latest_date = v1.last_updated_date))));


--
-- Name: vw_marketwise_summary; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_marketwise_summary AS
 WITH user_market AS (
        (
                 SELECT vw_user_to_market_mapping.user_id,
                    'GLOBAL'::text AS market_type,
                    'GLOBAL'::text AS market_name
                   FROM semantic_db.vw_user_to_market_mapping
                  WHERE (upper((vw_user_to_market_mapping.market_name)::text) = 'GLOBAL'::text)
                UNION
                 SELECT u.user_id,
                    'GLOBAL'::text AS text,
                    'GLOBAL'::text AS text
                   FROM ingest_db.users u
                  WHERE (NOT (EXISTS ( SELECT 1
                           FROM semantic_db.vw_user_to_market_mapping m
                          WHERE (m.user_id = u.user_id))))
        ) UNION ALL
         SELECT m.user_id,
            'SELECTIVE'::text AS text,
            upper((m.market_name)::text) AS market_name
           FROM semantic_db.vw_user_to_market_mapping m
          WHERE ((upper((m.market_name)::text) <> 'GLOBAL'::text) AND (NOT (EXISTS ( SELECT 1
                   FROM semantic_db.vw_user_to_market_mapping g
                  WHERE ((g.user_id = m.user_id) AND (upper((g.market_name)::text) = 'GLOBAL'::text))))))
        ), user_list AS (
         SELECT u.user_id
           FROM ingest_db.users u
        ), user_portfolios AS (
         SELECT p.user_id,
            p.portfolio_id
           FROM ingest_db.portfolio p
        ), default_positions AS (
         SELECT ps.stock_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM (semantic_db.vw_portfolio_stocks ps
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
          WHERE ((ps.portfolio_id = 4) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_specific AS (
         SELECT up.user_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM ((user_portfolios up
             JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.portfolio_id = up.portfolio_id)))
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
          WHERE (((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_raw AS (
         SELECT user_holdings_specific.user_id,
            user_holdings_specific.market,
            user_holdings_specific.sector,
            user_holdings_specific.stock_id,
            user_holdings_specific.quantity,
            user_holdings_specific.avg_buy_price_local_curr,
            user_holdings_specific.avg_buy_price_usd
           FROM user_holdings_specific
        UNION ALL
         SELECT ul.user_id,
            dp.market,
            dp.sector,
            dp.stock_id,
            dp.quantity,
            dp.avg_buy_price_local_curr,
            dp.avg_buy_price_usd
           FROM (user_list ul
             CROSS JOIN default_positions dp)
          WHERE (NOT (concat(ul.user_id, '||', dp.stock_id) IN ( SELECT concat(user_holdings_specific.user_id, '||', user_holdings_specific.stock_id) AS concat
                   FROM user_holdings_specific)))
        ), user_holdings_by_mapping AS (
         SELECT user_holdings_raw.user_id,
            user_holdings_raw.market,
            user_holdings_raw.sector,
            user_holdings_raw.stock_id,
            user_holdings_raw.quantity,
            user_holdings_raw.avg_buy_price_local_curr,
            user_holdings_raw.avg_buy_price_usd
           FROM user_holdings_raw
          WHERE (user_holdings_raw.user_id IN ( SELECT user_market.user_id
                   FROM user_market
                  WHERE (user_market.market_type = 'GLOBAL'::text)))
        UNION
         SELECT uhr.user_id,
            uhr.market,
            uhr.sector,
            uhr.stock_id,
            uhr.quantity,
            uhr.avg_buy_price_local_curr,
            uhr.avg_buy_price_usd
           FROM (user_holdings_raw uhr
             JOIN user_market um ON (((um.user_id = uhr.user_id) AND (um.market_name = uhr.market))))
          WHERE (um.market_type = 'SELECTIVE'::text)
        ), user_summary_market_specific AS (
         SELECT uhr.user_id,
            uhr.market,
            COALESCE(sum((uhr.quantity * md.price_local_curr)), (0)::numeric) AS total_value_local_curr,
            COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) AS total_value_usd,
            (COALESCE(sum((uhr.quantity * md.price_local_curr)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_local_curr)), (0)::numeric)) AS daily_profit_loss_local_curr,
            (COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) AS daily_profit_loss_usd,
                CASE
                    WHEN (COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric) > (0)::numeric) THEN (((COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) / COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) * (100)::numeric)
                    ELSE (0)::numeric
                END AS total_return_pct,
            round(avg(sl.sentiment_score), 2) AS sentiment_index,
            count(DISTINCT uhr.stock_id) AS holdings,
            count(DISTINCT uhr.sector) AS sector_count
           FROM ((user_holdings_by_mapping uhr
             LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((md.stock_id = uhr.stock_id)))
             LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((sl.stock_id = uhr.stock_id)))
          GROUP BY uhr.user_id, uhr.market
        )
 SELECT user_summary_market_specific.user_id,
    user_summary_market_specific.market,
    user_summary_market_specific.total_value_local_curr,
    user_summary_market_specific.total_value_usd,
    user_summary_market_specific.daily_profit_loss_local_curr,
    user_summary_market_specific.daily_profit_loss_usd,
    user_summary_market_specific.total_return_pct,
    user_summary_market_specific.sentiment_index,
    user_summary_market_specific.holdings,
    user_summary_market_specific.sector_count
   FROM user_summary_market_specific
UNION
 SELECT user_summary_market_specific.user_id,
    'GLOBAL'::text AS market,
    COALESCE(sum(user_summary_market_specific.total_value_local_curr), (0)::numeric) AS total_value_local_curr,
    COALESCE(sum(user_summary_market_specific.total_value_usd), (0)::numeric) AS total_value_usd,
    COALESCE(sum(user_summary_market_specific.daily_profit_loss_local_curr), (0)::numeric) AS daily_profit_loss_local_curr,
    COALESCE(sum(user_summary_market_specific.daily_profit_loss_usd), (0)::numeric) AS daily_profit_loss_usd,
    COALESCE(sum(user_summary_market_specific.total_return_pct), (0)::numeric) AS total_return_pct,
    round(avg(user_summary_market_specific.sentiment_index), 2) AS sentiment_index,
    sum(user_summary_market_specific.holdings) AS holdings,
    sum(user_summary_market_specific.sector_count) AS sector_count
   FROM user_summary_market_specific
  GROUP BY user_summary_market_specific.user_id;


--
-- Name: vw_marketwise_summary1; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_marketwise_summary1 AS
 WITH user_market AS (
        (
                 SELECT vw_user_to_market_mapping.user_id,
                    'GLOBAL'::text AS market_type,
                    'GLOBAL'::text AS market_name
                   FROM semantic_db.vw_user_to_market_mapping
                  WHERE (upper((vw_user_to_market_mapping.market_name)::text) = 'GLOBAL'::text)
                UNION
                 SELECT u.user_id,
                    'GLOBAL'::text AS text,
                    'GLOBAL'::text AS text
                   FROM ingest_db.users u
                  WHERE (NOT (EXISTS ( SELECT 1
                           FROM semantic_db.vw_user_to_market_mapping m
                          WHERE (m.user_id = u.user_id))))
        ) UNION ALL
         SELECT m.user_id,
            'SELECTIVE'::text AS text,
            upper((m.market_name)::text) AS market_name
           FROM semantic_db.vw_user_to_market_mapping m
          WHERE ((upper((m.market_name)::text) <> 'GLOBAL'::text) AND (NOT (EXISTS ( SELECT 1
                   FROM semantic_db.vw_user_to_market_mapping g
                  WHERE ((g.user_id = m.user_id) AND (upper((g.market_name)::text) = 'GLOBAL'::text))))))
        ), user_list AS (
         SELECT u.user_id
           FROM ingest_db.users u
        ), user_portfolios AS (
         SELECT p.user_id,
            p.portfolio_id
           FROM ingest_db.portfolio p
        ), default_positions AS (
         SELECT ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM semantic_db.vw_portfolio_stocks ps
          WHERE ((ps.portfolio_id = 4) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text))
        ), user_holdings_specific AS (
         SELECT up.user_id,
            ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM (user_portfolios up
             JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.portfolio_id = up.portfolio_id)))
          WHERE ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text)
        ), user_holdings_raw AS (
         SELECT user_holdings_specific.user_id,
            user_holdings_specific.stock_id,
            user_holdings_specific.quantity,
            user_holdings_specific.avg_buy_price_local_curr,
            user_holdings_specific.avg_buy_price_usd
           FROM user_holdings_specific
        UNION ALL
         SELECT ul.user_id,
            dp.stock_id,
            dp.quantity,
            dp.avg_buy_price_local_curr,
            dp.avg_buy_price_usd
           FROM (user_list ul
             CROSS JOIN default_positions dp)
          WHERE (NOT (concat(ul.user_id, '||', dp.stock_id) IN ( SELECT concat(user_holdings_specific.user_id, '||', user_holdings_specific.stock_id) AS concat
                   FROM user_holdings_specific)))
        ), user_summary_market_specific AS (
         SELECT uhr.user_id,
            s.country_name_display AS market,
            COALESCE(sum((uhr.quantity * md.price_local_curr)), (0)::numeric) AS total_value_local_curr,
            COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) AS total_value_usd,
            (COALESCE(sum((uhr.quantity * md.price_local_curr)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_local_curr)), (0)::numeric)) AS daily_profit_loss_local_curr,
            (COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) AS daily_profit_loss_usd,
                CASE
                    WHEN (COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric) > (0)::numeric) THEN (((COALESCE(sum((uhr.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) / COALESCE(sum((uhr.quantity * uhr.avg_buy_price_usd)), (0)::numeric)) * (100)::numeric)
                    ELSE (0)::numeric
                END AS total_return_pct,
            round(avg(sl.sentiment_score), 2) AS sentiment_index,
            count(DISTINCT uhr.stock_id) AS holdings,
            count(DISTINCT s.sector) AS sector_count
           FROM (((user_holdings_raw uhr
             JOIN ingest_db.stocks s ON ((s.stock_id = uhr.stock_id)))
             LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
             LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
          WHERE (s.is_peer = false)
          GROUP BY uhr.user_id, s.country_name_display
        )
 SELECT user_summary_market_specific.user_id,
    user_summary_market_specific.market,
    user_summary_market_specific.total_value_local_curr,
    user_summary_market_specific.total_value_usd,
    user_summary_market_specific.daily_profit_loss_local_curr,
    user_summary_market_specific.daily_profit_loss_usd,
    user_summary_market_specific.total_return_pct,
    user_summary_market_specific.sentiment_index,
    user_summary_market_specific.holdings,
    user_summary_market_specific.sector_count
   FROM user_summary_market_specific
UNION
 SELECT user_summary_market_specific.user_id,
    'GLOBAL'::character varying AS market,
    COALESCE(sum(user_summary_market_specific.total_value_local_curr), (0)::numeric) AS total_value_local_curr,
    COALESCE(sum(user_summary_market_specific.total_value_usd), (0)::numeric) AS total_value_usd,
    COALESCE(sum(user_summary_market_specific.daily_profit_loss_local_curr), (0)::numeric) AS daily_profit_loss_local_curr,
    COALESCE(sum(user_summary_market_specific.daily_profit_loss_usd), (0)::numeric) AS daily_profit_loss_usd,
    COALESCE(sum(user_summary_market_specific.total_return_pct), (0)::numeric) AS total_return_pct,
    round(avg(user_summary_market_specific.sentiment_index), 2) AS sentiment_index,
    sum(user_summary_market_specific.holdings) AS holdings,
    sum(user_summary_market_specific.sector_count) AS sector_count
   FROM user_summary_market_specific
  GROUP BY user_summary_market_specific.user_id;


--
-- Name: vw_marketwise_summary_bkp_01may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_marketwise_summary_bkp_01may2026 AS
 SELECT p.user_id,
    s.country_name_display AS market,
    COALESCE(sum((ps.quantity * md.price_local_curr)), (0)::numeric) AS total_value_local_curr,
    COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) AS total_value_usd,
    (COALESCE(sum((ps.quantity * md.price_local_curr)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_local_curr)), (0)::numeric)) AS daily_profit_loss_local_curr,
    (COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) AS daily_profit_loss_usd,
        CASE
            WHEN (COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric) > (0)::numeric) THEN (((COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) / COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) * (100)::numeric)
            ELSE (0)::numeric
        END AS total_return_pct,
    round(avg(sl.sentiment_score), 2) AS sentiment_index,
    count(DISTINCT ps.stock_id) AS holdings,
    count(DISTINCT s.sector) AS sector_count
   FROM ((((ingest_db.portfolio p
     JOIN semantic_db.vw_portfolio_stocks ps ON ((p.portfolio_id = ps.portfolio_id)))
     JOIN ingest_db.stocks s ON ((ps.stock_id = s.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
  WHERE ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text)
  GROUP BY p.user_id, s.country_name_display
UNION ALL
 SELECT p.user_id,
    'GLOBAL'::character varying AS market,
    COALESCE(sum((ps.quantity * md.price_local_curr)), (0)::numeric) AS total_value_local_curr,
    COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) AS total_value_usd,
    (COALESCE(sum((ps.quantity * md.price_local_curr)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_local_curr)), (0)::numeric)) AS daily_profit_loss_local_curr,
    (COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) AS daily_profit_loss_usd,
        CASE
            WHEN (COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric) > (0)::numeric) THEN (((COALESCE(sum((ps.quantity * md.price_usd)), (0)::numeric) - COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) / COALESCE(sum((ps.quantity * ps.avg_buy_price_usd)), (0)::numeric)) * (100)::numeric)
            ELSE (0)::numeric
        END AS total_return_pct,
    round(avg(sl.sentiment_score), 2) AS sentiment_index,
    count(DISTINCT ps.stock_id) AS holdings,
    count(DISTINCT s.sector) AS sector_count
   FROM ((((ingest_db.portfolio p
     JOIN semantic_db.vw_portfolio_stocks ps ON ((p.portfolio_id = ps.portfolio_id)))
     JOIN ingest_db.stocks s ON ((ps.stock_id = s.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
  WHERE ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text)
  GROUP BY p.user_id;


--
-- Name: portfolio_ai_analysis; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.portfolio_ai_analysis (
    id integer NOT NULL,
    portfolio_id integer NOT NULL,
    analysis_category character varying(50) NOT NULL,
    analysis_text text NOT NULL,
    generated_by character varying(50) DEFAULT 'AI'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    user_id integer NOT NULL
);


--
-- Name: vw_portfolio_ai_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_ai_analysis AS
 SELECT portfolio_id,
    analysis_category,
    analysis_text,
    created_at
   FROM transform_db.portfolio_ai_analysis v1
  WHERE (created_at = ( SELECT max(v2.created_at) AS max
           FROM transform_db.portfolio_ai_analysis v2
          WHERE (((v2.analysis_category)::text = (v1.analysis_category)::text) AND (v2.portfolio_id = v1.portfolio_id))));


--
-- Name: vw_portfolio_benchmark_drawdown_value_trend; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_benchmark_drawdown_value_trend AS
 WITH user_market AS (
        (
                 SELECT vw_user_to_market_mapping.user_id,
                    'GLOBAL'::text AS market_type,
                    'GLOBAL'::text AS market_name
                   FROM semantic_db.vw_user_to_market_mapping
                  WHERE (upper((vw_user_to_market_mapping.market_name)::text) = 'GLOBAL'::text)
                UNION
                 SELECT u.user_id,
                    'GLOBAL'::text AS text,
                    'GLOBAL'::text AS text
                   FROM ingest_db.users u
                  WHERE (NOT (EXISTS ( SELECT 1
                           FROM semantic_db.vw_user_to_market_mapping m
                          WHERE (m.user_id = u.user_id))))
        ) UNION ALL
         SELECT m.user_id,
            'SELECTIVE'::text AS text,
            upper((m.market_name)::text) AS market_name
           FROM semantic_db.vw_user_to_market_mapping m
          WHERE ((upper((m.market_name)::text) <> 'GLOBAL'::text) AND (NOT (EXISTS ( SELECT 1
                   FROM semantic_db.vw_user_to_market_mapping g
                  WHERE ((g.user_id = m.user_id) AND (upper((g.market_name)::text) = 'GLOBAL'::text))))))
        ), user_list AS (
         SELECT u.user_id
           FROM ingest_db.users u
        ), user_portfolios AS (
         SELECT p.user_id,
            p.portfolio_id,
            p.portfolio_name
           FROM ingest_db.portfolio p
        ), default_positions AS (
         SELECT ps.portfolio_id,
            p.portfolio_name,
            ps.stock_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd,
            ps.currency_code
           FROM ((semantic_db.vw_portfolio_stocks ps
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
             JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)))
          WHERE ((p.is_default = true) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_specific AS (
         SELECT up.user_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.portfolio_id,
            up.portfolio_name,
            ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd,
            ps.currency_code
           FROM ((user_portfolios up
             JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.portfolio_id = up.portfolio_id)))
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
          WHERE (((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_raw AS (
         SELECT user_holdings_specific.user_id,
            user_holdings_specific.market,
            user_holdings_specific.sector,
            user_holdings_specific.portfolio_id,
            user_holdings_specific.portfolio_name,
            user_holdings_specific.stock_id,
            user_holdings_specific.quantity,
            user_holdings_specific.avg_buy_price_local_curr,
            user_holdings_specific.avg_buy_price_usd,
            user_holdings_specific.currency_code
           FROM user_holdings_specific
        UNION ALL
         SELECT ul.user_id,
            dp.market,
            dp.sector,
            dp.portfolio_id,
            dp.portfolio_name,
            dp.stock_id,
            dp.quantity,
            dp.avg_buy_price_local_curr,
            dp.avg_buy_price_usd,
            dp.currency_code
           FROM (user_list ul
             CROSS JOIN default_positions dp)
        ), user_holdings_by_mapping AS (
         SELECT user_holdings_raw.user_id,
            user_holdings_raw.market,
            user_holdings_raw.sector,
            user_holdings_raw.portfolio_id,
            user_holdings_raw.portfolio_name,
            user_holdings_raw.stock_id,
            user_holdings_raw.quantity,
            user_holdings_raw.avg_buy_price_local_curr,
            user_holdings_raw.avg_buy_price_usd,
            user_holdings_raw.currency_code
           FROM user_holdings_raw
          WHERE (user_holdings_raw.user_id IN ( SELECT user_market.user_id
                   FROM user_market
                  WHERE (user_market.market_type = 'GLOBAL'::text)))
        UNION
         SELECT uhr.user_id,
            uhr.market,
            uhr.sector,
            uhr.portfolio_id,
            uhr.portfolio_name,
            uhr.stock_id,
            uhr.quantity,
            uhr.avg_buy_price_local_curr,
            uhr.avg_buy_price_usd,
            uhr.currency_code
           FROM (user_holdings_raw uhr
             JOIN user_market um ON (((um.user_id = uhr.user_id) AND (um.market_name = uhr.market))))
          WHERE (um.market_type = 'SELECTIVE'::text)
        ), date_series AS (
         SELECT (generate_series((CURRENT_DATE - '90 days'::interval), (CURRENT_DATE)::timestamp without time zone, '1 day'::interval))::date AS valuation_date
        ), stock_price_filled AS (
         SELECT uhm_1.user_id,
            uhm_1.portfolio_id,
            uhm_1.stock_id,
            ds.valuation_date,
            sp.price_local_curr,
            sp.price_usd
           FROM ((user_holdings_by_mapping uhm_1
             CROSS JOIN date_series ds)
             LEFT JOIN LATERAL ( SELECT h.price_local_curr,
                    h.price_usd
                   FROM semantic_db.vw_stocks_price_data_history h
                  WHERE ((h.stock_id = uhm_1.stock_id) AND (h.price_date <= ds.valuation_date))
                  ORDER BY h.price_date DESC
                 LIMIT 1) sp ON (true))
        ), benchmark_filled AS (
         SELECT bh.benchmark_name,
            ds.valuation_date,
            bh.benchmark_value_local_curr,
            bh.benchmark_value_usd
           FROM (date_series ds
             LEFT JOIN LATERAL ( SELECT h.benchmark_name,
                    h.benchmark_value_local_curr,
                    h.benchmark_value_usd
                   FROM semantic_db.vw_benchmark_history h
                  WHERE (h.valuation_date <= ds.valuation_date)
                  ORDER BY h.valuation_date DESC
                 LIMIT 1) bh ON (true))
        )
 SELECT uhm.user_id,
    uhm.portfolio_id,
    spf.valuation_date,
    sum((uhm.quantity * spf.price_local_curr)) AS portfolio_value_local_curr,
    sum((uhm.quantity * spf.price_usd)) AS portfolio_value_usd,
    bf.benchmark_name,
    bf.benchmark_value_local_curr,
    bf.benchmark_value_usd,
    (sum((uhm.quantity * spf.price_local_curr)) - bf.benchmark_value_local_curr) AS drawdown_value_local_curr,
    (sum((uhm.quantity * spf.price_usd)) - bf.benchmark_value_usd) AS drawdown_value_usd
   FROM ((user_holdings_by_mapping uhm
     JOIN stock_price_filled spf ON (((spf.portfolio_id = uhm.portfolio_id) AND (spf.stock_id = uhm.stock_id))))
     LEFT JOIN benchmark_filled bf ON ((bf.valuation_date = spf.valuation_date)))
  GROUP BY uhm.user_id, uhm.portfolio_id, spf.valuation_date, bf.benchmark_name, bf.benchmark_value_local_curr, bf.benchmark_value_usd;


--
-- Name: vw_portfolio_benchmark_drawdown_value_trend_bkp_02may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_benchmark_drawdown_value_trend_bkp_02may2026 AS
 WITH date_series AS (
         SELECT (generate_series((CURRENT_DATE - '90 days'::interval), (CURRENT_DATE)::timestamp without time zone, '1 day'::interval))::date AS valuation_date
        ), stock_price_filled AS (
         SELECT ps_1.portfolio_id,
            ps_1.stock_id,
            ds.valuation_date,
            sp.price_local_curr,
            sp.price_usd
           FROM ((semantic_db.vw_portfolio_stocks ps_1
             CROSS JOIN date_series ds)
             LEFT JOIN LATERAL ( SELECT h.price_local_curr,
                    h.price_usd
                   FROM semantic_db.vw_stocks_price_data_history h
                  WHERE ((h.stock_id = ps_1.stock_id) AND (h.price_date <= ds.valuation_date))
                  ORDER BY h.price_date DESC
                 LIMIT 1) sp ON (true))
        ), benchmark_filled AS (
         SELECT bh.benchmark_name,
            ds.valuation_date,
            bh.benchmark_value_local_curr,
            bh.benchmark_value_usd
           FROM (date_series ds
             LEFT JOIN LATERAL ( SELECT h.benchmark_name,
                    h.benchmark_value_local_curr,
                    h.benchmark_value_usd
                   FROM semantic_db.vw_benchmark_history h
                  WHERE (h.valuation_date <= ds.valuation_date)
                  ORDER BY h.valuation_date DESC
                 LIMIT 1) bh ON (true))
        )
 SELECT p.portfolio_id,
    spf.valuation_date,
    sum((ps.quantity * spf.price_local_curr)) AS portfolio_value_local_curr,
    sum((ps.quantity * spf.price_usd)) AS portfolio_value_usd,
    bf.benchmark_name,
    bf.benchmark_value_local_curr,
    bf.benchmark_value_usd,
    (sum((ps.quantity * spf.price_local_curr)) - bf.benchmark_value_local_curr) AS drawdown_value_local_curr,
    (sum((ps.quantity * spf.price_usd)) - bf.benchmark_value_usd) AS drawdown_value_usd,
    p.user_id
   FROM (((ingest_db.portfolio p
     JOIN semantic_db.vw_portfolio_stocks ps ON ((p.portfolio_id = ps.portfolio_id)))
     JOIN stock_price_filled spf ON (((spf.portfolio_id = ps.portfolio_id) AND (spf.stock_id = ps.stock_id))))
     LEFT JOIN benchmark_filled bf ON ((bf.valuation_date = spf.valuation_date)))
  GROUP BY p.portfolio_id, p.user_id, spf.valuation_date, bf.benchmark_name, bf.benchmark_value_local_curr, bf.benchmark_value_usd;


--
-- Name: vw_portfolio_copilot_chat_history; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_copilot_chat_history AS
 SELECT chat_id,
    user_id,
    session_id,
    conversation,
    message_time,
    context,
    metadata
   FROM ingest_db.portfolio_copilot_chat_history;


--
-- Name: vw_stocks_flags; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_flags AS
 WITH latest AS (
         SELECT stocks_flags.stock_id,
            max(stocks_flags.created_at) AS latest_date
           FROM ingest_db.stocks_flags
          GROUP BY stocks_flags.stock_id
        )
 SELECT v1.flag_id,
    v1.stock_id,
    v1.flag_type,
    v1.flag_description,
    v1.created_at
   FROM (ingest_db.stocks_flags v1
     JOIN latest v2 ON (((v1.stock_id = v2.stock_id) AND (v1.created_at = v2.latest_date))));


--
-- Name: vw_portfolio_stocks_details; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_details AS
 SELECT base_view.portfolio_id,
    base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.sector,
    base_view.country_name,
    base_view.action,
    base_view.quantity,
    base_view.last_updated,
    base_view.local_currency,
    base_view.last_price_local_curr,
    base_view.last_price_usd,
    base_view.off_market_price_local_curr,
    base_view.off_market_price_usd,
    base_view.value_local_curr,
    base_view.value_usd,
    base_view.day_price_change_local_curr,
    base_view.day_price_change_usd,
    base_view.day_price_change_pct,
    base_view.volume,
    base_view.volume_30d,
    base_view.off_market_volume,
    base_view.off_market_volume_30d,
    base_view.sentiment_score,
    base_view.sentiment_label,
    base_view.sentiment_reasons,
    base_view.flag_type,
    base_view.flag_description,
    base_view.price_date,
    base_view.priority,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.portfolio_id,
            base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.sector,
            base_view_1.country_name,
            base_view_1.action,
            base_view_1.quantity,
            base_view_1.last_updated,
            base_view_1.local_currency,
            base_view_1.last_price_local_curr,
            base_view_1.last_price_usd,
            base_view_1.off_market_price_local_curr,
            base_view_1.off_market_price_usd,
            base_view_1.value_local_curr,
            base_view_1.value_usd,
            base_view_1.day_price_change_local_curr,
            base_view_1.day_price_change_usd,
            base_view_1.day_price_change_pct,
            base_view_1.volume,
            base_view_1.volume_30d,
            base_view_1.off_market_volume,
            base_view_1.off_market_volume_30d,
            base_view_1.sentiment_score,
            base_view_1.sentiment_label,
            base_view_1.sentiment_reasons,
            base_view_1.flag_type,
            base_view_1.flag_description,
            base_view_1.price_date,
            base_view_1.priority,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT ps.portfolio_id,
                    s.stock_id,
                    s.ticker,
                    s.company_name,
                    s.sector,
                    s.country_name,
                    ps.action,
                    ps.quantity,
                    ps.last_updated,
                    md.local_currency,
                    md.price_local_curr AS last_price_local_curr,
                    md.price_usd AS last_price_usd,
                    md.off_market_price_local_curr,
                    md.off_market_price_usd,
                    (ps.quantity * md.price_local_curr) AS value_local_curr,
                    (ps.quantity * md.price_usd) AS value_usd,
                    md.day_price_change_local_curr,
                    md.day_price_change_usd,
                    md.day_price_change_pct,
                    md.volume,
                    md.volume_30d,
                    md.off_market_volume,
                    md.off_market_volume_30d,
                    sl.sentiment_score,
                    sl.sentiment_label,
                    sl.sentiment_reasons,
                    sf.flag_type,
                    sf.flag_description,
                    md.price_date,
                    ps.priority
                   FROM ((((ingest_db.stocks s
                     LEFT JOIN semantic_db.vw_portfolio_stocks ps ON ((s.stock_id = ps.stock_id)))
                     JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_flags sf ON ((s.stock_id = sf.stock_id)))
                  WHERE (s.is_peer = false)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_portfolio_stocks_details_bkp_02may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_details_bkp_02may2026 AS
 SELECT base_view.portfolio_id,
    base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.sector,
    base_view.country_name,
    base_view.action,
    base_view.quantity,
    base_view.last_updated,
    base_view.local_currency,
    base_view.last_price_local_curr,
    base_view.last_price_usd,
    base_view.off_market_price_local_curr,
    base_view.off_market_price_usd,
    base_view.value_local_curr,
    base_view.value_usd,
    base_view.day_price_change_local_curr,
    base_view.day_price_change_usd,
    base_view.day_price_change_pct,
    base_view.volume,
    base_view.volume_30d,
    base_view.off_market_volume,
    base_view.off_market_volume_30d,
    base_view.sentiment_score,
    base_view.sentiment_label,
    base_view.sentiment_reasons,
    base_view.flag_type,
    base_view.flag_description,
    base_view.price_date,
    base_view.priority,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.portfolio_id,
            base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.sector,
            base_view_1.country_name,
            base_view_1.action,
            base_view_1.quantity,
            base_view_1.last_updated,
            base_view_1.local_currency,
            base_view_1.last_price_local_curr,
            base_view_1.last_price_usd,
            base_view_1.off_market_price_local_curr,
            base_view_1.off_market_price_usd,
            base_view_1.value_local_curr,
            base_view_1.value_usd,
            base_view_1.day_price_change_local_curr,
            base_view_1.day_price_change_usd,
            base_view_1.day_price_change_pct,
            base_view_1.volume,
            base_view_1.volume_30d,
            base_view_1.off_market_volume,
            base_view_1.off_market_volume_30d,
            base_view_1.sentiment_score,
            base_view_1.sentiment_label,
            base_view_1.sentiment_reasons,
            base_view_1.flag_type,
            base_view_1.flag_description,
            base_view_1.price_date,
            base_view_1.priority,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT ps.portfolio_id,
                    s.stock_id,
                    s.ticker,
                    s.company_name,
                    s.sector,
                    s.country_name,
                    ps.action,
                    ps.quantity,
                    ps.last_updated,
                    md.local_currency,
                    md.price_local_curr AS last_price_local_curr,
                    md.price_usd AS last_price_usd,
                    md.off_market_price_local_curr,
                    md.off_market_price_usd,
                    (ps.quantity * md.price_local_curr) AS value_local_curr,
                    (ps.quantity * md.price_usd) AS value_usd,
                    md.day_price_change_local_curr,
                    md.day_price_change_usd,
                    md.day_price_change_pct,
                    md.volume,
                    md.volume_30d,
                    md.off_market_volume,
                    md.off_market_volume_30d,
                    sl.sentiment_score,
                    sl.sentiment_label,
                    sl.sentiment_reasons,
                    sf.flag_type,
                    sf.flag_description,
                    md.price_date,
                    ps.priority
                   FROM ((((ingest_db.stocks s
                     LEFT JOIN semantic_db.vw_portfolio_stocks ps ON ((s.stock_id = ps.stock_id)))
                     JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_flags sf ON ((s.stock_id = sf.stock_id)))
                  WHERE (s.is_peer = false)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_portfolio_stocks_events; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_events AS
 SELECT ps.portfolio_id,
    se.event_time,
    json_agg(json_build_object('stock_id', se.stock_id, 'ticker', se.ticker, 'event_type', se.event_type, 'event_description', se.event_description)) AS events
   FROM (semantic_db.vw_portfolio_stocks ps
     LEFT JOIN ingest_db.stocks_events se ON ((ps.stock_id = se.stock_id)))
  WHERE (se.event_time >= (CURRENT_DATE - '90 days'::interval))
  GROUP BY ps.portfolio_id, se.event_time;


--
-- Name: vw_portfolio_stocks_market_alerts; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_market_alerts AS
 SELECT ps.portfolio_id,
    sma.alert_id,
    sma.stock_id,
    sma.stock_symbol,
    sma.alert_type,
    sma.description,
    sma.source,
    sma.alert_date,
    sma.severity,
    sma.url,
    sma.status,
    sma.created_at,
    p.user_id,
    s.country_name AS market_name
   FROM (((ingest_db.stocks_market_alerts sma
     JOIN ingest_db.stocks s ON ((sma.stock_id = s.stock_id)))
     JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.stock_id = s.stock_id)))
     JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)));


--
-- Name: vw_portfolio_stocks_market_news; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_market_news AS
 SELECT ps.portfolio_id,
    sm.news_id,
    sm.stock_id,
    sm.stock_symbol,
    sm.headline,
    sm.description,
    sm.source,
    sm.published_date,
    sm.url,
    sm.stock_company,
    sm.sentiment_score,
    sm.sentiment_label,
    sm.created_at,
    p.user_id,
    s.country_name AS market_name
   FROM (((ingest_db.stocks_market_news sm
     JOIN ingest_db.stocks s ON ((sm.stock_id = s.stock_id)))
     JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.stock_id = s.stock_id)))
     JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)));


--
-- Name: vw_portfolio_stocks_upcoming_earnings; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_stocks_upcoming_earnings AS
 SELECT base_view.portfolio_id,
    base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.market_cap_local_curr,
    base_view.market_cap_usd,
    base_view.earnings_date,
    base_view.estimated_eps_local_curr,
    base_view.estimated_eps_usd,
    base_view.user_id,
    base_view.market_name,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.portfolio_id,
            base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.market_cap_local_curr,
            base_view_1.market_cap_usd,
            base_view_1.earnings_date,
            base_view_1.estimated_eps_local_curr,
            base_view_1.estimated_eps_usd,
            base_view_1.user_id,
            base_view_1.market_name,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT ps.portfolio_id,
                    s.stock_id,
                    ue.ticker,
                    s.company_name,
                    ue.market_cap AS market_cap_local_curr,
                        CASE
                            WHEN (ue.currency_code = (fr.target_currency)::bpchar) THEN ue.market_cap
                            ELSE (ue.market_cap * fr.exchange_rate)
                        END AS market_cap_usd,
                    ue.earnings_date,
                    ue.estimated_eps AS estimated_eps_local_curr,
                        CASE
                            WHEN (ue.currency_code = (fr.target_currency)::bpchar) THEN ue.estimated_eps
                            ELSE (ue.estimated_eps * fr.exchange_rate)
                        END AS estimated_eps_usd,
                    p.user_id,
                    s.country_name AS market_name
                   FROM ((((ingest_db.stocks_upcoming_earnings ue
                     JOIN ingest_db.stocks s ON ((ue.stock_id = s.stock_id)))
                     JOIN semantic_db.vw_portfolio_stocks ps ON ((s.stock_id = ps.stock_id)))
                     JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)))
                     JOIN semantic_db.vw_forex_rates fr ON (((ue.currency_code = (fr.source_currency)::bpchar) AND ((fr.target_currency)::text = 'USD'::text))))
                  WHERE ((ue.earnings_date >= CURRENT_DATE) AND (ue.earnings_date > ue.created_at))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_portfolio_summary; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_summary AS
 WITH user_market AS (
        (
                 SELECT vw_user_to_market_mapping.user_id,
                    'GLOBAL'::text AS market_type,
                    'GLOBAL'::text AS market_name
                   FROM semantic_db.vw_user_to_market_mapping
                  WHERE (upper((vw_user_to_market_mapping.market_name)::text) = 'GLOBAL'::text)
                UNION
                 SELECT u.user_id,
                    'GLOBAL'::text AS text,
                    'GLOBAL'::text AS text
                   FROM ingest_db.users u
                  WHERE (NOT (EXISTS ( SELECT 1
                           FROM semantic_db.vw_user_to_market_mapping m
                          WHERE (m.user_id = u.user_id))))
        ) UNION ALL
         SELECT m.user_id,
            'SELECTIVE'::text AS text,
            upper((m.market_name)::text) AS market_name
           FROM semantic_db.vw_user_to_market_mapping m
          WHERE ((upper((m.market_name)::text) <> 'GLOBAL'::text) AND (NOT (EXISTS ( SELECT 1
                   FROM semantic_db.vw_user_to_market_mapping g
                  WHERE ((g.user_id = m.user_id) AND (upper((g.market_name)::text) = 'GLOBAL'::text))))))
        ), user_list AS (
         SELECT u.user_id
           FROM ingest_db.users u
        ), user_portfolios AS (
         SELECT p.user_id,
            p.portfolio_id,
            p.portfolio_name
           FROM ingest_db.portfolio p
        ), default_positions AS (
         SELECT ps.portfolio_id,
            p.portfolio_name,
            ps.stock_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM ((semantic_db.vw_portfolio_stocks ps
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
             JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)))
          WHERE ((p.is_default = true) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_specific AS (
         SELECT up.user_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.portfolio_id,
            up.portfolio_name,
            ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd
           FROM ((user_portfolios up
             JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.portfolio_id = up.portfolio_id)))
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
          WHERE (((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_raw AS (
         SELECT user_holdings_specific.user_id,
            user_holdings_specific.market,
            user_holdings_specific.sector,
            user_holdings_specific.portfolio_id,
            user_holdings_specific.portfolio_name,
            user_holdings_specific.stock_id,
            user_holdings_specific.quantity,
            user_holdings_specific.avg_buy_price_local_curr,
            user_holdings_specific.avg_buy_price_usd
           FROM user_holdings_specific
        UNION ALL
         SELECT ul.user_id,
            dp.market,
            dp.sector,
            dp.portfolio_id,
            dp.portfolio_name,
            dp.stock_id,
            dp.quantity,
            dp.avg_buy_price_local_curr,
            dp.avg_buy_price_usd
           FROM (user_list ul
             CROSS JOIN default_positions dp)
        ), user_holdings_by_mapping AS (
         SELECT user_holdings_raw.user_id,
            user_holdings_raw.market,
            user_holdings_raw.sector,
            user_holdings_raw.portfolio_id,
            user_holdings_raw.portfolio_name,
            user_holdings_raw.stock_id,
            user_holdings_raw.quantity,
            user_holdings_raw.avg_buy_price_local_curr,
            user_holdings_raw.avg_buy_price_usd
           FROM user_holdings_raw
          WHERE (user_holdings_raw.user_id IN ( SELECT user_market.user_id
                   FROM user_market
                  WHERE (user_market.market_type = 'GLOBAL'::text)))
        UNION
         SELECT uhr_1.user_id,
            uhr_1.market,
            uhr_1.sector,
            uhr_1.portfolio_id,
            uhr_1.portfolio_name,
            uhr_1.stock_id,
            uhr_1.quantity,
            uhr_1.avg_buy_price_local_curr,
            uhr_1.avg_buy_price_usd
           FROM (user_holdings_raw uhr_1
             JOIN user_market um ON (((um.user_id = uhr_1.user_id) AND (um.market_name = uhr_1.market))))
          WHERE (um.market_type = 'SELECTIVE'::text)
        )
 SELECT uhr.user_id,
    uhr.portfolio_id,
    uhr.portfolio_name,
    sum((uhr.quantity * md.price_local_curr)) AS total_value_local_curr,
    sum((uhr.quantity * md.price_usd)) AS total_value_usd,
    (sum((uhr.quantity * md.price_local_curr)) - sum((uhr.quantity * uhr.avg_buy_price_local_curr))) AS daily_profit_loss_local_curr,
    (sum((uhr.quantity * md.price_usd)) - sum((uhr.quantity * uhr.avg_buy_price_usd))) AS daily_profit_loss_usd,
        CASE
            WHEN (sum((uhr.quantity * uhr.avg_buy_price_usd)) > (0)::numeric) THEN (((sum((uhr.quantity * md.price_usd)) - sum((uhr.quantity * uhr.avg_buy_price_usd))) / sum((uhr.quantity * uhr.avg_buy_price_usd))) * (100)::numeric)
            ELSE (0)::numeric
        END AS total_return_pct,
    round(avg(COALESCE(sl.sentiment_score, (0)::numeric)), 2) AS sentiment_index,
    count(DISTINCT uhr.stock_id) AS holdings,
    count(DISTINCT uhr.sector) AS sector_count
   FROM ((user_holdings_by_mapping uhr
     LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((md.stock_id = uhr.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((sl.stock_id = uhr.stock_id)))
  GROUP BY uhr.user_id, uhr.portfolio_id, uhr.portfolio_name;


--
-- Name: vw_portfolio_summary_bkp_02may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_portfolio_summary_bkp_02may2026 AS
 SELECT p.portfolio_id,
    p.portfolio_name,
    sum((ps.quantity * md.price_local_curr)) AS total_value_local_curr,
    sum((ps.quantity * md.price_usd)) AS total_value_usd,
    (sum((ps.quantity * md.price_local_curr)) - sum((ps.quantity * ps.avg_buy_price_local_curr))) AS daily_profit_loss_local_curr,
    (sum((ps.quantity * md.price_usd)) - sum((ps.quantity * ps.avg_buy_price_usd))) AS daily_profit_loss_usd,
        CASE
            WHEN (sum((ps.quantity * ps.avg_buy_price_usd)) > (0)::numeric) THEN (((sum((ps.quantity * md.price_usd)) - sum((ps.quantity * ps.avg_buy_price_usd))) / sum((ps.quantity * ps.avg_buy_price_usd))) * (100)::numeric)
            ELSE (0)::numeric
        END AS total_return_pct,
    round(avg(sl.sentiment_score), 2) AS sentiment_index,
    count(DISTINCT ps.stock_id) AS holdings,
    count(DISTINCT s.sector) AS sector_count
   FROM ((((ingest_db.portfolio p
     JOIN semantic_db.vw_portfolio_stocks ps ON (((p.portfolio_id = ps.portfolio_id) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text))))
     JOIN ingest_db.stocks s ON ((ps.stock_id = s.stock_id)))
     JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
  GROUP BY p.portfolio_id, p.portfolio_name;


--
-- Name: research_copilot_prompt_suggestions; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.research_copilot_prompt_suggestions (
    suggestion_id integer NOT NULL,
    stock_id integer,
    suggested_prompt text NOT NULL,
    generated_by character varying(50) DEFAULT 'AI'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: vw_research_copilot_prompt_suggestions; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_research_copilot_prompt_suggestions AS
 SELECT suggestion_id,
    stock_id,
    suggested_prompt,
    generated_by,
    created_at
   FROM transform_db.research_copilot_prompt_suggestions;


--
-- Name: research_copilot_report_sharing; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.research_copilot_report_sharing (
    share_id integer NOT NULL,
    report_id integer NOT NULL,
    shared_with character varying(100),
    share_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    share_method character varying(50)
);


--
-- Name: vw_research_copilot_report_sharing; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_research_copilot_report_sharing AS
 SELECT share_id,
    report_id,
    shared_with,
    share_date,
    share_method
   FROM transform_db.research_copilot_report_sharing;


--
-- Name: research_copilot_reports; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.research_copilot_reports (
    report_id integer NOT NULL,
    prompt_id integer NOT NULL,
    report_text text NOT NULL,
    generated_by character varying(50),
    download_url character varying(500),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: vw_research_copilot_reports; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_research_copilot_reports AS
 SELECT report_id,
    prompt_id,
    report_text,
    generated_by,
    download_url,
    created_at
   FROM transform_db.research_copilot_reports;


--
-- Name: vw_research_copilot_user_prompts; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_research_copilot_user_prompts AS
 SELECT prompt_id,
    stock_id,
    user_id,
    prompt_text,
    last_updated_at
   FROM ingest_db.research_copilot_user_prompts;


--
-- Name: vw_sectorwise_portfolio_stocks_allocation; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_sectorwise_portfolio_stocks_allocation AS
 WITH user_market AS (
        (
                 SELECT vw_user_to_market_mapping.user_id,
                    'GLOBAL'::text AS market_type,
                    'GLOBAL'::text AS market_name
                   FROM semantic_db.vw_user_to_market_mapping
                  WHERE (upper((vw_user_to_market_mapping.market_name)::text) = 'GLOBAL'::text)
                UNION
                 SELECT u.user_id,
                    'GLOBAL'::text AS text,
                    'GLOBAL'::text AS text
                   FROM ingest_db.users u
                  WHERE (NOT (EXISTS ( SELECT 1
                           FROM semantic_db.vw_user_to_market_mapping m
                          WHERE (m.user_id = u.user_id))))
        ) UNION ALL
         SELECT m.user_id,
            'SELECTIVE'::text AS text,
            upper((m.market_name)::text) AS market_name
           FROM semantic_db.vw_user_to_market_mapping m
          WHERE ((upper((m.market_name)::text) <> 'GLOBAL'::text) AND (NOT (EXISTS ( SELECT 1
                   FROM semantic_db.vw_user_to_market_mapping g
                  WHERE ((g.user_id = m.user_id) AND (upper((g.market_name)::text) = 'GLOBAL'::text))))))
        ), user_list AS (
         SELECT u.user_id
           FROM ingest_db.users u
        ), user_portfolios AS (
         SELECT p.user_id,
            p.portfolio_id,
            p.portfolio_name
           FROM ingest_db.portfolio p
        ), default_positions AS (
         SELECT ps.portfolio_id,
            p.portfolio_name,
            ps.stock_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd,
            ps.currency_code
           FROM ((semantic_db.vw_portfolio_stocks ps
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
             JOIN ingest_db.portfolio p ON ((p.portfolio_id = ps.portfolio_id)))
          WHERE ((p.is_default = true) AND ((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_specific AS (
         SELECT up.user_id,
            upper((s.country_name_display)::text) AS market,
            s.sector,
            ps.portfolio_id,
            up.portfolio_name,
            ps.stock_id,
            ps.quantity,
            ps.avg_buy_price_local_curr,
            ps.avg_buy_price_usd,
            ps.currency_code
           FROM ((user_portfolios up
             JOIN semantic_db.vw_portfolio_stocks ps ON ((ps.portfolio_id = up.portfolio_id)))
             JOIN ingest_db.stocks s ON ((s.stock_id = ps.stock_id)))
          WHERE (((COALESCE(ps.action, ''::character varying))::text <> 'Delete'::text) AND (s.is_peer = false))
        ), user_holdings_raw AS (
         SELECT user_holdings_specific.user_id,
            user_holdings_specific.market,
            user_holdings_specific.sector,
            user_holdings_specific.portfolio_id,
            user_holdings_specific.portfolio_name,
            user_holdings_specific.stock_id,
            user_holdings_specific.quantity,
            user_holdings_specific.avg_buy_price_local_curr,
            user_holdings_specific.avg_buy_price_usd,
            user_holdings_specific.currency_code
           FROM user_holdings_specific
        UNION ALL
         SELECT ul.user_id,
            dp.market,
            dp.sector,
            dp.portfolio_id,
            dp.portfolio_name,
            dp.stock_id,
            dp.quantity,
            dp.avg_buy_price_local_curr,
            dp.avg_buy_price_usd,
            dp.currency_code
           FROM (user_list ul
             CROSS JOIN default_positions dp)
        ), user_holdings_by_mapping AS (
         SELECT user_holdings_raw.user_id,
            user_holdings_raw.market,
            user_holdings_raw.sector,
            user_holdings_raw.portfolio_id,
            user_holdings_raw.portfolio_name,
            user_holdings_raw.stock_id,
            user_holdings_raw.quantity,
            user_holdings_raw.avg_buy_price_local_curr,
            user_holdings_raw.avg_buy_price_usd,
            user_holdings_raw.currency_code
           FROM user_holdings_raw
          WHERE (user_holdings_raw.user_id IN ( SELECT user_market.user_id
                   FROM user_market
                  WHERE (user_market.market_type = 'GLOBAL'::text)))
        UNION
         SELECT uhr_1.user_id,
            uhr_1.market,
            uhr_1.sector,
            uhr_1.portfolio_id,
            uhr_1.portfolio_name,
            uhr_1.stock_id,
            uhr_1.quantity,
            uhr_1.avg_buy_price_local_curr,
            uhr_1.avg_buy_price_usd,
            uhr_1.currency_code
           FROM (user_holdings_raw uhr_1
             JOIN user_market um ON (((um.user_id = uhr_1.user_id) AND (um.market_name = uhr_1.market))))
          WHERE (um.market_type = 'SELECTIVE'::text)
        )
 SELECT uhr.user_id,
    uhr.portfolio_id,
    uhr.sector,
    sum((uhr.quantity * md.price_local_curr)) AS allocation_value_local_curr,
    sum((uhr.quantity * md.price_usd)) AS allocation_value_usd,
    round(((sum((uhr.quantity * md.price_usd)) / NULLIF(( SELECT sum((uhr2.quantity * md2.price_usd)) AS sum
           FROM (user_holdings_by_mapping uhr2
             JOIN semantic_db.vw_stocks_price_data_latest md2 ON ((md2.stock_id = uhr2.stock_id)))
          WHERE ((uhr2.portfolio_id = uhr.portfolio_id) AND (uhr2.user_id = uhr.user_id))), (0)::numeric)) * (100)::numeric), 2) AS allocation_pct
   FROM ((user_holdings_by_mapping uhr
     JOIN semantic_db.vw_stocks_price_data_latest md ON ((md.stock_id = uhr.stock_id)))
     JOIN semantic_db.vw_forex_rates fr ON (((upper((md.currency_code)::text) = ((upper((fr.source_currency)::text))::bpchar)::text) AND (upper((uhr.currency_code)::text) = ((upper((fr.source_currency)::text))::bpchar)::text) AND ((fr.target_currency)::text = 'USD'::text))))
  GROUP BY uhr.user_id, uhr.portfolio_id, uhr.sector;


--
-- Name: vw_sectorwise_portfolio_stocks_allocation_bkp_02may2026; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_sectorwise_portfolio_stocks_allocation_bkp_02may2026 AS
 SELECT p.portfolio_id,
    s.sector,
    sum((ps.quantity * md.price_local_curr)) AS allocation_value_local_curr,
    sum((ps.quantity * md.price_usd)) AS allocation_value_usd,
    round(((sum((ps.quantity * md.price_usd)) / NULLIF(( SELECT sum((ps2.quantity * md2.price_usd)) AS sum
           FROM (ingest_db.portfolio_stocks ps2
             JOIN semantic_db.vw_stocks_price_data_latest md2 ON ((ps2.stock_id = md2.stock_id)))
          WHERE (ps2.portfolio_id = p.portfolio_id)), (0)::numeric)) * (100)::numeric), 2) AS allocation_pct
   FROM ((((ingest_db.portfolio p
     JOIN semantic_db.vw_portfolio_stocks ps ON ((p.portfolio_id = ps.portfolio_id)))
     JOIN ingest_db.stocks s ON ((ps.stock_id = s.stock_id)))
     JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
     JOIN semantic_db.vw_forex_rates fr ON (((md.currency_code = (fr.source_currency)::bpchar) AND (ps.currency_code = (fr.source_currency)::bpchar) AND ((fr.target_currency)::text = 'USD'::text))))
  GROUP BY p.portfolio_id, s.sector;


--
-- Name: vw_stock_copilot_chat_history; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stock_copilot_chat_history AS
 SELECT chat_id,
    user_id,
    session_id,
    conversation,
    stock_id,
    message_time,
    context,
    metadata
   FROM ingest_db.stock_copilot_chat_history;


--
-- Name: vw_stock_ingestion_job_progress; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stock_ingestion_job_progress AS
 SELECT job_id,
    tickers,
    requested_by,
    created_at,
    updated_at,
    status AS legacy_status,
    core_status,
    ai_status,
    current_tier,
    step_fn_execution,
    ai_step_fn_execution,
    error_message,
    ai_error_message,
    core_completed_at,
    ai_started_at,
    ai_completed_at,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 'failed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 'completed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 'core_completed_ai_pending'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'running'::text)) THEN 'ai_running'::text
            WHEN ((COALESCE(core_status, COALESCE(status, 'pending'::character varying)))::text = ANY (ARRAY['running'::text, 'pending'::text])) THEN 'core_running'::text
            ELSE 'pending'::text
        END AS overall_status,
        CASE
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 'stage3_ai'::text
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 'stage2_fundamentals_and_refresh'::text
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 'stage1_pre_fundamentals_and_refresh'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 'stage3_ai_queued'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 'stage3_ai_complete'::text
            ELSE 'queued'::text
        END AS current_step,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 'Failed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 'Completed'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 'AI summaries in progress'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 'Stock data ready, AI summary queued'::text
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 'Collecting fundamentals and refreshing data'::text
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 'Adding stock data and preparing first refresh'::text
            WHEN ((COALESCE(core_status, COALESCE(status, 'pending'::character varying)))::text = ANY (ARRAY['running'::text, 'pending'::text])) THEN 'Adding stock data'::text
            ELSE 'Pending'::text
        END AS ui_message,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 1
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 1
            ELSE 0
        END AS is_terminal,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN COALESCE(NULLIF(ai_error_message, ''::text), NULLIF(error_message, ''::text))
            ELSE NULL::text
        END AS active_error_message,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 100
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 90
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 75
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 55
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 25
            WHEN ((COALESCE(core_status, COALESCE(status, 'pending'::character varying)))::text = ANY (ARRAY['running'::text, 'pending'::text])) THEN 10
            ELSE 0
        END AS progress_pct,
    stage1_status,
    stage2_status,
    stage1_started_at,
    stage1_completed_at,
    stage2_started_at,
    stage2_completed_at,
        CASE
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'success'::text) THEN 'success'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) THEN 'failed'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 'running'::text
            ELSE 'pending'::text
        END AS stage3_status,
        CASE
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 3
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 2
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 1
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 3
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 3
            ELSE 1
        END AS active_stage,
    canonical_tickers
   FROM ingest_db.stock_ingestion_jobs j;


--
-- Name: vw_stock_ingestion_request_children; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stock_ingestion_request_children AS
 SELECT request_id,
    job_id,
    chunk_index,
    chunks_total,
    tickers AS chunk_tickers,
    chunk_size,
    attempt_count,
    created_at,
    updated_at,
    core_completed_at,
    ai_started_at,
    ai_completed_at,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 'failed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 'completed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 'core_completed_ai_pending'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'running'::text)) THEN 'ai_running'::text
            WHEN ((COALESCE(core_status, COALESCE(status, 'pending'::character varying)))::text = ANY (ARRAY['running'::text, 'pending'::text])) THEN 'core_running'::text
            ELSE 'pending'::text
        END AS overall_status,
    core_status,
    ai_status,
    stage1_status,
    stage2_status,
        CASE
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'success'::text) THEN 'success'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) THEN 'failed'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 'running'::text
            ELSE 'pending'::text
        END AS stage3_status,
        CASE
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 3
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 2
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 1
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 3
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 3
            ELSE 1
        END AS active_stage,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 100
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 90
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 75
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 55
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 25
            WHEN ((COALESCE(core_status, COALESCE(status, 'pending'::character varying)))::text = ANY (ARRAY['running'::text, 'pending'::text])) THEN 10
            ELSE 0
        END AS progress_pct,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN COALESCE(NULLIF(ai_error_message, ''::text), NULLIF(error_message, ''::text))
            ELSE NULL::text
        END AS active_error_message,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 'Failed'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 'Completed'::text
            WHEN ((COALESCE(ai_status, ''::character varying))::text = 'running'::text) THEN 'AI summaries in progress'::text
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, 'not_started'::character varying))::text = ANY (ARRAY['not_started'::text, 'pending'::text]))) THEN 'Stock data ready, AI summary queued'::text
            WHEN ((COALESCE(stage2_status, ''::character varying))::text = 'running'::text) THEN 'Collecting fundamentals'::text
            WHEN ((COALESCE(stage1_status, ''::character varying))::text = 'running'::text) THEN 'Adding stock data'::text
            ELSE 'Pending'::text
        END AS ui_message,
        CASE
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(ai_status, ''::character varying))::text = 'failed'::text) OR ((COALESCE(status, ''::character varying))::text = 'failed'::text)) THEN 1
            WHEN (((COALESCE(core_status, ''::character varying))::text = 'success'::text) AND ((COALESCE(ai_status, ''::character varying))::text = 'success'::text)) THEN 1
            ELSE 0
        END AS is_terminal,
    queue_message_id,
    queued_at,
    dequeued_at,
    step_fn_execution,
    canonical_tickers AS chunk_canonical_tickers
   FROM ingest_db.stock_ingestion_jobs j
  WHERE (request_id IS NOT NULL)
  ORDER BY request_id, chunk_index;


--
-- Name: vw_stock_ingestion_request_progress; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stock_ingestion_request_progress AS
 SELECT r.request_id,
    r.portfolio_id,
    r.requested_by,
    r.requested_tickers,
    r.chunk_size,
    r.child_jobs_total,
    COALESCE(agg.children_started, (0)::bigint) AS child_jobs_started,
    COALESCE(agg.children_succeeded, (0)::bigint) AS child_jobs_succeeded,
    COALESCE(agg.children_failed, (0)::bigint) AS child_jobs_failed,
    COALESCE(agg.children_running, (0)::bigint) AS child_jobs_running,
        CASE
            WHEN ((COALESCE(agg.children_failed, (0)::bigint) > 0) AND (COALESCE(agg.children_running, (0)::bigint) = 0)) THEN 'failed'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'success'::text)) THEN 'completed'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'failed'::text)) THEN 'failed'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'running'::text)) THEN 'ai_running'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0)) THEN 'core_completed_ai_pending'::text
            WHEN (COALESCE(agg.children_running, (0)::bigint) > 0) THEN 'core_running'::text
            WHEN ((COALESCE(agg.children_failed, (0)::bigint) > 0) AND (COALESCE(agg.children_running, (0)::bigint) > 0)) THEN 'partial_failure'::text
            ELSE 'running'::text
        END AS overall_status,
        CASE
            WHEN ((COALESCE(agg.children_core_failed, (0)::bigint) > 0) AND (COALESCE(agg.children_running, (0)::bigint) = 0)) THEN 'failed'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0)) THEN 'success'::text
            ELSE 'running'::text
        END AS core_status,
    (COALESCE(r.ai_status, 'not_started'::character varying))::text AS ai_status,
        CASE
            WHEN ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'running'::text) THEN 3
            WHEN (COALESCE(agg.children_stage2_running, (0)::bigint) > 0) THEN 2
            ELSE 1
        END AS active_stage,
        CASE
            WHEN (r.child_jobs_total = 0) THEN (0)::bigint
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'success'::text)) THEN (100)::bigint
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'running'::text)) THEN (90)::bigint
            WHEN (COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) THEN (75)::bigint
            ELSE LEAST((75)::bigint, ((COALESCE(agg.children_core_succeeded, (0)::bigint) * 75) / r.child_jobs_total))
        END AS progress_pct,
        CASE
            WHEN ((COALESCE(agg.children_failed, (0)::bigint) > 0) AND (COALESCE(agg.children_running, (0)::bigint) = 0)) THEN 'Request failed'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'success'::text)) THEN 'All tickers processed successfully'::text
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = 'running'::text)) THEN format('Core data ready for all %s tickers, AI summaries in progress'::text, array_length(r.requested_tickers, 1))
            WHEN ((COALESCE(agg.children_core_succeeded, (0)::bigint) = r.child_jobs_total) AND (r.child_jobs_total > 0)) THEN format('Core data ready for all %s tickers, AI pending'::text, array_length(r.requested_tickers, 1))
            WHEN ((COALESCE(agg.children_failed, (0)::bigint) > 0) AND (COALESCE(agg.children_running, (0)::bigint) > 0)) THEN format('%s of %s batches failed, %s still running'::text, agg.children_failed, r.child_jobs_total, agg.children_running)
            WHEN (COALESCE(agg.children_core_succeeded, (0)::bigint) > 0) THEN format('Core data ready for %s of %s batches'::text, agg.children_core_succeeded, r.child_jobs_total)
            ELSE format('Processing %s tickers in %s batches'::text, array_length(r.requested_tickers, 1), r.child_jobs_total)
        END AS ui_message,
    COALESCE(NULLIF(r.ai_error_message, ''::text), agg.first_error_message) AS active_error_message,
        CASE
            WHEN ((COALESCE(agg.children_running, (0)::bigint) = 0) AND (r.child_jobs_total > 0) AND ((COALESCE(agg.children_succeeded, (0)::bigint) + COALESCE(agg.children_failed, (0)::bigint)) = r.child_jobs_total) AND ((COALESCE(r.ai_status, 'not_started'::character varying))::text = ANY (ARRAY['success'::text, 'failed'::text]))) THEN 1
            ELSE 0
        END AS is_terminal,
    r.created_at,
    r.updated_at,
    r.completed_at,
    r.requested_canonical_tickers
   FROM (ingest_db.stock_ingestion_requests r
     LEFT JOIN LATERAL ( SELECT count(*) AS children_started,
            count(*) FILTER (WHERE (((COALESCE(j.core_status, j.status))::text = 'success'::text) AND ((COALESCE(j.ai_status, 'success'::character varying))::text = 'success'::text))) AS children_succeeded,
            count(*) FILTER (WHERE (((COALESCE(j.core_status, j.status))::text = 'failed'::text) OR ((COALESCE(j.ai_status, ''::character varying))::text = 'failed'::text))) AS children_failed,
            count(*) FILTER (WHERE ((COALESCE(j.core_status, j.status))::text = ANY (ARRAY['running'::text, 'pending'::text]))) AS children_running,
            count(*) FILTER (WHERE ((COALESCE(j.core_status, ''::character varying))::text = 'success'::text)) AS children_core_succeeded,
            count(*) FILTER (WHERE ((COALESCE(j.core_status, ''::character varying))::text = 'failed'::text)) AS children_core_failed,
            count(*) FILTER (WHERE ((COALESCE(j.stage2_status, ''::character varying))::text = 'running'::text)) AS children_stage2_running,
            min(COALESCE(NULLIF(j.ai_error_message, ''::text), NULLIF(j.error_message, ''::text))) FILTER (WHERE (((COALESCE(j.core_status, j.status))::text = 'failed'::text) OR ((COALESCE(j.ai_status, ''::character varying))::text = 'failed'::text))) AS first_error_message
           FROM ingest_db.stock_ingestion_jobs j
          WHERE (j.request_id = r.request_id)) agg ON (true));


--
-- Name: vw_stock_vs_benchmark_volatility; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stock_vs_benchmark_volatility AS
 WITH latest_stock_iv AS (
         SELECT DISTINCT ON (mv_stocks_price_volatility.stock_id, mv_stocks_price_volatility.period) mv_stocks_price_volatility.stock_id,
            mv_stocks_price_volatility.period,
            mv_stocks_price_volatility.calc_date,
            mv_stocks_price_volatility.volatility
           FROM semantic_db.mv_stocks_price_volatility
          ORDER BY mv_stocks_price_volatility.stock_id, mv_stocks_price_volatility.period, mv_stocks_price_volatility.calc_date DESC
        ), latest_benchmark_iv AS (
         SELECT DISTINCT ON (mv_instrument_price_volatility.instrument_id, mv_instrument_price_volatility.period) mv_instrument_price_volatility.instrument_id,
            mv_instrument_price_volatility.period,
            mv_instrument_price_volatility.calc_date,
            mv_instrument_price_volatility.volatility
           FROM semantic_db.mv_instrument_price_volatility
          ORDER BY mv_instrument_price_volatility.instrument_id, mv_instrument_price_volatility.period, mv_instrument_price_volatility.calc_date DESC
        )
 SELECT s.stock_id,
    s.ticker AS stock_symbol,
    iv.period,
    iv.volatility AS stock_volatility,
    i.symbol AS benchmark_symbol,
    biv.volatility AS benchmark_volatility,
    (iv.volatility / NULLIF(biv.volatility, (0)::double precision)) AS relative_ratio
   FROM ((((latest_stock_iv iv
     JOIN ingest_db.stocks s ON ((s.stock_id = iv.stock_id)))
     JOIN ingest_db.stocks_benchmark_mapping sb ON ((sb.stock_id = s.stock_id)))
     JOIN ingest_db.instruments i ON ((i.instrument_id = sb.instrument_id)))
     JOIN latest_benchmark_iv biv ON (((biv.instrument_id = sb.instrument_id) AND (biv.period = iv.period))));


--
-- Name: vw_stocks_cash_debt_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_cash_debt_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Cash & Debt'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_chatroom_filters; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_chatroom_filters AS
 SELECT filter_id,
    filter_type,
    filter_value
   FROM ingest_db.stocks_chatroom_filters;


--
-- Name: vw_stocks_company_report_sections; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_company_report_sections AS
 SELECT r.report_id,
    r.stock_id,
    r.report_type,
    r.report_title,
    r.fiscal_year,
    r.file_url,
    r.preview_image_url,
    r.page_count,
    r.ai_model_name,
    r.ai_confidence_score,
    r.created_at,
    rs.section_id,
    rs.section_title,
    rs.content,
    rs.display_order
   FROM ingest_db.stocks_company_reports r,
    ingest_db.stocks_company_report_sections rs
  WHERE (r.report_id = rs.report_id);


--
-- Name: vw_stocks_company_reports; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_company_reports AS
 SELECT report_id,
    stock_id,
    report_type,
    report_title,
    fiscal_year,
    file_url,
    preview_image_url,
    page_count,
    ai_model_name,
    ai_confidence_score,
    created_at
   FROM ingest_db.stocks_company_reports;


--
-- Name: vw_stocks_company_transcript_documents; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_company_transcript_documents AS
 SELECT base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.transcript_id,
    base_view.title,
    base_view.call_date,
    base_view.quarter,
    base_view.fiscal_year,
    base_view.document_url,
    base_view.source_document_id,
    base_view.source_system,
    base_view.asx_code,
    base_view.source_page_url,
    base_view.source_pdf_url,
    base_view.source_pdf_id,
    base_view.headline,
    base_view.announcement_type,
    base_view.document_category,
    base_view.document_type,
    base_view.reporting_period_type,
    base_view.reporting_period_label,
    base_view.reporting_period_year,
    base_view.reporting_period_quarter,
    base_view.reporting_period_half,
    base_view.reporting_period_basis,
    base_view.price_sensitive,
    base_view.published_at,
    base_view.document_size_bytes,
    base_view.sha256,
    base_view.status,
    base_view.first_seen_at,
    base_view.last_seen_at,
    base_view.created_at,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.transcript_id,
            base_view_1.title,
            base_view_1.call_date,
            base_view_1.quarter,
            base_view_1.fiscal_year,
            base_view_1.document_url,
            base_view_1.source_document_id,
            base_view_1.source_system,
            base_view_1.asx_code,
            base_view_1.source_page_url,
            base_view_1.source_pdf_url,
            base_view_1.source_pdf_id,
            base_view_1.headline,
            base_view_1.announcement_type,
            base_view_1.document_category,
            base_view_1.document_type,
            base_view_1.reporting_period_type,
            base_view_1.reporting_period_label,
            base_view_1.reporting_period_year,
            base_view_1.reporting_period_quarter,
            base_view_1.reporting_period_half,
            base_view_1.reporting_period_basis,
            base_view_1.price_sensitive,
            base_view_1.published_at,
            base_view_1.document_size_bytes,
            base_view_1.sha256,
            base_view_1.status,
            base_view_1.first_seen_at,
            base_view_1.last_seen_at,
            base_view_1.created_at,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT d.stock_id,
                    s.ticker,
                    s.company_name,
                    d.transcript_id,
                    t.title,
                    t.call_date,
                    t.quarter,
                    t.fiscal_year,
                    t.document_url,
                    d.source_document_id,
                    d.source_system,
                    d.asx_code,
                    d.source_page_url,
                    d.source_pdf_url,
                    d.source_pdf_id,
                    d.headline,
                    d.announcement_type,
                    d.document_category,
                    d.document_type,
                    d.reporting_period_type,
                    d.reporting_period_label,
                    d.reporting_period_year,
                    d.reporting_period_quarter,
                    d.reporting_period_half,
                    d.reporting_period_basis,
                    d.price_sensitive,
                    d.published_at,
                    d.document_size_bytes,
                    d.sha256,
                    d.status,
                    d.first_seen_at,
                    d.last_seen_at,
                    d.created_at
                   FROM ((ingest_db.stocks_company_transcript_source_documents d
                     LEFT JOIN ingest_db.stocks_company_transcripts t ON (((t.stock_id = d.stock_id) AND (t.transcript_id = d.transcript_id))))
                     LEFT JOIN ingest_db.stocks s ON ((s.stock_id = d.stock_id)))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_company_transcript_sections; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_company_transcript_sections AS
 SELECT t.transcript_id,
    t.stock_id,
    t.title,
    t.quarter,
    t.fiscal_year,
    t.call_date,
    t.duration,
    t.transcript_type,
    t.audio_url,
    t.document_url,
    t.ai_model_name,
    t.created_at,
    ts.section_id,
    ts.section_title,
    ts.content,
    ts.display_order
   FROM ingest_db.stocks_company_transcripts t,
    ingest_db.stocks_company_transcript_sections ts
  WHERE (t.transcript_id = ts.transcript_id);


--
-- Name: vw_stocks_company_transcripts; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_company_transcripts AS
 SELECT base_view.transcript_id,
    base_view.stock_id,
    base_view.title,
    base_view.quarter,
    base_view.fiscal_year,
    base_view.call_date,
    base_view.duration,
    base_view.transcript_type,
    base_view.audio_url,
    base_view.document_url,
    base_view.ai_model_name,
    base_view.created_at,
    base_view.ticker,
    base_view.company_name,
    base_view.exchange,
    base_view.sector,
    base_view.currency_code,
    base_view.country,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.transcript_id,
            base_view_1.stock_id,
            base_view_1.title,
            base_view_1.quarter,
            base_view_1.fiscal_year,
            base_view_1.call_date,
            base_view_1.duration,
            base_view_1.transcript_type,
            base_view_1.audio_url,
            base_view_1.document_url,
            base_view_1.ai_model_name,
            base_view_1.created_at,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.exchange,
            base_view_1.sector,
            base_view_1.currency_code,
            base_view_1.country,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT t.transcript_id,
                    t.stock_id,
                    t.title,
                    t.quarter,
                    t.fiscal_year,
                    t.call_date,
                    t.duration,
                    t.transcript_type,
                    t.audio_url,
                    t.document_url,
                    t.ai_model_name,
                    t.created_at,
                    s.ticker,
                    s.company_name,
                    s.exchange,
                    s.sector,
                    s.currency_code,
                    s.country_name AS country
                   FROM ingest_db.stocks_company_transcripts t,
                    ingest_db.stocks s
                  WHERE (t.stock_id = s.stock_id)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_details; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_details AS
 WITH distinct_portfolio_stocks AS (
         SELECT DISTINCT portfolio_stocks.stock_id,
            portfolio_stocks.action,
            portfolio_stocks.quantity,
            portfolio_stocks.priority,
            max(portfolio_stocks.last_updated) AS last_updated
           FROM ingest_db.portfolio_stocks
          GROUP BY portfolio_stocks.stock_id, portfolio_stocks.action, portfolio_stocks.quantity, portfolio_stocks.priority
        )
 SELECT base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.sector,
    base_view.country_name,
    base_view.action,
    base_view.quantity,
    base_view.priority,
    base_view.last_updated,
    base_view.local_currency,
    base_view.last_price_local_curr,
    base_view.last_price_usd,
    base_view.off_market_price_local_curr,
    base_view.off_market_price_usd,
    base_view.day_price_change_local_curr,
    base_view.day_price_change_usd,
    base_view.day_price_change_pct,
    base_view.volume,
    base_view.volume_30d,
    base_view.off_market_volume,
    base_view.off_market_volume_30d,
    base_view.sentiment_score,
    base_view.sentiment_label,
    base_view.sentiment_reasons,
    base_view.flag_type,
    base_view.flag_description,
    base_view.price_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.sector,
            base_view_1.country_name,
            base_view_1.action,
            base_view_1.quantity,
            base_view_1.priority,
            base_view_1.last_updated,
            base_view_1.local_currency,
            base_view_1.last_price_local_curr,
            base_view_1.last_price_usd,
            base_view_1.off_market_price_local_curr,
            base_view_1.off_market_price_usd,
            base_view_1.day_price_change_local_curr,
            base_view_1.day_price_change_usd,
            base_view_1.day_price_change_pct,
            base_view_1.volume,
            base_view_1.volume_30d,
            base_view_1.off_market_volume,
            base_view_1.off_market_volume_30d,
            base_view_1.sentiment_score,
            base_view_1.sentiment_label,
            base_view_1.sentiment_reasons,
            base_view_1.flag_type,
            base_view_1.flag_description,
            base_view_1.price_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.stock_id,
                    s.ticker,
                    s.company_name,
                    s.sector,
                    s.country_name,
                    ps.action,
                    ps.quantity,
                    ps.priority,
                    ps.last_updated,
                    md.local_currency,
                    md.price_local_curr AS last_price_local_curr,
                    md.price_usd AS last_price_usd,
                    md.off_market_price_local_curr,
                    md.off_market_price_usd,
                    md.day_price_change_local_curr,
                    md.day_price_change_usd,
                    md.day_price_change_pct,
                    md.volume,
                    md.volume_30d,
                    md.off_market_volume,
                    md.off_market_volume_30d,
                    sl.sentiment_score,
                    sl.sentiment_label,
                    sl.sentiment_reasons,
                    sf.flag_type,
                    sf.flag_description,
                    md.price_date
                   FROM ((((ingest_db.stocks s
                     LEFT JOIN distinct_portfolio_stocks ps ON ((s.stock_id = ps.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_price_data_latest md ON ((s.stock_id = md.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_sentiment_latest sl ON ((s.stock_id = sl.stock_id)))
                     LEFT JOIN semantic_db.vw_stocks_flags sf ON ((s.stock_id = sf.stock_id)))
                  WHERE (s.is_peer = false)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_dividend_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_dividend_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.dividend_value,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.dividend_value,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS dividend_value,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Dividend'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: stocks_driver_analysis; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_driver_analysis (
    driver_id integer NOT NULL,
    stock_id integer,
    driver_name character varying(100),
    analysis_text text,
    impact_score numeric(6,2),
    analysis_period character varying(50),
    analyzed_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: vw_stocks_driver_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_driver_analysis AS
 SELECT driver_id,
    stock_id,
    driver_name,
    analysis_text,
    impact_score,
    analysis_period,
    analyzed_date
   FROM transform_db.stocks_driver_analysis;


--
-- Name: vw_stocks_earnings_calendar; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_earnings_calendar AS
 SELECT base_view.stock_id,
    base_view.ticker,
    base_view.company_name,
    base_view.country,
    base_view.sector,
    base_view.market_cap_category_name,
    base_view.earnings_date,
    base_view.session_type,
    base_view.created_at,
    base_view.watchlist_id,
    base_view.watchlist_name,
    base_view.user_id,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.country,
            base_view_1.sector,
            base_view_1.market_cap_category_name,
            base_view_1.earnings_date,
            base_view_1.session_type,
            base_view_1.created_at,
            base_view_1.watchlist_id,
            base_view_1.watchlist_name,
            base_view_1.user_id,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.stock_id,
                    s.ticker,
                    s.company_name,
                    s.country_name AS country,
                    s.sector,
                    s.market_cap_category_name,
                    ec.earnings_date,
                    ec.session_type,
                    ec.created_at,
                    w.watchlist_id,
                    w.watchlist_name,
                    w.user_id
                   FROM ((ingest_db.stocks s
                     JOIN ingest_db.stocks_earnings_calendar ec ON ((s.stock_id = ec.stock_id)))
                     JOIN ingest_db.stocks_watchlist w ON ((s.stock_id = w.stock_id)))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_earnings_outlook; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_earnings_outlook AS
 SELECT base_view.id,
    base_view.stock_id,
    base_view.ticker,
    base_view.period,
    base_view.num_estimates,
    base_view.avg_estimate,
    base_view.low_estimate,
    base_view.high_estimate,
    base_view.metric_type,
    base_view.recorded_at,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.id,
            base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.period,
            base_view_1.num_estimates,
            base_view_1.avg_estimate,
            base_view_1.low_estimate,
            base_view_1.high_estimate,
            base_view_1.metric_type,
            base_view_1.recorded_at,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT v1.id,
                    v1.stock_id,
                    v1.ticker,
                    v1.period,
                    v1.num_estimates,
                    v1.avg_estimate,
                    v1.low_estimate,
                    v1.high_estimate,
                    v1.metric_type,
                    v1.recorded_at
                   FROM ingest_db.stocks_earnings_outlook v1
                  WHERE (v1.recorded_at = ( SELECT max(v2.recorded_at) AS max
                           FROM ingest_db.stocks_earnings_outlook v2
                          WHERE (v2.stock_id = v1.stock_id)))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_ebitda_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_ebitda_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.ebitda,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.ebitda,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS ebitda,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'EBITDA'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_eps_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_eps_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.eps,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.eps,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS eps,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'EPS'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_events; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_events AS
 SELECT base_view.event_id,
    base_view.stock_id,
    base_view.ticker,
    base_view.event_time,
    base_view.event_type,
    base_view.event_description,
    base_view.event_source,
    base_view.created_at,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.event_id,
            base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.event_time,
            base_view_1.event_type,
            base_view_1.event_description,
            base_view_1.event_source,
            base_view_1.created_at,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT stocks_events.event_id,
                    stocks_events.stock_id,
                    stocks_events.ticker,
                    stocks_events.event_time,
                    stocks_events.event_type,
                    stocks_events.event_description,
                    stocks_events.event_source,
                    stocks_events.created_at
                   FROM ingest_db.stocks_events) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_free_cash_flow_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_free_cash_flow_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_type,
    base_view.free_cash_flow,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_type,
            base_view_1.free_cash_flow,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_type,
                    fh.metric_value AS free_cash_flow,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Free Cash Flow'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: stocks_fundamentals_ai_analysis; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_fundamentals_ai_analysis (
    analysis_id integer NOT NULL,
    stock_id integer,
    analysis_type character varying(50),
    analysis_text text NOT NULL,
    generated_by character varying(50) DEFAULT 'AI'::character varying,
    generated_at timestamp without time zone NOT NULL
);


--
-- Name: vw_stocks_fundamentals_ai_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_fundamentals_ai_analysis AS
 SELECT analysis_id,
    stock_id,
    analysis_type,
    analysis_text,
    generated_by,
    generated_at
   FROM transform_db.stocks_fundamentals_ai_analysis v1
  WHERE (generated_at = ( SELECT max(v2.generated_at) AS max
           FROM transform_db.stocks_fundamentals_ai_analysis v2
          WHERE (v2.stock_id = v1.stock_id)));


--
-- Name: vw_stocks_fundamentals_balance; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_fundamentals_balance AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( WITH latest_data AS (
                         SELECT mv_stocks_fundamentals_latest.stock_id,
                            mv_stocks_fundamentals_latest.metric_category,
                            mv_stocks_fundamentals_latest.metric_type,
                            max(mv_stocks_fundamentals_latest.captured_date) AS latest_date
                           FROM semantic_db.mv_stocks_fundamentals_latest
                          WHERE ((mv_stocks_fundamentals_latest.metric_category)::text = 'Balance'::text)
                          GROUP BY mv_stocks_fundamentals_latest.stock_id, mv_stocks_fundamentals_latest.metric_category, mv_stocks_fundamentals_latest.metric_type
                        )
                 SELECT DISTINCT s.ticker,
                    s.stock_id,
                    f.metric_category,
                    f.metric_type,
                    f.metric_value
                   FROM ((semantic_db.mv_stocks_fundamentals_latest f
                     JOIN ingest_db.stocks s ON ((s.stock_id = f.stock_id)))
                     JOIN latest_data v2 ON (((f.stock_id = v2.stock_id) AND (f.captured_date = v2.latest_date) AND ((f.metric_category)::text = (v2.metric_category)::text) AND ((f.metric_type)::text = (v2.metric_type)::text))))
                  WHERE ((f.metric_category)::text = 'Balance'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_fundamentals_cashflow; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_fundamentals_cashflow AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( WITH latest_data AS (
                         SELECT mv_stocks_fundamentals_latest.stock_id,
                            mv_stocks_fundamentals_latest.metric_category,
                            mv_stocks_fundamentals_latest.metric_type,
                            max(mv_stocks_fundamentals_latest.captured_date) AS latest_date
                           FROM semantic_db.mv_stocks_fundamentals_latest
                          WHERE ((mv_stocks_fundamentals_latest.metric_category)::text = 'Cash Flow'::text)
                          GROUP BY mv_stocks_fundamentals_latest.stock_id, mv_stocks_fundamentals_latest.metric_category, mv_stocks_fundamentals_latest.metric_type
                        )
                 SELECT DISTINCT s.ticker,
                    s.stock_id,
                    f.metric_category,
                    f.metric_type,
                    f.metric_value
                   FROM ((semantic_db.mv_stocks_fundamentals_latest f
                     JOIN ingest_db.stocks s ON ((s.stock_id = f.stock_id)))
                     JOIN latest_data v2 ON (((f.stock_id = v2.stock_id) AND (f.captured_date = v2.latest_date) AND ((f.metric_category)::text = (v2.metric_category)::text) AND ((f.metric_type)::text = (v2.metric_type)::text))))
                  WHERE ((f.metric_category)::text = 'Cash Flow'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_fundamentals_margin_growth; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_fundamentals_margin_growth AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( WITH latest_data AS (
                         SELECT mv_stocks_fundamentals_latest.stock_id,
                            mv_stocks_fundamentals_latest.metric_category,
                            mv_stocks_fundamentals_latest.metric_type,
                            max(mv_stocks_fundamentals_latest.captured_date) AS latest_date
                           FROM semantic_db.mv_stocks_fundamentals_latest
                          WHERE ((mv_stocks_fundamentals_latest.metric_category)::text = 'Margin & Growth'::text)
                          GROUP BY mv_stocks_fundamentals_latest.stock_id, mv_stocks_fundamentals_latest.metric_category, mv_stocks_fundamentals_latest.metric_type
                        )
                 SELECT DISTINCT s.ticker,
                    s.stock_id,
                    f.metric_category,
                    f.metric_type,
                    f.metric_value
                   FROM ((semantic_db.mv_stocks_fundamentals_latest f
                     JOIN ingest_db.stocks s ON ((s.stock_id = f.stock_id)))
                     JOIN latest_data v2 ON (((f.stock_id = v2.stock_id) AND (f.captured_date = v2.latest_date) AND ((f.metric_category)::text = (v2.metric_category)::text) AND ((f.metric_type)::text = (v2.metric_type)::text))))
                  WHERE ((f.metric_category)::text = 'Margin & Growth'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_fundamentals_valuation; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_fundamentals_valuation AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( WITH latest_data AS (
                         SELECT mv_stocks_fundamentals_latest.stock_id,
                            mv_stocks_fundamentals_latest.metric_category,
                            mv_stocks_fundamentals_latest.metric_type,
                            max(mv_stocks_fundamentals_latest.captured_date) AS latest_date
                           FROM semantic_db.mv_stocks_fundamentals_latest
                          WHERE ((mv_stocks_fundamentals_latest.metric_category)::text = 'Valuation'::text)
                          GROUP BY mv_stocks_fundamentals_latest.stock_id, mv_stocks_fundamentals_latest.metric_category, mv_stocks_fundamentals_latest.metric_type
                        )
                 SELECT DISTINCT s.ticker,
                    s.stock_id,
                    f.metric_category,
                    f.metric_type,
                    f.metric_value
                   FROM ((semantic_db.mv_stocks_fundamentals_latest f
                     JOIN ingest_db.stocks s ON ((s.stock_id = f.stock_id)))
                     JOIN latest_data v2 ON (((f.stock_id = v2.stock_id) AND (f.captured_date = v2.latest_date) AND ((f.metric_category)::text = (v2.metric_category)::text) AND ((f.metric_type)::text = (v2.metric_type)::text))))
                  WHERE ((f.metric_category)::text = 'Valuation'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_funding_sources_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_funding_sources_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.price,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.price,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS price,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Funding Sources'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_indicators; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_indicators AS
 SELECT base_view.stock_id,
    base_view.ticker,
    base_view.indicator_name,
    base_view.value,
    base_view.recorded_at,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.stock_id,
            base_view_1.ticker,
            base_view_1.indicator_name,
            base_view_1.value,
            base_view_1.recorded_at,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( WITH latest_indicator_data AS (
                         SELECT stocks_indicators.stock_id,
                            stocks_indicators.indicator_name,
                            max(stocks_indicators.recorded_at) AS latest_date
                           FROM ingest_db.stocks_indicators
                          GROUP BY stocks_indicators.stock_id, stocks_indicators.indicator_name
                        )
                 SELECT a.stock_id,
                    a.ticker,
                    a.indicator_name,
                    a.value,
                    a.recorded_at
                   FROM ingest_db.stocks_indicators a,
                    latest_indicator_data b
                  WHERE ((a.stock_id = b.stock_id) AND ((a.indicator_name)::text = (b.indicator_name)::text) AND (a.recorded_at = b.latest_date))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: stocks_insights_ai_summary; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_insights_ai_summary (
    summary_id integer NOT NULL,
    stock_id integer,
    summary_text text NOT NULL,
    generated_at timestamp without time zone NOT NULL
);


--
-- Name: vw_stocks_insights_ai_summary; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_insights_ai_summary AS
 SELECT summary_id,
    stock_id,
    summary_text,
    generated_at
   FROM transform_db.stocks_insights_ai_summary v1
  WHERE (generated_at = ( SELECT max(v2.generated_at) AS max
           FROM transform_db.stocks_insights_ai_summary v2
          WHERE (v2.stock_id = v1.stock_id)));


--
-- Name: vw_stocks_market_alerts; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_market_alerts AS
 SELECT alert_id,
    stock_id,
    stock_symbol,
    alert_type,
    description,
    source,
    alert_date,
    severity,
    url,
    status,
    created_at
   FROM ingest_db.stocks_market_alerts;


--
-- Name: vw_stocks_message_sentiments_latest; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_message_sentiments_latest AS
 SELECT message_id,
    stock_id,
    analysis_id,
    source_name,
    source_url,
    source_message_id,
    message_author,
    message_text,
    llm_sentiment_score,
    llm_sentiment_label,
    sentiment_description,
    keywords,
    is_bullish,
    is_bearish,
    is_sarcasm,
    confidence_score,
    llm_explanation,
    count_likes,
    count_dislikes,
    count_shares,
    count_replies,
    analyzed_at
   FROM transform_db.stocks_message_sentiments v1
  WHERE (analysis_id = ( SELECT max(v2.analysis_id) AS max
           FROM transform_db.stocks_message_sentiments v2
          WHERE (v2.stock_id = v1.stock_id)));


--
-- Name: vw_stocks_metrics_details; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_metrics_details AS
 WITH latest_data AS (
         SELECT stocks_metrics.stock_id,
            stocks_metrics.metric_id,
            max(stocks_metrics.snapshot_timestamp) AS latest_time
           FROM ingest_db.stocks_metrics
          GROUP BY stocks_metrics.stock_id, stocks_metrics.metric_id
        ), latest_data_with_metric_type AS (
         SELECT ld.stock_id,
            ld.metric_id,
            ld.latest_time,
            smt.metric_name,
            smt.metric_category,
            smt.metric_unit
           FROM latest_data ld,
            ingest_db.stocks_metric_types smt
          WHERE (ld.metric_id = smt.metric_id)
        )
 SELECT v1.stock_metric_id,
    v1.stock_id,
    v1.metric_id,
    v1.metric_value,
    v1.snapshot_timestamp,
    v2.metric_name,
    v2.metric_category,
    v2.metric_unit
   FROM (ingest_db.stocks_metrics v1
     JOIN latest_data_with_metric_type v2 ON (((v1.stock_id = v2.stock_id) AND (v1.metric_id = v2.metric_id) AND (v1.snapshot_timestamp = v2.latest_time))));


--
-- Name: vw_stocks_net_income_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_net_income_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.net_income,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.net_income,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS net_income,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Net Income'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_price_to_earning_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_price_to_earning_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.price,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.price,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS price,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Price To Earning'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_price_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_price_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.price,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.price,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS price,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Price'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_ratios_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_ratios_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.metric_value,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.metric_value,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Ratios'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_return_of_capital_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_return_of_capital_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.return_of_capital,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.return_of_capital,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS return_of_capital,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Return of Capital'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_revenue_by_segment_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_revenue_by_segment_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.revenue_segment,
    base_view.revenue,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.revenue_segment,
            base_view_1.revenue,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type AS revenue_segment,
                    fh.metric_value AS revenue,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Revenue By Segment'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_revenue_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_revenue_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.revenue,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.revenue,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS revenue,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Revenue'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_sentiment_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_sentiment_analysis AS
 SELECT analysis_id,
    stock_id,
    sentiment_score,
    sentiment_label,
    analysis_description,
    analyzed_by,
    analyzed_at
   FROM transform_db.stocks_sentiment_analysis;


--
-- Name: vw_stocks_shares_outstanding_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_shares_outstanding_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.shares_outstanding,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.shares_outstanding,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS shares_outstanding,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Shares Outstanding'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_upcoming_events; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_upcoming_events AS
 SELECT event_id,
    stock_id,
    event_type,
    event_description,
    event_source,
    expected_event_time,
    created_at
   FROM ingest_db.stocks_upcoming_events
  WHERE (expected_event_time > CURRENT_TIMESTAMP);


--
-- Name: vw_stocks_valuation_trend_analysis; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_valuation_trend_analysis AS
 SELECT base_view.ticker,
    base_view.stock_id,
    base_view.metric_category,
    base_view.metric_type,
    base_view.valuation,
    base_view.period_type,
    base_view.period_label,
    base_view.captured_date,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.stock_id,
            base_view_1.metric_category,
            base_view_1.metric_type,
            base_view_1.valuation,
            base_view_1.period_type,
            base_view_1.period_label,
            base_view_1.captured_date,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.stock_id,
                    fh.metric_category,
                    fh.metric_type,
                    fh.metric_value AS valuation,
                    fh.period_type,
                    fh.period_label,
                    fh.captured_date
                   FROM (ingest_db.stocks_fundamentals fh
                     JOIN ingest_db.stocks s ON ((fh.stock_id = s.stock_id)))
                  WHERE ((fh.metric_category)::text = 'Valuation'::text)) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_watchlist; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_watchlist AS
 SELECT base_view.ticker,
    base_view.company_name,
    base_view.watchlist_id,
    base_view.watchlist_name,
    base_view.user_id,
    base_view.stock_id,
    base_view.created_at,
    base_view.canonical_ticker,
    stock_map.country_name_display
   FROM (( SELECT base_view_1.ticker,
            base_view_1.company_name,
            base_view_1.watchlist_id,
            base_view_1.watchlist_name,
            base_view_1.user_id,
            base_view_1.stock_id,
            base_view_1.created_at,
            COALESCE(stock_map_1.canonical_ticker, stock_map_1.canonical_symbol, stock_map_1.ticker) AS canonical_ticker
           FROM (( SELECT s.ticker,
                    s.company_name,
                    sw.watchlist_id,
                    sw.watchlist_name,
                    sw.user_id,
                    sw.stock_id,
                    sw.created_at
                   FROM (ingest_db.stocks s
                     JOIN ingest_db.stocks_watchlist sw ON ((s.stock_id = sw.stock_id)))) base_view_1
             LEFT JOIN ingest_db.stocks stock_map_1 ON ((stock_map_1.stock_id = base_view_1.stock_id)))) base_view
     LEFT JOIN ingest_db.stocks stock_map ON ((stock_map.stock_id = base_view.stock_id)));


--
-- Name: vw_stocks_word_cloud_metrics; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_stocks_word_cloud_metrics AS
 SELECT word_id,
    stock_id,
    keyword,
    positive_reaction_percent,
    negative_reaction_percent,
    recorded_at
   FROM ingest_db.stocks_word_cloud_metrics;


--
-- Name: vw_ticker_resolution_catalog; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_ticker_resolution_catalog AS
 WITH base AS (
         SELECT tl.id,
            tl.symbol,
            tl.company_name,
            tl.exchange_code,
            tl.currency,
            tl.country,
            tl.fmp_available,
            tl.data_source,
            tl.canonical_symbol,
            tl.base_symbol,
            tl.market_code,
            tl.country_code,
            tl.country_name_display,
            tl.provider_name,
            tl.provider_symbol,
            tl.provider_exchange_code,
            tl.stock_id,
            tl.is_primary_resolution,
            tl.is_active,
            tl.alias_type,
            count(*) OVER (PARTITION BY tl.canonical_symbol) AS canonical_symbol_candidate_count,
            count(*) OVER (PARTITION BY tl.base_symbol) AS base_symbol_candidate_count
           FROM ingest_db.ticker_list tl
        )
 SELECT id,
    symbol,
    company_name,
    exchange_code,
    currency,
    country,
    fmp_available,
    data_source,
    canonical_symbol,
    base_symbol,
    market_code,
    country_code,
    country_name_display,
    provider_name,
    provider_symbol,
    provider_exchange_code,
    stock_id,
    is_primary_resolution,
    is_active,
    alias_type,
    canonical_symbol_candidate_count,
    base_symbol_candidate_count,
    ((canonical_symbol_candidate_count > 1) OR (base_symbol_candidate_count > 1)) AS is_ambiguous
   FROM base;


--
-- Name: vw_ticker_search; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_ticker_search AS
 SELECT id,
    symbol,
    company_name,
    exchange_code,
    currency,
    country,
    fmp_available,
    data_source,
    canonical_symbol,
    base_symbol,
    market_code,
    country_code,
    country_name_display,
    provider_name,
    provider_symbol,
    provider_exchange_code,
    stock_id,
    is_primary_resolution,
    is_active,
    alias_type,
        CASE
            WHEN (canonical_ticker IS NOT NULL) THEN (count(*) OVER (PARTITION BY canonical_ticker) > 1)
            ELSE false
        END AS is_ambiguous,
    canonical_ticker
   FROM ingest_db.ticker_list tl;


--
-- Name: vw_users; Type: VIEW; Schema: semantic_db; Owner: -
--

CREATE VIEW semantic_db.vw_users AS
 SELECT user_id,
    first_name,
    last_name,
    email,
    created_at,
    role
   FROM ingest_db.users;


--
-- Name: ab_before_daily_20260415; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.ab_before_daily_20260415 (
    analysis_id integer,
    stock_id integer,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20)
);


--
-- Name: ab_before_messages_20260415; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.ab_before_messages_20260415 (
    message_id integer,
    stock_id integer,
    analysis_id integer,
    source_name character varying(50),
    source_url text,
    source_message_id integer,
    message_author character varying(50),
    message_text jsonb,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone,
    platform character varying(50),
    country character varying(20),
    main_source_url text
);


--
-- Name: instrument_correlation_matrix_correlation_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.instrument_correlation_matrix ALTER COLUMN correlation_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.instrument_correlation_matrix_correlation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: market_summary_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.market_summary ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.market_summary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: portfolio_ai_analysis_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.portfolio_ai_analysis ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.portfolio_ai_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: research_copilot_prompt_suggestions_suggestion_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.research_copilot_prompt_suggestions ALTER COLUMN suggestion_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.research_copilot_prompt_suggestions_suggestion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: research_copilot_report_sharing_share_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.research_copilot_report_sharing ALTER COLUMN share_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.research_copilot_report_sharing_share_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: research_copilot_reports_report_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

CREATE SEQUENCE transform_db.research_copilot_reports_report_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: research_copilot_reports_report_id_seq; Type: SEQUENCE OWNED BY; Schema: transform_db; Owner: -
--

ALTER SEQUENCE transform_db.research_copilot_reports_report_id_seq OWNED BY transform_db.research_copilot_reports.report_id;


--
-- Name: stocks_driver_analysis_driver_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_driver_analysis ALTER COLUMN driver_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.stocks_driver_analysis_driver_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_events_messages_correlation; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_events_messages_correlation (
    stock_id integer NOT NULL,
    event_id integer NOT NULL,
    src_message_id_list integer[],
    analysis_details text NOT NULL,
    metadata jsonb,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    concise_report text
);


--
-- Name: stocks_fundamentals_ai_analysis_analysis_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_fundamentals_ai_analysis ALTER COLUMN analysis_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.stocks_fundamentals_ai_analysis_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_insights_ai_summary_summary_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_insights_ai_summary ALTER COLUMN summary_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.stocks_insights_ai_summary_summary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_message_sentiments_bkp_20260415; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_bkp_20260415 (
    message_id integer,
    stock_id integer,
    analysis_id integer,
    source_name character varying(50),
    source_url text,
    source_message_id integer,
    message_author character varying(50),
    message_text jsonb,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone,
    platform character varying(50),
    country character varying(20),
    main_source_url text
);


--
-- Name: stocks_message_sentiments_bkp_20260418; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_bkp_20260418 (
    message_id integer,
    stock_id integer,
    analysis_id integer,
    source_name character varying(50),
    source_url text,
    source_message_id integer,
    message_author character varying(50),
    message_text jsonb,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone,
    platform character varying(50),
    country character varying(20),
    main_source_url text
);


--
-- Name: stocks_message_sentiments_bkp_predups_20260427_194115; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_bkp_predups_20260427_194115 (
    message_id integer,
    stock_id integer,
    analysis_id integer,
    source_name character varying(50),
    source_url text,
    source_message_id integer,
    message_author character varying(50),
    message_text jsonb,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_message_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_message_sentiments ALTER COLUMN message_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.stocks_message_sentiments_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_message_sentiments_p0; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p0 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p1; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p1 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p2; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p2 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p3; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p3 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p4; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p4 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p5; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p5 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p6; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p6 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p7; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p7 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p8; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p8 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_message_sentiments_p9; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_message_sentiments_p9 (
    message_id integer NOT NULL,
    stock_id integer NOT NULL,
    analysis_id integer NOT NULL,
    source_name character varying(50) NOT NULL,
    source_url text NOT NULL,
    source_message_id integer NOT NULL,
    message_author character varying(50),
    message_text jsonb NOT NULL,
    llm_sentiment_score numeric(10,6),
    llm_sentiment_label character varying(20),
    sentiment_description text,
    keywords jsonb,
    is_bullish boolean,
    is_bearish boolean,
    is_sarcasm boolean,
    confidence_score numeric(5,4),
    llm_explanation text,
    count_likes integer,
    count_dislikes integer,
    count_shares integer,
    count_replies integer,
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    platform character varying(50),
    country character varying(20),
    main_source_url text,
    session character varying(12)
);


--
-- Name: stocks_sentiment_analysis_analysis_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_sentiment_analysis ALTER COLUMN analysis_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME transform_db.stocks_sentiment_analysis_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: stocks_sentiment_analysis_bkp_backfill_20260424; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_bkp_backfill_20260424 (
    analysis_id integer,
    stock_id integer,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4)
);


--
-- Name: stocks_sentiment_analysis_bkp_predups_20260427_194115; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_bkp_predups_20260427_194115 (
    analysis_id integer,
    stock_id integer,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4)
);


--
-- Name: stocks_sentiment_analysis_p0; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p0 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p1; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p1 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p2; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p2 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p3; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p3 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p4; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p4 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p5; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p5 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p6; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p6 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p7; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p7 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p8; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p8 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_sentiment_analysis_p9; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_sentiment_analysis_p9 (
    analysis_id integer NOT NULL,
    stock_id integer NOT NULL,
    sentiment_score numeric(4,2),
    sentiment_label character varying(20),
    analysis_description text,
    analyzed_by character varying(50),
    analyzed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    total_messages integer,
    positive_count integer,
    neutral_count integer,
    flags jsonb,
    sentiment_reasons jsonb,
    negative_count integer,
    platform character varying(50),
    country character varying(20),
    premarket_sentiment numeric(6,4),
    postmarket_sentiment numeric(6,4),
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_weekly_sentiment_analysis; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_weekly_sentiment_analysis (
    weekly_analysis_id bigint NOT NULL,
    stock_id integer NOT NULL,
    week_start date NOT NULL,
    week_end date NOT NULL,
    weekly_sentiment numeric(6,4),
    weekly_sentiment_predictive numeric(6,4),
    weekly_sentiment_reactive numeric(6,4),
    weekly_sentiment_label character varying(20),
    total_messages integer DEFAULT 0 NOT NULL,
    predictive_messages integer DEFAULT 0 NOT NULL,
    reactive_messages integer DEFAULT 0 NOT NULL,
    days_covered integer DEFAULT 0 NOT NULL,
    weekly_price_return numeric(10,6),
    anomaly_flag boolean DEFAULT false NOT NULL,
    anomaly_reason text,
    flags jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: stocks_weekly_sentiment_analysis_bkp_backfill_20260424; Type: TABLE; Schema: transform_db; Owner: -
--

CREATE TABLE transform_db.stocks_weekly_sentiment_analysis_bkp_backfill_20260424 (
    weekly_analysis_id bigint,
    stock_id integer,
    week_start date,
    week_end date,
    weekly_sentiment numeric(6,4),
    weekly_sentiment_predictive numeric(6,4),
    weekly_sentiment_reactive numeric(6,4),
    weekly_sentiment_label character varying(20),
    total_messages integer,
    predictive_messages integer,
    reactive_messages integer,
    days_covered integer,
    weekly_price_return numeric(10,6),
    anomaly_flag boolean,
    anomaly_reason text,
    flags jsonb,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: stocks_weekly_sentiment_analysis_weekly_analysis_id_seq; Type: SEQUENCE; Schema: transform_db; Owner: -
--

CREATE SEQUENCE transform_db.stocks_weekly_sentiment_analysis_weekly_analysis_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stocks_weekly_sentiment_analysis_weekly_analysis_id_seq; Type: SEQUENCE OWNED BY; Schema: transform_db; Owner: -
--

ALTER SEQUENCE transform_db.stocks_weekly_sentiment_analysis_weekly_analysis_id_seq OWNED BY transform_db.stocks_weekly_sentiment_analysis.weekly_analysis_id;


--
-- Name: chatroom_stocks_news_chat_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: chatroom_stocks_news_chat_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: chatroom_stocks_news_chat_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: chatroom_stocks_news_chat_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: chatroom_stocks_news_chat_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: chatroom_stocks_news_chat_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: chatroom_stocks_news_chat_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: chatroom_stocks_news_chat_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: chatroom_stocks_news_chat_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: chatroom_stocks_news_chat_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: instrument_prices_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices ATTACH PARTITION ingest_db.instrument_prices_p0 FOR VALUES WITH (modulus 5, remainder 0);


--
-- Name: instrument_prices_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices ATTACH PARTITION ingest_db.instrument_prices_p1 FOR VALUES WITH (modulus 5, remainder 1);


--
-- Name: instrument_prices_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices ATTACH PARTITION ingest_db.instrument_prices_p2 FOR VALUES WITH (modulus 5, remainder 2);


--
-- Name: instrument_prices_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices ATTACH PARTITION ingest_db.instrument_prices_p3 FOR VALUES WITH (modulus 5, remainder 3);


--
-- Name: instrument_prices_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices ATTACH PARTITION ingest_db.instrument_prices_p4 FOR VALUES WITH (modulus 5, remainder 4);


--
-- Name: stocks_company_report_sections_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_company_report_sections_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_company_report_sections_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_company_report_sections_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_company_report_sections_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_company_report_sections_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_company_report_sections_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_company_report_sections_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_company_report_sections_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_company_report_sections_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections ATTACH PARTITION ingest_db.stocks_company_report_sections_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_company_reports_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_company_reports_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_company_reports_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_company_reports_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_company_reports_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_company_reports_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_company_reports_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_company_reports_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_company_reports_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_company_reports_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports ATTACH PARTITION ingest_db.stocks_company_reports_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_company_transcript_sections_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_company_transcript_sections_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_company_transcript_sections_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_company_transcript_sections_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_company_transcript_sections_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_company_transcript_sections_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_company_transcript_sections_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_company_transcript_sections_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_company_transcript_sections_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_company_transcript_sections_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_company_transcript_source_documents_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_company_transcript_source_documents_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_company_transcript_source_documents_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_company_transcript_source_documents_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_company_transcript_source_documents_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_company_transcript_source_documents_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_company_transcript_source_documents_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_company_transcript_source_documents_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_company_transcript_source_documents_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_company_transcript_source_documents_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_company_transcripts_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_company_transcripts_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_company_transcripts_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_company_transcripts_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_company_transcripts_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_company_transcripts_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_company_transcripts_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_company_transcripts_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_company_transcripts_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_company_transcripts_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts ATTACH PARTITION ingest_db.stocks_company_transcripts_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_events_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_events_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_events_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_events_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_events_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_events_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_events_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_events_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_events_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_events_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events ATTACH PARTITION ingest_db.stocks_events_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_fundamentals_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_fundamentals_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_fundamentals_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_fundamentals_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_fundamentals_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_fundamentals_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_fundamentals_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_fundamentals_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_fundamentals_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_fundamentals_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals ATTACH PARTITION ingest_db.stocks_fundamentals_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_market_alerts_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_market_alerts_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_market_alerts_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_market_alerts_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_market_alerts_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_market_alerts_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_market_alerts_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_market_alerts_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_market_alerts_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_market_alerts_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts ATTACH PARTITION ingest_db.stocks_market_alerts_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_market_news_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_market_news_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_market_news_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_market_news_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_market_news_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_market_news_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_market_news_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_market_news_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_market_news_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_market_news_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news ATTACH PARTITION ingest_db.stocks_market_news_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_metrics_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_metrics_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_metrics_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_metrics_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_metrics_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_metrics_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_metrics_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_metrics_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_metrics_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_metrics_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics ATTACH PARTITION ingest_db.stocks_metrics_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_price_data_p0; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_price_data_p1; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_price_data_p2; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_price_data_p3; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_price_data_p4; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_price_data_p5; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_price_data_p6; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_price_data_p7; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_price_data_p8; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_price_data_p9; Type: TABLE ATTACH; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data ATTACH PARTITION ingest_db.stocks_price_data_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_message_sentiments_p0; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_message_sentiments_p1; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_message_sentiments_p2; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_message_sentiments_p3; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_message_sentiments_p4; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_message_sentiments_p5; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_message_sentiments_p6; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_message_sentiments_p7; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_message_sentiments_p8; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_message_sentiments_p9; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments ATTACH PARTITION transform_db.stocks_message_sentiments_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: stocks_sentiment_analysis_p0; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0 FOR VALUES WITH (modulus 10, remainder 0);


--
-- Name: stocks_sentiment_analysis_p1; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1 FOR VALUES WITH (modulus 10, remainder 1);


--
-- Name: stocks_sentiment_analysis_p2; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2 FOR VALUES WITH (modulus 10, remainder 2);


--
-- Name: stocks_sentiment_analysis_p3; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3 FOR VALUES WITH (modulus 10, remainder 3);


--
-- Name: stocks_sentiment_analysis_p4; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4 FOR VALUES WITH (modulus 10, remainder 4);


--
-- Name: stocks_sentiment_analysis_p5; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5 FOR VALUES WITH (modulus 10, remainder 5);


--
-- Name: stocks_sentiment_analysis_p6; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6 FOR VALUES WITH (modulus 10, remainder 6);


--
-- Name: stocks_sentiment_analysis_p7; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7 FOR VALUES WITH (modulus 10, remainder 7);


--
-- Name: stocks_sentiment_analysis_p8; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8 FOR VALUES WITH (modulus 10, remainder 8);


--
-- Name: stocks_sentiment_analysis_p9; Type: TABLE ATTACH; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9 FOR VALUES WITH (modulus 10, remainder 9);


--
-- Name: indexed_records id; Type: DEFAULT; Schema: indexing_state; Owner: -
--

ALTER TABLE ONLY indexing_state.indexed_records ALTER COLUMN id SET DEFAULT nextval('indexing_state.indexed_records_id_seq'::regclass);


--
-- Name: stock_ingestion_event_outbox outbox_id; Type: DEFAULT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_event_outbox ALTER COLUMN outbox_id SET DEFAULT nextval('ingest_db.stock_ingestion_event_outbox_outbox_id_seq'::regclass);


--
-- Name: stock_ingestion_events event_id; Type: DEFAULT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_events ALTER COLUMN event_id SET DEFAULT nextval('ingest_db.stock_ingestion_events_event_id_seq'::regclass);


--
-- Name: stock_ingestion_jobs job_id; Type: DEFAULT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_jobs ALTER COLUMN job_id SET DEFAULT nextval('ingest_db.stock_ingestion_jobs_job_id_seq'::regclass);


--
-- Name: stock_ingestion_requests request_id; Type: DEFAULT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_requests ALTER COLUMN request_id SET DEFAULT nextval('ingest_db.stock_ingestion_requests_request_id_seq'::regclass);


--
-- Name: stock_peers id; Type: DEFAULT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_peers ALTER COLUMN id SET DEFAULT nextval('ingest_db.stock_peers_id_seq'::regclass);


--
-- Name: research_copilot_reports report_id; Type: DEFAULT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_reports ALTER COLUMN report_id SET DEFAULT nextval('transform_db.research_copilot_reports_report_id_seq'::regclass);


--
-- Name: stocks_weekly_sentiment_analysis weekly_analysis_id; Type: DEFAULT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_weekly_sentiment_analysis ALTER COLUMN weekly_analysis_id SET DEFAULT nextval('transform_db.stocks_weekly_sentiment_analysis_weekly_analysis_id_seq'::regclass);


--
-- Name: indexed_records indexed_records_pkey; Type: CONSTRAINT; Schema: indexing_state; Owner: -
--

ALTER TABLE ONLY indexing_state.indexed_records
    ADD CONSTRAINT indexed_records_pkey PRIMARY KEY (id);


--
-- Name: indexed_records indexed_records_source_type_source_id_stock_id_key; Type: CONSTRAINT; Schema: indexing_state; Owner: -
--

ALTER TABLE ONLY indexing_state.indexed_records
    ADD CONSTRAINT indexed_records_source_type_source_id_stock_id_key UNIQUE (source_type, source_id, stock_id);


--
-- Name: indexing_jobs indexing_jobs_pkey; Type: CONSTRAINT; Schema: indexing_state; Owner: -
--

ALTER TABLE ONLY indexing_state.indexing_jobs
    ADD CONSTRAINT indexing_jobs_pkey PRIMARY KEY (job_id);


--
-- Name: benchmark_history benchmark_history_uniq; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.benchmark_history
    ADD CONSTRAINT benchmark_history_uniq UNIQUE (benchmark_name, valuation_date);


--
-- Name: chatroom_stocks_news_chat chatroom_stocks_news_chat_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat
    ADD CONSTRAINT chatroom_stocks_news_chat_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p0 chatroom_stocks_news_chat_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p0
    ADD CONSTRAINT chatroom_stocks_news_chat_p0_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p1 chatroom_stocks_news_chat_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p1
    ADD CONSTRAINT chatroom_stocks_news_chat_p1_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p2 chatroom_stocks_news_chat_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p2
    ADD CONSTRAINT chatroom_stocks_news_chat_p2_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p3 chatroom_stocks_news_chat_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p3
    ADD CONSTRAINT chatroom_stocks_news_chat_p3_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p4 chatroom_stocks_news_chat_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p4
    ADD CONSTRAINT chatroom_stocks_news_chat_p4_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p5 chatroom_stocks_news_chat_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p5
    ADD CONSTRAINT chatroom_stocks_news_chat_p5_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p6 chatroom_stocks_news_chat_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p6
    ADD CONSTRAINT chatroom_stocks_news_chat_p6_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p7 chatroom_stocks_news_chat_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p7
    ADD CONSTRAINT chatroom_stocks_news_chat_p7_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p8 chatroom_stocks_news_chat_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p8
    ADD CONSTRAINT chatroom_stocks_news_chat_p8_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: chatroom_stocks_news_chat_p9 chatroom_stocks_news_chat_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_stocks_news_chat_p9
    ADD CONSTRAINT chatroom_stocks_news_chat_p9_pkey PRIMARY KEY (message_id, stock_id);


--
-- Name: company_executive_summary company_executive_summary_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_executive_summary
    ADD CONSTRAINT company_executive_summary_pkey PRIMARY KEY (summary_id);


--
-- Name: company_growth_history company_growth_history_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_growth_history
    ADD CONSTRAINT company_growth_history_pkey PRIMARY KEY (growth_id);


--
-- Name: company_profile company_profile_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_profile
    ADD CONSTRAINT company_profile_pkey PRIMARY KEY (stock_symbol);


--
-- Name: forex_rates forex_rates_uniq_pair_date; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.forex_rates
    ADD CONSTRAINT forex_rates_uniq_pair_date UNIQUE (source_currency, target_currency, rate_date);


--
-- Name: industry_average_metric_values industry_average_metric_values_sector_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.industry_average_metric_values
    ADD CONSTRAINT industry_average_metric_values_sector_key UNIQUE (sector);


--
-- Name: industry_metric_reference industry_metric_reference_sector_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.industry_metric_reference
    ADD CONSTRAINT industry_metric_reference_sector_key UNIQUE (sector);


--
-- Name: instrument_prices instrument_prices_uniq; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices
    ADD CONSTRAINT instrument_prices_uniq UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices_p0 instrument_prices_p0_instrument_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p0
    ADD CONSTRAINT instrument_prices_p0_instrument_id_price_date_key UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices instrument_prices_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices
    ADD CONSTRAINT instrument_prices_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instrument_prices_p0 instrument_prices_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p0
    ADD CONSTRAINT instrument_prices_p0_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instrument_prices_p1 instrument_prices_p1_instrument_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p1
    ADD CONSTRAINT instrument_prices_p1_instrument_id_price_date_key UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices_p1 instrument_prices_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p1
    ADD CONSTRAINT instrument_prices_p1_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instrument_prices_p2 instrument_prices_p2_instrument_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p2
    ADD CONSTRAINT instrument_prices_p2_instrument_id_price_date_key UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices_p2 instrument_prices_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p2
    ADD CONSTRAINT instrument_prices_p2_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instrument_prices_p3 instrument_prices_p3_instrument_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p3
    ADD CONSTRAINT instrument_prices_p3_instrument_id_price_date_key UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices_p3 instrument_prices_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p3
    ADD CONSTRAINT instrument_prices_p3_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instrument_prices_p4 instrument_prices_p4_instrument_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p4
    ADD CONSTRAINT instrument_prices_p4_instrument_id_price_date_key UNIQUE (instrument_id, price_date);


--
-- Name: instrument_prices_p4 instrument_prices_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instrument_prices_p4
    ADD CONSTRAINT instrument_prices_p4_pkey PRIMARY KEY (price_id, instrument_id);


--
-- Name: instruments instruments_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.instruments
    ADD CONSTRAINT instruments_pkey PRIMARY KEY (instrument_id);


--
-- Name: market_indexes market_indexes_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.market_indexes
    ADD CONSTRAINT market_indexes_pkey PRIMARY KEY (index_id);


--
-- Name: market market_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.market
    ADD CONSTRAINT market_pkey PRIMARY KEY (market_id);


--
-- Name: pipeline_exchange_hours pipeline_exchange_hours_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_exchange_hours
    ADD CONSTRAINT pipeline_exchange_hours_pkey PRIMARY KEY (exchange);


--
-- Name: pipeline_ingestion_file_csv_ids pipeline_ingestion_file_csv_ids_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_ingestion_file_csv_ids
    ADD CONSTRAINT pipeline_ingestion_file_csv_ids_pkey PRIMARY KEY (filename, csv_id);


--
-- Name: pipeline_ingestion_files pipeline_ingestion_files_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_ingestion_files
    ADD CONSTRAINT pipeline_ingestion_files_pkey PRIMARY KEY (filename);


--
-- Name: pipeline_s3_trigger_files pipeline_s3_trigger_files_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_s3_trigger_files
    ADD CONSTRAINT pipeline_s3_trigger_files_pkey PRIMARY KEY (file_key);


--
-- Name: pipeline_sentiment_dates pipeline_sentiment_dates_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_sentiment_dates
    ADD CONSTRAINT pipeline_sentiment_dates_pkey PRIMARY KEY (stock_id, date_str);


--
-- Name: pipeline_sentiment_processed_ids pipeline_sentiment_processed_ids_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_sentiment_processed_ids
    ADD CONSTRAINT pipeline_sentiment_processed_ids_pkey PRIMARY KEY (stock_id, message_id);


--
-- Name: pipeline_stock_csv_map pipeline_stock_csv_map_csv_filename_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_stock_csv_map
    ADD CONSTRAINT pipeline_stock_csv_map_csv_filename_key UNIQUE (csv_filename);


--
-- Name: pipeline_stock_csv_map pipeline_stock_csv_map_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_stock_csv_map
    ADD CONSTRAINT pipeline_stock_csv_map_pkey PRIMARY KEY (stock_id);


--
-- Name: portfolio portfolio_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio
    ADD CONSTRAINT portfolio_pkey PRIMARY KEY (portfolio_id);


--
-- Name: portfolio_stocks portfolio_stocks_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio_stocks
    ADD CONSTRAINT portfolio_stocks_pkey PRIMARY KEY (portfolio_stock_id);


--
-- Name: research_copilot_user_prompts research_copilot_user_prompts_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.research_copilot_user_prompts
    ADD CONSTRAINT research_copilot_user_prompts_pkey PRIMARY KEY (prompt_id);


--
-- Name: stock_ingestion_event_outbox stock_ingestion_event_outbox_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_event_outbox
    ADD CONSTRAINT stock_ingestion_event_outbox_pkey PRIMARY KEY (outbox_id);


--
-- Name: stock_ingestion_events stock_ingestion_events_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_events
    ADD CONSTRAINT stock_ingestion_events_pkey PRIMARY KEY (event_id);


--
-- Name: stock_ingestion_jobs stock_ingestion_jobs_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_jobs
    ADD CONSTRAINT stock_ingestion_jobs_pkey PRIMARY KEY (job_id);


--
-- Name: stock_ingestion_requests stock_ingestion_requests_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_requests
    ADD CONSTRAINT stock_ingestion_requests_pkey PRIMARY KEY (request_id);


--
-- Name: stock_peers stock_peers_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_peers
    ADD CONSTRAINT stock_peers_pkey PRIMARY KEY (id);


--
-- Name: stocks_benchmark_mapping stocks_benchmark_mapping_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_benchmark_mapping
    ADD CONSTRAINT stocks_benchmark_mapping_pkey PRIMARY KEY (stock_id, instrument_id);


--
-- Name: stocks_chatroom_filters stocks_chatroom_filters_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_chatroom_filters
    ADD CONSTRAINT stocks_chatroom_filters_pkey PRIMARY KEY (filter_id);


--
-- Name: stocks_company_report_sections stocks_company_report_sections_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections
    ADD CONSTRAINT stocks_company_report_sections_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p0 stocks_company_report_sections_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p0
    ADD CONSTRAINT stocks_company_report_sections_p0_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p1 stocks_company_report_sections_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p1
    ADD CONSTRAINT stocks_company_report_sections_p1_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p2 stocks_company_report_sections_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p2
    ADD CONSTRAINT stocks_company_report_sections_p2_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p3 stocks_company_report_sections_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p3
    ADD CONSTRAINT stocks_company_report_sections_p3_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p4 stocks_company_report_sections_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p4
    ADD CONSTRAINT stocks_company_report_sections_p4_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p5 stocks_company_report_sections_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p5
    ADD CONSTRAINT stocks_company_report_sections_p5_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p6 stocks_company_report_sections_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p6
    ADD CONSTRAINT stocks_company_report_sections_p6_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p7 stocks_company_report_sections_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p7
    ADD CONSTRAINT stocks_company_report_sections_p7_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p8 stocks_company_report_sections_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p8
    ADD CONSTRAINT stocks_company_report_sections_p8_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_report_sections_p9 stocks_company_report_sections_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_report_sections_p9
    ADD CONSTRAINT stocks_company_report_sections_p9_pkey PRIMARY KEY (report_id, section_id);


--
-- Name: stocks_company_reports stocks_company_reports_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports
    ADD CONSTRAINT stocks_company_reports_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p0 stocks_company_reports_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p0
    ADD CONSTRAINT stocks_company_reports_p0_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p1 stocks_company_reports_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p1
    ADD CONSTRAINT stocks_company_reports_p1_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p2 stocks_company_reports_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p2
    ADD CONSTRAINT stocks_company_reports_p2_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p3 stocks_company_reports_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p3
    ADD CONSTRAINT stocks_company_reports_p3_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p4 stocks_company_reports_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p4
    ADD CONSTRAINT stocks_company_reports_p4_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p5 stocks_company_reports_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p5
    ADD CONSTRAINT stocks_company_reports_p5_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p6 stocks_company_reports_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p6
    ADD CONSTRAINT stocks_company_reports_p6_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p7 stocks_company_reports_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p7
    ADD CONSTRAINT stocks_company_reports_p7_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p8 stocks_company_reports_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p8
    ADD CONSTRAINT stocks_company_reports_p8_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_reports_p9 stocks_company_reports_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_reports_p9
    ADD CONSTRAINT stocks_company_reports_p9_pkey PRIMARY KEY (report_id, stock_id);


--
-- Name: stocks_company_transcript_sections stocks_company_transcript_sections_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections
    ADD CONSTRAINT stocks_company_transcript_sections_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p0 stocks_company_transcript_sections_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p0
    ADD CONSTRAINT stocks_company_transcript_sections_p0_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p1 stocks_company_transcript_sections_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p1
    ADD CONSTRAINT stocks_company_transcript_sections_p1_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p2 stocks_company_transcript_sections_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p2
    ADD CONSTRAINT stocks_company_transcript_sections_p2_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p3 stocks_company_transcript_sections_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p3
    ADD CONSTRAINT stocks_company_transcript_sections_p3_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p4 stocks_company_transcript_sections_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p4
    ADD CONSTRAINT stocks_company_transcript_sections_p4_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p5 stocks_company_transcript_sections_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p5
    ADD CONSTRAINT stocks_company_transcript_sections_p5_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p6 stocks_company_transcript_sections_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p6
    ADD CONSTRAINT stocks_company_transcript_sections_p6_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p7 stocks_company_transcript_sections_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p7
    ADD CONSTRAINT stocks_company_transcript_sections_p7_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p8 stocks_company_transcript_sections_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p8
    ADD CONSTRAINT stocks_company_transcript_sections_p8_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_sections_p9 stocks_company_transcript_sections_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_sections_p9
    ADD CONSTRAINT stocks_company_transcript_sections_p9_pkey PRIMARY KEY (section_id, transcript_id);


--
-- Name: stocks_company_transcript_source_documents stocks_company_transcript_source_documents_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents
    ADD CONSTRAINT stocks_company_transcript_source_documents_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p0 stocks_company_transcript_source_documents_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p0
    ADD CONSTRAINT stocks_company_transcript_source_documents_p0_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p1 stocks_company_transcript_source_documents_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p1
    ADD CONSTRAINT stocks_company_transcript_source_documents_p1_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p2 stocks_company_transcript_source_documents_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p2
    ADD CONSTRAINT stocks_company_transcript_source_documents_p2_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p3 stocks_company_transcript_source_documents_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p3
    ADD CONSTRAINT stocks_company_transcript_source_documents_p3_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p4 stocks_company_transcript_source_documents_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p4
    ADD CONSTRAINT stocks_company_transcript_source_documents_p4_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p5 stocks_company_transcript_source_documents_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p5
    ADD CONSTRAINT stocks_company_transcript_source_documents_p5_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p6 stocks_company_transcript_source_documents_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p6
    ADD CONSTRAINT stocks_company_transcript_source_documents_p6_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p7 stocks_company_transcript_source_documents_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p7
    ADD CONSTRAINT stocks_company_transcript_source_documents_p7_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p8 stocks_company_transcript_source_documents_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p8
    ADD CONSTRAINT stocks_company_transcript_source_documents_p8_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcript_source_documents_p9 stocks_company_transcript_source_documents_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcript_source_documents_p9
    ADD CONSTRAINT stocks_company_transcript_source_documents_p9_pkey PRIMARY KEY (source_document_id, stock_id);


--
-- Name: stocks_company_transcripts stocks_company_transcripts_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts
    ADD CONSTRAINT stocks_company_transcripts_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p0 stocks_company_transcripts_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p0
    ADD CONSTRAINT stocks_company_transcripts_p0_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p1 stocks_company_transcripts_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p1
    ADD CONSTRAINT stocks_company_transcripts_p1_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p2 stocks_company_transcripts_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p2
    ADD CONSTRAINT stocks_company_transcripts_p2_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p3 stocks_company_transcripts_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p3
    ADD CONSTRAINT stocks_company_transcripts_p3_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p4 stocks_company_transcripts_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p4
    ADD CONSTRAINT stocks_company_transcripts_p4_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p5 stocks_company_transcripts_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p5
    ADD CONSTRAINT stocks_company_transcripts_p5_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p6 stocks_company_transcripts_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p6
    ADD CONSTRAINT stocks_company_transcripts_p6_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p7 stocks_company_transcripts_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p7
    ADD CONSTRAINT stocks_company_transcripts_p7_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p8 stocks_company_transcripts_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p8
    ADD CONSTRAINT stocks_company_transcripts_p8_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_company_transcripts_p9 stocks_company_transcripts_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_company_transcripts_p9
    ADD CONSTRAINT stocks_company_transcripts_p9_pkey PRIMARY KEY (transcript_id, stock_id);


--
-- Name: stocks_earnings_calendar stocks_earnings_calendar_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_earnings_calendar
    ADD CONSTRAINT stocks_earnings_calendar_pkey PRIMARY KEY (earnings_id);


--
-- Name: stocks_events stocks_events_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events
    ADD CONSTRAINT stocks_events_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p0 stocks_events_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p0
    ADD CONSTRAINT stocks_events_p0_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p1 stocks_events_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p1
    ADD CONSTRAINT stocks_events_p1_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p2 stocks_events_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p2
    ADD CONSTRAINT stocks_events_p2_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p3 stocks_events_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p3
    ADD CONSTRAINT stocks_events_p3_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p4 stocks_events_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p4
    ADD CONSTRAINT stocks_events_p4_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p5 stocks_events_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p5
    ADD CONSTRAINT stocks_events_p5_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p6 stocks_events_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p6
    ADD CONSTRAINT stocks_events_p6_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p7 stocks_events_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p7
    ADD CONSTRAINT stocks_events_p7_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p8 stocks_events_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p8
    ADD CONSTRAINT stocks_events_p8_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_events_p9 stocks_events_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_events_p9
    ADD CONSTRAINT stocks_events_p9_pkey PRIMARY KEY (event_id, stock_id);


--
-- Name: stocks_fundamentals stocks_fundamentals_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals
    ADD CONSTRAINT stocks_fundamentals_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p0 stocks_fundamentals_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p0
    ADD CONSTRAINT stocks_fundamentals_p0_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals stocks_fundamentals_uniq; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals
    ADD CONSTRAINT stocks_fundamentals_uniq UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p0 stocks_fundamentals_p0_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p0
    ADD CONSTRAINT stocks_fundamentals_p0_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p1 stocks_fundamentals_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p1
    ADD CONSTRAINT stocks_fundamentals_p1_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p1 stocks_fundamentals_p1_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p1
    ADD CONSTRAINT stocks_fundamentals_p1_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p2 stocks_fundamentals_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p2
    ADD CONSTRAINT stocks_fundamentals_p2_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p2 stocks_fundamentals_p2_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p2
    ADD CONSTRAINT stocks_fundamentals_p2_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p3 stocks_fundamentals_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p3
    ADD CONSTRAINT stocks_fundamentals_p3_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p3 stocks_fundamentals_p3_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p3
    ADD CONSTRAINT stocks_fundamentals_p3_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p4 stocks_fundamentals_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p4
    ADD CONSTRAINT stocks_fundamentals_p4_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p4 stocks_fundamentals_p4_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p4
    ADD CONSTRAINT stocks_fundamentals_p4_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p5 stocks_fundamentals_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p5
    ADD CONSTRAINT stocks_fundamentals_p5_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p5 stocks_fundamentals_p5_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p5
    ADD CONSTRAINT stocks_fundamentals_p5_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p6 stocks_fundamentals_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p6
    ADD CONSTRAINT stocks_fundamentals_p6_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p6 stocks_fundamentals_p6_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p6
    ADD CONSTRAINT stocks_fundamentals_p6_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p7 stocks_fundamentals_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p7
    ADD CONSTRAINT stocks_fundamentals_p7_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p7 stocks_fundamentals_p7_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p7
    ADD CONSTRAINT stocks_fundamentals_p7_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p8 stocks_fundamentals_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p8
    ADD CONSTRAINT stocks_fundamentals_p8_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p8 stocks_fundamentals_p8_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p8
    ADD CONSTRAINT stocks_fundamentals_p8_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_fundamentals_p9 stocks_fundamentals_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p9
    ADD CONSTRAINT stocks_fundamentals_p9_pkey PRIMARY KEY (fundamentals_id, stock_id);


--
-- Name: stocks_fundamentals_p9 stocks_fundamentals_p9_stock_id_metric_category_metric_type_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_fundamentals_p9
    ADD CONSTRAINT stocks_fundamentals_p9_stock_id_metric_category_metric_type_key UNIQUE (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: stocks_indicators stocks_indicators_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_indicators
    ADD CONSTRAINT stocks_indicators_pkey PRIMARY KEY (indicator_id);


--
-- Name: stocks_market_alerts stocks_market_alerts_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts
    ADD CONSTRAINT stocks_market_alerts_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p0 stocks_market_alerts_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p0
    ADD CONSTRAINT stocks_market_alerts_p0_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p1 stocks_market_alerts_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p1
    ADD CONSTRAINT stocks_market_alerts_p1_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p2 stocks_market_alerts_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p2
    ADD CONSTRAINT stocks_market_alerts_p2_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p3 stocks_market_alerts_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p3
    ADD CONSTRAINT stocks_market_alerts_p3_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p4 stocks_market_alerts_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p4
    ADD CONSTRAINT stocks_market_alerts_p4_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p5 stocks_market_alerts_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p5
    ADD CONSTRAINT stocks_market_alerts_p5_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p6 stocks_market_alerts_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p6
    ADD CONSTRAINT stocks_market_alerts_p6_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p7 stocks_market_alerts_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p7
    ADD CONSTRAINT stocks_market_alerts_p7_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p8 stocks_market_alerts_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p8
    ADD CONSTRAINT stocks_market_alerts_p8_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_alerts_p9 stocks_market_alerts_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_alerts_p9
    ADD CONSTRAINT stocks_market_alerts_p9_pkey PRIMARY KEY (alert_id, stock_id);


--
-- Name: stocks_market_news stocks_market_news_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news
    ADD CONSTRAINT stocks_market_news_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p0 stocks_market_news_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p0
    ADD CONSTRAINT stocks_market_news_p0_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p1 stocks_market_news_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p1
    ADD CONSTRAINT stocks_market_news_p1_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p2 stocks_market_news_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p2
    ADD CONSTRAINT stocks_market_news_p2_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p3 stocks_market_news_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p3
    ADD CONSTRAINT stocks_market_news_p3_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p4 stocks_market_news_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p4
    ADD CONSTRAINT stocks_market_news_p4_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p5 stocks_market_news_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p5
    ADD CONSTRAINT stocks_market_news_p5_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p6 stocks_market_news_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p6
    ADD CONSTRAINT stocks_market_news_p6_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p7 stocks_market_news_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p7
    ADD CONSTRAINT stocks_market_news_p7_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p8 stocks_market_news_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p8
    ADD CONSTRAINT stocks_market_news_p8_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_market_news_p9 stocks_market_news_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_market_news_p9
    ADD CONSTRAINT stocks_market_news_p9_pkey PRIMARY KEY (news_id, stock_id);


--
-- Name: stocks_metric_types stocks_metric_types_metric_id_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metric_types
    ADD CONSTRAINT stocks_metric_types_metric_id_key UNIQUE (metric_id);


--
-- Name: stocks_metric_types stocks_metric_types_metric_name_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metric_types
    ADD CONSTRAINT stocks_metric_types_metric_name_key UNIQUE (metric_name);


--
-- Name: stocks_metrics stocks_metrics_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics
    ADD CONSTRAINT stocks_metrics_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p0 stocks_metrics_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p0
    ADD CONSTRAINT stocks_metrics_p0_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics stocks_metrics_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics
    ADD CONSTRAINT stocks_metrics_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p0 stocks_metrics_p0_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p0
    ADD CONSTRAINT stocks_metrics_p0_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p1 stocks_metrics_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p1
    ADD CONSTRAINT stocks_metrics_p1_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p1 stocks_metrics_p1_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p1
    ADD CONSTRAINT stocks_metrics_p1_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p2 stocks_metrics_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p2
    ADD CONSTRAINT stocks_metrics_p2_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p2 stocks_metrics_p2_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p2
    ADD CONSTRAINT stocks_metrics_p2_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p3 stocks_metrics_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p3
    ADD CONSTRAINT stocks_metrics_p3_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p3 stocks_metrics_p3_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p3
    ADD CONSTRAINT stocks_metrics_p3_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p4 stocks_metrics_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p4
    ADD CONSTRAINT stocks_metrics_p4_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p4 stocks_metrics_p4_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p4
    ADD CONSTRAINT stocks_metrics_p4_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p5 stocks_metrics_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p5
    ADD CONSTRAINT stocks_metrics_p5_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p5 stocks_metrics_p5_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p5
    ADD CONSTRAINT stocks_metrics_p5_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p6 stocks_metrics_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p6
    ADD CONSTRAINT stocks_metrics_p6_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p6 stocks_metrics_p6_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p6
    ADD CONSTRAINT stocks_metrics_p6_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p7 stocks_metrics_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p7
    ADD CONSTRAINT stocks_metrics_p7_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p7 stocks_metrics_p7_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p7
    ADD CONSTRAINT stocks_metrics_p7_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p8 stocks_metrics_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p8
    ADD CONSTRAINT stocks_metrics_p8_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p8 stocks_metrics_p8_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p8
    ADD CONSTRAINT stocks_metrics_p8_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks_metrics_p9 stocks_metrics_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p9
    ADD CONSTRAINT stocks_metrics_p9_pkey PRIMARY KEY (stock_metric_id, stock_id);


--
-- Name: stocks_metrics_p9 stocks_metrics_p9_stock_id_metric_id_snapshot_timestamp_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_metrics_p9
    ADD CONSTRAINT stocks_metrics_p9_stock_id_metric_id_snapshot_timestamp_key UNIQUE (stock_id, metric_id, snapshot_timestamp);


--
-- Name: stocks stocks_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks
    ADD CONSTRAINT stocks_pkey PRIMARY KEY (stock_id);


--
-- Name: stocks_price_data stocks_price_data_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data
    ADD CONSTRAINT stocks_price_data_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p0 stocks_price_data_p0_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p0
    ADD CONSTRAINT stocks_price_data_p0_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data stocks_price_data_uniq; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data
    ADD CONSTRAINT stocks_price_data_uniq UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p0 stocks_price_data_p0_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p0
    ADD CONSTRAINT stocks_price_data_p0_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p1 stocks_price_data_p1_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p1
    ADD CONSTRAINT stocks_price_data_p1_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p1 stocks_price_data_p1_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p1
    ADD CONSTRAINT stocks_price_data_p1_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p2 stocks_price_data_p2_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p2
    ADD CONSTRAINT stocks_price_data_p2_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p2 stocks_price_data_p2_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p2
    ADD CONSTRAINT stocks_price_data_p2_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p3 stocks_price_data_p3_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p3
    ADD CONSTRAINT stocks_price_data_p3_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p3 stocks_price_data_p3_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p3
    ADD CONSTRAINT stocks_price_data_p3_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p4 stocks_price_data_p4_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p4
    ADD CONSTRAINT stocks_price_data_p4_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p4 stocks_price_data_p4_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p4
    ADD CONSTRAINT stocks_price_data_p4_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p5 stocks_price_data_p5_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p5
    ADD CONSTRAINT stocks_price_data_p5_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p5 stocks_price_data_p5_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p5
    ADD CONSTRAINT stocks_price_data_p5_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p6 stocks_price_data_p6_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p6
    ADD CONSTRAINT stocks_price_data_p6_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p6 stocks_price_data_p6_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p6
    ADD CONSTRAINT stocks_price_data_p6_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p7 stocks_price_data_p7_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p7
    ADD CONSTRAINT stocks_price_data_p7_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p7 stocks_price_data_p7_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p7
    ADD CONSTRAINT stocks_price_data_p7_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p8 stocks_price_data_p8_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p8
    ADD CONSTRAINT stocks_price_data_p8_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p8 stocks_price_data_p8_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p8
    ADD CONSTRAINT stocks_price_data_p8_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_price_data_p9 stocks_price_data_p9_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p9
    ADD CONSTRAINT stocks_price_data_p9_pkey PRIMARY KEY (market_data_id, stock_id);


--
-- Name: stocks_price_data_p9 stocks_price_data_p9_stock_id_price_date_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_price_data_p9
    ADD CONSTRAINT stocks_price_data_p9_stock_id_price_date_key UNIQUE (stock_id, price_date);


--
-- Name: stocks_upcoming_events stocks_upcoming_events_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_upcoming_events
    ADD CONSTRAINT stocks_upcoming_events_pkey PRIMARY KEY (event_id);


--
-- Name: stocks_watchlist stocks_watchlist_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_watchlist
    ADD CONSTRAINT stocks_watchlist_pkey PRIMARY KEY (watchlist_id);


--
-- Name: stocks_watchlist stocks_watchlist_watchlist_name_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_watchlist
    ADD CONSTRAINT stocks_watchlist_watchlist_name_key UNIQUE (watchlist_name);


--
-- Name: stocks_word_cloud_metrics stocks_word_cloud_metrics_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_word_cloud_metrics
    ADD CONSTRAINT stocks_word_cloud_metrics_pkey PRIMARY KEY (word_id);


--
-- Name: ticker_list ticker_list_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.ticker_list
    ADD CONSTRAINT ticker_list_pkey PRIMARY KEY (id);


--
-- Name: portfolio_stocks uniq_key1; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio_stocks
    ADD CONSTRAINT uniq_key1 UNIQUE (portfolio_id, stock_id);


--
-- Name: stock_ingestion_jobs uq_sij_request_chunk; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_jobs
    ADD CONSTRAINT uq_sij_request_chunk UNIQUE (request_id, chunk_index);


--
-- Name: stock_peers uq_stock_peer; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_peers
    ADD CONSTRAINT uq_stock_peer UNIQUE (stock_id, peer_stock_id);


--
-- Name: stocks uq_stocks_ticker_exchange; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks
    ADD CONSTRAINT uq_stocks_ticker_exchange UNIQUE (ticker, exchange);


--
-- Name: ticker_list uq_symbol_exchange; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.ticker_list
    ADD CONSTRAINT uq_symbol_exchange UNIQUE (symbol, exchange_code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: instrument_correlation_matrix instrument_correlation_matrix_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.instrument_correlation_matrix
    ADD CONSTRAINT instrument_correlation_matrix_pkey PRIMARY KEY (correlation_id);


--
-- Name: market_summary market_summary_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.market_summary
    ADD CONSTRAINT market_summary_pkey PRIMARY KEY (id);


--
-- Name: portfolio_ai_analysis portfolio_ai_analysis_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.portfolio_ai_analysis
    ADD CONSTRAINT portfolio_ai_analysis_pkey PRIMARY KEY (id);


--
-- Name: research_copilot_prompt_suggestions research_copilot_prompt_suggestions_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_prompt_suggestions
    ADD CONSTRAINT research_copilot_prompt_suggestions_pkey PRIMARY KEY (suggestion_id);


--
-- Name: research_copilot_report_sharing research_copilot_report_sharing_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_report_sharing
    ADD CONSTRAINT research_copilot_report_sharing_pkey PRIMARY KEY (share_id);


--
-- Name: research_copilot_reports research_copilot_reports_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_reports
    ADD CONSTRAINT research_copilot_reports_pkey PRIMARY KEY (report_id);


--
-- Name: stocks_driver_analysis stocks_driver_analysis_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_driver_analysis
    ADD CONSTRAINT stocks_driver_analysis_pkey PRIMARY KEY (driver_id);


--
-- Name: stocks_events_messages_correlation stocks_events_messages_correlation_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_events_messages_correlation
    ADD CONSTRAINT stocks_events_messages_correlation_pkey PRIMARY KEY (stock_id, event_id);


--
-- Name: stocks_fundamentals_ai_analysis stocks_fundamentals_ai_analysis_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_fundamentals_ai_analysis
    ADD CONSTRAINT stocks_fundamentals_ai_analysis_pkey PRIMARY KEY (analysis_id);


--
-- Name: stocks_insights_ai_summary stocks_insights_ai_summary_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_insights_ai_summary
    ADD CONSTRAINT stocks_insights_ai_summary_pkey PRIMARY KEY (summary_id);


--
-- Name: stocks_message_sentiments stocks_message_sentiments_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments
    ADD CONSTRAINT stocks_message_sentiments_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p0 stocks_message_sentiments_p0_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p0
    ADD CONSTRAINT stocks_message_sentiments_p0_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p1 stocks_message_sentiments_p1_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p1
    ADD CONSTRAINT stocks_message_sentiments_p1_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p2 stocks_message_sentiments_p2_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p2
    ADD CONSTRAINT stocks_message_sentiments_p2_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p3 stocks_message_sentiments_p3_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p3
    ADD CONSTRAINT stocks_message_sentiments_p3_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p4 stocks_message_sentiments_p4_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p4
    ADD CONSTRAINT stocks_message_sentiments_p4_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p5 stocks_message_sentiments_p5_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p5
    ADD CONSTRAINT stocks_message_sentiments_p5_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p6 stocks_message_sentiments_p6_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p6
    ADD CONSTRAINT stocks_message_sentiments_p6_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p7 stocks_message_sentiments_p7_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p7
    ADD CONSTRAINT stocks_message_sentiments_p7_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p8 stocks_message_sentiments_p8_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p8
    ADD CONSTRAINT stocks_message_sentiments_p8_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_message_sentiments_p9 stocks_message_sentiments_p9_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_message_sentiments_p9
    ADD CONSTRAINT stocks_message_sentiments_p9_pkey PRIMARY KEY (message_id, stock_id, analyzed_at);


--
-- Name: stocks_sentiment_analysis uniq_analysis_id; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis
    ADD CONSTRAINT uniq_analysis_id UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p0 stocks_sentiment_analysis_p0_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p0
    ADD CONSTRAINT stocks_sentiment_analysis_p0_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis stocks_sentiment_analysis_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis
    ADD CONSTRAINT stocks_sentiment_analysis_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p0 stocks_sentiment_analysis_p0_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p0
    ADD CONSTRAINT stocks_sentiment_analysis_p0_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p1 stocks_sentiment_analysis_p1_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p1
    ADD CONSTRAINT stocks_sentiment_analysis_p1_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p1 stocks_sentiment_analysis_p1_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p1
    ADD CONSTRAINT stocks_sentiment_analysis_p1_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p2 stocks_sentiment_analysis_p2_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p2
    ADD CONSTRAINT stocks_sentiment_analysis_p2_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p2 stocks_sentiment_analysis_p2_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p2
    ADD CONSTRAINT stocks_sentiment_analysis_p2_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p3 stocks_sentiment_analysis_p3_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p3
    ADD CONSTRAINT stocks_sentiment_analysis_p3_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p3 stocks_sentiment_analysis_p3_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p3
    ADD CONSTRAINT stocks_sentiment_analysis_p3_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p4 stocks_sentiment_analysis_p4_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p4
    ADD CONSTRAINT stocks_sentiment_analysis_p4_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p4 stocks_sentiment_analysis_p4_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p4
    ADD CONSTRAINT stocks_sentiment_analysis_p4_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p5 stocks_sentiment_analysis_p5_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p5
    ADD CONSTRAINT stocks_sentiment_analysis_p5_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p5 stocks_sentiment_analysis_p5_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p5
    ADD CONSTRAINT stocks_sentiment_analysis_p5_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p6 stocks_sentiment_analysis_p6_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p6
    ADD CONSTRAINT stocks_sentiment_analysis_p6_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p6 stocks_sentiment_analysis_p6_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p6
    ADD CONSTRAINT stocks_sentiment_analysis_p6_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p7 stocks_sentiment_analysis_p7_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p7
    ADD CONSTRAINT stocks_sentiment_analysis_p7_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p7 stocks_sentiment_analysis_p7_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p7
    ADD CONSTRAINT stocks_sentiment_analysis_p7_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p8 stocks_sentiment_analysis_p8_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p8
    ADD CONSTRAINT stocks_sentiment_analysis_p8_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p8 stocks_sentiment_analysis_p8_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p8
    ADD CONSTRAINT stocks_sentiment_analysis_p8_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p9 stocks_sentiment_analysis_p9_analysis_id_stock_id_key; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p9
    ADD CONSTRAINT stocks_sentiment_analysis_p9_analysis_id_stock_id_key UNIQUE (analysis_id, stock_id);


--
-- Name: stocks_sentiment_analysis_p9 stocks_sentiment_analysis_p9_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_sentiment_analysis_p9
    ADD CONSTRAINT stocks_sentiment_analysis_p9_pkey PRIMARY KEY (analysis_id, stock_id);


--
-- Name: stocks_weekly_sentiment_analysis stocks_weekly_sentiment_analysis_pkey; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_weekly_sentiment_analysis
    ADD CONSTRAINT stocks_weekly_sentiment_analysis_pkey PRIMARY KEY (weekly_analysis_id);


--
-- Name: stocks_weekly_sentiment_analysis stocks_weekly_sentiment_unique; Type: CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_weekly_sentiment_analysis
    ADD CONSTRAINT stocks_weekly_sentiment_unique UNIQUE (stock_id, week_start);


--
-- Name: idx_indexed_records_hash; Type: INDEX; Schema: indexing_state; Owner: -
--

CREATE INDEX idx_indexed_records_hash ON indexing_state.indexed_records USING btree (source_type, source_id, content_hash);


--
-- Name: idx_indexed_records_source; Type: INDEX; Schema: indexing_state; Owner: -
--

CREATE INDEX idx_indexed_records_source ON indexing_state.indexed_records USING btree (source_type, stock_id);


--
-- Name: idx_indexed_records_status; Type: INDEX; Schema: indexing_state; Owner: -
--

CREATE INDEX idx_indexed_records_status ON indexing_state.indexed_records USING btree (status);


--
-- Name: idx_exchange_hours_enabled; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_exchange_hours_enabled ON ingest_db.pipeline_exchange_hours USING btree (enabled) WHERE (enabled = true);


--
-- Name: idx_outbox_event_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_outbox_event_id ON ingest_db.stock_ingestion_event_outbox USING btree (event_id);


--
-- Name: idx_outbox_pending; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_outbox_pending ON ingest_db.stock_ingestion_event_outbox USING btree (publish_status, next_retry_at) WHERE ((publish_status)::text = ANY ((ARRAY['pending'::character varying, 'failed'::character varying])::text[]));


--
-- Name: idx_price_latest_stock; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_price_latest_stock ON ONLY ingest_db.stocks_price_data USING btree (stock_id);


--
-- Name: idx_sb_map_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sb_map_stock_id ON ingest_db.stocks_benchmark_mapping USING btree (stock_id);


--
-- Name: idx_sie_created_at_recent; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sie_created_at_recent ON ingest_db.stock_ingestion_events USING btree (created_at DESC);


--
-- Name: idx_sie_event_type_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sie_event_type_created ON ingest_db.stock_ingestion_events USING btree (event_type, created_at DESC);


--
-- Name: idx_sie_job_id_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sie_job_id_created ON ingest_db.stock_ingestion_events USING btree (job_id, created_at DESC) WHERE (job_id IS NOT NULL);


--
-- Name: idx_sie_request_id_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sie_request_id_created ON ingest_db.stock_ingestion_events USING btree (request_id, created_at DESC) WHERE (request_id IS NOT NULL);


--
-- Name: idx_sij_queue_message_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sij_queue_message_id ON ingest_db.stock_ingestion_jobs USING btree (queue_message_id) WHERE (queue_message_id IS NOT NULL);


--
-- Name: idx_sij_request_id_chunk; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sij_request_id_chunk ON ingest_db.stock_ingestion_jobs USING btree (request_id, chunk_index);


--
-- Name: idx_sij_request_id_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sij_request_id_created ON ingest_db.stock_ingestion_jobs USING btree (request_id, created_at);


--
-- Name: idx_sij_request_id_status; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sij_request_id_status ON ingest_db.stock_ingestion_jobs USING btree (request_id, status);


--
-- Name: idx_sir_ai_dispatch_status; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sir_ai_dispatch_status ON ingest_db.stock_ingestion_requests USING btree (ai_dispatch_status, updated_at DESC);


--
-- Name: idx_sir_created_at_desc; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sir_created_at_desc ON ingest_db.stock_ingestion_requests USING btree (created_at DESC);


--
-- Name: idx_sir_overall_status_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sir_overall_status_created ON ingest_db.stock_ingestion_requests USING btree (overall_status, created_at DESC);


--
-- Name: idx_sir_portfolio_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sir_portfolio_created ON ingest_db.stock_ingestion_requests USING btree (portfolio_id, created_at DESC);


--
-- Name: idx_sir_requested_by_created; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_sir_requested_by_created ON ingest_db.stock_ingestion_requests USING btree (requested_by, created_at DESC);


--
-- Name: idx_stock_csv_map_enabled; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stock_csv_map_enabled ON ingest_db.pipeline_stock_csv_map USING btree (enabled) WHERE (enabled = true);


--
-- Name: idx_stocks_canonical_symbol; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stocks_canonical_symbol ON ingest_db.stocks USING btree (canonical_symbol);


--
-- Name: idx_stocks_canonical_ticker; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stocks_canonical_ticker ON ingest_db.stocks USING btree (canonical_ticker);


--
-- Name: idx_stocks_instrument_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stocks_instrument_id ON ingest_db.instruments USING btree (instrument_id);


--
-- Name: idx_stocks_price_data_date; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stocks_price_data_date ON ONLY ingest_db.stocks_price_data USING btree (price_date);


--
-- Name: idx_stocks_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_stocks_stock_id ON ingest_db.stocks USING btree (stock_id);


--
-- Name: idx_ticker_list_base_symbol; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_base_symbol ON ingest_db.ticker_list USING btree (base_symbol);


--
-- Name: idx_ticker_list_canonical_symbol; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_canonical_symbol ON ingest_db.ticker_list USING btree (canonical_symbol);


--
-- Name: idx_ticker_list_canonical_ticker; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_canonical_ticker ON ingest_db.ticker_list USING btree (canonical_ticker);


--
-- Name: idx_ticker_list_exchange; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_exchange ON ingest_db.ticker_list USING btree (exchange_code);


--
-- Name: idx_ticker_list_fts; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_fts ON ingest_db.ticker_list USING gin (to_tsvector('english'::regconfig, (((symbol)::text || ' '::text) || (company_name)::text)));


--
-- Name: idx_ticker_list_market_code; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_market_code ON ingest_db.ticker_list USING btree (market_code);


--
-- Name: idx_ticker_list_name; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_name ON ingest_db.ticker_list USING btree (company_name text_pattern_ops);


--
-- Name: idx_ticker_list_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_stock_id ON ingest_db.ticker_list USING btree (stock_id);


--
-- Name: idx_ticker_list_symbol; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX idx_ticker_list_symbol ON ingest_db.ticker_list USING btree (symbol text_pattern_ops);


--
-- Name: ix_pif_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX ix_pif_stock_id ON ingest_db.pipeline_ingestion_files USING btree (stock_id);


--
-- Name: ix_pifci_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX ix_pifci_stock_id ON ingest_db.pipeline_ingestion_file_csv_ids USING btree (stock_id);


--
-- Name: ix_psd_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX ix_psd_stock_id ON ingest_db.pipeline_sentiment_dates USING btree (stock_id);


--
-- Name: ix_psp_stock_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX ix_psp_stock_id ON ingest_db.pipeline_sentiment_processed_ids USING btree (stock_id);


--
-- Name: stocks_company_transcript_source_documents_category_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_category_idx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_p_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_pu_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_category_pu_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, document_category, published_at DESC);


--
-- Name: stocks_company_transcript_source_documents_type_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_type_idx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publi_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publis_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_document_type_publis_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, document_type, published_at DESC);


--
-- Name: stocks_company_transcript_source_documents_stock_pdf_url_uidx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_documents_stock_pdf_url_uidx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_p_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_pd_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_sou_stock_id_normalized_source_pd_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, normalized_source_pdf_url);


--
-- Name: stocks_company_transcript_source_documents_reporting_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_reporting_idx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_ty_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_typ_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_sou_stock_id_reporting_period_typ_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, reporting_period_type, reporting_period_year, reporting_period_quarter, published_at DESC);


--
-- Name: stocks_company_transcript_source_documents_stock_pdf_id_uidx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_documents_stock_pdf_id_uidx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_do_stock_id_source_pdf_id_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_documents_published_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_published_idx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx1 ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx2; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx2 ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx3; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx3 ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx4; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx4 ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx5; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx5 ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx6; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx6 ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx7; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx7 ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx8; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx8 ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx9; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_doc_stock_id_published_at_idx9 ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_doc_stock_id_source_pdf_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_company_transcript_source_doc_stock_id_source_pdf_id_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, source_pdf_id);


--
-- Name: stocks_company_transcript_source_docu_stock_id_published_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_docu_stock_id_published_at_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (stock_id, published_at DESC);


--
-- Name: stocks_company_transcript_source_documents_transcript_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_transcript_idx ON ONLY ingest_db.stocks_company_transcript_source_documents USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p0_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p0_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p0 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p1_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p1_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p1 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p2_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p2_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p2 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p3_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p3_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p3 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p4_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p4_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p4 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p5_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p5_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p5 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p6_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p6_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p6 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p7_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p7_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p7 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p8_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p8_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p8 USING btree (transcript_id);


--
-- Name: stocks_company_transcript_source_documents_p9_transcript_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_company_transcript_source_documents_p9_transcript_id_idx ON ingest_db.stocks_company_transcript_source_documents_p9 USING btree (transcript_id);


--
-- Name: stocks_price_data_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_price_date_idx ON ONLY ingest_db.stocks_price_data USING btree (price_date);


--
-- Name: stocks_price_data_p0_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p0_price_date_idx ON ingest_db.stocks_price_data_p0 USING btree (price_date);


--
-- Name: stocks_price_data_p0_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p0_price_date_idx1 ON ingest_db.stocks_price_data_p0 USING btree (price_date);


--
-- Name: stocks_price_data_uidx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_uidx ON ONLY ingest_db.stocks_price_data USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p0_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p0_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p0 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_stock_id_captured_at_idx ON ONLY ingest_db.stocks_price_data USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p0_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p0_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p0 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p0_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p0_stock_id_idx ON ingest_db.stocks_price_data_p0 USING btree (stock_id);


--
-- Name: stocks_price_data_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_stock_id_price_date_idx ON ONLY ingest_db.stocks_price_data USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p0_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p0_stock_id_price_date_idx ON ingest_db.stocks_price_data_p0 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p1_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p1_price_date_idx ON ingest_db.stocks_price_data_p1 USING btree (price_date);


--
-- Name: stocks_price_data_p1_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p1_price_date_idx1 ON ingest_db.stocks_price_data_p1 USING btree (price_date);


--
-- Name: stocks_price_data_p1_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p1_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p1 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p1_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p1_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p1 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p1_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p1_stock_id_idx ON ingest_db.stocks_price_data_p1 USING btree (stock_id);


--
-- Name: stocks_price_data_p1_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p1_stock_id_price_date_idx ON ingest_db.stocks_price_data_p1 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p2_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p2_price_date_idx ON ingest_db.stocks_price_data_p2 USING btree (price_date);


--
-- Name: stocks_price_data_p2_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p2_price_date_idx1 ON ingest_db.stocks_price_data_p2 USING btree (price_date);


--
-- Name: stocks_price_data_p2_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p2_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p2 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p2_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p2_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p2 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p2_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p2_stock_id_idx ON ingest_db.stocks_price_data_p2 USING btree (stock_id);


--
-- Name: stocks_price_data_p2_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p2_stock_id_price_date_idx ON ingest_db.stocks_price_data_p2 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p3_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p3_price_date_idx ON ingest_db.stocks_price_data_p3 USING btree (price_date);


--
-- Name: stocks_price_data_p3_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p3_price_date_idx1 ON ingest_db.stocks_price_data_p3 USING btree (price_date);


--
-- Name: stocks_price_data_p3_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p3_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p3 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p3_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p3_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p3 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p3_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p3_stock_id_idx ON ingest_db.stocks_price_data_p3 USING btree (stock_id);


--
-- Name: stocks_price_data_p3_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p3_stock_id_price_date_idx ON ingest_db.stocks_price_data_p3 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p4_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p4_price_date_idx ON ingest_db.stocks_price_data_p4 USING btree (price_date);


--
-- Name: stocks_price_data_p4_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p4_price_date_idx1 ON ingest_db.stocks_price_data_p4 USING btree (price_date);


--
-- Name: stocks_price_data_p4_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p4_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p4 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p4_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p4_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p4 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p4_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p4_stock_id_idx ON ingest_db.stocks_price_data_p4 USING btree (stock_id);


--
-- Name: stocks_price_data_p4_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p4_stock_id_price_date_idx ON ingest_db.stocks_price_data_p4 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p5_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p5_price_date_idx ON ingest_db.stocks_price_data_p5 USING btree (price_date);


--
-- Name: stocks_price_data_p5_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p5_price_date_idx1 ON ingest_db.stocks_price_data_p5 USING btree (price_date);


--
-- Name: stocks_price_data_p5_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p5_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p5 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p5_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p5_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p5 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p5_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p5_stock_id_idx ON ingest_db.stocks_price_data_p5 USING btree (stock_id);


--
-- Name: stocks_price_data_p5_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p5_stock_id_price_date_idx ON ingest_db.stocks_price_data_p5 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p6_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p6_price_date_idx ON ingest_db.stocks_price_data_p6 USING btree (price_date);


--
-- Name: stocks_price_data_p6_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p6_price_date_idx1 ON ingest_db.stocks_price_data_p6 USING btree (price_date);


--
-- Name: stocks_price_data_p6_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p6_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p6 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p6_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p6_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p6 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p6_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p6_stock_id_idx ON ingest_db.stocks_price_data_p6 USING btree (stock_id);


--
-- Name: stocks_price_data_p6_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p6_stock_id_price_date_idx ON ingest_db.stocks_price_data_p6 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p7_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p7_price_date_idx ON ingest_db.stocks_price_data_p7 USING btree (price_date);


--
-- Name: stocks_price_data_p7_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p7_price_date_idx1 ON ingest_db.stocks_price_data_p7 USING btree (price_date);


--
-- Name: stocks_price_data_p7_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p7_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p7 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p7_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p7_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p7 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p7_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p7_stock_id_idx ON ingest_db.stocks_price_data_p7 USING btree (stock_id);


--
-- Name: stocks_price_data_p7_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p7_stock_id_price_date_idx ON ingest_db.stocks_price_data_p7 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p8_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p8_price_date_idx ON ingest_db.stocks_price_data_p8 USING btree (price_date);


--
-- Name: stocks_price_data_p8_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p8_price_date_idx1 ON ingest_db.stocks_price_data_p8 USING btree (price_date);


--
-- Name: stocks_price_data_p8_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p8_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p8 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p8_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p8_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p8 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p8_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p8_stock_id_idx ON ingest_db.stocks_price_data_p8 USING btree (stock_id);


--
-- Name: stocks_price_data_p8_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p8_stock_id_price_date_idx ON ingest_db.stocks_price_data_p8 USING btree (stock_id, price_date);


--
-- Name: stocks_price_data_p9_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p9_price_date_idx ON ingest_db.stocks_price_data_p9 USING btree (price_date);


--
-- Name: stocks_price_data_p9_price_date_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p9_price_date_idx1 ON ingest_db.stocks_price_data_p9 USING btree (price_date);


--
-- Name: stocks_price_data_p9_stock_id_captured_at_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX stocks_price_data_p9_stock_id_captured_at_idx ON ingest_db.stocks_price_data_p9 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p9_stock_id_captured_at_idx1; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p9_stock_id_captured_at_idx1 ON ingest_db.stocks_price_data_p9 USING btree (stock_id, captured_at);


--
-- Name: stocks_price_data_p9_stock_id_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p9_stock_id_idx ON ingest_db.stocks_price_data_p9 USING btree (stock_id);


--
-- Name: stocks_price_data_p9_stock_id_price_date_idx; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE INDEX stocks_price_data_p9_stock_id_price_date_idx ON ingest_db.stocks_price_data_p9 USING btree (stock_id, price_date);


--
-- Name: uniq_stocks_upcoming_earnings; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX uniq_stocks_upcoming_earnings ON ingest_db.stocks_upcoming_earnings USING btree (stock_id, earnings_date);


--
-- Name: uq_outbox_event_id; Type: INDEX; Schema: ingest_db; Owner: -
--

CREATE UNIQUE INDEX uq_outbox_event_id ON ingest_db.stock_ingestion_event_outbox USING btree (event_id);


--
-- Name: idx_mv_instr_iv_latest; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX idx_mv_instr_iv_latest ON semantic_db.mv_instrument_price_volatility USING btree (instrument_id, period, calc_date DESC);


--
-- Name: mv_stocks_price_volatility_uidx; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX mv_stocks_price_volatility_uidx ON semantic_db.mv_stocks_price_volatility USING btree (stock_id, calc_date, period);


--
-- Name: uniq_idx_mv_stocks_dividend_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_dividend_trend_summary ON semantic_db.mv_stocks_dividend_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_ebitda_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_ebitda_trend_summary ON semantic_db.mv_stocks_ebitda_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_eps_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_eps_trend_summary ON semantic_db.mv_stocks_eps_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_free_cash_flow_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_free_cash_flow_trend_summary ON semantic_db.mv_stocks_free_cash_flow_trend_summary USING btree (stock_id, period_type, period_label, metric_type, captured_date);


--
-- Name: uniq_idx_mv_stocks_fundamentals_latest; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_fundamentals_latest ON semantic_db.mv_stocks_fundamentals_latest USING btree (stock_id, metric_category, metric_type, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_price_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_price_trend_summary ON semantic_db.mv_stocks_price_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_return_of_capital_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_return_of_capital_trend_summary ON semantic_db.mv_stocks_return_of_capital_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_revenue_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_revenue_trend_summary ON semantic_db.mv_stocks_revenue_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: uniq_idx_mv_stocks_shares_outstanding_trend_summary; Type: INDEX; Schema: semantic_db; Owner: -
--

CREATE UNIQUE INDEX uniq_idx_mv_stocks_shares_outstanding_trend_summary ON semantic_db.mv_stocks_shares_outstanding_trend_summary USING btree (stock_id, period_type, period_label, captured_date);


--
-- Name: idx_daily_agg_updated_at; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX idx_daily_agg_updated_at ON ONLY transform_db.stocks_sentiment_analysis USING btree (stock_id, updated_at);


--
-- Name: idx_sentiment_latest_stock; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX idx_sentiment_latest_stock ON ONLY transform_db.stocks_sentiment_analysis USING btree (stock_id);


--
-- Name: idx_sms_session; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX idx_sms_session ON ONLY transform_db.stocks_message_sentiments USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: idx_weekly_sentiment_anomaly; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX idx_weekly_sentiment_anomaly ON transform_db.stocks_weekly_sentiment_analysis USING btree (anomaly_flag) WHERE (anomaly_flag = true);


--
-- Name: idx_weekly_sentiment_stock_week; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX idx_weekly_sentiment_stock_week ON transform_db.stocks_weekly_sentiment_analysis USING btree (stock_id, week_start DESC);


--
-- Name: stocks_message_sentiments_p0_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p0_session_idx ON transform_db.stocks_message_sentiments_p0 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p1_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p1_session_idx ON transform_db.stocks_message_sentiments_p1 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p2_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p2_session_idx ON transform_db.stocks_message_sentiments_p2 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p3_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p3_session_idx ON transform_db.stocks_message_sentiments_p3 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p4_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p4_session_idx ON transform_db.stocks_message_sentiments_p4 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p5_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p5_session_idx ON transform_db.stocks_message_sentiments_p5 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p6_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p6_session_idx ON transform_db.stocks_message_sentiments_p6 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p7_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p7_session_idx ON transform_db.stocks_message_sentiments_p7 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p8_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p8_session_idx ON transform_db.stocks_message_sentiments_p8 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: stocks_message_sentiments_p9_session_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_message_sentiments_p9_session_idx ON transform_db.stocks_message_sentiments_p9 USING btree (session) WHERE (session IS NOT NULL);


--
-- Name: uniq_daily_agg_stock_date_by; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX uniq_daily_agg_stock_date_by ON ONLY transform_db.stocks_sentiment_analysis USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p0_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p0_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p0 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p0_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p0_stock_id_idx ON transform_db.stocks_sentiment_analysis_p0 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p0_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p0_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p0 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p1_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p1_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p1 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p1_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p1_stock_id_idx ON transform_db.stocks_sentiment_analysis_p1 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p1_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p1_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p1 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p2_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p2_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p2 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p2_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p2_stock_id_idx ON transform_db.stocks_sentiment_analysis_p2 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p2_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p2_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p2 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p3_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p3_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p3 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p3_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p3_stock_id_idx ON transform_db.stocks_sentiment_analysis_p3 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p3_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p3_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p3 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p4_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p4_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p4 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p4_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p4_stock_id_idx ON transform_db.stocks_sentiment_analysis_p4 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p4_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p4_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p4 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p5_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p5_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p5 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p5_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p5_stock_id_idx ON transform_db.stocks_sentiment_analysis_p5 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p5_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p5_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p5 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p6_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p6_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p6 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p6_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p6_stock_id_idx ON transform_db.stocks_sentiment_analysis_p6 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p6_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p6_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p6 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p7_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p7_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p7 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p7_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p7_stock_id_idx ON transform_db.stocks_sentiment_analysis_p7 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p7_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p7_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p7 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p8_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p8_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p8 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p8_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p8_stock_id_idx ON transform_db.stocks_sentiment_analysis_p8 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p8_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p8_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p8 USING btree (stock_id, updated_at);


--
-- Name: stocks_sentiment_analysis_p9_stock_id_analyzed_at_analyzed__idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE UNIQUE INDEX stocks_sentiment_analysis_p9_stock_id_analyzed_at_analyzed__idx ON transform_db.stocks_sentiment_analysis_p9 USING btree (stock_id, analyzed_at, analyzed_by);


--
-- Name: stocks_sentiment_analysis_p9_stock_id_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p9_stock_id_idx ON transform_db.stocks_sentiment_analysis_p9 USING btree (stock_id);


--
-- Name: stocks_sentiment_analysis_p9_stock_id_updated_at_idx; Type: INDEX; Schema: transform_db; Owner: -
--

CREATE INDEX stocks_sentiment_analysis_p9_stock_id_updated_at_idx ON transform_db.stocks_sentiment_analysis_p9 USING btree (stock_id, updated_at);


--
-- Name: chatroom_stocks_news_chat_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p0_pkey;


--
-- Name: chatroom_stocks_news_chat_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p1_pkey;


--
-- Name: chatroom_stocks_news_chat_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p2_pkey;


--
-- Name: chatroom_stocks_news_chat_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p3_pkey;


--
-- Name: chatroom_stocks_news_chat_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p4_pkey;


--
-- Name: chatroom_stocks_news_chat_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p5_pkey;


--
-- Name: chatroom_stocks_news_chat_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p6_pkey;


--
-- Name: chatroom_stocks_news_chat_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p7_pkey;


--
-- Name: chatroom_stocks_news_chat_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p8_pkey;


--
-- Name: chatroom_stocks_news_chat_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.chatroom_stocks_news_chat_pkey ATTACH PARTITION ingest_db.chatroom_stocks_news_chat_p9_pkey;


--
-- Name: instrument_prices_p0_instrument_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_uniq ATTACH PARTITION ingest_db.instrument_prices_p0_instrument_id_price_date_key;


--
-- Name: instrument_prices_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_pkey ATTACH PARTITION ingest_db.instrument_prices_p0_pkey;


--
-- Name: instrument_prices_p1_instrument_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_uniq ATTACH PARTITION ingest_db.instrument_prices_p1_instrument_id_price_date_key;


--
-- Name: instrument_prices_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_pkey ATTACH PARTITION ingest_db.instrument_prices_p1_pkey;


--
-- Name: instrument_prices_p2_instrument_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_uniq ATTACH PARTITION ingest_db.instrument_prices_p2_instrument_id_price_date_key;


--
-- Name: instrument_prices_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_pkey ATTACH PARTITION ingest_db.instrument_prices_p2_pkey;


--
-- Name: instrument_prices_p3_instrument_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_uniq ATTACH PARTITION ingest_db.instrument_prices_p3_instrument_id_price_date_key;


--
-- Name: instrument_prices_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_pkey ATTACH PARTITION ingest_db.instrument_prices_p3_pkey;


--
-- Name: instrument_prices_p4_instrument_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_uniq ATTACH PARTITION ingest_db.instrument_prices_p4_instrument_id_price_date_key;


--
-- Name: instrument_prices_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.instrument_prices_pkey ATTACH PARTITION ingest_db.instrument_prices_p4_pkey;


--
-- Name: stocks_company_report_sections_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p0_pkey;


--
-- Name: stocks_company_report_sections_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p1_pkey;


--
-- Name: stocks_company_report_sections_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p2_pkey;


--
-- Name: stocks_company_report_sections_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p3_pkey;


--
-- Name: stocks_company_report_sections_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p4_pkey;


--
-- Name: stocks_company_report_sections_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p5_pkey;


--
-- Name: stocks_company_report_sections_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p6_pkey;


--
-- Name: stocks_company_report_sections_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p7_pkey;


--
-- Name: stocks_company_report_sections_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p8_pkey;


--
-- Name: stocks_company_report_sections_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_report_sections_pkey ATTACH PARTITION ingest_db.stocks_company_report_sections_p9_pkey;


--
-- Name: stocks_company_reports_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p0_pkey;


--
-- Name: stocks_company_reports_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p1_pkey;


--
-- Name: stocks_company_reports_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p2_pkey;


--
-- Name: stocks_company_reports_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p3_pkey;


--
-- Name: stocks_company_reports_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p4_pkey;


--
-- Name: stocks_company_reports_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p5_pkey;


--
-- Name: stocks_company_reports_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p6_pkey;


--
-- Name: stocks_company_reports_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p7_pkey;


--
-- Name: stocks_company_reports_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p8_pkey;


--
-- Name: stocks_company_reports_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_reports_pkey ATTACH PARTITION ingest_db.stocks_company_reports_p9_pkey;


--
-- Name: stocks_company_transcript_sections_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p0_pkey;


--
-- Name: stocks_company_transcript_sections_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p1_pkey;


--
-- Name: stocks_company_transcript_sections_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p2_pkey;


--
-- Name: stocks_company_transcript_sections_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p3_pkey;


--
-- Name: stocks_company_transcript_sections_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p4_pkey;


--
-- Name: stocks_company_transcript_sections_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p5_pkey;


--
-- Name: stocks_company_transcript_sections_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p6_pkey;


--
-- Name: stocks_company_transcript_sections_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p7_pkey;


--
-- Name: stocks_company_transcript_sections_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p8_pkey;


--
-- Name: stocks_company_transcript_sections_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_sections_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_sections_p9_pkey;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx1;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx2;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx3;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx4;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx5;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx6;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx7;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx8;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_p_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_p_idx9;


--
-- Name: stocks_company_transcript_sou_stock_id_document_category_pu_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_category_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_category_pu_idx;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx1;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx2;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx3;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx4;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx5;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx6;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx7;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx8;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publi_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publi_idx9;


--
-- Name: stocks_company_transcript_sou_stock_id_document_type_publis_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_type_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_document_type_publis_idx;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx1;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx2;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx3;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx4;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx5;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx6;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx7;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx8;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_p_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_p_idx9;


--
-- Name: stocks_company_transcript_sou_stock_id_normalized_source_pd_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_url_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_normalized_source_pd_idx;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx1;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx2;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx3;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx4;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx5;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx6;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx7;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx8;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_ty_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_ty_idx9;


--
-- Name: stocks_company_transcript_sou_stock_id_reporting_period_typ_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_reporting_idx ATTACH PARTITION ingest_db.stocks_company_transcript_sou_stock_id_reporting_period_typ_idx;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx1;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx2;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx3;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx4;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx5;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx6;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx7;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx8;


--
-- Name: stocks_company_transcript_source_do_stock_id_source_pdf_id_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_do_stock_id_source_pdf_id_idx9;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx1;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx2; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx2;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx3; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx3;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx4; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx4;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx5; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx5;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx6; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx6;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx7; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx7;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx8; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx8;


--
-- Name: stocks_company_transcript_source_doc_stock_id_published_at_idx9; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_published_at_idx9;


--
-- Name: stocks_company_transcript_source_doc_stock_id_source_pdf_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_stock_pdf_id_uidx ATTACH PARTITION ingest_db.stocks_company_transcript_source_doc_stock_id_source_pdf_id_idx;


--
-- Name: stocks_company_transcript_source_docu_stock_id_published_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_published_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_docu_stock_id_published_at_idx;


--
-- Name: stocks_company_transcript_source_documents_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p0_pkey;


--
-- Name: stocks_company_transcript_source_documents_p0_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p0_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p1_pkey;


--
-- Name: stocks_company_transcript_source_documents_p1_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p1_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p2_pkey;


--
-- Name: stocks_company_transcript_source_documents_p2_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p2_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p3_pkey;


--
-- Name: stocks_company_transcript_source_documents_p3_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p3_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p4_pkey;


--
-- Name: stocks_company_transcript_source_documents_p4_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p4_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p5_pkey;


--
-- Name: stocks_company_transcript_source_documents_p5_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p5_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p6_pkey;


--
-- Name: stocks_company_transcript_source_documents_p6_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p6_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p7_pkey;


--
-- Name: stocks_company_transcript_source_documents_p7_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p7_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p8_pkey;


--
-- Name: stocks_company_transcript_source_documents_p8_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p8_transcript_id_idx;


--
-- Name: stocks_company_transcript_source_documents_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_pkey ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p9_pkey;


--
-- Name: stocks_company_transcript_source_documents_p9_transcript_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcript_source_documents_transcript_idx ATTACH PARTITION ingest_db.stocks_company_transcript_source_documents_p9_transcript_id_idx;


--
-- Name: stocks_company_transcripts_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p0_pkey;


--
-- Name: stocks_company_transcripts_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p1_pkey;


--
-- Name: stocks_company_transcripts_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p2_pkey;


--
-- Name: stocks_company_transcripts_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p3_pkey;


--
-- Name: stocks_company_transcripts_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p4_pkey;


--
-- Name: stocks_company_transcripts_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p5_pkey;


--
-- Name: stocks_company_transcripts_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p6_pkey;


--
-- Name: stocks_company_transcripts_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p7_pkey;


--
-- Name: stocks_company_transcripts_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p8_pkey;


--
-- Name: stocks_company_transcripts_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_company_transcripts_pkey ATTACH PARTITION ingest_db.stocks_company_transcripts_p9_pkey;


--
-- Name: stocks_events_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p0_pkey;


--
-- Name: stocks_events_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p1_pkey;


--
-- Name: stocks_events_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p2_pkey;


--
-- Name: stocks_events_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p3_pkey;


--
-- Name: stocks_events_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p4_pkey;


--
-- Name: stocks_events_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p5_pkey;


--
-- Name: stocks_events_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p6_pkey;


--
-- Name: stocks_events_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p7_pkey;


--
-- Name: stocks_events_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p8_pkey;


--
-- Name: stocks_events_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_events_pkey ATTACH PARTITION ingest_db.stocks_events_p9_pkey;


--
-- Name: stocks_fundamentals_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p0_pkey;


--
-- Name: stocks_fundamentals_p0_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p0_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p1_pkey;


--
-- Name: stocks_fundamentals_p1_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p1_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p2_pkey;


--
-- Name: stocks_fundamentals_p2_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p2_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p3_pkey;


--
-- Name: stocks_fundamentals_p3_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p3_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p4_pkey;


--
-- Name: stocks_fundamentals_p4_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p4_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p5_pkey;


--
-- Name: stocks_fundamentals_p5_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p5_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p6_pkey;


--
-- Name: stocks_fundamentals_p6_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p6_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p7_pkey;


--
-- Name: stocks_fundamentals_p7_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p7_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p8_pkey;


--
-- Name: stocks_fundamentals_p8_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p8_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_fundamentals_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_pkey ATTACH PARTITION ingest_db.stocks_fundamentals_p9_pkey;


--
-- Name: stocks_fundamentals_p9_stock_id_metric_category_metric_type_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_fundamentals_uniq ATTACH PARTITION ingest_db.stocks_fundamentals_p9_stock_id_metric_category_metric_type_key;


--
-- Name: stocks_market_alerts_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p0_pkey;


--
-- Name: stocks_market_alerts_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p1_pkey;


--
-- Name: stocks_market_alerts_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p2_pkey;


--
-- Name: stocks_market_alerts_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p3_pkey;


--
-- Name: stocks_market_alerts_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p4_pkey;


--
-- Name: stocks_market_alerts_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p5_pkey;


--
-- Name: stocks_market_alerts_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p6_pkey;


--
-- Name: stocks_market_alerts_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p7_pkey;


--
-- Name: stocks_market_alerts_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p8_pkey;


--
-- Name: stocks_market_alerts_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_alerts_pkey ATTACH PARTITION ingest_db.stocks_market_alerts_p9_pkey;


--
-- Name: stocks_market_news_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p0_pkey;


--
-- Name: stocks_market_news_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p1_pkey;


--
-- Name: stocks_market_news_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p2_pkey;


--
-- Name: stocks_market_news_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p3_pkey;


--
-- Name: stocks_market_news_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p4_pkey;


--
-- Name: stocks_market_news_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p5_pkey;


--
-- Name: stocks_market_news_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p6_pkey;


--
-- Name: stocks_market_news_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p7_pkey;


--
-- Name: stocks_market_news_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p8_pkey;


--
-- Name: stocks_market_news_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_market_news_pkey ATTACH PARTITION ingest_db.stocks_market_news_p9_pkey;


--
-- Name: stocks_metrics_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p0_pkey;


--
-- Name: stocks_metrics_p0_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p0_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p1_pkey;


--
-- Name: stocks_metrics_p1_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p1_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p2_pkey;


--
-- Name: stocks_metrics_p2_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p2_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p3_pkey;


--
-- Name: stocks_metrics_p3_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p3_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p4_pkey;


--
-- Name: stocks_metrics_p4_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p4_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p5_pkey;


--
-- Name: stocks_metrics_p5_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p5_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p6_pkey;


--
-- Name: stocks_metrics_p6_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p6_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p7_pkey;


--
-- Name: stocks_metrics_p7_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p7_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p8_pkey;


--
-- Name: stocks_metrics_p8_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p8_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_metrics_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_pkey ATTACH PARTITION ingest_db.stocks_metrics_p9_pkey;


--
-- Name: stocks_metrics_p9_stock_id_metric_id_snapshot_timestamp_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_metrics_stock_id_metric_id_snapshot_timestamp_key ATTACH PARTITION ingest_db.stocks_metrics_p9_stock_id_metric_id_snapshot_timestamp_key;


--
-- Name: stocks_price_data_p0_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p0_pkey;


--
-- Name: stocks_price_data_p0_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p0_price_date_idx;


--
-- Name: stocks_price_data_p0_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p0_price_date_idx1;


--
-- Name: stocks_price_data_p0_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p0_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p0_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p0_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p0_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p0_stock_id_idx;


--
-- Name: stocks_price_data_p0_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p0_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p0_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p0_stock_id_price_date_key;


--
-- Name: stocks_price_data_p1_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p1_pkey;


--
-- Name: stocks_price_data_p1_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p1_price_date_idx;


--
-- Name: stocks_price_data_p1_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p1_price_date_idx1;


--
-- Name: stocks_price_data_p1_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p1_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p1_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p1_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p1_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p1_stock_id_idx;


--
-- Name: stocks_price_data_p1_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p1_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p1_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p1_stock_id_price_date_key;


--
-- Name: stocks_price_data_p2_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p2_pkey;


--
-- Name: stocks_price_data_p2_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p2_price_date_idx;


--
-- Name: stocks_price_data_p2_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p2_price_date_idx1;


--
-- Name: stocks_price_data_p2_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p2_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p2_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p2_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p2_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p2_stock_id_idx;


--
-- Name: stocks_price_data_p2_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p2_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p2_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p2_stock_id_price_date_key;


--
-- Name: stocks_price_data_p3_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p3_pkey;


--
-- Name: stocks_price_data_p3_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p3_price_date_idx;


--
-- Name: stocks_price_data_p3_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p3_price_date_idx1;


--
-- Name: stocks_price_data_p3_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p3_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p3_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p3_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p3_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p3_stock_id_idx;


--
-- Name: stocks_price_data_p3_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p3_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p3_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p3_stock_id_price_date_key;


--
-- Name: stocks_price_data_p4_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p4_pkey;


--
-- Name: stocks_price_data_p4_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p4_price_date_idx;


--
-- Name: stocks_price_data_p4_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p4_price_date_idx1;


--
-- Name: stocks_price_data_p4_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p4_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p4_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p4_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p4_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p4_stock_id_idx;


--
-- Name: stocks_price_data_p4_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p4_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p4_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p4_stock_id_price_date_key;


--
-- Name: stocks_price_data_p5_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p5_pkey;


--
-- Name: stocks_price_data_p5_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p5_price_date_idx;


--
-- Name: stocks_price_data_p5_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p5_price_date_idx1;


--
-- Name: stocks_price_data_p5_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p5_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p5_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p5_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p5_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p5_stock_id_idx;


--
-- Name: stocks_price_data_p5_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p5_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p5_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p5_stock_id_price_date_key;


--
-- Name: stocks_price_data_p6_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p6_pkey;


--
-- Name: stocks_price_data_p6_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p6_price_date_idx;


--
-- Name: stocks_price_data_p6_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p6_price_date_idx1;


--
-- Name: stocks_price_data_p6_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p6_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p6_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p6_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p6_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p6_stock_id_idx;


--
-- Name: stocks_price_data_p6_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p6_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p6_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p6_stock_id_price_date_key;


--
-- Name: stocks_price_data_p7_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p7_pkey;


--
-- Name: stocks_price_data_p7_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p7_price_date_idx;


--
-- Name: stocks_price_data_p7_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p7_price_date_idx1;


--
-- Name: stocks_price_data_p7_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p7_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p7_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p7_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p7_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p7_stock_id_idx;


--
-- Name: stocks_price_data_p7_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p7_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p7_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p7_stock_id_price_date_key;


--
-- Name: stocks_price_data_p8_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p8_pkey;


--
-- Name: stocks_price_data_p8_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p8_price_date_idx;


--
-- Name: stocks_price_data_p8_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p8_price_date_idx1;


--
-- Name: stocks_price_data_p8_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p8_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p8_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p8_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p8_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p8_stock_id_idx;


--
-- Name: stocks_price_data_p8_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p8_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p8_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p8_stock_id_price_date_key;


--
-- Name: stocks_price_data_p9_pkey; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_pkey ATTACH PARTITION ingest_db.stocks_price_data_p9_pkey;


--
-- Name: stocks_price_data_p9_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p9_price_date_idx;


--
-- Name: stocks_price_data_p9_price_date_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_stocks_price_data_date ATTACH PARTITION ingest_db.stocks_price_data_p9_price_date_idx1;


--
-- Name: stocks_price_data_p9_stock_id_captured_at_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uidx ATTACH PARTITION ingest_db.stocks_price_data_p9_stock_id_captured_at_idx;


--
-- Name: stocks_price_data_p9_stock_id_captured_at_idx1; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_captured_at_idx ATTACH PARTITION ingest_db.stocks_price_data_p9_stock_id_captured_at_idx1;


--
-- Name: stocks_price_data_p9_stock_id_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.idx_price_latest_stock ATTACH PARTITION ingest_db.stocks_price_data_p9_stock_id_idx;


--
-- Name: stocks_price_data_p9_stock_id_price_date_idx; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_stock_id_price_date_idx ATTACH PARTITION ingest_db.stocks_price_data_p9_stock_id_price_date_idx;


--
-- Name: stocks_price_data_p9_stock_id_price_date_key; Type: INDEX ATTACH; Schema: ingest_db; Owner: -
--

ALTER INDEX ingest_db.stocks_price_data_uniq ATTACH PARTITION ingest_db.stocks_price_data_p9_stock_id_price_date_key;


--
-- Name: stocks_message_sentiments_p0_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p0_pkey;


--
-- Name: stocks_message_sentiments_p0_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p0_session_idx;


--
-- Name: stocks_message_sentiments_p1_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p1_pkey;


--
-- Name: stocks_message_sentiments_p1_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p1_session_idx;


--
-- Name: stocks_message_sentiments_p2_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p2_pkey;


--
-- Name: stocks_message_sentiments_p2_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p2_session_idx;


--
-- Name: stocks_message_sentiments_p3_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p3_pkey;


--
-- Name: stocks_message_sentiments_p3_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p3_session_idx;


--
-- Name: stocks_message_sentiments_p4_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p4_pkey;


--
-- Name: stocks_message_sentiments_p4_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p4_session_idx;


--
-- Name: stocks_message_sentiments_p5_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p5_pkey;


--
-- Name: stocks_message_sentiments_p5_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p5_session_idx;


--
-- Name: stocks_message_sentiments_p6_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p6_pkey;


--
-- Name: stocks_message_sentiments_p6_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p6_session_idx;


--
-- Name: stocks_message_sentiments_p7_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p7_pkey;


--
-- Name: stocks_message_sentiments_p7_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p7_session_idx;


--
-- Name: stocks_message_sentiments_p8_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p8_pkey;


--
-- Name: stocks_message_sentiments_p8_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p8_session_idx;


--
-- Name: stocks_message_sentiments_p9_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_message_sentiments_pkey ATTACH PARTITION transform_db.stocks_message_sentiments_p9_pkey;


--
-- Name: stocks_message_sentiments_p9_session_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sms_session ATTACH PARTITION transform_db.stocks_message_sentiments_p9_session_idx;


--
-- Name: stocks_sentiment_analysis_p0_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p0_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0_pkey;


--
-- Name: stocks_sentiment_analysis_p0_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p0_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p0_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p0_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p1_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p1_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1_pkey;


--
-- Name: stocks_sentiment_analysis_p1_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p1_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p1_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p1_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p2_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p2_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2_pkey;


--
-- Name: stocks_sentiment_analysis_p2_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p2_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p2_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p2_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p3_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p3_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3_pkey;


--
-- Name: stocks_sentiment_analysis_p3_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p3_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p3_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p3_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p4_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p4_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4_pkey;


--
-- Name: stocks_sentiment_analysis_p4_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p4_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p4_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p4_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p5_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p5_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5_pkey;


--
-- Name: stocks_sentiment_analysis_p5_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p5_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p5_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p5_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p6_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p6_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6_pkey;


--
-- Name: stocks_sentiment_analysis_p6_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p6_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p6_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p6_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p7_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p7_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7_pkey;


--
-- Name: stocks_sentiment_analysis_p7_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p7_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p7_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p7_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p8_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p8_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8_pkey;


--
-- Name: stocks_sentiment_analysis_p8_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p8_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p8_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p8_stock_id_updated_at_idx;


--
-- Name: stocks_sentiment_analysis_p9_analysis_id_stock_id_key; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_analysis_id ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9_analysis_id_stock_id_key;


--
-- Name: stocks_sentiment_analysis_p9_pkey; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.stocks_sentiment_analysis_pkey ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9_pkey;


--
-- Name: stocks_sentiment_analysis_p9_stock_id_analyzed_at_analyzed__idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.uniq_daily_agg_stock_date_by ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9_stock_id_analyzed_at_analyzed__idx;


--
-- Name: stocks_sentiment_analysis_p9_stock_id_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_sentiment_latest_stock ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9_stock_id_idx;


--
-- Name: stocks_sentiment_analysis_p9_stock_id_updated_at_idx; Type: INDEX ATTACH; Schema: transform_db; Owner: -
--

ALTER INDEX transform_db.idx_daily_agg_updated_at ATTACH PARTITION transform_db.stocks_sentiment_analysis_p9_stock_id_updated_at_idx;


--
-- Name: stock_ingestion_events trg_enqueue_stock_ingestion_event_outbox; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_enqueue_stock_ingestion_event_outbox AFTER INSERT ON ingest_db.stock_ingestion_events FOR EACH ROW EXECUTE FUNCTION ingest_db.fn_enqueue_stock_ingestion_event_outbox();


--
-- Name: stocks_events trg_index_events; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_index_events AFTER INSERT OR UPDATE ON ingest_db.stocks_events FOR EACH ROW EXECUTE FUNCTION indexing_state.notify_indexer();


--
-- Name: stocks_market_news trg_index_news; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_index_news AFTER INSERT OR UPDATE ON ingest_db.stocks_market_news FOR EACH ROW EXECUTE FUNCTION indexing_state.notify_indexer();


--
-- Name: stocks_company_transcripts trg_index_transcripts; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_index_transcripts AFTER INSERT OR UPDATE ON ingest_db.stocks_company_transcripts FOR EACH ROW EXECUTE FUNCTION indexing_state.notify_indexer();


--
-- Name: portfolio_stocks trg_portfolio_stocks_fill_country_metadata; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_portfolio_stocks_fill_country_metadata BEFORE INSERT OR UPDATE OF stock_id, country_name, country_name_display, currency_code ON ingest_db.portfolio_stocks FOR EACH ROW EXECUTE FUNCTION ingest_db.portfolio_stocks_fill_country_metadata();


--
-- Name: stocks_earnings_outlook trg_stocks_earnings_outlook_fill_canonical_ticker; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_stocks_earnings_outlook_fill_canonical_ticker BEFORE INSERT OR UPDATE OF stock_id, ticker ON ingest_db.stocks_earnings_outlook FOR EACH ROW EXECUTE FUNCTION ingest_db.fill_canonical_ticker_from_stock();


--
-- Name: stocks_events trg_stocks_events_fill_canonical_ticker; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_stocks_events_fill_canonical_ticker BEFORE INSERT OR UPDATE OF stock_id, ticker ON ingest_db.stocks_events FOR EACH ROW EXECUTE FUNCTION ingest_db.fill_canonical_ticker_from_stock();


--
-- Name: stocks trg_stocks_fill_canonical_columns; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_stocks_fill_canonical_columns BEFORE INSERT OR UPDATE OF ticker, exchange, country_name ON ingest_db.stocks FOR EACH ROW EXECUTE FUNCTION ingest_db.stocks_fill_canonical_columns();


--
-- Name: stocks_indicators trg_stocks_indicators_fill_canonical_ticker; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_stocks_indicators_fill_canonical_ticker BEFORE INSERT OR UPDATE OF stock_id, ticker ON ingest_db.stocks_indicators FOR EACH ROW EXECUTE FUNCTION ingest_db.fill_canonical_ticker_from_stock();


--
-- Name: stocks_upcoming_earnings trg_stocks_upcoming_earnings_fill_canonical_ticker; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_stocks_upcoming_earnings_fill_canonical_ticker BEFORE INSERT OR UPDATE OF stock_id, ticker ON ingest_db.stocks_upcoming_earnings FOR EACH ROW EXECUTE FUNCTION ingest_db.fill_canonical_ticker_from_stock();


--
-- Name: ticker_list trg_ticker_list_fill_canonical_columns; Type: TRIGGER; Schema: ingest_db; Owner: -
--

CREATE TRIGGER trg_ticker_list_fill_canonical_columns BEFORE INSERT OR UPDATE OF symbol, exchange_code, country, data_source, provider_name, provider_symbol, provider_exchange_code ON ingest_db.ticker_list FOR EACH ROW EXECUTE FUNCTION ingest_db.ticker_list_fill_canonical_columns();


--
-- Name: stocks_message_sentiments trg_index_sentiments; Type: TRIGGER; Schema: transform_db; Owner: -
--

CREATE TRIGGER trg_index_sentiments AFTER INSERT OR UPDATE ON transform_db.stocks_message_sentiments FOR EACH ROW EXECUTE FUNCTION indexing_state.notify_indexer();


--
-- Name: chatroom_ai_chat_interactions chatroom_ai_chat_interactions_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.chatroom_ai_chat_interactions
    ADD CONSTRAINT chatroom_ai_chat_interactions_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: chatroom_stocks_news_chat chatroom_stocks_news_chat_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.chatroom_stocks_news_chat
    ADD CONSTRAINT chatroom_stocks_news_chat_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: company_executive_summary company_executive_summary_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_executive_summary
    ADD CONSTRAINT company_executive_summary_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: company_growth_history company_growth_history_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_growth_history
    ADD CONSTRAINT company_growth_history_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: company_insider_trading company_insider_trading_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_insider_trading
    ADD CONSTRAINT company_insider_trading_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: company_profile company_profile_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.company_profile
    ADD CONSTRAINT company_profile_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: pipeline_ingestion_files fk_pif_stock; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_ingestion_files
    ADD CONSTRAINT fk_pif_stock FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: pipeline_ingestion_file_csv_ids fk_pifci_file; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_ingestion_file_csv_ids
    ADD CONSTRAINT fk_pifci_file FOREIGN KEY (filename) REFERENCES ingest_db.pipeline_ingestion_files(filename) ON DELETE CASCADE;


--
-- Name: portfolio fk_portfolio_user; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio
    ADD CONSTRAINT fk_portfolio_user FOREIGN KEY (user_id) REFERENCES ingest_db.users(user_id) ON DELETE CASCADE;


--
-- Name: pipeline_sentiment_dates fk_psd_stock; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_sentiment_dates
    ADD CONSTRAINT fk_psd_stock FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: pipeline_sentiment_processed_ids fk_psp_stock; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.pipeline_sentiment_processed_ids
    ADD CONSTRAINT fk_psp_stock FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stock_ingestion_jobs fk_sij_request_id; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_jobs
    ADD CONSTRAINT fk_sij_request_id FOREIGN KEY (request_id) REFERENCES ingest_db.stock_ingestion_requests(request_id);


--
-- Name: industry_average_metric_values industry_average_metric_values_metric_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.industry_average_metric_values
    ADD CONSTRAINT industry_average_metric_values_metric_id_fkey FOREIGN KEY (metric_id) REFERENCES ingest_db.stocks_metric_types(metric_id) ON DELETE CASCADE;


--
-- Name: industry_metric_reference industry_metric_reference_metric_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.industry_metric_reference
    ADD CONSTRAINT industry_metric_reference_metric_id_fkey FOREIGN KEY (metric_id) REFERENCES ingest_db.stocks_metric_types(metric_id) ON DELETE CASCADE;


--
-- Name: instrument_prices instrument_prices_instrument_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.instrument_prices
    ADD CONSTRAINT instrument_prices_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES ingest_db.instruments(instrument_id);


--
-- Name: portfolio_stocks portfolio_stocks_portfolio_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio_stocks
    ADD CONSTRAINT portfolio_stocks_portfolio_id_fkey FOREIGN KEY (portfolio_id) REFERENCES ingest_db.portfolio(portfolio_id) ON DELETE CASCADE;


--
-- Name: portfolio_stocks portfolio_stocks_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.portfolio_stocks
    ADD CONSTRAINT portfolio_stocks_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: research_copilot_user_prompts research_copilot_user_prompts_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.research_copilot_user_prompts
    ADD CONSTRAINT research_copilot_user_prompts_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stock_copilot_chat_history stock_copilot_chat_history_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_copilot_chat_history
    ADD CONSTRAINT stock_copilot_chat_history_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stock_ingestion_event_outbox stock_ingestion_event_outbox_event_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_ingestion_event_outbox
    ADD CONSTRAINT stock_ingestion_event_outbox_event_id_fkey FOREIGN KEY (event_id) REFERENCES ingest_db.stock_ingestion_events(event_id);


--
-- Name: stock_peers stock_peers_peer_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_peers
    ADD CONSTRAINT stock_peers_peer_stock_id_fkey FOREIGN KEY (peer_stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stock_peers stock_peers_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stock_peers
    ADD CONSTRAINT stock_peers_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_benchmark_mapping stocks_benchmark_mapping_instrument_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_benchmark_mapping
    ADD CONSTRAINT stocks_benchmark_mapping_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES ingest_db.instruments(instrument_id) ON DELETE CASCADE;


--
-- Name: stocks_benchmark_mapping stocks_benchmark_mapping_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_benchmark_mapping
    ADD CONSTRAINT stocks_benchmark_mapping_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_company_reports stocks_company_reports_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_reports
    ADD CONSTRAINT stocks_company_reports_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_company_transcript_source_documents stocks_company_transcript_source_documents_stock_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcript_source_documents
    ADD CONSTRAINT stocks_company_transcript_source_documents_stock_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_company_transcript_source_documents stocks_company_transcript_source_documents_transcript_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcript_source_documents
    ADD CONSTRAINT stocks_company_transcript_source_documents_transcript_fkey FOREIGN KEY (transcript_id, stock_id) REFERENCES ingest_db.stocks_company_transcripts(transcript_id, stock_id) ON DELETE CASCADE;


--
-- Name: stocks_company_transcripts stocks_company_transcripts_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_company_transcripts
    ADD CONSTRAINT stocks_company_transcripts_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_earnings_calendar stocks_earnings_calendar_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_earnings_calendar
    ADD CONSTRAINT stocks_earnings_calendar_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_earnings_outlook stocks_earnings_outlook_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_earnings_outlook
    ADD CONSTRAINT stocks_earnings_outlook_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_events stocks_events_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_events
    ADD CONSTRAINT stocks_events_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_flags stocks_flags_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_flags
    ADD CONSTRAINT stocks_flags_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_fundamentals stocks_fundamentals_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_fundamentals
    ADD CONSTRAINT stocks_fundamentals_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_indicators stocks_indicators_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_indicators
    ADD CONSTRAINT stocks_indicators_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_market_alerts stocks_market_alerts_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_market_alerts
    ADD CONSTRAINT stocks_market_alerts_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_market_news stocks_market_news_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_market_news
    ADD CONSTRAINT stocks_market_news_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_metrics stocks_metrics_metric_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_metrics
    ADD CONSTRAINT stocks_metrics_metric_id_fkey FOREIGN KEY (metric_id) REFERENCES ingest_db.stocks_metric_types(metric_id) ON DELETE CASCADE;


--
-- Name: stocks_metrics stocks_metrics_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_metrics
    ADD CONSTRAINT stocks_metrics_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_price_data stocks_price_data_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ingest_db.stocks_price_data
    ADD CONSTRAINT stocks_price_data_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_upcoming_earnings stocks_upcoming_earnings_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_upcoming_earnings
    ADD CONSTRAINT stocks_upcoming_earnings_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_upcoming_events stocks_upcoming_events_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_upcoming_events
    ADD CONSTRAINT stocks_upcoming_events_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_watchlist stocks_watchlist_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_watchlist
    ADD CONSTRAINT stocks_watchlist_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_word_cloud_metrics stocks_word_cloud_metrics_stock_id_fkey; Type: FK CONSTRAINT; Schema: ingest_db; Owner: -
--

ALTER TABLE ONLY ingest_db.stocks_word_cloud_metrics
    ADD CONSTRAINT stocks_word_cloud_metrics_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: market_summary market_summary_market_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.market_summary
    ADD CONSTRAINT market_summary_market_id_fkey FOREIGN KEY (market_id) REFERENCES ingest_db.market(market_id) ON DELETE CASCADE;


--
-- Name: market_summary market_summary_user_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.market_summary
    ADD CONSTRAINT market_summary_user_id_fkey FOREIGN KEY (user_id) REFERENCES ingest_db.users(user_id) ON DELETE CASCADE;


--
-- Name: portfolio_ai_analysis portfolio_ai_analysis_portfolio_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.portfolio_ai_analysis
    ADD CONSTRAINT portfolio_ai_analysis_portfolio_id_fkey FOREIGN KEY (portfolio_id) REFERENCES ingest_db.portfolio(portfolio_id) ON DELETE CASCADE;


--
-- Name: portfolio_ai_analysis portfolio_ai_analysis_user_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.portfolio_ai_analysis
    ADD CONSTRAINT portfolio_ai_analysis_user_id_fkey FOREIGN KEY (user_id) REFERENCES ingest_db.users(user_id) ON DELETE CASCADE;


--
-- Name: research_copilot_prompt_suggestions research_copilot_prompt_suggestions_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_prompt_suggestions
    ADD CONSTRAINT research_copilot_prompt_suggestions_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: research_copilot_report_sharing research_copilot_report_sharing_report_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_report_sharing
    ADD CONSTRAINT research_copilot_report_sharing_report_id_fkey FOREIGN KEY (report_id) REFERENCES transform_db.research_copilot_reports(report_id) ON DELETE CASCADE;


--
-- Name: research_copilot_reports research_copilot_reports_prompt_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.research_copilot_reports
    ADD CONSTRAINT research_copilot_reports_prompt_id_fkey FOREIGN KEY (prompt_id) REFERENCES ingest_db.research_copilot_user_prompts(prompt_id) ON DELETE CASCADE;


--
-- Name: stocks_driver_analysis stocks_driver_analysis_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_driver_analysis
    ADD CONSTRAINT stocks_driver_analysis_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_events_messages_correlation stocks_events_messages_correlation_event_id_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_events_messages_correlation
    ADD CONSTRAINT stocks_events_messages_correlation_event_id_stock_id_fkey FOREIGN KEY (event_id, stock_id) REFERENCES ingest_db.stocks_events(event_id, stock_id) ON DELETE CASCADE;


--
-- Name: stocks_fundamentals_ai_analysis stocks_fundamentals_ai_analysis_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_fundamentals_ai_analysis
    ADD CONSTRAINT stocks_fundamentals_ai_analysis_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_insights_ai_summary stocks_insights_ai_summary_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.stocks_insights_ai_summary
    ADD CONSTRAINT stocks_insights_ai_summary_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: stocks_sentiment_analysis stocks_sentiment_analysis_stock_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE transform_db.stocks_sentiment_analysis
    ADD CONSTRAINT stocks_sentiment_analysis_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES ingest_db.stocks(stock_id) ON DELETE CASCADE;


--
-- Name: user_to_market_mapping user_to_market_mapping_user_id_fkey; Type: FK CONSTRAINT; Schema: transform_db; Owner: -
--

ALTER TABLE ONLY transform_db.user_to_market_mapping
    ADD CONSTRAINT user_to_market_mapping_user_id_fkey FOREIGN KEY (user_id) REFERENCES ingest_db.users(user_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict zd9204sNeatcb6Xm0WliN9Nan7R5ZyjCRa8zPFNyA730UP1abaPOVrrx3J88h1k

