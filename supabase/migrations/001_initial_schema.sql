-- Viornet Database Schema for Supabase PostgreSQL
-- This mirrors the local SQLite schema for cloud sync
-- Created: 2026-02-06

-- Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    role TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Sites Table
CREATE TABLE sites (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    location TEXT,
    gps_coordinates TEXT,
    router_ip TEXT,
    router_username TEXT,
    router_password TEXT,
    contact_person TEXT,
    contact_phone TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Clients Table
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    mac_address TEXT,
    site_id INTEGER REFERENCES sites(id),
    address TEXT,
    registration_date TIMESTAMP NOT NULL,
    last_purchase_date TIMESTAMP,
    expiry_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    sms_reminder BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Vouchers Table
CREATE TABLE vouchers (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    code TEXT UNIQUE NOT NULL,
    username TEXT,
    password TEXT,
    duration INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL,
    site_id INTEGER REFERENCES sites(id),
    agent_id INTEGER REFERENCES users(id),
    client_id INTEGER REFERENCES clients(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    sold_at TIMESTAMP,
    activated_at TIMESTAMP,
    expires_at TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Sales Table
CREATE TABLE sales (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    receipt_number TEXT UNIQUE NOT NULL,
    voucher_id INTEGER REFERENCES vouchers(id) NOT NULL,
    client_id INTEGER REFERENCES clients(id),
    agent_id INTEGER REFERENCES users(id) NOT NULL,
    site_id INTEGER REFERENCES sites(id),
    amount DECIMAL(10, 2) NOT NULL,
    commission DECIMAL(10, 2) DEFAULT 0.0,
    payment_method TEXT NOT NULL,
    notes TEXT,
    sale_date TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Expenses Table
CREATE TABLE expenses (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    site_id INTEGER REFERENCES sites(id),
    created_by INTEGER REFERENCES users(id) NOT NULL,
    expense_date TIMESTAMP NOT NULL,
    receipt_number TEXT,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Assets Table
CREATE TABLE assets (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    serial_number TEXT,
    model TEXT,
    manufacturer TEXT,
    site_id INTEGER REFERENCES sites(id),
    purchase_date TIMESTAMP,
    purchase_price DECIMAL(10, 2),
    warranty_expiry TIMESTAMP,
    condition TEXT NOT NULL,
    location TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Maintenance Table
CREATE TABLE maintenance (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL,
    status TEXT NOT NULL,
    site_id INTEGER REFERENCES sites(id),
    asset_id INTEGER REFERENCES assets(id),
    reported_by INTEGER REFERENCES users(id) NOT NULL,
    assigned_to INTEGER REFERENCES users(id),
    reported_date TIMESTAMP NOT NULL,
    scheduled_date TIMESTAMP,
    completed_date TIMESTAMP,
    cost DECIMAL(10, 2),
    resolution TEXT,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- SMS Logs Table
CREATE TABLE sms_logs (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    recipient TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT NOT NULL,
    type TEXT NOT NULL,
    client_id INTEGER REFERENCES clients(id),
    scheduled_at TIMESTAMP,
    sent_at TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- SMS Templates Table
CREATE TABLE sms_templates (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Packages Table
CREATE TABLE packages (
    id SERIAL PRIMARY KEY,
    server_id UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
    name TEXT NOT NULL,
    duration INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    is_synced BOOLEAN DEFAULT TRUE,
    last_synced_at TIMESTAMP DEFAULT NOW()
);

-- Roles Table (no sync fields - reference data)
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- User Roles Table (Many-to-Many)
CREATE TABLE user_roles (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, role_id)
);

-- User Sites Table (Many-to-Many)
CREATE TABLE user_sites (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    site_id INTEGER REFERENCES sites(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, site_id)
);

-- Create indexes for better performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_server_id ON users(server_id);
CREATE INDEX idx_clients_server_id ON clients(server_id);
CREATE INDEX idx_clients_phone ON clients(phone);
CREATE INDEX idx_clients_site_id ON clients(site_id);
CREATE INDEX idx_vouchers_code ON vouchers(code);
CREATE INDEX idx_vouchers_server_id ON vouchers(server_id);
CREATE INDEX idx_vouchers_status ON vouchers(status);
CREATE INDEX idx_sales_server_id ON sales(server_id);
CREATE INDEX idx_sales_receipt ON sales(receipt_number);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_expenses_server_id ON expenses(server_id);
CREATE INDEX idx_assets_server_id ON assets(server_id);
CREATE INDEX idx_maintenance_server_id ON maintenance(server_id);
CREATE INDEX idx_sms_logs_server_id ON sms_logs(server_id);

-- Trigger to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sites_updated_at BEFORE UPDATE ON sites FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_vouchers_updated_at BEFORE UPDATE ON vouchers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_expenses_updated_at BEFORE UPDATE ON expenses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_assets_updated_at BEFORE UPDATE ON assets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_maintenance_updated_at BEFORE UPDATE ON maintenance FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sms_logs_updated_at BEFORE UPDATE ON sms_logs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sms_templates_updated_at BEFORE UPDATE ON sms_templates FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_packages_updated_at BEFORE UPDATE ON packages FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default roles
INSERT INTO roles (name, description) VALUES
    ('SUPER_ADMIN', 'Full system access'),
    ('ADMIN', 'Site management and reporting'),
    ('AGENT', 'Sales and basic operations'),
    ('TECHNICIAN', 'Maintenance and technical support');

COMMENT ON DATABASE postgres IS 'Viornet ISP Management System - Cloud Database';
