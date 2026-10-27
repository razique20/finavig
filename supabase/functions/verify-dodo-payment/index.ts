// Finavig — `verify-dodo-payment` Supabase Edge Function.
//
// Verifies whether the signed-in user has completed a successful payment
// directly with Dodo Payments API and immediately activates their tier in
// `public.user_tiers`. This guarantees immediate in-app entitlement activation
// without waiting for webhooks.

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });

function calculatePlanEndsAt(duration: string): Date {
  const now = new Date();
  if (duration === '1_year') {
    now.setFullYear(now.getFullYear() + 1);
  } else if (duration === '3_months') {
    now.setMonth(now.getMonth() + 3);
  } else {
    // 1 month default
    now.setMonth(now.getMonth() + 1);
  }
  return now;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  const dodoApiKey = Deno.env.get('DODO_PAYMENTS_API_KEY');
  if (!dodoApiKey) {
    return json({ error: 'server_misconfigured', message: 'Dodo Payments API key not configured.' }, 500);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown> = {};
  if (req.method === 'POST') {
    try {
      body = await req.json();
    } catch {
      // empty body is fine
    }
  }

  let user: { id: string; email?: string } | null = null;
  if (jwt === serviceRoleKey) {
    // Admin / Service Role mode
    const targetEmail = (body.email as string) || '';
    const targetUserId = (body.user_id as string) || '';
    if (targetUserId || targetEmail) {
      const { data: usersData } = await admin.auth.admin.listUsers();
      const matched = usersData?.users?.find(
        (u) =>
          (targetUserId && u.id === targetUserId) ||
          (targetEmail && u.email?.toLowerCase() === targetEmail.toLowerCase())
      );
      if (matched) {
        user = { id: matched.id, email: matched.email };
      }
    }
    if (!user) {
      // Default to most recent user if not specified
      const { data: usersData } = await admin.auth.admin.listUsers();
      if (usersData?.users && usersData.users.length > 0) {
        const sorted = [...usersData.users].sort(
          (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
        );
        user = { id: sorted[0].id, email: sorted[0].email };
      }
    }
  } else {
    const { data: authData, error: authError } = await admin.auth.getUser(jwt);
    if (authError || !authData.user) {
      return json({ error: 'unauthorized', message: 'Invalid authentication session.' }, 401);
    }
    user = authData.user;
  }

  if (!user) {
    return json({ error: 'user_not_found', message: 'Could not resolve user.' }, 404);
  }

  const dodoEnv = (Deno.env.get('DODO_PAYMENTS_ENVIRONMENT') || 'test_mode').toLowerCase();
  const dodoBaseUrl = dodoEnv === 'live_mode'
    ? 'https://live.dodopayments.com'
    : 'https://test.dodopayments.com';

  const userEmail = (user.email || '').trim().toLowerCase();
  console.log(`verify-dodo-payment: checking payments for user ${user.id} (${userEmail})...`);

  try {
    // 1. Fetch payments from Dodo Payments
    const paymentsRes = await fetch(`${dodoBaseUrl}/payments?pageSize=50`, {
      headers: {
        'Authorization': `Bearer ${dodoApiKey}`,
        'Content-Type': 'application/json',
      },
    });

    if (!paymentsRes.ok) {
      const errText = await paymentsRes.text();
      console.error('verify-dodo-payment: failed to fetch payments from Dodo:', errText);
      return json({ error: 'dodo_api_error', message: 'Could not fetch payments from Dodo Payments.' }, 502);
    }

    const paymentsData = await paymentsRes.json();
    const paymentsList: Array<Record<string, unknown>> =
      paymentsData.items || paymentsData.data || (Array.isArray(paymentsData) ? paymentsData : []);

    console.log(`verify-dodo-payment: found ${paymentsList.length} payments from Dodo.`);

    // 2. Find a successful payment matching this user
    let matchedPayment: Record<string, unknown> | null = null;

    for (const p of paymentsList) {
      const status = ((p.status as string) || '').toLowerCase();
      if (status !== 'succeeded') continue;

      const customerObj = (p.customer as Record<string, unknown>) || {};
      const custEmail = ((customerObj.email as string) || (p.customer_email as string) || '').trim().toLowerCase();
      const metadata = (p.metadata as Record<string, unknown>) || {};
      const metaUserId = (metadata.user_id as string) || (metadata.userId as string) || '';
      const metaEmail = ((metadata.user_email as string) || '').trim().toLowerCase();

      if (
        (userEmail && custEmail === userEmail) ||
        (metaUserId && metaUserId === user.id) ||
        (userEmail && metaEmail === userEmail)
      ) {
        matchedPayment = p;
        break;
      }
    }

    if (!matchedPayment) {
      // 3. Fallback: check subscriptions in Dodo Payments
      try {
        const subsRes = await fetch(`${dodoBaseUrl}/subscriptions?pageSize=50`, {
          headers: {
            'Authorization': `Bearer ${dodoApiKey}`,
            'Content-Type': 'application/json',
          },
        });
        if (subsRes.ok) {
          const subsData = await subsRes.json();
          const subsList: Array<Record<string, unknown>> =
            subsData.items || subsData.data || (Array.isArray(subsData) ? subsData : []);

          for (const s of subsList) {
            const status = ((s.status as string) || '').toLowerCase();
            if (status !== 'active') continue;

            const customerObj = (s.customer as Record<string, unknown>) || {};
            const custEmail = ((customerObj.email as string) || '').trim().toLowerCase();
            const metadata = (s.metadata as Record<string, unknown>) || {};
            const metaUserId = (metadata.user_id as string) || '';

            if ((userEmail && custEmail === userEmail) || (metaUserId && metaUserId === user.id)) {
              matchedPayment = s;
              break;
            }
          }
        }
      } catch (subErr) {
        console.warn('verify-dodo-payment: subscription check failed:', subErr);
      }
    }

    if (!matchedPayment) {
      console.log(`verify-dodo-payment: no matching successful payment for user ${user.id} (${userEmail})`);
      return json({
        upgraded: false,
        message: 'No completed payment found in Dodo Payments for this account yet.',
      });
    }

    // 4. Resolve tier & duration
    const metadata = (matchedPayment.metadata as Record<string, unknown>) || {};
    let tier = ((metadata.tier as string) || (metadata.plan as string) || '').toLowerCase();
    const duration = ((metadata.duration as string) || (metadata.plan_duration as string) || '1_month').toLowerCase();

    const businessMonthlyId = Deno.env.get('DODO_PRODUCT_BUSINESS_MONTHLY');
    const plusMonthlyId = Deno.env.get('DODO_PRODUCT_PLUS_MONTHLY');
    const productCart = (matchedPayment.product_cart as Array<Record<string, unknown>>) || [];
    const primaryProductId = (matchedPayment.product_id as string) || (productCart[0]?.product_id as string) || '';

    if (!tier) {
      if (businessMonthlyId && primaryProductId === businessMonthlyId) {
        tier = 'business';
      } else if (plusMonthlyId && primaryProductId === plusMonthlyId) {
        tier = 'plus';
      } else {
        tier = 'plus';
      }
    }

    const tierToGrant = ['plus', 'business'].includes(tier) ? tier : 'plus';
    const planStartedAt = new Date();
    const planEndsAt = calculatePlanEndsAt(duration);

    const paymentId = (matchedPayment.payment_id || matchedPayment.id || '') as string;
    const subscriptionId = (matchedPayment.subscription_id || '') as string;
    const customerObj = (matchedPayment.customer as Record<string, unknown>) || {};
    const customerId = (matchedPayment.customer_id || customerObj.customer_id || '') as string;

    console.log(`verify-dodo-payment: activating tier '${tierToGrant}' for user ${user.id} until ${planEndsAt.toISOString()}`);

    const fullPayload = {
      user_id: user.id,
      tier: tierToGrant,
      plan_duration: duration,
      plan_started_at: planStartedAt.toISOString(),
      plan_ends_at: planEndsAt.toISOString(),
      dodo_customer_id: customerId || null,
      dodo_subscription_id: subscriptionId || null,
      dodo_payment_id: paymentId || null,
      updated_at: new Date().toISOString(),
      updated_by: 'verify_dodo_payment',
      note: 'Verified directly via Dodo Payments API',
    };

    let { error: upsertError } = await admin
      .from('user_tiers')
      .upsert(fullPayload, { onConflict: 'user_id' });

    if (upsertError) {
      console.warn('verify-dodo-payment: full upsert failed, retrying with standard columns:', upsertError.message);
      const basicPayload = {
        user_id: user.id,
        tier: tierToGrant,
        plan_duration: duration,
        plan_started_at: planStartedAt.toISOString(),
        plan_ends_at: planEndsAt.toISOString(),
        updated_at: new Date().toISOString(),
        updated_by: 'verify_dodo_payment',
        note: 'Verified directly via Dodo Payments API',
      };
      const fallbackRes = await admin
        .from('user_tiers')
        .upsert(basicPayload, { onConflict: 'user_id' });
      upsertError = fallbackRes.error;
    }

    if (upsertError) {
      console.error('verify-dodo-payment: failed to upsert user_tier:', upsertError);
      return json({ error: 'db_error', message: upsertError.message }, 500);
    }

    return json({
      success: true,
      upgraded: true,
      tier: tierToGrant,
      plan_duration: duration,
      plan_ends_at: planEndsAt.toISOString(),
      payment_id: paymentId,
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('verify-dodo-payment: unexpected error:', message);
    return json({ error: 'verification_failed', message }, 500);
  }
});
