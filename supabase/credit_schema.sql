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
  deadline date not null,
  extension_history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

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
