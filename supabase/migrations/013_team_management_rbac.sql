-- ============================================================
-- 013_team_management_rbac.sql
-- Custom Roles, Role Permissions, and User Permission Overrides
-- Created: 2026-02-24
-- ============================================================

-- ---------------------------------------------------------------------------
-- custom_roles: Roles created by Super Admin at runtime
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS custom_roles (
  id              BIGSERIAL PRIMARY KEY,
  name            TEXT        NOT NULL UNIQUE,
  description     TEXT        NOT NULL DEFAULT '',
  color           TEXT        NOT NULL DEFAULT '#6366F1',
  icon            TEXT        NOT NULL DEFAULT 'person',
  is_system       BOOLEAN     NOT NULL DEFAULT FALSE,  -- TRUE for built-in roles
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_by      BIGINT      REFERENCES users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed the built-in roles so they appear in the UI (read-only)
INSERT INTO custom_roles (name, description, color, icon, is_system, is_active)
VALUES
  ('SUPER_ADMIN', 'Full system access. Cannot be modified.',   '#EF4444', 'admin_panel_settings', TRUE,  TRUE),
  ('ADMIN',       'Admin – full access except super-admin controls.',  '#F97316', 'manage_accounts', TRUE,  TRUE),
  ('MARKETING',   'Client management, SMS & vouchers.',       '#8B5CF6', 'campaign',              TRUE,  TRUE),
  ('SALES',       'Sales and POS operations.',                '#22C55E', 'point_of_sale',         TRUE,  TRUE),
  ('TECHNICAL',   'Technical operations and maintenance.',    '#3B82F6', 'engineering',           TRUE,  TRUE),
  ('FINANCE',     'Financial management and reporting.',      '#F59E0B', 'account_balance',       TRUE,  TRUE),
  ('AGENT',       'Basic sales agent.',                       '#14B8A6', 'person',                TRUE,  TRUE)
ON CONFLICT (name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- custom_role_permissions: Which permissions belong to each custom role
-- One row per (role, permission) pair
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS custom_role_permissions (
  id            BIGSERIAL PRIMARY KEY,
  custom_role_id BIGINT NOT NULL REFERENCES custom_roles(id) ON DELETE CASCADE,
  permission    TEXT   NOT NULL,  -- matches Permission.name e.g. 'view_clients'
  granted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (custom_role_id, permission)
);

-- ---------------------------------------------------------------------------
-- user_permission_overrides: Per-user GRANT or DENY of a specific permission
-- Overrides take precedence over role-derived permissions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_permission_overrides (
  id            BIGSERIAL PRIMARY KEY,
  user_id       BIGINT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  permission    TEXT    NOT NULL,   -- matches Permission.name
  is_granted    BOOLEAN NOT NULL,   -- TRUE = explicitly granted, FALSE = explicitly denied
  reason        TEXT,
  set_by        BIGINT  REFERENCES users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, permission)
);

-- ---------------------------------------------------------------------------
-- user_custom_roles: Users assigned to custom (non-system) roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_custom_roles (
  id             BIGSERIAL PRIMARY KEY,
  user_id        BIGINT  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  custom_role_id BIGINT  NOT NULL REFERENCES custom_roles(id) ON DELETE CASCADE,
  assigned_by    BIGINT  REFERENCES users(id) ON DELETE SET NULL,
  assigned_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, custom_role_id)
);

-- ---------------------------------------------------------------------------
-- Indexes for fast lookups
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_custom_role_permissions_role  ON custom_role_permissions(custom_role_id);
CREATE INDEX IF NOT EXISTS idx_user_permission_overrides_user ON user_permission_overrides(user_id);
CREATE INDEX IF NOT EXISTS idx_user_custom_roles_user        ON user_custom_roles(user_id);

-- ---------------------------------------------------------------------------
-- Row-Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE custom_roles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_role_permissions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_permission_overrides   ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_custom_roles           ENABLE ROW LEVEL SECURITY;

-- Service-role key bypasses RLS entirely — no policy needed for app layer.
-- These policies permit the anon/service role used by the Flutter app:
CREATE POLICY "service_role_all_custom_roles"
  ON custom_roles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_crp"
  ON custom_role_permissions FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_upo"
  ON user_permission_overrides FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_ucr"
  ON user_custom_roles FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- ---------------------------------------------------------------------------
-- Helper: update updated_at automatically
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_custom_roles_updated_at
  BEFORE UPDATE ON custom_roles
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TRIGGER set_upo_updated_at
  BEFORE UPDATE ON user_permission_overrides
  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
