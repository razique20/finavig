// Finavig — `create-dodo-checkout` Supabase Edge Function.
//
// Creates a hosted checkout session with Dodo Payments for tier upgrades.
// Requires a real user JWT in Authorization header.
//
// Deploy:
//   supabase secrets set DODO_PAYMENTS_API_KEY=your_dodo_api_key
//   supabase secrets set DODO_PAYMENTS_ENVIRONMENT=test_mode # or live_mode
//   supabase functions deploy create-dodo-checkout

import { createClient } from 'npm:@supabase/supabase-js@2';

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

  const dodoApiKey = Deno.env.get('DODO_PAYMENTS_API_KEY');
  if (!dodoApiKey) {
    console.error('create-dodo-checkout: missing DODO_PAYMENTS_API_KEY');
    return json({ error: 'server_misconfigured', message: 'Dodo Payments is not configured on the server.' }, 500);
  }

  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) {
    return json({ error: 'unauthorized', message: 'User must be signed in to purchase a plan.' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: { user }, error: authError } = await admin.auth.getUser(jwt);
  if (authError || !user) {
    return json({ error: 'unauthorized', message: 'Invalid authentication session.' }, 401);
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const tier = (body.tier as string)?.toLowerCase();
  const duration = (body.duration as string) || '1_month';
  const returnUrl = (body.return_url as string) || 'finavig://payment-success';
  let productId = (body.product_id as string) || '';

  if (!productId) {
    // Resolve product ID from environment secrets
    if (tier === 'plus') {
      if (duration === '1_year') {
        productId = Deno.env.get('DODO_PRODUCT_PLUS_YEARLY') || Deno.env.get('DODO_PRODUCT_PLUS') || '';
      } else if (duration === '3_months') {
        productId = Deno.env.get('DODO_PRODUCT_PLUS_3MONTHS') || Deno.env.get('DODO_PRODUCT_PLUS') || '';
      } else {
        productId = Deno.env.get('DODO_PRODUCT_PLUS_MONTHLY') || Deno.env.get('DODO_PRODUCT_PLUS') || '';
      }
    } else if (tier === 'business') {
      if (duration === '1_year') {
        productId = Deno.env.get('DODO_PRODUCT_BUSINESS_YEARLY') || Deno.env.get('DODO_PRODUCT_BUSINESS') || '';
      } else if (duration === '3_months') {
        productId = Deno.env.get('DODO_PRODUCT_BUSINESS_3MONTHS') || Deno.env.get('DODO_PRODUCT_BUSINESS') || '';
      } else {
        productId = Deno.env.get('DODO_PRODUCT_BUSINESS_MONTHLY') || Deno.env.get('DODO_PRODUCT_BUSINESS') || '';
      }
    }
  }

  if (!productId) {
    return json({
      error: 'missing_product_id',
      message: `No Dodo Payments product ID found for tier '${tier}' (${duration}). Set DODO_PRODUCT_PLUS_MONTHLY / DODO_PRODUCT_BUSINESS_MONTHLY in Supabase secrets.`,
    }, 400);
  }

  const dodoEnv = (Deno.env.get('DODO_PAYMENTS_ENVIRONMENT') || 'test_mode').toLowerCase();
  const dodoBaseUrl = dodoEnv === 'live_mode'
    ? 'https://live.dodopayments.com'
    : 'https://test.dodopayments.com';

  const checkoutPayload = {
    product_cart: [
      {
        product_id: productId,
        quantity: 1,
      },
    ],
    customer: {
      email: user.email,
    },
    metadata: {
      user_id: user.id,
      tier: tier,
      duration: duration,
      user_email: user.email || '',
    },
    return_url: returnUrl,
  };

  try {
    const res = await fetch(`${dodoBaseUrl}/checkouts`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${dodoApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(checkoutPayload),
    });

    const resJson = await res.json();
    if (!res.ok) {
      console.error('Dodo Payments API error:', resJson);
      return json({
        error: 'dodo_api_error',
        message: resJson.message || 'Failed to create checkout session with Dodo Payments.',
        details: resJson,
      }, res.status);
    }

    return json({
      checkout_url: resJson.checkout_url,
      session_id: resJson.session_id,
      tier: tier,
      duration: duration,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('Error invoking Dodo Payments API:', message);
    return json({ error: 'checkout_request_failed', message }, 502);
  }
});
