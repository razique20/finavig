# Finavig — Complete Application & Feature Guide 🚀

> **AI-Powered Financial Intelligence, Cash-Flow Forecasting, and GCC Document Compliance Management.**

---

## 📌 1. What is Finavig?

**Finavig** is a comprehensive mobile and web application designed specifically for **personal users, freelancers, and businesses in the GCC (Gulf Cooperation Council)** region. It bridges the gap between **financial budgeting/cash-flow intelligence** and **document compliance management**.

In the GCC, unmanaged document expiries (such as trade licences, visas, Emirates IDs, or vehicle registrations) lead to immediate government fines, impoundment, or frozen bank accounts. At the same time, unpredictable renewal fees can destabilize cash flow if not planned in advance.

Finavig solves this problem by combining:
1. **Document Expiry & Fine Prevention**: Tracking expiries, calculating estimated renewal costs, and forecasting government penalties.
2. **Financial Ledger & Cash-Flow Intelligence**: Tracking income, expenses, category budgets, savings envelopes, borrowed/lent credit, and 90-day cash forecasts.
3. **Groq AI Engine**: Generating unified executive summaries and goal-driven AI budget plans with tier quota controls — metered server-side through the `groq-proxy` Edge Function so the shared key never ships in the app.
4. **Smart Automation**: Voice and text natural language entry, OCR scanning, and automatic category prediction.
5. **Account Security**: Welcome → quiz-style login → onboarding, plus an optional local App Lock (6-digit passcode + biometric unlock).

---

## 🌐 2. Multi-GCC Currency & Regionalization

Finavig natively supports all 6 GCC national currencies and adjusts all calculations, money parsing, and AI prompts dynamically based on the user's active country selection:

| Country | Flag | Currency Code | Supported Authority Catalogs |
| :--- | :---: | :---: | :--- |
| **United Arab Emirates** | 🇦🇪 | `AED` | RTA, GDRFA, MOHRE, ICP, Dubai Municipality, DED |
| **Saudi Arabia** | 🇸🇦 | `SAR` | ZATCA, Absher, Qiwa, Muqeem, CR |
| **Qatar** | 🇶🇦 | `QAR` | Metrash2, Ministry of Interior, MOCI |
| **Kuwait** | 🇰🇼 | `KWD` | PACI (Civil ID), MOI Kuwait, PAM |
| **Bahrain** | 🇧🇭 | `BHD` | Sijilat, LMRA, Information & eGovernment Authority |
| **Oman** | 🇴🇲 | `OMR` | ROP, Invest Easy, Ministry of Labour |

---

## ✨ 3. Core Features Breakdown

### 📁 A. Document Expiry & Compliance Tracking
- **Multi-Collection Scoping**: Organize documents under **Personal** collections or custom **Business / Company** collections.
- **Pre-configured Document Types**: Built-in rules for Emirates ID / Civil ID, Trade Licences, Commercial Registration, Visas, Passports, Vehicle Registrations, Tenancy Contracts, Insurance, and Software Subscriptions.
- **Custom Document Types**: Create user-defined document types with custom renewal cycles and issuing authorities.
- **Penalty & Fine Risk Estimates**: Real-time calculation of potential fines if documents expire (e.g. *Driver Licence expired → Fine 500 + 12 black points*).
- **OCR Scan & Attachment Extraction**: Built-in text recognition powered by **Google ML Kit** to automatically scan documents, pull expiry dates, and attach PDF/image files.
- **Smart Reminders**: Automated notifications scheduled 90, 60, and 30 days before expiration.

---

### 💸 B. Financial Ledger & Cash-Flow Intelligence
- **Unified Transaction Ledger**: Log income and expense line items tagged by collection, payment method, category, and attached document.
- **90-Day Cash-Flow Forecast**: Daily balance projection that merges historical spending habits, recurring commitments, and upcoming document renewal fees into a forward-looking cash curve.
- **Category Budget Caps**: Define monthly spending limits per category (*Rent, Salaries, Utilities, Marketing, Transport, Software, Suppliers, Food & Beverages, Shopping, Medical, Entertainment, Other*) with visual utilization bars and 80%/100% threshold alerts.
- **Savings Envelopes**: Virtual savings targets (e.g. *MacBook Fund, Emergency Reserve*) where users allocate monthly contributions and track progress.
- **Recurring Schedules**: Engine that automatically logs recurring monthly, quarterly, or annual fixed commitments.
- **Credit Book (Borrowed / Lent)**: Track obligations with a counterparty — name, phone, amount, currency, description, deadline, extension history and a settled state. Cards show open vs settled, overdue/deadline chips and a WhatsApp follow-up sheet. Creating or settling a credit can **optionally** write the matching cash movement into the ledger; the two rows are tagged (`credit_id` / `credit_leg = disbursement | settlement`) so they show a **Credit** badge and are excluded from income/expense totals, budgets, the 6-week chart and AI summaries. Full design: [`docs/credit-money-sync.md`](docs/credit-money-sync.md).

---

### 🧠 C. Groq AI Engine (AI Summary & AI Planner)

Finavig includes an AI engine powered by **Groq** for high-speed financial analysis:

1. **AI Executive Summary**:
   - Merges active document expiries, pending renewal fees, monthly spending patterns, and net cash position into a concise 2–3 sentence executive narrative.
   - Includes actionable insights and alert cards.

2. **AI Budget Planner**:
   - Takes a user's financial goal (e.g. *"Buy a delivery van for AED 25,000"*) and target deadline.
   - Evaluates the user's real 3-month spending average and upcoming renewal obligations.
   - Generates concrete, step-by-step actionable recommendations (create envelope, cap category budget, trim flexible spend).
   - Includes ready-made budget templates (*Comfortable*, *Balanced*, *Goal-first*) with interactive slider adjustments and a live Goal-Health score meter.

3. **Quota & Confirmation Management**:
   - Monthly quota limits enforced based on subscription tier (Free / Plus / Business), **server-side** by the `groq-proxy` Supabase Edge Function (`consume_ai_quota` SQL function) so a modified client cannot exceed them.
   - The function requires a real user JWT (the public anon key is rejected with `401`) and holds the Groq API key as a function secret — the client never sees it.
   - The credit is refunded if the upstream Groq call fails (`502 groq_error`, never a fake `401`).
   - Syncs usage with the Supabase `ai_quota_usage` table with offline `SharedPreferences` caching.
   - Explicit confirmation modal dialogs (*"Use 1 credit from your monthly quota?"*) before generating new requests.
   - Persistent display of the previous last generated AI summary or plan without consuming quota.

---

### ⚡ D. Smart Automation & AI Helpers
- **Natural Language Quick-Add (Text & Voice)**: Type or speak prompts (e.g. *"Paid 1,200 SAR for office rent today"*) and Finavig automatically parses the amount, currency, category, date, and transaction kind.
- **Smart Auto-Categorization**: Pure Dart engine combining fuzzy Levenshtein distance matching, GCC vendor dictionaries (*Talabat, Salik, DEWA, Etisalat, Aramenco*), and persistent user habit learning.
- **Bill Spike & Anomaly Detection**: Moving average statistical engine that detects unusual expense spikes (e.g. *DEWA bill 35% higher than 3-month average*) and ignores credit-linked ledger rows.

---

### 🔐 E. Onboarding, Accounts & App Lock
- **Welcome screen**: first-launch dark brand landing — the `Finavig` headline, a WhatsApp-style thread of quote bubbles with a quoted reply, and a single *Continue to Login* CTA that marks the welcome as seen.
- **Quiz-style Login / Sign-up**: one question per step with per-step validation. Step 0 asks what kind of user you are and routes into the 3-step sign-in quiz (email → password) or the 6-step sign-up quiz (adds date of birth, GCC country and phone). The screen always renders the dark brand theme so welcome → login reads as one flow, and it hosts the legal (terms/privacy) dialogs.
- **App Lock**: an optional 6-digit re-entry passcode with biometric unlock (`local_auth`), layered *on top of* the Supabase session. Only a salted, iterated SHA-256 hash is persisted, in iOS Keychain / Android Keystore — never the passcode itself. Repeated wrong entries trigger a persisted escalating lockout; "Forgot passcode" signs the user out so they re-authenticate with their password. It never locks while signed out.

---

## 💳 4. Subscription Tiers & Entitlements

Finavig enforces a 3-tier monetization framework (`EntitlementService`):

| Feature | 🆓 Free Tier | ⚡ Plus Tier | 🏢 Business Tier |
| :--- | :---: | :---: | :---: |
| **Tracked Documents** | Up to 10 | Unlimited | Unlimited |
| **Document Collections** | Personal + 1 Company | Unlimited | Unlimited |
| **Groq AI Summaries** | 3 / month | 15 / month | 40 / month |
| **AI Budget Plans** | 2 / month | 10 / month | 25 / month |
| **Team / Admin Access** | Single User | 2 Users | Unlimited Team |
| **Local App Lock** | ✅ | ✅ | ✅ |

Quota numbers mirror `lib/models/subscription_tier.dart` (`groqAiSummaryMonthlyQuota`, `aiBudgetPlanMonthlyQuota`) and the same table inside `supabase/functions/groq-proxy/index.ts`; the Edge Function is the enforcement point.

---

## 🛠️ 5. Technical Architecture & Stack

```
   ┌─────────────────────────────────────────────────────────────┐
   │                        Finavig UI Layer                        │
   │   (Home, Documents, Money Ledger, AI Summary, AI Planner)   │
   └──────────────────────────────┬──────────────────────────────┘
                                  │
   ┌──────────────────────────────▼──────────────────────────────┐
   │                   State & Service Layer                     │
   │  DocumentScannerService · FinanceService · CollectionService│
   │  CreditService · AiExecutiveSummaryService · AiBudgetPlanService│
   │  EntitlementService · AppLockService · GroqApiService        │
   └──────────────┬──────────────────────────────┬───────────────┘
                  │                              │
   ┌──────────────▼──────────────┐  ┌────────────▼──────────────┐
   │       Supabase Cloud        │  │  Supabase Edge Function    │
   │ (PostgreSQL + RLS + Storage)│  │  groq-proxy (holds the key,│
   │  + user_tiers + ai_quota    │  │  meters quota per tier)    │
   └─────────────────────────────┘  └────────────┬──────────────┘
                                                 │ server-held key
                                    ┌────────────▼──────────────┐
                                    │     Groq AI API           │
                                    │ (gpt-oss-120b JSON engine)│
                                    └───────────────────────────┘
```

- **Frontend**: Flutter 3.x (Dart 3.11+)
- **Routing**: `go_router`
- **Backend & DB**: Supabase (PostgreSQL with Row Level Security policies)
- **AI transport**: Supabase Edge Function `groq-proxy` (Deno/TypeScript) — holds the Groq key, verifies the user JWT, meters the tier quota
- **Local Storage**: `shared_preferences` & `path_provider` (+ platform secure storage for the App Lock hash)
- **OCR Engine**: `google_mlkit_text_recognition`
- **Speech Engine**: `speech_to_text`
- **Biometrics**: `local_auth`
- **Notifications**: `flutter_local_notifications` & `timezone`
- **PDF & Export**: `pdf`, `printing`, CSV exporter

---

## 🗄️ 6. Supabase Database Tables

- **`collections`**: User document containers (`is_personal` flag for primary personal collection).
- **`documents`**: Metadata for tracked documents, renewal fees, expiry dates, and file storage paths.
- **`finance_transactions`**: Income and expense line items linked to collections and documents, plus the optional credit link (`credit_id`, `credit_leg`).
- **`category_budgets`**: Monthly spending limits per category.
- **`savings_envelopes`**: Savings goal progress and monthly allocations.
- **`recurring_transactions`**: Recurrence templates for automated line items.
- **`credit_entries`**: Borrowed/lent obligations — counterparty, amount, currency, deadline, `extension_history`, `settled_at`, and the linked disbursement/settlement transaction ids.
- **`user_tiers`**: Subscription plan levels (`free`, `plus`, `business`) and plan duration.
- **`ai_quota_usage`**: Monthly AI generation usage counters per user (`groq_ai_summary`, `groq_ai_budget_plan`).
- **`app_versions`**: Splash update-check table.
- **`support_requests`**: In-app support/upgrade request tickets with status tracking.

---

## 🚀 7. Quick Start & Execution

### Run locally:
```bash
flutter pub get
flutter run
```

### Execute Unit Tests:
```bash
flutter test
```

### Apply Supabase SQL Schemas:
Run the following idempotent scripts in Supabase SQL Editor:
1. `supabase/schema.sql` (Core document schemas & RLS)
2. `supabase/finance_schema.sql` (Finance ledger tables)
3. `supabase/credit_schema.sql` (Credit tracker + credit link columns)
4. `supabase/user_tiers_schema.sql` (Subscription tiers table)
5. `supabase/ai_quota_schema.sql` (AI quota usage database table)
6. `supabase/ai_quota_proxy_schema.sql` (server-side `consume_ai_quota` function used by the Edge Function)
7. `supabase/app_version_schema.sql` (splash update check)

### Deploy the AI proxy (keeps the Groq key off the client):
```bash
supabase secrets set GROQ_API_KEY=gsk_your_real_key
supabase functions deploy groq-proxy
```
See `supabase/functions/groq-proxy/README.md` for the full runbook, verification curl and troubleshooting table.

---
*Document created for Finavig Release v1.0.0.*
