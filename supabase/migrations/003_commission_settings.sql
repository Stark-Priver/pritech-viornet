-- Commission Settings Table
-- Allows admin/finance to configure commission rates
CREATE TABLE commission_settings (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    commission_type TEXT NOT NULL CHECK (commission_type IN ('PERCENTAGE', 'FIXED_AMOUNT', 'TIERED')),
    rate DECIMAL(10, 2) NOT NULL, -- Percentage (0-100) or fixed amount
    min_sale_amount DECIMAL(10, 2) DEFAULT 0, -- Minimum sale amount to qualify
    max_sale_amount DECIMAL(10, 2), -- Maximum sale amount (for tiered)
    applicable_to TEXT NOT NULL CHECK (applicable_to IN ('ALL_AGENTS', 'SPECIFIC_ROLE', 'SPECIFIC_USER')),
    role_id INTEGER REFERENCES roles(id),
    user_id INTEGER REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 0, -- Higher priority rules apply first
    start_date TIMESTAMP DEFAULT NOW(),
    end_date TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Commission History Table
-- Tracks all commission calculations
CREATE TABLE commission_history (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    sale_id INTEGER REFERENCES sales(id) ON DELETE CASCADE,
    agent_id INTEGER REFERENCES users(id) NOT NULL,
    commission_amount DECIMAL(10, 2) NOT NULL,
    sale_amount DECIMAL(10, 2) NOT NULL,
    commission_setting_id INTEGER REFERENCES commission_settings(id),
    commission_rate DECIMAL(10, 2), -- Rate applied at time of calculation
    calculation_details JSONB, -- Stores details of how commission was calculated
    status TEXT DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'PAID', 'CANCELLED')),
    approved_by INTEGER REFERENCES users(id),
    approved_at TIMESTAMP,
    paid_at TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX idx_commission_settings_active ON commission_settings(is_active);
CREATE INDEX idx_commission_settings_user ON commission_settings(user_id);
CREATE INDEX idx_commission_settings_role ON commission_settings(role_id);
CREATE INDEX idx_commission_history_agent ON commission_history(agent_id);
CREATE INDEX idx_commission_history_sale ON commission_history(sale_id);
CREATE INDEX idx_commission_history_status ON commission_history(status);
CREATE INDEX idx_commission_history_server_id ON commission_history(server_id);

-- Add automatic updated_at trigger function (reusable)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER commission_settings_updated_at
    BEFORE UPDATE ON commission_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER commission_history_updated_at
    BEFORE UPDATE ON commission_history
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Insert default commission settings
INSERT INTO commission_settings (name, description, commission_type, rate, applicable_to, priority)
VALUES 
('Default Agent Commission', 'Standard 10% commission for all agents', 'PERCENTAGE', 10.0, 'ALL_AGENTS', 1),
('High Value Sales Bonus', 'Additional 5% for sales above 100,000', 'PERCENTAGE', 5.0, 'ALL_AGENTS', 2);

COMMENT ON TABLE commission_settings IS 'Configurable commission rules for agents';
COMMENT ON TABLE commission_history IS 'Historical record of all commission calculations and payments';
