-- ============================================================
-- Migration 012: Add package_id dimension to voucher_quota_settings
-- ============================================================
-- Quota can now be set per (site, package) combo.
-- NULL site    = applies to all sites
-- NULL package = applies to all packages for that site
-- Both NULL    = global default
-- ============================================================

-- 1. Add package_id column (nullable FK to packages table)
ALTER TABLE voucher_quota_settings
  ADD COLUMN IF NOT EXISTS package_id INTEGER REFERENCES packages(id) ON DELETE CASCADE;

-- 2. Drop the old unique constraint that only covered site_id
ALTER TABLE voucher_quota_settings
  DROP CONSTRAINT IF EXISTS voucher_quota_settings_site_id_key;

-- Also drop the new constraint if a previous failed migration attempt left it
ALTER TABLE voucher_quota_settings
  DROP CONSTRAINT IF EXISTS voucher_quota_settings_site_package_unique;

-- 3. Remove duplicate rows before creating the unique constraint.
--    Keep the most-recently updated row for each (site_id, package_id) pair.
--    coalesce(-1) is used so that NULLs compare equal in the GROUP BY.
DELETE FROM voucher_quota_settings
WHERE id NOT IN (
  SELECT DISTINCT ON (
    COALESCE(site_id, -1),
    COALESCE(package_id, -1)
  ) id
  FROM voucher_quota_settings
  ORDER BY
    COALESCE(site_id, -1),
    COALESCE(package_id, -1),
    updated_at DESC
);

-- 4. Add the new unique constraint treating NULLs as equal.
--    NULLS NOT DISTINCT is available in PostgreSQL 15+ (Supabase Cloud ≥ 2023).
ALTER TABLE voucher_quota_settings
  ADD CONSTRAINT voucher_quota_settings_site_package_unique
  UNIQUE NULLS NOT DISTINCT (site_id, package_id);

-- 5. Index for fast lookup in getVoucherQuotaSetting
CREATE INDEX IF NOT EXISTS idx_vqs_site_package
  ON voucher_quota_settings (site_id, package_id);
