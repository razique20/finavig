# Finavig — Dodo Payments Integration Guide

This guide walks through connecting **Dodo Payments** (Merchant of Record) with Finavig so users can upgrade to **Plus** or **Business** automatically.

---

## 1. Dodo Payments Dashboard Setup

1. Log into your [Dodo Payments Dashboard](https://app.dodopayments.com).
2. Go to **Products** and create your subscription products:
   * **Finavig Plus (Monthly)** — Set price in AED (or USD), recurring monthly.
   * **Finavig Business (Monthly)** — Set price in AED (or USD), recurring monthly.
   * *(Optional)* Create 3-month and 1-year product variants if offering bundled billing.
3. Note the generated Product IDs (e.g., `pdt_plus_monthly`, `pdt_biz_monthly`).

---

## 2. Database Migration

Run **`supabase/dodo_payments_schema.sql`** in your Supabase SQL Editor:
* Adds `dodo_customer_id`, `dodo_subscription_id`, `dodo_payment_id` columns to `public.user_tiers`.
* Creates `public.dodo_payment_logs` for webhook auditing.

---

## 3. Set Supabase Function Secrets

Run in your terminal from `finavig`:

```bash
# Set your Dodo Payments API Key (starts with test_ or live_)
supabase secrets set DODO_PAYMENTS_API_KEY=your_dodo_api_key

# Set environment mode: test_mode or live_mode
supabase secrets set DODO_PAYMENTS_ENVIRONMENT=test_mode

# Set Product IDs for tiers
supabase secrets set DODO_PRODUCT_PLUS_MONTHLY=pdt_your_plus_monthly_id
supabase secrets set DODO_PRODUCT_BUSINESS_MONTHLY=pdt_your_business_monthly_id

# (Optional: longer duration products)
supabase secrets set DODO_PRODUCT_PLUS_3MONTHS=pdt_your_plus_3m_id
supabase secrets set DODO_PRODUCT_PLUS_YEARLY=pdt_your_plus_1y_id
supabase secrets set DODO_PRODUCT_BUSINESS_3MONTHS=pdt_your_biz_3m_id
supabase secrets set DODO_PRODUCT_BUSINESS_YEARLY=pdt_your_biz_1y_id
```

---

## 4. Deploy the Edge Functions

```bash
# 1. Deploy checkout creator
supabase functions deploy create-dodo-checkout

# 2. Deploy webhook receiver (allow unauthenticated POST from Dodo's servers)
supabase functions deploy dodo-webhook --no-verify-jwt
```

---

## 5. Configure Webhook in Dodo Payments Dashboard

1. In Dodo Payments Dashboard, go to **Developer → Webhooks → Add Webhook Endpoint**.
2. Set Endpoint URL to:
   ```
   https://<your-project-ref>.supabase.co/functions/v1/dodo-webhook
   ```
3. Subscribe to the following events:
   * `payment.succeeded`
   * `subscription.active`
   * `subscription.renewed`
   * `subscription.cancelled`
   * `subscription.expired`
4. Copy the **Signing Secret** (starts with `whsec_`) and save it in Supabase secrets:
   ```bash
   supabase secrets set DODO_WEBHOOK_SECRET=whsec_your_secret
   ```

---

## 6. How it Works in the App

1. When a user opens the **Upgrade Plan** sheet or hits a feature paywall, they see **"Pay with Dodo Payments (Card / Apple Pay)"**.
2. Tapping it calls `create-dodo-checkout` with their user JWT.
3. Dodo returns a secure checkout session URL, which opens in the browser.
4. When the user completes payment, Dodo triggers `dodo-webhook`.
5. The webhook verifies the signature and grants the tier in `public.user_tiers`.
6. When the user switches back to the app, `EntitlementService` automatically refreshes and displays the unlocked features!
