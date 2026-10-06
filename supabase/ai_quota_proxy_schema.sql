-- ============================================================
-- Finavig — AI quota helpers for the `groq-proxy` Edge Function
-- Run this script in Supabase Dashboard → SQL Editor → New query
-- (after ai_quota_schema.sql)
--
-- The existing `increment_ai_quota` RPC is bound to auth.uid(), so it can only
-- run for the calling user. The Edge Function runs with the service-role key
-- and must meter a specific user id, so it needs these two helpers instead.
-- Both are SECURITY DEFINER and take an explicit p_user_id; they are intended
-- to be called with the service-role key only.
-- ============================================================

-- Atomically consume one unit of quota for a user.
-- Returns the new used_count, or -1 when the monthly limit is already reached
-- (in which case nothing is consumed).
CREATE OR REPLACE FUNCTION public.consume_ai_quota(
  p_user_id      UUID,
  p_feature_name TEXT,
  p_usage_month  TEXT,
  p_limit        INT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cur INT;
BEGIN
  IF p_feature_name NOT IN ('groq_ai_summary', 'groq_ai_budget_plan') THEN
    RAISE EXCEPTION 'unknown ai feature %', p_feature_name;
  END IF;

  SELECT used_count INTO v_cur
    FROM public.ai_quota_usage
   WHERE user_id = p_user_id
     AND feature_name = p_feature_name
     AND usage_month = p_usage_month
   FOR UPDATE;

  IF v_cur IS NULL THEN
    v_cur := 0;
  END IF;

  IF v_cur >= p_limit THEN
    RETURN -1;
  END IF;

  INSERT INTO public.ai_quota_usage
    (user_id, feature_name, usage_month, used_count, updated_at)
  VALUES
    (p_user_id, p_feature_name, p_usage_month, v_cur + 1, NOW())
  ON CONFLICT (user_id, feature_name, usage_month)
  DO UPDATE SET used_count = v_cur + 1, updated_at = NOW();

  RETURN v_cur + 1;
END;
$$;

-- Give back one unit when the upstream model call fails after consuming, so a
-- failed request never costs the user a credit.
CREATE OR REPLACE FUNCTION public.refund_ai_quota(
  p_user_id      UUID,
  p_feature_name TEXT,
  p_usage_month  TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.ai_quota_usage
     SET used_count = GREATEST(used_count - 1, 0),
         updated_at = NOW()
   WHERE user_id = p_user_id
     AND feature_name = p_feature_name
     AND usage_month = p_usage_month;
END;
$$;

-- Service-role only: revoke from the public API surface so app clients cannot
-- call these directly with the anon key.
REVOKE ALL ON FUNCTION public.consume_ai_quota(UUID, TEXT, TEXT, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refund_ai_quota(UUID, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
