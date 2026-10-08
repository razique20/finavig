# Finavig 🚀

> **AI-powered budgeting & cash-flow intelligence — with every document expiry tracked and every renewal fee forecast.**  
> **Finavig** is a financial budgeting & intelligence platform for personal & small-business use, with built-in document expiry tracking and renewal alerts. Built for mobile and web.

📚 **Project documentation** lives in [`docs/`](docs/): [technical documentation](docs/technical-documentation.md), [architecture & workflows](ARCHITECTURE.md), [credit ↔ Money sync](docs/credit-money-sync.md), [market study](docs/market-study.md), [feasibility study](docs/feasibility-study.md), the [launch playbook](docs/launch-playbook.md) (run, ship and win the first users), and a [screenshot gallery](docs/README.md#-screenshot-gallery) of every feature.

---

## 🌟 Key Features

### 💸 1. Financial Intelligence & Budgeting
- **Unified Ledger**: Track income and expense transactions (`finance_transactions`) tagged by collection, category and payment method.
- **Credit Book — Borrowed / Lent**: Track money owed to people and money owed to you (`credit_entries`): counterparty, phone, amount, deadline, extensions and a settled state, with WhatsApp follow-up prompts. Creating or settling a credit can **optionally** write the matching cash movement into the ledger (`credit_id` / `credit_leg` tags on `finance_transactions`), so a loan is never double-counted as income or expense — credit-linked rows carry a **Credit** badge and are excluded from income/expense totals, budgets, charts and AI summaries. See [`docs/credit-money-sync.md`](docs/credit-money-sync.md).
- **Category Budgets**: Set monthly spending limits per category (`renewals`, `salaries`, `rent`, `utilities`, `suppliers`, `marketing`, `transport`, `software`, `sales`, `other`) with visual budget utilization and 80/100% alerts.
- **90-Day Cash-Flow Forecast**: Daily balance simulation that folds in recurring bills and upcoming renewal fees, with dip/lowest-balance detection.
- **Savings Envelopes**: Virtual piggy banks (`savings_envelopes`) for goal tracking and monthly contribution allocation.
- **Recurring Schedules**: Template engine (`recurring_transactions`) that automatically logs monthly, quarterly, or annual fixed costs.

### 📁 2. Document Expiry Tracking
- **Multi-Entity Scoping**: Group documents into built-in **Personal** collections or custom **Company / Business** collections.
- **Expiry Horizon Tracking**: Monitor renewals for Emirates ID, Trade Licences, Visas, Passports, Vehicle Registrations, Tenancy Contracts, Insurance, and Subscriptions.
- **Custom Document Types**: Create custom document classifications with user-defined renewal cycles and authority details.
- **Smart Reminders**: Automated push & local notifications triggered 30, 60, and 90 days prior to expiration.
- **OCR Scan & Attachment**: Instant document detail extraction powered by **Google ML Kit Text Recognition** and PDF preview/printing.

### 🧠 3. Smart AI Engine & Automation
- **Natural Language Quick Add**: Parse complex text or voice prompts (e.g. *"Paid AED 450 for DEWA utilities yesterday"*) into structured transactions or document reminders automatically.
- **Smart Auto-Categorization**: Pure Dart string matching engine combining Levenshtein distance, UAE vendor dictionaries (e.g. *Talabat, Salik, DEWA, Etisalat*), and persistent user habit learning.
- **Bill Spike & Anomaly Detection**: Statistical moving average and standard deviation analysis to highlight price hikes (e.g. utility bills 35% higher than 3-month baseline).
- **Server-side AI proxy**: the shared Groq key lives in a Supabase Edge Function (`supabase/functions/groq-proxy`), never in the app. It requires a real user JWT, enforces the tier's monthly quota server-side (`consume_ai_quota`), and refunds the credit if the upstream call fails.

### 🔐 4. Onboarding, Accounts & App Lock
- **Welcome screen**: dark brand landing with a WhatsApp-style quote thread and a single *Continue to Login* CTA.
- **Quiz-style login**: one question per step — step 0 asks what kind of user you are and routes into sign-in (3 steps) or sign-up (6 steps: email → password → date of birth → country → phone). The screen always renders the dark brand theme, matching the welcome page.
- **App Lock**: optional 6-digit re-entry passcode with biometric unlock, layered on top of the Supabase session. Only a salted, iterated SHA-256 hash is stored, in platform secure storage (iOS Keychain / Android Keystore), with a persisted escalating lockout. "Forgot passcode" signs the user out rather than weakening the lock.

---

## 🛠️ System Architecture & Tech Stack

| Component | Technology / Library |
| :--- | :--- |
| **Frontend Framework** | Flutter 3.x (Dart 3.11+) |
| **Routing & State** | `go_router`, State-driven ChangeNotifier services |
| **Backend & Database** | **Supabase** (PostgreSQL with Row Level Security) |
| **Storage** | Supabase Storage Buckets for document scans |
| **OCR & Vision** | `google_mlkit_text_recognition` |
| **Voice & Speech** | `speech_to_text` |
| **Notifications** | `flutter_local_notifications` & `timezone` |
| **Reporting & Export** | `pdf`, `printing`, CSV Exporter |
| **AI / LLM** | Groq via the `groq-proxy` Edge Function (server-held key + per-tier quota), optional user-supplied Gemini key |
| **App Lock** | `local_auth` (biometric unlock) + platform secure storage for the salted passcode hash |

---

## 🗄️ Database Schema Summary

The backend uses a multi-tenant, collection-based model in Supabase:

- **`collections`**: User document containers (`is_personal` boolean for owner's personal docs).
- **`documents`**: Document metadata, expiry dates, renewal fees, assigned owners, and attachment paths.
- **`reminders`**: Scheduled notification logs (Push, Email, WhatsApp).
- **`custom_document_types`**: User-defined document rules and default validity periods.
- **`finance_transactions`**: Income/expense line items linked to collections and optional documents, plus the optional credit link (`credit_id` / `credit_leg = disbursement|settlement`).
- **`category_budgets`**: Monthly spending limits per collection/category.
- **`savings_envelopes`**: Savings targets and current progress.
- **`recurring_transactions`**: Recurrence templates for automated expense logging.
- **`credit_entries`**: Borrowed/lent obligations — counterparty, amount, deadline, extension history, `settled_at` and the linked disbursement/settlement transactions.
- **`user_tiers`**: Subscription tier per user (read-only in the app; granted server-side).
- **`ai_quota_usage`**: Monthly AI generation counters (`groq_ai_summary`, `groq_ai_budget_plan`).
- **`app_versions`**: Splash update-check table.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.11.0`)
- [Dart SDK](https://dart.dev/get-dart)
- A Supabase Project ([supabase.com](https://supabase.com))

### 1. Installation
Clone the repository and install dependencies:
```bash
git clone https://github.com/razique20/wazy-app.git
cd finavig
flutter pub get
```

### 2. Backend Setup
1. Execute `supabase/schema.sql` in your Supabase SQL Editor.
2. Execute `supabase/finance_schema.sql` to initialize the financial ledger tables.
3. Execute `supabase/credit_schema.sql` for the credit tracker (`credit_entries` + the credit link columns).
4. Execute `supabase/user_tiers_schema.sql` and `supabase/ai_quota_schema.sql` for tiers and AI quota, then `supabase/ai_quota_proxy_schema.sql` for the server-side quota function.
5. Deploy the AI proxy so the Groq key stays off the client (see [`supabase/functions/groq-proxy/README.md`](supabase/functions/groq-proxy/README.md)):
   ```bash
   supabase secrets set GROQ_API_KEY=gsk_your_real_key
   supabase functions deploy groq-proxy
   ```
6. Configure your Supabase credentials in `lib/config/app_credentials.dart`:
   ```dart
   class AppCredentials {
     static const String supabaseUrl = 'YOUR_SUPABASE_URL';
     static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

### 3. Run the App
Launch on iOS, Android, or Web:
```bash
flutter run
```

---

## 🧪 Testing & Quality Assurance

Run the comprehensive unit and integration test suite:
```bash
flutter test
```
*Current test suite: **525 passing unit & widget tests** across 54 suites covering document expiry math, financial category rules, credit ↔ Money sync, anomaly detection thresholds, budget tracking, App Lock, and complete end-to-end flows (see [`docs/app-test-report.md`](docs/app-test-report.md) and [`docs/credit-money-sync-verification.md`](docs/credit-money-sync-verification.md)).*

---

## 💻 Web Admin Console

The admin console is a separate codebase and is not part of this repository. Tier grants and AI quotas are managed server-side with the service-role key against the `user_tiers` / `ai_quota_usage` tables; see [`ARCHITECTURE.md`](ARCHITECTURE.md) §7 for the auth & entitlements flow.


For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
