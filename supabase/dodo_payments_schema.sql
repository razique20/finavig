-- ============================================================
-- Finavig — Dodo Payments Integration Schema
-- Run this in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Add Dodo Payments reference columns to user_tiers
alter table public.user_tiers
  add column if not exists dodo_customer_id text,
  add column if not exists dodo_subscription_id text,
  add column if not exists dodo_payment_id text;

comment on column public.user_tiers.dodo_customer_id is 'Dodo Payments customer ID';
comment on column public.user_tiers.dodo_subscription_id is 'Active Dodo Payments recurring subscription ID';
comment on column public.user_tiers.dodo_payment_id is 'Latest Dodo Payments checkout/payment transaction ID';

-- 2. Audit log table for inbound Dodo webhooks
create table if not exists public.dodo_payment_logs (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  dodo_payment_id text,
  dodo_subscription_id text,
  user_id uuid references auth.users(id) on delete set null,
  amount numeric(10,2),
  currency text default 'AED',
  tier_granted text,
  raw_payload jsonb,
  created_at timestamptz not null default now()
);

-- Secure: only accessible via service-role key (Edge Functions & Admin)
alter table public.dodo_payment_logs enable row level security;
