-- Drop old vouchers table if exists
DROP TABLE IF EXISTS vouchers CASCADE;

-- Create vouchers table with new schema
CREATE TABLE vouchers (
    id SERIAL PRIMARY KEY,
    server_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    package_id INTEGER REFERENCES packages(id),
    price DECIMAL(10, 2),
    validity VARCHAR(100),
    speed VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE' CHECK (status IN ('AVAILABLE', 'SOLD', 'USED', 'EXPIRED')),
    sold_at TIMESTAMP,
    sold_by_user_id INTEGER REFERENCES users(id),
    sale_id INTEGER REFERENCES sales(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Create index on voucher code for fast lookup
CREATE INDEX idx_vouchers_code ON vouchers(code);
CREATE INDEX idx_vouchers_status ON vouchers(status);
CREATE INDEX idx_vouchers_package_id ON vouchers(package_id);
CREATE INDEX idx_vouchers_server_id ON vouchers(server_id);

-- Create updated_at trigger
CREATE TRIGGER update_vouchers_updated_at
    BEFORE UPDATE ON vouchers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Enable RLS
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;

-- RLS Policies for vouchers
-- All authenticated users can view vouchers
CREATE POLICY "Users can view vouchers"
    ON vouchers FOR SELECT
    TO authenticated
    USING (true);

-- Admin, Finance, and Technical can insert vouchers
CREATE POLICY "Admin, Finance, Technical can insert vouchers"
    ON vouchers FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.server_id::text = auth.uid()::text
            AND users.role IN ('ADMIN', 'FINANCE', 'TECHNICAL')
        )
    );

-- Admin, Finance, Technical, and Agents can update vouchers (for selling)
CREATE POLICY "Authorized users can update vouchers"
    ON vouchers FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.server_id::text = auth.uid()::text
            AND users.role IN ('ADMIN', 'FINANCE', 'TECHNICAL', 'AGENT', 'SALES')
        )
    );

-- Only Admin can delete vouchers
CREATE POLICY "Admin can delete vouchers"
    ON vouchers FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.server_id::text = auth.uid()::text
            AND users.role = 'ADMIN'
        )
    );
