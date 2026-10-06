-- ============================================================
-- Finavig — Credit tracker schema
-- Adds: credit_entries (money borrowed from / lent to someone).
--
-- Safe to re-run: every statement is idempotent.
-- Run this AFTER supabase/schema.sql.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Tables
-- ------------------------------------------------------------

-- Credit obligations: the user either borrowed from
-- (borrowed) or lent to (lent) the counterparty. An
-- obligation, not a money movement — repayments are logged
-- as finance transactions separately.
-- extension_history is a jsonb array of
-- {"from": date, "to": date, "at": timestamptz} entries —
-- the repayment-behaviour trail for the future credit-giving
-- mechanism. Never truncated.
create table if not exists public.credit_entries (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete cascade,
  direction text not null default 'borrowed' check (direction in ('borrowed','lent')),
  counterparty_name text not null,
  counterparty_phone text,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'AED',
  -- The date the money actually changed hands (when the user
  -- borrowed or lent it). Optional for rows created before this
  -- column existed; the app then falls back to created_at.
  start_date date,
  -- Short free-text note explaining why the obligation exists.
  description text,
  deadline date not null,
  extension_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  -- When the obligation was closed. Null while still outstanding.
  settled_at date,
  -- The Money transactions mirroring this credit's cash movements,
  -- set only when the user opted to sync them into Money.
  disbursement_transaction_id uuid,
  settlement_transaction_id uuid
);

-- Backfill the columns on databases created by an earlier version
-- of this script (create table if not exists won't alter them).
alter table public.credit_entries
  add column if not exists start_date date;
alter table public.credit_entries
  add column if not exists description text;
alter table public.credit_entries
  add column if not exists settled_at date;
alter table public.credit_entries
  add column if not exists disbursement_transaction_id uuid;
alter table public.credit_entries
  add column if not exists settlement_transaction_id uuid;

create index if not exists idx_credit_owner
  on public.credit_entries(owner_id);
create index if not exists idx_credit_collection
  on public.credit_entries(collection_id);
create index if not exists idx_credit_deadline
  on public.credit_entries(deadline);

-- ------------------------------------------------------------
-- 2. Row Level Security — same owner-scoped model as the core tables
-- ------------------------------------------------------------

alter table public.credit_entries enable row level security;

-- Credit entries: full access to own rows.
drop policy if exists "own credit entries select" on public.credit_entries;
create policy "own credit entries select" on public.credit_entries
  for select using (auth.uid() = owner_id);

drop policy if exists "own credit entries insert" on public.credit_entries;
create policy "own credit entries insert" on public.credit_entries
  for insert with check (auth.uid() = owner_id);

drop policy if exists "own credit entries update" on public.credit_entries;
create policy "own credit entries update" on public.credit_entries
  for update using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "own credit entries delete" on public.credit_entries;
create policy "own credit entries delete" on public.credit_entries
  for delete using (auth.uid() = owner_id);
