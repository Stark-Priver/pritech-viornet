-- Migration 010: Investors table
-- Tracks investors, their investment amounts, and ROI configuration

CREATE TABLE IF NOT EXISTS investors (
  id              SERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  email           TEXT,
  phone           TEXT,
  invested_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
  invest_date     DATE NOT NULL,
  roi_percentage  NUMERIC(6,3) NOT NULL DEFAULT 0,
  return_period   TEXT NOT NULL DEFAULT 'MONTHLY'
                    CHECK (return_period IN ('MONTHLY', 'QUARTERLY', 'ANNUALLY')),
  notes           TEXT,
  is_active       BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_investors_is_active ON investors(is_active);
CREATE INDEX IF NOT EXISTS idx_investors_invest_date ON investors(invest_date);

-- Row Level Security
ALTER TABLE investors ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Service role can manage investors"
  ON investors FOR ALL
  USING (true)
  WITH CHECK (true);

-- Auto-update updated_at on modification
CREATE OR REPLACE FUNCTION update_investors_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER investors_updated_at_trigger
  BEFORE UPDATE ON investors
  FOR EACH ROW EXECUTE FUNCTION update_investors_updated_at();
