-- Baseline migration: full public schema as of 2026-05-19
-- Captures the state after all 10 applied migrations.
-- This file is safe to run on a fresh database.

-- ============================================================
-- SEQUENCES
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS public.events_id_seq
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE NO CYCLE;

CREATE SEQUENCE IF NOT EXISTS public.parser_failures_id_seq
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE NO CYCLE;

CREATE SEQUENCE IF NOT EXISTS public.purchases_id_seq
    START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE NO CYCLE;

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS public.tracked_wallets (
    wallet_address      text        NOT NULL,
    name                text,
    emoji               text        DEFAULT '💎'::text,
    priority_score      numeric(12,4) NOT NULL DEFAULT 0,
    confidence_score    numeric(12,4),
    wallet_tier         text,
    groups              text[]      DEFAULT ARRAY['Main'::text],
    source              text        DEFAULT 'manual'::text,
    added_at            timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    is_active           boolean     NOT NULL DEFAULT true,
    notes               text,
    alert_on_bubble     text,
    alert_on_feed       text,
    alert_sound         text,
    alert_on_toast      text,
    CONSTRAINT tracked_wallets_pkey PRIMARY KEY (wallet_address),
    CONSTRAINT tracked_wallets_wallet_address_not_blank
        CHECK (length(TRIM(BOTH FROM wallet_address)) > 0)
);
COMMENT ON TABLE public.tracked_wallets IS 'Tracked wallets used by wallet_event_ingestor.py';

CREATE TABLE IF NOT EXISTS public.events (
    id              bigint      NOT NULL DEFAULT nextval('public.events_id_seq'::regclass),
    event_source    text        NOT NULL,
    event_type      text        NOT NULL,
    signature       text,
    wallet_address  text,
    occurred_at     timestamptz NOT NULL,
    ingested_at     timestamptz NOT NULL DEFAULT now(),
    token_mint      text,
    token_symbol    text,
    action          text,
    amount_sol      numeric(38,12),
    amount_token    numeric(38,18),
    price_per_token numeric(38,18),
    dedupe_key      text,
    source_ref      text,
    metadata        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT events_pkey PRIMARY KEY (id),
    CONSTRAINT events_event_source_valid
        CHECK (event_source = ANY (ARRAY[
            'wallet_trade'::text, 'alpha_mention'::text, 'telegram_signal'::text,
            'system'::text, 'manual'::text
        ])),
    CONSTRAINT events_event_type_not_blank
        CHECK (length(TRIM(BOTH FROM event_type)) > 0),
    CONSTRAINT events_action_valid
        CHECK (action IS NULL OR action = ANY (ARRAY['buy'::text, 'sell'::text])),
    CONSTRAINT events_amounts_nonnegative
        CHECK (
            (amount_sol IS NULL OR amount_sol >= 0) AND
            (amount_token IS NULL OR amount_token >= 0) AND
            (price_per_token IS NULL OR price_per_token >= 0)
        ),
    CONSTRAINT events_wallet_trade_required_fields
        CHECK (
            event_source <> 'wallet_trade'::text OR (
                signature IS NOT NULL AND
                wallet_address IS NOT NULL AND
                token_mint IS NOT NULL AND
                action IS NOT NULL
            )
        )
);
COMMENT ON TABLE public.events IS 'Unified event log for wallet trades and related intelligence events';

CREATE TABLE IF NOT EXISTS public.source_heartbeats (
    source              text        NOT NULL,
    last_event_at       timestamptz,
    last_success_at     timestamptz,
    status              text        NOT NULL DEFAULT 'healthy'::text,
    event_count_24h     bigint      NOT NULL DEFAULT 0,
    error_count_24h     bigint      NOT NULL DEFAULT 0,
    last_error_message  text,
    metadata            jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT source_heartbeats_pkey PRIMARY KEY (source),
    CONSTRAINT source_heartbeats_source_not_blank
        CHECK (length(TRIM(BOTH FROM source)) > 0),
    CONSTRAINT source_heartbeats_status_valid
        CHECK (status = ANY (ARRAY[
            'healthy'::text, 'degraded'::text, 'error'::text, 'stale'::text, 'unknown'::text
        ]))
);
COMMENT ON TABLE public.source_heartbeats IS 'Heartbeat monitor for ingestion sources such as wallet_websocket';

CREATE TABLE IF NOT EXISTS public.parser_failures (
    id              bigint      NOT NULL DEFAULT nextval('public.parser_failures_id_seq'::regclass),
    source          text        NOT NULL,
    failure_type    text        NOT NULL,
    raw_data        jsonb,
    error_message   text        NOT NULL,
    signature       text,
    wallet_address  text,
    occurred_at     timestamptz NOT NULL DEFAULT now(),
    resolved        boolean     NOT NULL DEFAULT false,
    metadata        jsonb       NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT parser_failures_pkey PRIMARY KEY (id),
    CONSTRAINT parser_failures_source_not_blank
        CHECK (length(TRIM(BOTH FROM source)) > 0),
    CONSTRAINT parser_failures_failure_type_not_blank
        CHECK (length(TRIM(BOTH FROM failure_type)) > 0)
);
COMMENT ON TABLE public.parser_failures IS 'Parser and fetch failures logged by the wallet ingestor';

CREATE TABLE IF NOT EXISTS public.purchases (
    id                      bigint          NOT NULL DEFAULT nextval('public.purchases_id_seq'::regclass),
    created_at              timestamptz     DEFAULT now(),
    updated_at              timestamptz     DEFAULT now(),
    token_address           varchar(255)    NOT NULL,
    token_symbol            varchar(20),
    token_name              varchar(255),
    decimals                integer         DEFAULT 18,
    amount                  numeric         NOT NULL,
    wallet_address          varchar(255),
    wallet_id               varchar(255),
    source                  varchar(50),
    status                  varchar(50)     DEFAULT 'pending'::character varying,
    priority                varchar(20)     DEFAULT 'normal'::character varying,
    scheduled_at            timestamptz,
    slippage_percent        numeric         DEFAULT 5,
    gas_price               numeric,
    priority_fee            numeric,
    min_liquidity           numeric,
    max_market_cap          numeric,
    max_price_impact        numeric,
    entry_price             numeric,
    actual_amount_spent     numeric,
    actual_tokens_received  numeric,
    execution_time          timestamptz,
    price_impact_percent    numeric,
    auto_sell               boolean         DEFAULT false,
    take_profit_percent     numeric,
    stop_loss_percent       numeric,
    sell_time_minutes       integer,
    gmgn_order_id           varchar(255),
    tx_hash                 varchar(255),
    profit_loss_percent     numeric,
    profit_loss_amount      numeric,
    executed_at             timestamptz,
    error_message           text,
    retry_count             integer         DEFAULT 0,
    notes                   text,
    tags                    varchar(255),
    CONSTRAINT purchases_pkey PRIMARY KEY (id)
);

-- ============================================================
-- INDEXES
-- ============================================================

-- tracked_wallets
CREATE INDEX IF NOT EXISTS idx_tracked_wallets_active_priority
    ON public.tracked_wallets (is_active, priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_tracked_wallets_groups
    ON public.tracked_wallets USING gin (groups);
CREATE INDEX IF NOT EXISTS idx_tracked_wallets_source
    ON public.tracked_wallets (source);

-- events
CREATE INDEX IF NOT EXISTS idx_events_occurred_at
    ON public.events (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_event_source_type_occurred
    ON public.events (event_source, event_type, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_wallet_occurred_at
    ON public.events (wallet_address, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_token_occurred_at
    ON public.events (token_mint, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_metadata_gin
    ON public.events USING gin (metadata);
CREATE UNIQUE INDEX IF NOT EXISTS uq_events_wallet_signature
    ON public.events (wallet_address, signature)
    WHERE event_source = 'wallet_trade' AND wallet_address IS NOT NULL AND signature IS NOT NULL;

-- source_heartbeats
CREATE INDEX IF NOT EXISTS idx_source_heartbeats_status
    ON public.source_heartbeats (status);

-- parser_failures
CREATE INDEX IF NOT EXISTS idx_parser_failures_occurred_at
    ON public.parser_failures (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_parser_failures_source_type
    ON public.parser_failures (source, failure_type, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_parser_failures_raw_data_gin
    ON public.parser_failures USING gin (raw_data);
CREATE INDEX IF NOT EXISTS idx_public_parser_failures_occurred
    ON public.parser_failures (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_public_parser_failures_source
    ON public.parser_failures (source);

-- purchases
CREATE INDEX IF NOT EXISTS idx_purchases_created_at
    ON public.purchases (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_executed_at
    ON public.purchases (executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_status
    ON public.purchases (status);
CREATE INDEX IF NOT EXISTS idx_purchases_token_address
    ON public.purchases (token_address);
CREATE INDEX IF NOT EXISTS idx_purchases_wallet_id
    ON public.purchases (wallet_id);
CREATE INDEX IF NOT EXISTS idx_purchases_source
    ON public.purchases (source);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.tracked_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parser_failures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases       ENABLE ROW LEVEL SECURITY;

-- tracked_wallets policies
CREATE POLICY anon_select ON public.tracked_wallets
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY authenticated_select ON public.tracked_wallets
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

-- events policies
CREATE POLICY anon_select ON public.events
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY authenticated_select ON public.events
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

-- source_heartbeats policies
CREATE POLICY anon_select ON public.source_heartbeats
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY authenticated_select ON public.source_heartbeats
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

-- parser_failures policies
CREATE POLICY anon_select ON public.parser_failures
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
CREATE POLICY authenticated_select ON public.parser_failures
    AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);

-- ============================================================
-- FUNCTIONS (public schema)
-- ============================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_new_purchase()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    payload JSON;
BEGIN
    payload = row_to_json(NEW);
    PERFORM pg_notify('new_purchase', payload::text);
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_purchase(
    p_token_address text,
    p_amount        numeric
)
RETURNS public.purchases LANGUAGE plpgsql AS $$
DECLARE
    v_row public.purchases;
BEGIN
    INSERT INTO public.purchases (token_address, amount)
    VALUES (p_token_address, p_amount)
    RETURNING * INTO v_row;
    RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_token_smart(
    p_raw_text       text,
    p_extraction_type text DEFAULT 'contract'::text
)
RETURNS TABLE(token_mint text, token_symbol text, confidence numeric, candidates_count integer)
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    is_valid_solana BOOLEAN;
BEGIN
    is_valid_solana := p_extraction_type = 'contract'
        AND LENGTH(p_raw_text) BETWEEN 32 AND 44
        AND p_raw_text ~ '^[A-HJ-NP-Za-km-z1-9]{32,44}$';

    IF is_valid_solana THEN
        RETURN QUERY SELECT
            p_raw_text,
            LEFT(p_raw_text, 8) || '...',
            0.95::numeric,
            1;
    ELSE
        RETURN QUERY SELECT
            NULL::TEXT,
            p_raw_text,
            0.5::numeric,
            0;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_all()
RETURNS TABLE(
    trades_synced        integer,
    positions_updated    integer,
    rolling_stats_updated integer,
    wallets_scored       integer
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT * FROM wallet_intel.refresh_all();
END;
$$;

CREATE OR REPLACE FUNCTION public.ingest_wallet_trade_event(
    p_signature       text,
    p_wallet_address  text,
    p_occurred_at     timestamptz,
    p_token_mint      text,
    p_token_symbol    text,
    p_action          text,
    p_amount_sol      numeric,
    p_amount_token    numeric,
    p_price_per_token numeric
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN wallet_intel.ingest_wallet_trade_event(
        p_signature, p_wallet_address, p_occurred_at, p_token_mint,
        p_token_symbol, p_action, p_amount_sol, p_amount_token, p_price_per_token
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.wallet_intel_counts()
RETURNS TABLE(
    wallet_trades          bigint,
    telegram_mentions      bigint,
    last_wallet_trade      timestamptz,
    last_telegram_mention  timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*) FROM wallet_intel.wallet_trade_events)::BIGINT,
        (SELECT COUNT(*) FROM wallet_intel.telegram_mentions)::BIGINT,
        (SELECT MAX(occurred_at) FROM wallet_intel.wallet_trade_events),
        (SELECT MAX(mention_timestamp) FROM wallet_intel.telegram_mentions);
END;
$$;

CREATE OR REPLACE FUNCTION public.wallet_intel_recent_trades(p_limit integer DEFAULT 10)
RETURNS TABLE(
    id             bigint,
    signature      text,
    wallet_address text,
    occurred_at    timestamptz,
    token_mint     text,
    token_symbol   text,
    action         text,
    amount_sol     numeric,
    amount_token   numeric,
    price_per_token numeric
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        wte.id, wte.signature, wte.wallet_address, wte.occurred_at,
        wte.token_mint, wte.token_symbol, wte.action::TEXT,
        wte.amount_sol, wte.amount_token, wte.price_per_token
    FROM wallet_intel.wallet_trade_events wte
    ORDER BY wte.occurred_at DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.wallet_intel_recent_mentions(p_limit integer DEFAULT 10)
RETURNS TABLE(
    id                bigint,
    token_address     text,
    mention_timestamp timestamptz,
    channel_name      text,
    conviction_score  numeric,
    quality_tier      text,
    price_at_mention  numeric,
    price_5m_after    numeric
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        tm.id, tm.token_address, tm.mention_timestamp, tm.channel_name,
        tm.conviction_score, tm.quality_tier, tm.price_at_mention, tm.price_5m_after
    FROM wallet_intel.telegram_mentions tm
    ORDER BY tm.mention_timestamp DESC
    LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.ingest_alpha_mention_event(
    p_token_mint          text,
    p_mention_timestamp   timestamptz,
    p_channel_name        text,
    p_message_id          text,
    p_mention_type        text,
    p_sentiment_score     numeric   DEFAULT 0.0,
    p_conviction_score    numeric   DEFAULT 0.5,
    p_quality_tier        text      DEFAULT 'medium'::text,
    p_unique_chat_count   integer   DEFAULT 1,
    p_mention_velocity    integer   DEFAULT 1,
    p_prior_mention_count integer   DEFAULT 0,
    p_price_at_mention    numeric   DEFAULT NULL::numeric,
    p_price_1m_after      numeric   DEFAULT NULL::numeric,
    p_price_5m_after      numeric   DEFAULT NULL::numeric,
    p_price_15m_after     numeric   DEFAULT NULL::numeric,
    p_raw_message         text      DEFAULT NULL::text
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    sig      TEXT;
    event_id BIGINT;
BEGIN
    sig := 'tg_' || MD5(p_channel_name || p_message_id || COALESCE(p_token_mint, ''));
    INSERT INTO wallet_intel.telegram_mentions (
        token_address, mention_timestamp, channel_name, message_id,
        mention_type, sentiment_score, conviction_score, quality_tier,
        unique_chat_count, mention_velocity, prior_mention_count,
        price_at_mention, price_1m_after, price_5m_after, price_15m_after, raw_message
    ) VALUES (
        p_token_mint, p_mention_timestamp, p_channel_name, p_message_id,
        p_mention_type, p_sentiment_score, p_conviction_score, p_quality_tier,
        p_unique_chat_count, p_mention_velocity, p_prior_mention_count,
        p_price_at_mention, p_price_1m_after, p_price_5m_after, p_price_15m_after, p_raw_message
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO event_id;
    RETURN COALESCE(event_id, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.ingest_alpha_mention_event(
    p_source_name             text,
    p_source_tier             text,
    p_channel_name            text,
    p_channel_id              bigint,
    p_telegram_message_id     bigint,
    p_message_timestamp       timestamptz,
    p_token_address           text,
    p_token_symbol            text,
    p_chain                   text,
    p_message_type            text,
    p_alert_type              text,
    p_called_market_cap       numeric,
    p_entry_market_cap        numeric,
    p_ath_market_cap          numeric,
    p_roi_multiple            numeric,
    p_time_to_milestone_seconds integer,
    p_is_success              boolean,
    p_success_tier            text,
    p_platform_links          jsonb,
    p_raw_text                text,
    p_metadata                jsonb
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_id bigint;
BEGIN
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, source_tier, channel_name, channel_id, telegram_message_id,
        message_timestamp, token_address, token_symbol, chain, message_type,
        alert_type, called_market_cap, entry_market_cap, ath_market_cap,
        roi_multiple, time_to_milestone_seconds, is_success, success_tier,
        platform_links, raw_text, metadata
    ) VALUES (
        p_source_name, p_source_tier, p_channel_name, p_channel_id, p_telegram_message_id,
        p_message_timestamp, p_token_address, p_token_symbol, p_chain, p_message_type,
        p_alert_type, p_called_market_cap, p_entry_market_cap, p_ath_market_cap,
        p_roi_multiple, p_time_to_milestone_seconds, p_is_success, p_success_tier,
        p_platform_links, p_raw_text, p_metadata
    )
    RETURNING id INTO v_id;
    RAISE NOTICE 'inserted telegram_call_outcomes id=%', v_id;
    RETURN v_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ingest_alpha_mention_event failed: %, SQLSTATE=%', SQLERRM, SQLSTATE;
END;
$$;

CREATE OR REPLACE FUNCTION public.insert_telegram_call_outcome(
    p_source_name             text,
    p_source_tier             text,
    p_channel_name            text,
    p_channel_id              bigint,
    p_telegram_message_id     bigint,
    p_message_timestamp       timestamptz,
    p_token_address           text,
    p_token_symbol            text,
    p_chain                   text,
    p_message_type            text,
    p_alert_type              text,
    p_called_market_cap       numeric,
    p_entry_market_cap        numeric,
    p_ath_market_cap          numeric,
    p_roi_multiple            numeric,
    p_time_to_milestone_seconds integer,
    p_is_success              boolean,
    p_success_tier            text,
    p_platform_links          jsonb,
    p_raw_text                text,
    p_metadata                jsonb
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_id bigint;
BEGIN
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, source_tier, channel_name, channel_id, telegram_message_id,
        message_timestamp, token_address, token_symbol, chain, message_type,
        alert_type, called_market_cap, entry_market_cap, ath_market_cap,
        roi_multiple, time_to_milestone_seconds, is_success, success_tier,
        platform_links, raw_text, metadata
    ) VALUES (
        p_source_name, p_source_tier, p_channel_name, p_channel_id, p_telegram_message_id,
        p_message_timestamp, p_token_address, p_token_symbol, p_chain, p_message_type,
        p_alert_type, p_called_market_cap, p_entry_market_cap, p_ath_market_cap,
        p_roi_multiple, p_time_to_milestone_seconds, p_is_success, p_success_tier,
        p_platform_links, p_raw_text, p_metadata
    )
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.milestone_tracker(
    p_token_mint          text,
    p_mention_timestamp   timestamptz,
    p_channel_name        text,
    p_message_id          text,
    p_mention_type        text,
    p_quality_tier        text,
    p_price_at_mention    numeric,
    p_raw_message         text,
    p_sentiment_score     numeric,
    p_conviction_score    numeric,
    p_unique_chat_count   integer,
    p_mention_velocity    integer,
    p_prior_mention_count integer,
    p_price_1m_after      numeric,
    p_price_5m_after      numeric,
    p_price_15m_after     numeric
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_id       bigint;
    v_message_id bigint;
BEGIN
    IF p_token_mint IS NULL OR BTRIM(p_token_mint) = '' THEN
        RAISE EXCEPTION 'p_token_mint cannot be null or empty';
    END IF;
    v_message_id := NULLIF(REGEXP_REPLACE(COALESCE(p_message_id, ''), '[^0-9]', '', 'g'), '')::bigint;
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, source_tier, channel_name, channel_id, telegram_message_id,
        message_timestamp, token_address, token_symbol, chain, message_type,
        alert_type, called_market_cap, entry_market_cap, ath_market_cap,
        roi_multiple, time_to_milestone_seconds, is_success, success_tier,
        platform_links, raw_text, metadata
    ) VALUES (
        'telegram', p_quality_tier, p_channel_name, null, v_message_id,
        p_mention_timestamp, p_token_mint, null, 'solana', p_mention_type,
        'milestone_tracker', p_price_at_mention, p_price_at_mention, p_price_15m_after,
        CASE WHEN p_price_at_mention IS NOT NULL AND p_price_at_mention <> 0 AND p_price_15m_after IS NOT NULL
             THEN p_price_15m_after / p_price_at_mention ELSE null END,
        null, null, null, null, p_raw_message,
        jsonb_build_object(
            'quality_tier', p_quality_tier, 'sentiment_score', p_sentiment_score,
            'conviction_score', p_conviction_score, 'unique_chat_count', p_unique_chat_count,
            'mention_velocity', p_mention_velocity, 'prior_mention_count', p_prior_mention_count,
            'price_1m_after', p_price_1m_after, 'price_5m_after', p_price_5m_after,
            'price_15m_after', p_price_15m_after
        )
    )
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.milestone_tracker(
    p_source_name             text,
    p_source_tier             text,
    p_channel_name            text,
    p_channel_id              bigint,
    p_telegram_message_id     bigint,
    p_message_timestamp       timestamptz,
    p_token_address           text,
    p_token_symbol            text,
    p_chain                   text,
    p_message_type            text,
    p_alert_type              text,
    p_called_market_cap       numeric,
    p_entry_market_cap        numeric,
    p_ath_market_cap          numeric,
    p_roi_multiple            numeric,
    p_time_to_milestone_seconds integer,
    p_is_success              boolean,
    p_success_tier            text,
    p_platform_links          jsonb,
    p_raw_text                text,
    p_metadata                jsonb
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_id bigint;
BEGIN
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, source_tier, channel_name, channel_id, telegram_message_id,
        message_timestamp, token_address, token_symbol, chain, message_type,
        alert_type, called_market_cap, entry_market_cap, ath_market_cap,
        roi_multiple, time_to_milestone_seconds, is_success, success_tier,
        platform_links, raw_text, metadata
    ) VALUES (
        p_source_name, p_source_tier, p_channel_name, p_channel_id, p_telegram_message_id,
        p_message_timestamp, p_token_address, p_token_symbol, p_chain, p_message_type,
        p_alert_type, p_called_market_cap, p_entry_market_cap, p_ath_market_cap,
        p_roi_multiple, p_time_to_milestone_seconds, p_is_success, p_success_tier,
        p_platform_links, p_raw_text, p_metadata
    )
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.tg_milestone_tracker(
    p_token_mint          text,
    p_mention_timestamp   timestamptz,
    p_channel_name        text,
    p_message_id          text,
    p_mention_type        text,
    p_quality_tier        text,
    p_price_at_mention    numeric,
    p_raw_message         text,
    p_sentiment_score     numeric,
    p_conviction_score    numeric,
    p_unique_chat_count   integer,
    p_mention_velocity    integer,
    p_prior_mention_count integer,
    p_price_1m_after      numeric,
    p_price_5m_after      numeric,
    p_price_15m_after     numeric
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_id       bigint;
    v_message_id bigint;
BEGIN
    IF p_token_mint IS NULL OR BTRIM(p_token_mint) = '' THEN
        RAISE EXCEPTION 'p_token_mint cannot be null or empty';
    END IF;
    v_message_id := NULLIF(REGEXP_REPLACE(COALESCE(p_message_id, ''), '[^0-9]', '', 'g'), '')::bigint;
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, source_tier, channel_name, channel_id, telegram_message_id,
        message_timestamp, token_address, token_symbol, chain, message_type,
        alert_type, called_market_cap, entry_market_cap, ath_market_cap,
        roi_multiple, time_to_milestone_seconds, is_success, success_tier,
        platform_links, raw_text, metadata
    ) VALUES (
        'telegram', p_quality_tier, p_channel_name, null, v_message_id,
        p_mention_timestamp, p_token_mint, null, 'solana', p_mention_type,
        'tg_milestone_tracker', p_price_at_mention, p_price_at_mention, p_price_15m_after,
        CASE WHEN p_price_at_mention IS NOT NULL AND p_price_at_mention <> 0 AND p_price_15m_after IS NOT NULL
             THEN p_price_15m_after / p_price_at_mention ELSE null END,
        null, null, null, null, p_raw_message,
        jsonb_build_object(
            'quality_tier', p_quality_tier, 'sentiment_score', p_sentiment_score,
            'conviction_score', p_conviction_score, 'unique_chat_count', p_unique_chat_count,
            'mention_velocity', p_mention_velocity, 'prior_mention_count', p_prior_mention_count,
            'price_1m_after', p_price_1m_after, 'price_5m_after', p_price_5m_after,
            'price_15m_after', p_price_15m_after
        )
    )
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.tg_milestone_tracker(
    p_channel_id          bigint,
    p_telegram_message_id bigint,
    p_token_symbol        text,
    p_token_address       text,
    p_chain               text      DEFAULT 'solana'::text,
    p_entry_market_cap    numeric   DEFAULT NULL::numeric,
    p_ath_market_cap      numeric   DEFAULT NULL::numeric,
    p_roi_multiple        numeric   DEFAULT NULL::numeric,
    p_is_success          boolean   DEFAULT false,
    p_success_tier        text      DEFAULT NULL::text,
    p_message_type        text      DEFAULT 'milestone'::text,
    p_source_name         text      DEFAULT NULL::text,
    p_raw_text            text      DEFAULT NULL::text,
    p_detected_at         timestamptz DEFAULT now()
)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    outcome_id bigint;
BEGIN
    IF p_token_address IS NULL OR BTRIM(p_token_address) = '' THEN
        RAISE EXCEPTION 'p_token_address is required';
    END IF;
    INSERT INTO wallet_intel.telegram_call_outcomes (
        source_name, channel_id, telegram_message_id, message_timestamp,
        token_address, token_symbol, chain, message_type,
        entry_market_cap, ath_market_cap, roi_multiple,
        is_success, success_tier, raw_text
    ) VALUES (
        p_source_name, p_channel_id, p_telegram_message_id, p_detected_at,
        p_token_address, p_token_symbol, p_chain, p_message_type,
        p_entry_market_cap, p_ath_market_cap, p_roi_multiple,
        p_is_success, p_success_tier, p_raw_text
    )
    RETURNING id INTO outcome_id;
    RETURN outcome_id;
END;
$$;

-- ============================================================
-- TRIGGERS
-- ============================================================

CREATE TRIGGER trg_tracked_wallets_set_updated_at
    BEFORE UPDATE ON public.tracked_wallets
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_source_heartbeats_set_updated_at
    BEFORE UPDATE ON public.source_heartbeats
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER purchases_insert_trigger
    AFTER INSERT ON public.purchases
    FOR EACH ROW EXECUTE FUNCTION public.notify_new_purchase();
