// Finavig — `dodo-webhook` Supabase Edge Function.
//
// Receives webhook events from Dodo Payments (Standard Webhooks specification)
// and updates the user's tier in `public.user_tiers` in real-time.
//
// Deploy:
//   supabase functions deploy dodo-webhook --no-verify-jwt

import { createClient } from 'npm:@supabase/supabase-js@2';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

// Verify Standard Webhook signature
async function verifyWebhookSignature(
  rawBody: string,
  headers: Headers,
  secret: string
): Promise<boolean> {
  const webhookId = headers.get('webhook-id');
  const webhookTimestamp = headers.get('webhook-timestamp');
  const webhookSignature = headers.get('webhook-signature');

  if (!webhookId || !webhookTimestamp || !webhookSignature) {
    console.warn('dodo-webhook: missing webhook signature headers');
    return false;
  }

  // Prevent replay attacks (5 minute window)
  const timestampNum = parseInt(webhookTimestamp, 10);
  const nowSec = Math.floor(Date.now() / 1000);
  if (isNaN(timestampNum) || Math.abs(nowSec - timestampNum) > 300) {
    console.warn('dodo-webhook: timestamp expired or clock skew too large');
    return false;
  }

  try {
    let cleanSecret = secret.trim();
    if (cleanSecret.startsWith('whsec_')) {
      cleanSecret = cleanSecret.substring(6);
    }

    // Decode base64 secret to binary
    let secretBytes: Uint8Array;
    try {
      const binStr = atob(cleanSecret);
      secretBytes = new Uint8Array(binStr.length);
      for (let i = 0; i < binStr.length; i++) {
        secretBytes[i] = binStr.charCodeAt(i);
      }
    } catch {
      // Fallback: UTF-8 encoding if not base64
      secretBytes = new TextEncoder().encode(cleanSecret);
    }

    const signedPayload = `${webhookId}.${webhookTimestamp}.${rawBody}`;
    const encoder = new TextEncoder();
    const dataBytes = encoder.encode(signedPayload);

    const key = await crypto.subtle.importKey(
      'raw',
      secretBytes,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const signatureBuffer = await crypto.subtle.sign('HMAC', key, dataBytes);
    const computedBase64 = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)));

    // Parse signatures list (format: "v1,signature1 v1,signature2")
    const signatures = webhookSignature
      .split(' ')
      .map((s) => s.trim().replace(/^v\d+,/, ''));

    return signatures.some((sig) => sig === computedBase64);
  } catch (err) {
    console.error('dodo-webhook: signature verification exception:', err);
    return false;
  }
}

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
  if (req.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  const rawBody = await req.text();
  const webhookSecret = Deno.env.get('DODO_WEBHOOK_SECRET');

  // Verify signature if secret is configured
  if (webhookSecret) {
    const isValid = await verifyWebhookSignature(rawBody, req.headers, webhookSecret);
    if (!isValid) {
      console.error('dodo-webhook: invalid signature');
      return json({ error: 'invalid_signature' }, 401);
    }
  } else {
    console.warn('dodo-webhook: DODO_WEBHOOK_SECRET not set; running in unverified mode.');
  }

  let event: Record<string, unknown> = {};
  try {
    event = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const eventType = ((event.event_type || event.type) as string) || '';
  const data = ((event.data || event.payload || event) as Record<string, unknown>);
  const metadata = ((data.metadata || event.metadata || {}) as Record<string, unknown>);

  console.log(`dodo-webhook: received event '${eventType}'`);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  // 1. Resolve User ID (from metadata, client_reference_id, or customer email lookup)
  let userId = (metadata.user_id as string) || (metadata.userId as string) || (data.client_reference_id as string) || '';

  const customerObj = (data.customer as Record<string, unknown>) || {};
  const customerEmail = (customerObj.email as string) || (metadata.user_email as string) || (data.customer_email as string) || (data.email as string) || '';

  if (!userId && customerEmail) {
    try {
      console.log(`dodo-webhook: resolving user by email '${customerEmail}'...`);
      const { data: usersData, error: userLookupError } = await admin.auth.admin.listUsers();
      if (!userLookupError && usersData?.users) {
        const matched = usersData.users.find(
          (u) => u.email?.trim().toLowerCase() === customerEmail.trim().toLowerCase()
        );
        if (matched) {
          userId = matched.id;
          console.log(`dodo-webhook: resolved user ${userId} for email '${customerEmail}'`);
        }
      }
    } catch (lookupErr) {
      console.warn('dodo-webhook: user lookup by email failed:', lookupErr);
    }
  }

  // 2. Resolve Tier (from metadata or product IDs)
  let requestedTier = ((metadata.tier as string) || (metadata.plan as string) || '').toLowerCase();
  const duration = ((metadata.duration as string) || (metadata.plan_duration as string) || '1_month').toLowerCase();

  const businessMonthlyId = Deno.env.get('DODO_PRODUCT_BUSINESS_MONTHLY');
  const plusMonthlyId = Deno.env.get('DODO_PRODUCT_PLUS_MONTHLY');

  const productCart = (data.product_cart as Array<Record<string, unknown>>) || [];
  const primaryProductId = (data.product_id as string) || (productCart[0]?.product_id as string) || '';

  if (!requestedTier) {
    if (businessMonthlyId && primaryProductId === businessMonthlyId) {
      requestedTier = 'business';
    } else if (plusMonthlyId && primaryProductId === plusMonthlyId) {
      requestedTier = 'plus';
    } else {
      const productName = ((data.product_name || productCart[0]?.name || '') as string).toLowerCase();
      if (productName.includes('business')) {
        requestedTier = 'business';
      } else {
        requestedTier = 'plus'; // Default fallback
      }
    }
  }

  const paymentId = (data.payment_id || data.id || '') as string;
  const subscriptionId = (data.subscription_id || '') as string;
  const customerId = (data.customer_id || customerObj.customer_id || '') as string;
  const totalAmount = (data.total_amount || data.amount) as number | undefined;

  // 3. Best-effort audit log
  try {
    await admin.from('dodo_payment_logs').insert({
      event_type: eventType,
      dodo_payment_id: paymentId || null,
      dodo_subscription_id: subscriptionId || null,
      user_id: userId || null,
      amount: totalAmount ? totalAmount / 100 : null,
      currency: (data.currency as string) || 'AED',
      tier_granted: requestedTier || null,
      raw_payload: event,
    });
  } catch (logErr) {
    console.warn('dodo-webhook: could not write to dodo_payment_logs:', logErr);
  }

  // 4. Handle activation events
  const isActivationEvent = [
    'payment.succeeded',
    'payment.successful',
    'subscription.active',
    'subscription.renewed',
  ].includes(eventType);

  if (isActivationEvent && userId) {
    const tierToGrant = ['plus', 'business'].includes(requestedTier) ? requestedTier : 'plus';
    const planStartedAt = new Date();
    const planEndsAt = calculatePlanEndsAt(duration);

    console.log(`dodo-webhook: activating '${tierToGrant}' for user ${userId} until ${planEndsAt.toISOString()}`);

    // Attempt upsert with all dodo columns
    const fullPayload = {
      user_id: userId,
      tier: tierToGrant,
      plan_duration: duration,
      plan_started_at: planStartedAt.toISOString(),
      plan_ends_at: planEndsAt.toISOString(),
      dodo_customer_id: customerId || null,
      dodo_subscription_id: subscriptionId || null,
      dodo_payment_id: paymentId || null,
      updated_at: new Date().toISOString(),
      updated_by: 'dodo_webhook',
      note: `Provisioned by Dodo Payments (${eventType})`,
    };

    let { error: upsertError } = await admin
      .from('user_tiers')
      .upsert(fullPayload, { onConflict: 'user_id' });

    // Fallback without dodo-specific columns if schema doesn't have them
    if (upsertError) {
      console.warn('dodo-webhook: full upsert failed, retrying with standard columns:', upsertError.message);
      const basicPayload = {
        user_id: userId,
        tier: tierToGrant,
        plan_duration: duration,
        plan_started_at: planStartedAt.toISOString(),
        plan_ends_at: planEndsAt.toISOString(),
        updated_at: new Date().toISOString(),
        updated_by: 'dodo_webhook',
        note: `Provisioned by Dodo Payments (${eventType})`,
      };
      const fallbackRes = await admin
        .from('user_tiers')
        .upsert(basicPayload, { onConflict: 'user_id' });
      upsertError = fallbackRes.error;
    }

    if (upsertError) {
      console.error('dodo-webhook: failed to upsert user_tier:', upsertError);
      return json({ error: 'db_error', message: upsertError.message }, 500);
    }

    // Optional audit log entry
    try {
      await admin.from('user_tier_audit').insert({
        user_id: userId,
        old_tier: 'free',
        new_tier: tierToGrant,
        changed_by: 'dodo_webhook',
        note: `Payment succeeded via Dodo Payments (${eventType})`,
      });
    } catch {
      // Optional
    }

    return json({
      success: true,
      message: `Tier '${tierToGrant}' activated for user ${userId}`,
      tier: tierToGrant,
      plan_ends_at: planEndsAt.toISOString(),
    });
  }

  // 5. Handle cancellations / expiration
  const isDeactivationEvent = [
    'subscription.cancelled',
    'subscription.expired',
  ].includes(eventType);

  if (isDeactivationEvent && userId) {
    console.log(`dodo-webhook: revoking tier for user ${userId} due to ${eventType}`);
    await admin.from('user_tiers').update({
      tier: 'free',
      updated_at: new Date().toISOString(),
      updated_by: 'dodo_webhook',
      note: `Subscription ended (${eventType})`,
    }).eq('user_id', userId);

    return json({ success: true, message: `Subscription cancelled for user ${userId}` });
  }

  return json({ received: true, event_type: eventType, userId: userId || null });
});
