// Finavig — `groq-proxy` Edge Function.
//
// Keeps the Groq API key server-side (Deno.env GROQ_API_KEY) instead of
// compiling it into the app binary, and meters AI usage per signed-in user
// with the same monthly limits the client shows.
//
// Deploy:
//   supabase secrets set GROQ_API_KEY=gsk_...
//   supabase functions deploy groq-proxy
//
// The function rejects anonymous callers: the public anon key is bundled in
// the app, so it is NOT treated as authorization — a real user JWT is required.

import { createClient } from 'npm:@supabase/supabase-js@2';

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = 'openai/gpt-oss-120b';

// Monthly quota per tier — mirrors lib/models/subscription_tier.dart.
const QUOTA_LIMITS: Record<string, Record<string, number>> = {
  groq_ai_summary: { free: 3, plus: 15, business: 40 },
  groq_ai_budget_plan: { free: 2, plus: 10, business: 25 },
};

// Client `feature` value -> metered feature name (null = unmetered).
const FEATURE_WIRE: Record<string, string | null> = {
  summary: 'groq_ai_summary',
  budget_plan: 'groq_ai_budget_plan',
  intent: null, // intent routing is free — it never touches the quota table
};

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!groqKey) {
    return json({ error: 'server_misconfigured' }, 500);
  }

  const jwt = (req.headers.get('Authorization') ?? '').replace(
    /^Bearer\s+/i,
    '',
  );
  if (!jwt) {
    console.error('groq-proxy: no Authorization header — caller not signed in');
    return json({ error: 'unauthorized' }, 401);
  }

  // Service-role client: verifies the caller's JWT and reads/writes the quota
  // and tier tables regardless of RLS.
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userErr || !user) {
    console.error(
      `groq-proxy: getUser failed — ${userErr?.message ?? 'no user for token'}`,
    );
    return json({ error: 'unauthorized' }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const feature = typeof payload.feature === 'string' ? payload.feature : '';
  if (!(feature in FEATURE_WIRE)) {
    return json({ error: 'unknown_feature' }, 400);
  }
  const featureName = FEATURE_WIRE[feature];

  const month = new Date().toISOString().slice(0, 7); // YYYY-MM
  let used: number | null = null;
  let limit: number | null = null;

  // Metered features: enforce the monthly quota atomically before calling Groq.
  if (featureName) {
    const tier = await resolveTier(admin, user.id);
    limit = QUOTA_LIMITS[featureName]?.[tier] ?? QUOTA_LIMITS[featureName].free;

    const { data: consumed, error: quotaErr } = await admin.rpc(
      'consume_ai_quota',
      {
        p_user_id: user.id,
        p_feature_name: featureName,
        p_usage_month: month,
        p_limit: limit,
      },
    );
    if (quotaErr) {
      return json({ error: 'quota_check_failed', detail: quotaErr.message }, 500);
    }

    used = Number(consumed);
    if (used < 0) {
      const { data: row } = await admin
        .from('ai_quota_usage')
        .select('used_count')
        .eq('user_id', user.id)
        .eq('feature_name', featureName)
        .eq('usage_month', month)
        .maybeSingle();
      return json(
        { error: 'quota_exceeded', used: row?.used_count ?? limit, limit },
        429,
      );
    }
  }

  // Call Groq with the server-held key — it is never exposed to the client.
  let groqRes: Response;
  try {
    groqRes = await fetch(GROQ_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${groqKey}`,
      },
      body: JSON.stringify({
        model: (payload.model as string) ?? DEFAULT_MODEL,
        messages: [
          { role: 'system', content: (payload.systemPrompt as string) ?? '' },
          { role: 'user', content: (payload.userPrompt as string) ?? '' },
        ],
        temperature: (payload.temperature as number) ?? 0.3,
        max_tokens: (payload.maxTokens as number) ?? 450,
        reasoning_effort: 'low',
      }),
    });
  } catch (e) {
    await refundQuota(admin, user.id, featureName, month);
    return json({ error: 'upstream_unreachable', detail: String(e) }, 502);
  }

  if (!groqRes.ok) {
    await refundQuota(admin, user.id, featureName, month);
    const detail = await groqRes.text();
    // Never echo Groq's own status to the client: a Groq 401 (bad/revoked key)
    // must not be confused with a Supabase auth failure. Report 502 and carry
    // the upstream status as data instead.
    console.error(`groq-proxy: Groq responded ${groqRes.status}: ${detail}`);
    return json(
      { error: 'groq_error', upstreamStatus: groqRes.status, detail },
      502,
    );
  }

  const completion = await groqRes.json();
  const text: string = (completion?.choices?.[0]?.message?.content ?? '').trim();
  return json({ text, used, limit });
});

// Reads the user's tier and treats an expired paid plan as Free, matching the
// client's `expire_finished_plans` trigger semantics.
// deno-lint-ignore no-explicit-any
async function resolveTier(admin: any, userId: string): Promise<string> {
  const { data } = await admin
    .from('user_tiers')
    .select('tier, plan_ends_at')
    .eq('user_id', userId)
    .maybeSingle();

  const tier: string = data?.tier ?? 'free';
  const endsAt = data?.plan_ends_at ? Date.parse(data.plan_ends_at) : null;
  if (tier !== 'free' && endsAt !== null && endsAt <= Date.now()) {
    return 'free';
  }
  return tier;
}

// deno-lint-ignore no-explicit-any
async function refundQuota(
  admin: any,
  userId: string,
  featureName: string | null,
  month: string,
): Promise<void> {
  if (!featureName) return;
  try {
    await admin.rpc('refund_ai_quota', {
      p_user_id: userId,
      p_feature_name: featureName,
      p_usage_month: month,
    });
  } catch {
    // Refunds are best-effort; never fail the request over one.
  }
}
