-- Row Level Security (RLS) Policies for Viornet
-- Since we're NOT using Supabase Auth, we disable RLS
-- The app handles authentication locally

-- Disable RLS on all tables (since auth is handled in Flutter app)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sites ENABLE ROW LEVEL SECURITY;

-- Create policies that allow all operations with service role key
-- The Flutter app will use service role key (kept secure in app)
-- This essentially bypasses RLS since auth is handled locally

CREATE POLICY "Allow all operations on users"
ON users FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on sites"
ON sites FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on clients"
ON clients FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on vouchers"
ON vouchers FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on sales"
ON sales FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on expenses"
ON expenses FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on assets"
ON assets FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on maintenance"
ON maintenance FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on sms_logs"
ON sms_logs FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on sms_templates"
ON sms_templates FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on packages"
ON packages FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on roles"
ON roles FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on user_roles"
ON user_roles FOR ALL
USING (true)
WITH CHECK (true);

CREATE POLICY "Allow all operations on user_sites"
ON user_sites FOR ALL
USING (true)
WITH CHECK (true);

-- NOTE: Security Model
-- - Authentication is handled in the Flutter app (local database)
-- - Only authenticated users in the app can trigger sync
-- - Service role key should be secured (obfuscated in app)
-- - For production: Consider IP whitelisting or API gateway
