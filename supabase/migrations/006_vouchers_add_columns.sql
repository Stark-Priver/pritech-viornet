-- Add missing columns to vouchers table
ALTER TABLE vouchers
  ADD COLUMN IF NOT EXISTS site_id INTEGER REFERENCES sites(id),
  ADD COLUMN IF NOT EXISTS qr_code_data TEXT,
  ADD COLUMN IF NOT EXISTS batch_id VARCHAR(36);

-- Indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_vouchers_site_id   ON vouchers(site_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_batch_id  ON vouchers(batch_id);
