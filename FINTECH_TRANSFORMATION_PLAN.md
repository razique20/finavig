# Finavig Fintech Transformation Plan & Research Report

**Document Version:** 1.0
**Date:** October 31, 2026
**Project:** Finavig (Flutter app — financial budgeting + document expiry tracking for GCC)
**Current Status:** Pilot-ready (525 tests, CI-guarded, GCC-wide, freemium SaaS tiers built)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [GCC Fintech Ecosystem Research](#3-gcc-fintech-ecosystem-research)
4. [Feasibility Analysis: Visa Cards, Document Encryption, Renewal Service](#4-feasibility-analysis)
5. [Phased Transformation Roadmap](#5-phased-transformation-roadmap)
   - Phase 0: Foundations (Immediate — Q4 2026)
   - Phase 1: Embedded Payments (Q1 2027)
   - Phase 2: Wallet & Collections (Q2–Q3 2027)
   - Phase 3: Credit & Insurance (Q4 2027 – Q2 2028)
   - Phase 4: Open Finance & Platform (Q3 2028+)
6. [Regulatory Compliance Roadmap](#6-regulatory-compliance-roadmap)
7. [Technical Implementation Plan](#7-technical-implementation-plan)
8. [Risk Assessment & Mitigation](#8-risk-assessment--mitigation)
9. [Immediate Next Steps (This Quarter)](#9-immediate-next-steps-this-quarter)

---

## 1. Executive Summary

Finavig is **strongly positioned** to transform from a document/d budgeting tracker into a full fintech platform for GCC SMEs and enterprises. The app already owns the critical wedge: **document expiry deadlines with known renewal fees**. Every tracked document (trade licence, visa, insurance, Ejari) has three things that fintech monetizes:

1. **A payment due date** — renewal is a guaranteed, recurring payment intent.
2. **A known amount** — the business must pay to stay compliant.
3. **Trust at the moment of urgency** — users open the app when money must move.

The product already has the user base, the document model, the financial ledger, the AI engine, and the GCC-wide scope. The pivot to embedded payments, wallets, and credit is not a distant moonshot — it is a **phased, partner-first execution path** that can begin within the current quarter.

**Key thesis:** *Finavig doesn't need to build a bank or a payment processor. It needs to integrate licensed PSPs (Payment Service Providers), partner with BIN sponsors for cards, and integrate with licensed lenders/insurers — while keeping the client-side experience unchanged.*

---

## 2. Current State Assessment

### Strengths (already built)

| Area | Status |
|---|---|
| **Document tracking** | Full CRUD with OCR pre-fill, urgency ladder (90/60/30/7), custom alert days, PDF/CSV export |
| **Financial ledger** | Double-entry capable, budgets, envelopes, recurring transactions, credit book with optional ledger linkage |
| **AI engine** | Server-held Groq key via `groq-proxy` Edge Function, per-tier quotas, quota refund on failure, optional Gemini user key |
| **GCC scope** | 6 countries, per-country authority catalogs, per-collection currency (AED, SAR, QAR, KWD, BHD, OMR) |
| **Tier system** | Free → Plus (AED 25/mo) → Business (AED 99/mo) with feature gates |
| **App security** | App Lock (6-digit passcode + biometric), local-first storage, RLS-protected backend |
| **Test coverage** | 54 suites / 525 tests, CI-gated (analyze + file-size budget + full suite) |
| **Retention plumbing** | Notification deep links, pre-permission explainer, demo document, offline banner, PDPL data export |

### Gaps (vs. fintech-ready)

| Gap | Impact | Roadmap Reference |
|---|---|---|
| No server-side money-adjacent logic | Retrofitting later is expensive; Edge Functions layer needed now (Phase 0) | FINTECH_ROADMAP.md §0 |
| No payment facilitator posture | Must integrate with PSP before any in-app renewal | FINTECH_ROADMAP.md §1 |
| No card-on-file / tokenization | Requires BIN sponsor; UI can be built before processing | FINTECH_ROADMAP.md §1/§2 |
| No KYC/AML hooks | Required before any payments flow; can be vendor SDK later | FINTECH_ROADMAP.md §0/§3 |
| No consent ledger | Legal backbone for data monetization; simple tables needed | FINTECH_ROADMAP.md §0 |
| No feature-flag system | Paid features must roll out per cohort | FINTECH_ROADMAP.md §0 |

---

## 3. GCC Fintech Ecosystem Research

### Market Pain (validated by the market study)

| Pain Point | Frequency | Financial Impact |
|---|---|---|
| **Trade licence renewal** | Annual (AED 10k–50k typical) | Fines + activity suspension; banks freeze dealings |
| **Residence visa renewal** | Every 1–3 years (AED 3k–7k) | Overstay fines (AED 100/day), sponsor liability |
| **Emirates ID / Iqama / Civil ID** | Every 5–10 years | Service access breaks (banking, SIM, portals) |
| **Vehicle registration / insurance** | Annual | Fines + impoundment risk; insurance claims denied |
| **Tenancy (Ejari / Ejar)** | Annual + contract change | Utilities stall, tenancy process breaks |

**Key insight:** Every single one of these has **(a) a payment due date, (b) a known amount, and (c) a moment of urgency when the user opens the app.** This is the fintech wedge.

### GCC Regulatory Landscape (high-level)

| Activity | Regulator | Requirement |
|---|---|---|
| Facilitating card payments via PSP | — | PSP merchant agreement; payment-facilitator terms (no licence needed if purely facilitating) |
| Holding client funds / wallet | CBUAE | Stored Value Facility / Retail Payment Services licence **or** partner-bank escrow structure |
| Lending / credit | CBUAE | Banking licence **or** licensed partner model (revenue-share) |
| Insurance distribution | Insurance Authority | Registration / embedded partner model |
| KYC / AML | goAML + KYC vendors (IDWise, Focal, Shufti Pro) + UAE PASS | Identity verification at onboarding |
| Data protection | PDPL (Federal Decree-Law 45/2021) | Consent, residency, breach rules; local-first is highly defensible |

### Sandbox Availability

| Sandbox | Cost/Effort | What It Enables |
|---|---|---|
| CBUAE sandbox | Free / low-cost | Pilot payments, wallets, credit under regulatory supervision |
| ADGM RegLab (DIFC) | Free / low-cost | Fintech licensing sandbox, ideal for UAE-first pilot |
| DIFC DFSA Testing Licence | Moderate | Full licence testing for payments/credit/insurance |

**Recommendation:** Start with ADGM RegLab or CBUAE sandbox for Phase 1 embedded payments. The product can launch Phase 0–1 without a licence (payment facilitator model), then graduate to a licence once volume validates demand.

### Addressable Market Estimate

| Segment | Size Signal | Finavig Fit |
|---|---|---|
| Solo founders & freelancers (free-zone + SME) | Tens of thousands in UAE alone | **Primary** — avoids one fine, tracks personal + company docs |
| PRO / corporate services providers | High concentration of pain | **Expansion** — multi-collection = "one workspace per client" |
| Expatriate households | ~88% non-national in UAE/Qatar | **Volume** — Free tier drives adoption; family sharing → Plus upsell |
| SMEs with 5–50 staff | Policy target: >1/3 of GDP | **Secondary** — needs assignment + shared collections (partially built) |

**Realistic 12-month objective:** 5–15k registered users, 2–5% conversion to paid tier = **AED 15k–90k/yr** revenue, sufficient to validate willingness to pay before investing in PRO/SME team features.

---

## 4. Feasibility Analysis: Visa Cards, Document Encryption, Renewal Service

### 4.1 Visa-/Card-Linked Offering

**Feasibility: HIGH** — but requires partner integration, not built from scratch.

| Approach | Effort | Regulatory | Timeline |
|---|---|---|---|
| **BIN sponsor (e.g., Nymcard, Emirates NBD, Mashreq)** | Low–moderate (API integration + UI) | BIN sponsor holds licence; Finavig gets interchange share | 2–3 months |
| **Co-branded prepaid card** | Moderate (legal + API + compliance) | Requires Stored Value Facility (CBUAE) or partner bank | 6+ months |
| **Virtual card for renewals only** | Low (PSP SDK hosted fields) | Pays the renewal fee to govt/vendor; card not held long-term | 1–2 months |

**Recommended approach for Phase 1:** Virtual card / card-on-file for renewals only via a BIN sponsor. The user gets a virtual card number (tokenized) to pay the renewal fee; Finavig earns a small interchange share; the card expires after the transaction. This avoids holding client funds and stays within payment-facilitator posture.

### 4.2 Document Encryption

**Feasibility: MODERATE** — the app already stores document metadata and OCR-extracted fields. Full document encryption at rest requires:

| Consideration | Current State | Required Action |
|---|---|---|
| Metadata (expiry, fee, vendor) | Stored in Supabase Postgres with RLS (per-owner path) | Add client-side encryption (e.g., `libsodium` or `google_crypto`) before upload; key derived from user passcode/JWT |
| Attachment files (PDFs, images) | Supabase Storage (unencrypted at rest) | Optional: client-side encrypt before upload; or use private bucket with owner-only IAM; for pilot, message limitation in-app and keep bytes device-local |
| PDPL compliance | Local-first architecture is the strongest defence | Privacy policy must disclose: (a) metadata stored in Supabase, (b) attachments may be device-only until backup ships, (c) user can export and delete anytime |

**Recommended approach:** For Phase 0–1, keep the device-local posture (bytes never leave the device). Add an optional "encrypted backup" toggle that client-encrypts before upload — this is a Plus-tier differentiator and a PDPL-friendly feature. For Phase 2–3, make client-side encryption the default with a key derived from the App Lock passcode.

### 4.3 Document Renewal Service (In-App Pay)

**Feasibility: HIGH** — this is the **core wedge** the roadmap already identifies. The flow is:

1. Reminder fires → user taps "Renew now"
2. Amount preview (from document metadata) → PSP checkout (hosted fields / tokenized card)
3. Receipt attached to document → status auto-updates to "renewed"
4. Urgency engine recalculates (days remaining → +365 days)

**No licence needed** if Finavig operates as a *payment facilitator*: the PSP (Checkout.com, Network International, Stripe, Tabby, Tamara) collects and settles the funds; Finavig takes a take-rate (1–3%) on each transaction. The PSP handles PCI compliance, card data, and refunds.

**Required before going live:**
- PSP sandbox account (choose 1–2 from: Checkout.com, Network International, Telr, PayTabs, Amazon Payment Services, Stripe — all have UAE presence)
- Feature-flag system to roll out per cohort
- Consent ledger (simple tables: `consents` with `scope`, `granted_at`, `revoked_at`)
- Idempotency keys on every write (can be retried)

---

## 5. Phased Transformation Roadmap

The roadmap builds on the existing `FINTECH_ROADMAP.md` phases. Each phase has concrete deliverables, dependencies, and success metrics.

### Phase 0: Foundations (Immediate — Q4 2026)

**Goal:** Move money-adjacent logic server-side, build the legal backbone, prepare for payments.

| Deliverable | Effort | Owner | Success Metric |
|---|---|---|---|
| **Edge Functions layer** for any transaction, amount, fee, or vendor call | 2–3 days | Move all money logic from Flutter client to Supabase Edge Functions; the client should never be trusted with pricing | `flutter test` passes; `groq-proxy` deployed with `GROQ_API_KEY` |
| **Double-entry ledger schema** (SQL tables: `transactions`, `ledger_entries`, `payment_methods`, `consents`) | 3–4 days | Add to `supabase/`; migrations run against production project | RLS policies verified; supabase CLI diff clean |
| **Idempotency keys** on every write that can be retried (payments, webhooks) | 2 days | Add `idempotency_key` column to transaction tables; handler generates/uses it | Re-tries don't create duplicates |
| **Immutable audit log** (who did what, when) | 2 days | Table `audit_log` (id, owner_id, action, entity_type, entity_id, created_at, ip, user_agent) | Every CRUD operation inserts a row; RLS restricts to owner |
| **Consent ledger** (versioned policy the user accepted) | 2 days | Table `consents` (id, owner_id, scope, granted_at, revoked_at, policy_version) | First consent captured on tier upgrade; every data-use tracked |
| **`amount_due` / `last_paid_amount` fields** on expiry items | 2 days | Add columns to `documents` table; populate from OCR-extracted fee | Document detail screen shows " renewal fee: AED X" |
| **Feature-flag system** for paid features per cohort | 3–4 days | Simple boolean flags in `user_tiers` or a `feature_flags` table; app reads server-side | Free users see paywall only for flags set to `plus`/`business`; no code changes needed for new flags |
| **Survey 20 users** on willingness to pay renewals in-app | 1 week (external) | Recruit 20 pilot users; ask "Would you pay this renewal here?" | ≥40% say yes → validate Phase 1 investment |
| **Book consult with UAE fintech lawyer** on facilitation-model setup | 1 day (external) | Legal review of PSP partnership structure, consent ledger, take-rate disclosure | Lawyer sign-off on Phase 1 compliance framework |

**Dependencies:** None beyond the existing codebase. All are additive SQL/migration changes.

**Why this matters:** Phase 0 costs little now and is painful to retrofit later. It establishes the server-side money layer that every subsequent phase requires.

---

### Phase 1: Embedded Payments (First Revenue) — Q1 2027

**Goal:** Pay renewals in-app for the top 3 document types; generate first fintech revenue via take-rate.

| Deliverable | Effort | Owner | Success Metric |
|---|---|---|---|
| **Pay renewals in-app** for top 3 document types (trade licence, Ejari, insurance) | 3–4 weeks | Flow: reminder → "Renew now" → amount preview → PSP checkout → receipt attached → status auto-renews | First successful in-app renewal; PSP sandbox transactions logged |
| **Apple Pay / Google Pay** integration (highest conversion in UAE) | 2–3 weeks | PSP SDK or third-party provider (Stripe/Checkout.com support) | Conversion rate ≥ Apple Pay / Google Pay vs. card entry |
| **Card-on-file / auto-renew** — one toggle per document: "Auto-pay 14 days before expiry" | 2–3 weeks | Toggle stores card token (via PSP); recurring revenue + lock-in | ≥15% of users enable auto-renew for at least one document |
| **BNPL for large renewals** (AED 10k+ trade licences) via Tabby/Tamara | 2–3 weeks | Integrate Tabby/Tamara SDK; interest-free installments | ≥10% of large-renewal users choose BNPL |
| **Service fee / take-rate** per transaction (1–3%) — check PSP surcharging terms | 1 week | Configure in PSP dashboard; disclose to user before payment | Revenue recorded per-transaction; PSP statements reconciled |
| **UAE PSP options evaluation & sandbox accounts** | 1 week | Set up accounts with 2 PSPs (e.g., Checkout.com + Stripe or Tabby) | Sandbox accounts active; API keys stored in Supabase secrets (not in app) |
| **Compliance prerequisites**: never store card numbers, PSP SDK hosted fields, clear pricing disclosure, receipts, refund flow | Ongoing | Legal + engineering; PSP docs reviewed; UI discloses take-rate before checkout | Zero PCI violations; all receipts include take-rate breakdown |

**Regulatory posture:** Payment *facilitator* via licensed PSP. Funds flow through the PSP; Finavig never touches card data. PSP remains PCI scope.

**Success metric for Phase 1:** ≥50 in-app renewal transactions in the first month; ≥10% of users enable auto-renew; take-rate revenue > $0 (validates business model).

---

### Phase 2: Money Features (Wallet & Collections) — Q2–Q3 2027

**Goal:** Pre-funded renewal wallet, multi-document auto-pay, invoicing, corporate expense cards.

| Deliverable | Effort | Owner | Success Metric |
|---|---|---|---|
| **Renewal Wallet** ("set aside") — round-ups/micro-deposits pre-funding renewals | 3–4 weeks | Start as *goal-tracking only* (no custody = no licence); UI shows "funded AED X of AED Y needed" | Users can toggle on/off; progress bar visible on document detail |
| **Transition to partner-bank escrow** for custody (if/when licensed) | 4–6 weeks (post-Phase 1) | Partner bank holds funds; Finavig API triggers disbursement; or keep tracking-only | If licensed: funds legally held; if not: UI messages "goal tracking only" |
| **Multi-document auto-pay rules** — "never miss a renewal" subscription tier on top of Business | 2–3 weeks | Rules engine: "for each document type, auto-pay N days before expiry"; per-user toggle | Business-tier users can set rules; ≥20% enable auto-pay for ≥2 document types |
| **Invoicing / get paid** — SMEs invoice clients; Finavig takes a cut | 3–4 weeks | Invoice service: create invoice → send via email → track payment → take 1–2% cut | First invoice created; payment tracked; revenue recorded |
| **Corporate expense cards** via BIN sponsor (e.g., Nymcard) — interchange share | 4–6 weeks | BIN sponsor issues cards; Finavig gets interchange share per spend; spend data completes financial picture | Cards issued to Business-tier users; spend data appears in ledger |
| **Tiered SaaS plans** layered on top (free → paid payments + autopay → team seats, API access) | 2–3 weeks | Feature-flag-gated UI; upgrade request flow (email to admin console) | Clear upgrade path; ≥5% of Free users upgrade to Plus within 90 days |

**Regulatory note:** Holding client money in the UAE = CBUAE Stored Value Facility / Retail Payment Services licence, **or** partner-bank escrow. Phase 2 starts tracking-only; custody requires licence or partner.

**Success metric for Phase 2:** ≥30% of Plus users enable Renewal Wallet goal; ≥20% of Business users set auto-pay rules; ≥5 invoices generated through the platform; corporate card issuance if BIN sponsor integrated.

---

### Phase 3: Credit & Insurance (Data Monetization) — Q4 2027 – Q2 2028

**Goal:** SME credit line, credit score, embedded insurance distribution.

| Deliverable | Effort | Owner | Success Metric |
|---|---|---|---|
| **SME credit line / invoice financing** — renewal-payment history underwrites working-capital offers *with* a licensed lender (revenue share) | 4–6 weeks | Lender partner underwrites; Finavig provides data (consent-based) and gets revenue share | First credit offer generated; lender integrates Finavig API; revenue share recorded |
| **SME credit score product** (consent-based, bureau-aligned) | 3–4 weeks | Score model: on-time renewal payment history + extension history from `credit_entries`; score returned by lender | Score displayed on user dashboard; lender uses it for underwriting |
| **Embedded insurance distribution** — liability, property, cyber at renewal moments via licensed broker | 4–6 weeks | Broker partnership; Finavig presents insurance option at renewal → user purchases → Finavig gets commission | Insurance option shown at renewal; ≥5% of renewals add insurance; commission recorded |
| **Cross-border / supplier payments** if customers import — partner with licensed remitters | 3–4 weeks | Remitter partnership (e.g., WIO, Western Union API); pay supplier in another country | First cross-border payment processed; fee recorded |

**Regulatory note:** Lending requires CBUAE banking licence **or** licensed partner model. Insurance distribution requires Insurance Authority registration **or** embedded partner model. Phase 3 works with partners first; own licence considered after volume validates demand.

**Success metric for Phase 3:** ≥50 credit offers generated (with lender partner); ≥10 SMEs receive credit lines; ≥20 insurance policies distributed; revenue share + commission recorded.

---

### Phase 4: Open Finance & Full Stack — Q3 2028+

**Goal:** Bank account aggregation, full business account, API platform.

| Deliverable | Effort | Owner | Success Metric |
|---|---|---|---|
| **Bank account aggregation** under UAE Open Finance framework | 4–6 weeks | Connect accounts to auto-detect subscriptions and renewals (turns manual tracking into automatic) | Auto-detected subscriptions appear in Documents; ≥30% of users have at least 1 auto-detected |
| **Full business account** (Wio-style) — only after Phases 1–3 and serious capital/licensing; via BaaS partner | 6–12 months (post-Phase 3) | Banking-as-a-service partner issues IBAN, virtual IBAN, debit card; Finavig UI on top | Business account opened; IBAN visible in UI; salary + expense tracking |
| **API platform** — let accountants/ERP tools read expiry + payment data; per-seat / per-call fees | 3–4 weeks | API endpoints: `/documents`, `/finance_transactions`, `/renewals`, `/credit`; API keys; rate limiting | First external partner integrates; per-call fees recorded; tiered access (Free/Plus/API) |
| **Open Finance standards compliance** (UAE-specific data sharing consent) | 2–3 weeks | Consent flows, data portability, audit logs for external access | User can grant/revoke API access; PDPL-compliant logs |

**Success metric for Phase 4:** ≥10 API partners; ≥5% of Business users connect bank accounts; API revenue > $0; full business account launched.

---

## 6. Regulatory Compliance Roadmap

| Phase | Regulatory Milestone | Action | Effort |
|---|---|---|---|
| **Phase 0** | None (tracker only) | Keep as-is; document PDPL compliance in privacy policy | 1 day |
| **Phase 1** | Payment facilitator via PSP | Sign PSP merchant agreement; implement consent ledger; disclose take-rate; never store card numbers | 2–3 weeks (legal + engineering) |
| **Phase 2** | Stored Value Facility / partner-bank escrow | If holding client funds: apply for CBUAE sandbox or partner with bank; otherwise keep tracking-only | 4–6 weeks (if pursuing licence) |
| **Phase 3** | Lending licence + Insurance Authority registration | Engage legal counsel; pilot with partner lender/broker first; no own licence needed if partner-first | 6–8 weeks (partner integration + legal review) |
| **Phase 4** | Open Finance framework compliance | Register with UAE Open Finance office (if required); implement consent flows for API data sharing | 3–4 weeks (post-Phase 3) |

**Key compliance principles (from FINTECH_ROADMAP.md § "UAE regulatory map"):**
- Never take custody of client funds before licensing; partner-first keeps you legal.
- Never store card numbers (PCI stays with the PSP).
- Never extend credit yourself before a licensed partner validates demand.
- Always disclose pricing before purchase (Terms §7 commitment).
- Use sandboxes (CBUAE, ADGM RegLab, DIFC DFSA) to pilot regulated features cheaply.

---

## 7. Technical Implementation Plan

### 7.1 Architecture Changes (Phase 0)

| Concern | Current State | Action |
|---|---|---|
| Money logic in client | Flutter calls Supabase directly | Add Edge Functions layer for any transaction, amount, fee, or vendor call; client sends request, function validates and returns result |
| Ledger | None (basic finance_transactions) | Add double-entry tables: `transactions`, `ledger_entries`, `payment_methods`, `consents`; migrations in `supabase/` |
| Webhooks | N/A | Idempotent webhook handler + signature verification (PSP webhooks terminate at Edge Function) |
| PCI | N/A (no cards) | Keep it that way — PSP SDK only; hosted fields; no card data in DB or client |
| KYC | Email/password auth only | Add KYC step before first payment (vendor SDK: IDWise, Focal, Shufti Pro); user data flows to PSP for risk check |
| Notifications | Local reminder engine (good!) | Extend: "Pay now" deep links from WhatsApp/email alerts; optional server-side FCM/APNs for durability |
| Collections | Already multi-tenant by owner | Reuse as per-legal-entity scoping for invoices/cards (each company = own collection/workspace) |
| Feature flags | None | Add before monetizing; simple table `feature_flags` (id, owner_id, feature_name, is_enabled, tier_minimum) |

### 7.2 Key APIs & Endpoints

| Endpoint | Method | Auth | Description |
|---|---|---|---|
| `POST /api/renewals/preview` | POST | User JWT | Given document ID, preview renewal amount; rate-limited per tier; enforced by `groq-proxy` quota |
| `POST /api/renewals/initiate` | POST | User JWT | Start renewal payment; PSP checkout URL returned; idempotency key required |
| `POST /api/renewals/webhook` | POST | PSP signature | PSP callback; verifies idempotency key; updates document status to "renewed"; inserts receipt |
| `POST /api/consents` | POST | User JWT | Record user consent for data use / payment processing; scope field tracks what was agreed |
| `GET /api/feature-flags` | GET | User JWT | Returns which paid features are enabled for the user's tier |
| `POST /api/payments/virtual-card` | POST | User JWT | (Phase 2+) Generate virtual card token for a specific amount; BIN sponsor returns token |
| `GET /api/credit-offers` | GET | User JWT | (Phase 3+) Generate credit offer based on renewal payment history; lender partner underwrites |

### 7.3 Data Schema Additions (Phase 0)

```sql
-- transactions (append-only, never delete)
transactions (
  id UUID PRIMARY KEY,
  owner_id UUID REFERENCES auth.users(id),
  collection_id UUID REFERENCES collections(id),
  document_id UUID REFERENCES documents(id),
  kind text, -- 'renewal_fee', 'take_rate', 'bnpl_interest', 'invoice_cut', 'interchange'
  status text, -- 'pending', 'completed', 'failed', 'refunded'
  currency text, -- AED, SAR, etc.
  amount numeric,
  fee_amount numeric, -- Finavig take-rate
  provider text, -- 'checkout.com', 'stripe', 'tabby', 'tamara'
  provider_ref text, -- PSP reference id
  idempotency_key UUID UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- ledger_entries (double-entry)
ledger_entries (
  id UUID PRIMARY KEY,
  transaction_id UUID REFERENCES transactions(id),
  account text, -- e.g. 'cash', 'accounts_receivable', 'credit_disbursement', 'credit_settlement'
  direction text, -- 'debit' | 'credit'
  amount numeric,
  created_at timestamptz DEFAULT now()
);

-- payment_methods (tokenized, never PAN)
payment_methods (
  id UUID PRIMARY KEY,
  owner_id UUID REFERENCES auth.users(id),
  provider_token text, -- PSP token; never stores PAN or full card number
  brand text, -- 'visa', 'mastercard', 'tabby', 'tamara'
  last4 text, -- last 4 digits (if applicable; may be masked)
  expiry text, -- expiry month/year (if applicable; may be masked)
  is_default boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- consents (legal backbone)
consents (
  id UUID PRIMARY KEY,
  owner_id UUID REFERENCES auth.users(id),
  scope text, -- e.g. 'renewal-payments', 'card-on-file', 'credit-offer', 'insurance-distribution'
  granted_at timestamptz DEFAULT now(),
  revoked_at timestamptz, -- null if still active
  policy_version text, -- e.g. 'v1.0', 'v1.1'
  created_at timestamptz DEFAULT now()
);
```

### 7.4 Edge Function Changes (Phase 0)

The `groq-proxy` Edge Function already handles Groq AI calls with per-tier quota. Add:

1. **`consume_payment_quota`** SQL function — similar pattern: decrement user's monthly payment-processing quota; refund credit on failure.
2. **`preview_renewal`** — new function that takes `document_id`, returns `amount`, `fee_amount` (take-rate), `provider_options`. Enforces tier quota.
3. **`initiate_renewal_payment`** — new function that starts the PSP checkout; returns checkout URL + idempotency key. Requires real user JWT.
4. **Webhook signature verification** middleware — verify PSP signature before processing webhook body.

All Edge Functions should remain Deno/TypeScript in `supabase/functions/`. The Groq key never ships in the client; all AI calls go through the function with user JWT.

### 7.5 UI Changes (Phased)

| Phase | UI Feature | Tier Gate |
|---|---|---|
| **Phase 0** | No UI changes needed (foundation) | N/A |
| **Phase 1** | "Renew now" CTA on document expiry card; amount preview before checkout; auto-renew toggle; Apple Pay / Google Pay buttons; BNPL badge (Tabby/Tamara) | `plus` / `business` gate |
| **Phase 2** | Renewal Wallet goal progress bar; "Set aside AED X for renewals" UI; multi-document auto-pay rule editor; invoice creation flow; corporate card virtual number display | `business` gate (some Plus features) |
| **Phase 3** | Credit offer banner on dashboard; credit score display; insurance option at renewal; cross-border payment UI | `business` gate (or separate add-on) |
| **Phase 4** | API keys management; bank account connection toggle; API usage dashboard; per-call quota display | `business` / `api` gate |

---

## 8. Risk Assessment & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **PSP integration fails / PSP goes out of business** | Low | High (no in-app renewals) | Integrate 2 PSPs in parallel (e.g., Checkout.com + Stripe); contract clauses for transition; keep UI modular so swapping PSP is a config change |
| **Regulatory change (CBUAE new rule)** | Medium | High (cannot hold funds / cannot process cards) | Stay in payment-facilitator mode as long as possible; use sandboxes; legal counsel on retainer; design architecture so licence-to-custody can be added later without rewriting core flows |
| **User trust: storing document scans** | Medium | Medium (uninstalls, PDPL complaints) | Device-local posture (bytes never leave phone); optional encrypted backup with clear disclosure; PDPL privacy policy explicit about data residency; one-tap data export + delete |
| **Notification reliability on aggressive Android OEMs** | High | High (missed renewal = fine + user churn) | OEM battery guidance shipped in-app; server-side `reminders` table + FCM path (future); real-device QA on Samsung, Xiaomi, Huawei, Oppo before Phase 1 launch; pre-permission explainer before OS prompt |
| **GCC regulatory divergence** (different rules per country) | Medium | Medium (feature must work across 6 countries) | Country-code isolation: every document/collection has `country_code`; all logic branches on it; data models already GCC-wide; new country = add catalog entry, not rewrite logic |
| **AI quota exhaustion / cost overruns** | Low | Medium (user complaints, bill shock) | Per-tier quotas enforced server-side; refund on upstream failure; explicit "use 1 credit?" confirmation before generating; Groq key rotation script; optional user-supplied Gemini key for heavy users |
| **Feature-flag drift (flag enabled for wrong tier)** | Low | Low (users see paywall incorrectly) | Centralised `EntitlementService` reads from `user_tiers`; every feature gate goes through `EntitlementFeature`; automated test that asserts flag/tier alignment |
| **Partner lender/broker renegotiates terms** | Medium | Medium (credit/insurance revenue vanishes) | Contracts with exit clauses; diversify 2+ partners per vertical; keep Finavig's data value independent (the renewal-payment history is Finavig's; partner is interchangeable) |
| **Cross-currency forecast aggregation** | Low | Medium (user sees negative balance due to FX) | Each collection carries its own currency; deliberately show cross-currency totals as informational only; avoid auto-conversion in forecast; UI clearly labels "AED total" vs "SAR total" |
| **App Store review rejection (payments, card collection)** | Medium | Medium (launch delay) | Submit to TestFlight / internal testing first; ensure Take-rate is disclosed before purchase; Apple/Google require clear pricing; have legal review App Store metadata before public launch |

---

## 9. Immediate Next Steps (This Quarter)

### Week 1–2: Phase 0 Foundation
- [ ] Create SQL migration for `transactions`, `ledger_entries`, `payment_methods`, `consents` tables
- [ ] Add Edge Functions: `preview_renewal`, `initiate_renewal_payment`, `consume_payment_quota`
- [ ] Add feature-flag table and `EntitlementService` reads
- [ ] Add `amount_due` column to `documents` table; populate from existing OCR data
- [ ] Survey 20 pilot users: "Would you pay this renewal here?" → document responses
- [ ] Book consult with UAE fintech lawyer on facilitation-model structure
- [ ] Set up PSP sandbox accounts with 2 providers (recommend: Checkout.com + Stripe, or Tabby for BNPL)

### Week 3–4: Phase 0 Validation + Phase 1 Spike
- [ ] Deploy Edge Functions to production Supabase project
- [ ] Test `preview_renewal` flow end-to-end with a demo document
- [ ] Implement "Renew now" CTA in Documents screen (initially disabled; shows "Coming Soon" for Free users)
- [ ] Add take-rate disclosure modal before payment checkout (even in sandbox)
- [ ] Set up idempotency key pattern on all payment-related writes
- [ ] Run full test suite (`flutter test`) to confirm no regressions
- [ ] Verify `groq-proxy` is deployed with `GROQ_API_KEY` set

### Week 5–6: PSP Integration Spike
- [ ] Implement hosted fields UI for card entry (PSP SDK or Stripe Elements lite)
- [ ] Test sandbox transaction: simulate AED 2,000 trade licence renewal
- [ ] Verify receipt attaches to document; status auto-updates to "renewed"
- [ ] Measure conversion: "Renew now" tap → completed payment
- [ ] Add auto-renew toggle on document detail screen (disabled for Free; gated to Plus)
- [ ] Document lessons learned; create checklist for full Phase 1 build

### Ongoing (Concurrent)
- [ ] Real-device notification QA on Samsung + Xiaomi + iOS (highest-value item; battery-saver pass)
- [ ] Privacy policy update covering GCC data residency + AI processing + PSP payments
- [ ] Store data-safety forms completed (Google Play Console)
- [ ] ErrorCaptureService → forward to Sentry (half-day task; already funnels every error)
- [ ] Frame-time baseline on mid-tier device using `PerfTracingService`

---

## Summary: Is Finavig on the Right Track?

**Yes — strongly.**

The app already possesses the critical wedge: **document expiry + known renewal fee + user trust at the moment of urgency**. The GCC market has no unified solution combining these elements. The existing codebase (525 tests, CI-garded, GCC-wide scope, freemium tiers, AI engine with server-held key) provides a solid foundation.

The transformation to fintech is **feasible in phases**, partner-first, and does not require building a bank or payment processor from scratch. The roadmap from Phase 0 (foundations) through Phase 1 (embedded payments) can begin within the current quarter, with regulatory compliance achievable via PSP facilitator model and sandboxes.

**The one non-negotiable investment:** real-device notification QA on aggressive Android OEMs. This is the component the lone developer cannot fully control and the one that most impacts renewal-alert reliability — the core promise of the app.

**Next concrete action:** Start Phase 0 this week (SQL migrations + Edge Functions + lawyer consult + 20-user survey). That is the enabler for everything that follows.

---
*End of Report*