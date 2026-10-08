# `groq-proxy` — server-side Groq key + per-user quota

Keeps the shared Groq API key off the client and meters AI usage per signed-in
user. The app calls this function through `GroqApiService` whenever the user has
not supplied their own key (`lib/services/groq_api_service.dart`).

## What it does

1. Requires a **real user JWT** — the public anon key is not accepted. Anonymous
   callers get `401`.
2. For metered features (`summary`, `budget_plan`) it reads the user's tier from
   `user_tiers`, enforces the matching monthly limit via the `consume_ai_quota`
   SQL function, and refunds the credit if the Groq call fails.
3. Forwards the prompt to Groq with the **server-held** key and returns
   `{ text, used, limit }`. `intent` (Ask Finavig routing) is unmetered.

Quota limits mirror `lib/models/subscription_tier.dart`:

| Feature (`groq_ai_*`) | Free | Plus | Business |
| --- | --- | --- | --- |
| `groq_ai_summary` | 3 | 15 | 40 |
| `groq_ai_budget_plan` | 2 | 10 | 25 |

## One-time setup

Run the SQL first (Dashboard → SQL Editor, after `ai_quota_schema.sql`):

```
supabase/ai_quota_proxy_schema.sql
```

Then deploy the function (requires the [Supabase CLI](https://supabase.com/docs/guides/cli)):

```bash
supabase login
supabase link --project-ref <your-project-ref>

# Store the Groq key as a function secret — never in the app.
supabase secrets set GROQ_API_KEY=gsk_your_real_key

supabase functions deploy groq-proxy
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically by the
Supabase runtime — do not set them yourself.

## Verify

```bash
# Anonymous call must be rejected.
curl -i -X POST "https://<project-ref>.supabase.co/functions/v1/groq-proxy" \
  -H "Content-Type: application/json" \
  -d '{"feature":"intent","systemPrompt":"s","userPrompt":"u"}'
# => HTTP 401 {"error":"unauthorized"}
```

Then run the app signed in and open **AI Executive Summary → Regenerate**: the
call now goes through the proxy, and the counter comes back from the server.

## Troubleshooting

The app's fallback message hides the real cause. Check the function logs:

```bash
supabase functions logs groq-proxy
```

| Log line | Cause | Fix |
| --- | --- | --- |
| `Groq responded 401: {"error":{"message":"Invalid API Key"...}}` | The `GROQ_API_KEY` secret is invalid or revoked | Set a fresh key: `supabase secrets set GROQ_API_KEY=gsk_...` |
| `no Authorization header` | The app called while signed out | Sign in (the client only proxies with a real session) |
| `getUser failed — ...` | The session token was expired/invalid | Sign out and back in |
| no log at all, app shows `401` | The function isn't deployed under this name, or the gateway rejected the request | `supabase functions deploy groq-proxy` |

Note: a Groq-side failure is returned to the app as **502 `groq_error`** (with
`upstreamStatus`), deliberately not as a 401, so it can never be confused with
"please sign in".

## Rotating the key

Use the helper script — it stores the new key as the function secret **and**
strips any copy that may have crept back into `lib/config/app_credentials.dart`:

```bash
./supabase/functions/groq-proxy/rotate-key.sh gsk_new_key
# or, with no argument, it reads GROQ_API_KEY or the value in
# lib/config/app_credentials.dart
```

Or do it by hand:

```bash
supabase secrets set GROQ_API_KEY=gsk_new_key
# redeploy is optional; the secret is read at request time
```

Revoke the old key in the Groq console afterwards.
