-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 011: Voucher Quota & Agent Remittances
-- Run this in Supabase SQL Editor (Database → SQL Editor → New query)
-- ─────────────────────────────────────────────────────────────────────────────

-- ---------------------------------------------------------------------------
-- 1. Voucher Quota Settings
--    Controls how many AVAILABLE vouchers agents can see per site.
--    site_id = NULL means the setting is a global (app-wide) default.
-- ---------------------------------------------------------------------------
create table if not exists voucher_quota_settings (
  id           serial primary key,
  site_id      int  references sites(id) on delete cascade,
  quota_limit  int  not null default 10,
  is_enabled   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (site_id)          -- one row per site (or one NULL row for global)
);

-- Insert default global setting (quota disabled, limit 10)
insert into voucher_quota_settings (site_id, quota_limit, is_enabled)
values (null, 10, false)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 2. Sales Remittances
--    Agents submit their collected money here; Finance/Admin confirms.
-- ---------------------------------------------------------------------------
create table if not exists sales_remittances (
  id            serial primary key,
  server_id     uuid  not null default gen_random_uuid(),
  agent_id      int   not null references users(id) on delete cascade,
  site_id       int   references sites(id),
  amount        double precision not null,
  notes         text,
  status        text  not null default 'PENDING',  -- PENDING | CONFIRMED | REJECTED
  submitted_at  timestamptz not null default now(),
  reviewed_by   int   references users(id),
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_remittances_agent  on sales_remittances(agent_id);
create index if not exists idx_remittances_status on sales_remittances(status);

-- ---------------------------------------------------------------------------
-- 3. RLS Policies
-- ---------------------------------------------------------------------------
alter table voucher_quota_settings enable row level security;
alter table sales_remittances       enable row level security;

-- Allow all authenticated users to read quota settings
create policy "quota_settings_read_all"
  on voucher_quota_settings for select
  using (true);

-- Only admin/finance can insert/update quota settings  
-- (enforcement is done in Flutter with role checks; Supabase anon key is used)
create policy "quota_settings_write"
  on voucher_quota_settings for all
  using (true)
  with check (true);

create policy "remittances_all"
  on sales_remittances for all
  using (true)
  with check (true);
