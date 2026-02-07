-- Add client_id and package_id to commission_settings for more specific commission rules
ALTER TABLE commission_settings 
ADD COLUMN IF NOT EXISTS client_id INTEGER REFERENCES clients(id),
ADD COLUMN IF NOT EXISTS package_id INTEGER REFERENCES packages(id);

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_commission_settings_client ON commission_settings(client_id);
CREATE INDEX IF NOT EXISTS idx_commission_settings_package ON commission_settings(package_id);

-- Update the check constraint to include new applicable_to options
ALTER TABLE commission_settings DROP CONSTRAINT IF EXISTS commission_settings_applicable_to_check;
ALTER TABLE commission_settings ADD CONSTRAINT commission_settings_applicable_to_check 
CHECK (applicable_to IN ('ALL_AGENTS', 'SPECIFIC_ROLE', 'SPECIFIC_USER', 'SPECIFIC_CLIENT', 'SPECIFIC_PACKAGE'));

COMMENT ON COLUMN commission_settings.client_id IS 'Applies commission only for specific client sales';
COMMENT ON COLUMN commission_settings.package_id IS 'Applies commission only for specific package sales';
