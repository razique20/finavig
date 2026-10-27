// Finavig — `dodo-webhook` Supabase Edge Function.
//
// Receives webhook events from Dodo Payments (Standard Webhooks specification)
// and updates the user's tier in `public.user_tiers` in real-time.
//
// Deploy:
//   supabase secrets set DODO_WEBHOOK_SECRET=whsec_...
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
    console.warn('dodo-webhook: DODO_WEBHOOK_SECRET not set; running in unverified test mode.');
  }

  let event: Record<string, unknown> = {};
  try {
    event = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }

  const eventType = ((event.event_type || event.type) as string) || '';
  const data = ((event.data || event.payload || {}) as Record<string, unknown>);
  const metadata = ((data.metadata || {}) as Record<string, unknown>);

  console.log(`dodo-webhook: received event '${eventType}'`);

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const userId = (metadata.user_id as string) || (data.client_reference_id as string) || '';
  const requestedTier = (metadata.tier as string)?.toLowerCase() || '';
  const duration = (metadata.duration as string) || '1_month';

  const paymentId = (data.payment_id || data.id || '') as string;
  const subscriptionId = (data.subscription_id || '') as string;
  const customerId = (data.customer_id || (data.customer as Record<string, unknown>)?.customer_id || '') as string;
  const totalAmount = (data.total_amount || data.amount) as number | undefined;

  // Log raw event for auditability (best effort)
  try {
    await admin.from('dodo_payment_logs').insert({
      event_type: eventType,
      dodo_payment_id: paymentId,
      dodo_subscription_id: subscriptionId,
      user_id: userId || null,
      amount: totalAmount ? totalAmount / 100 : null,
      currency: (data.currency as string) || 'AED',
      tier_granted: requestedTier || null,
      raw_payload: event,
    });
  } catch (logErr) {
    console.warn('dodo-webhook: could not write to dodo_payment_logs:', logErr);
  }

  // Handle successful payments / active subscriptions
  const isActivationEvent = [
    'payment.succeeded',
    'subscription.active',
    'subscription.renewed',
  ].includes(eventType);

  if (isActivationEvent && userId) {
    const tierToGrant = ['plus', 'business'].includes(requestedTier) ? requestedTier : 'plus';
    const planStartedAt = new Date();
    const planEndsAt = calculatePlanEndsAt(duration);

    console.log(`dodo-webhook: granting '${tierToGrant}' to user ${userId} until ${planEndsAt.toISOString()}`);

    const { error: upsertError } = await admin.from('user_tiers').upsert({
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
    }, { onConflict: 'user_id' });

    if (upsertError) {
      console.error('dodo-webhook: failed to upsert user_tier:', upsertError);
      return json({ error: 'db_error', message: upsertError.message }, 500);
    }

    // Record tier audit history
    try {
      await admin.from('user_tier_audit').insert({
        user_id: userId,
        old_tier: 'free',
        new_tier: tierToGrant,
        changed_by: 'dodo_webhook',
        note: `Payment succeeded via Dodo Payments (${eventType})`,
      });
    } catch {
      // audit table is optional
    }

    return json({ success: true, message: `Tier '${tierToGrant}' activated for user ${userId}` });
  }

  // Handle cancellations / expiration
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

  return json({ received: true });
});
