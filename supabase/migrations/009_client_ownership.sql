-- Migration 009: Client ownership (registered_by + assigned_to)
-- Tracks who registered a client and who it has been assigned/transferred to.

ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS registered_by INTEGER REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS assigned_to   INTEGER REFERENCES users(id);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_clients_registered_by ON clients(registered_by);
CREATE INDEX IF NOT EXISTS idx_clients_assigned_to   ON clients(assigned_to);

-- RLS: allow users to see their own clients (registered_by OR assigned_to)
-- The existing broad policy already covers admin/finance; this is additive.
-- (If you have per-row RLS enabled, adjust the policy below)
-- For now we rely on app-level filtering; no change to existing RLS policies needed.
