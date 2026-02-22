-- Create isp_subscriptions table
-- Tracks the reseller's own ISP uplink payments per site (not client subscriptions)

CREATE TABLE IF NOT EXISTS isp_subscriptions (
    id            SERIAL PRIMARY KEY,
    site_id       INTEGER NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    provider_name             VARCHAR(255) NOT NULL,
    payment_control_number    VARCHAR(255),
    registered_name           VARCHAR(255),
    service_number            VARCHAR(255),
    paid_at       TIMESTAMPTZ NOT NULL,
    ends_at       TIMESTAMPTZ NOT NULL,
    amount        NUMERIC(12, 2),
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_isp_subscriptions_site_id  ON isp_subscriptions(site_id);
CREATE INDEX IF NOT EXISTS idx_isp_subscriptions_paid_at  ON isp_subscriptions(paid_at DESC);
CREATE INDEX IF NOT EXISTS idx_isp_subscriptions_ends_at  ON isp_subscriptions(ends_at);

-- RLS
ALTER TABLE isp_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view isp_subscriptions"
    ON isp_subscriptions FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Admin and Finance can manage isp_subscriptions"
    ON isp_subscriptions FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.server_id::text = auth.uid()::text
            AND users.role IN ('ADMIN', 'SUPER_ADMIN', 'FINANCE')
            AND users.is_active = true
        )
    );
