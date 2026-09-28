# Finavig — Documentation

Everything you need to understand, run, and evaluate Finavig.

> **Finavig** is an AI-powered financial budgeting & cash-flow intelligence app with built-in document expiry tracking, built for the UAE: plan budgets, forecast cash, and keep every trade licence, visa, Emirates ID, insurance and subscription countdown — and the money to renew it — on one dashboard. Speak or type one sentence ("Log DEWA bill of 450 AED", "Add Emirates ID expiring 14 Oct 2027") and Finavig routes it, parses it, and asks for one confirmation.

## 📚 Documents

| Document | What's inside |
|---|---|
| **[Technical documentation](technical-documentation.md)** | System architecture, data model & schema, the offline-first sync engine (outbox + LWW merge), the AI layer (Groq routing, voice, OCR), performance instrumentation & CI guards, every feature explained with screenshots, notifications, build & test guide, migrations, known limitations |
| **[Market study](market-study.md)** | The UAE expiry problem in numbers, target segments, competitive landscape (government apps vs calendars vs PRO agents), positioning, demand estimate, monetization options, market risks |
| **[Feasibility study](feasibility-study.md)** | Technical / operational / financial / legal verdicts, remaining risks, effort-to-launch estimate, go-to-market channels, validation metrics, and the go/no-go pilot checklist |

Other project-level docs (repo root): [`../PRODUCTION_READINESS.md`](../PRODUCTION_READINESS.md) (pre-launch audit), [`../FINTECH_ROADMAP.md`](../FINTECH_ROADMAP.md), [`../APP_OPTIMIZATION_ROADMAP.md`](../APP_OPTIMIZATION_ROADMAP.md) (performance wave — implemented), [`../README.md`](../README.md) (quick start).

## 🖼️ Screenshot gallery

Captured from a real app build with seeded demo data. Click any image for full size. All files live in [`screenshots/`](screenshots/).

### First run & accounts

| | |
|---|---|
| **Permission dialog** — notifications explained before the OS prompt | **Splash & version gate** — checks `app_versions` for updates on every launch |
| ![Permission dialog](screenshots/00-permission-dialog.png) | ![Splash](screenshots/01-splash.png) |
| **Welcome** — first-launch landing | **Welcome CTA** — sign in or explore local-only |
| ![Welcome](screenshots/02-welcome.png) | ![Welcome CTA](screenshots/03-welcome-cta.png) |
| **Login** — quiz-style onboarding flow matching the app theme | **Sign-up form** |
| ![Login](screenshots/04-login.png) | ![Sign-up](screenshots/05-signup-form.png) |

### Core dashboards

| | |
|---|---|
| **Home dashboard** — categories grid, plan-restriction/attention/expired banners, next renewals, collection switcher, live month balance with action pills | **Money dashboard** — overall + per-category budgets with 80/100% alerts, bill-spike detection, spending pace, 6-week chart, renewal outlook |
| ![Home](screenshots/06-home.png) | ![Money](screenshots/07-money.png) |
| **Documents radar** — urgency-tinted cards with renewal-window progress, fees, reminder state; inline search, filter chips, type filter & sort sheets | **Profile (Settings)** — modular sections: account, subscription with usage meters, collections, appearance, preferences, AI summary key, help & support |
| ![Documents](screenshots/08-documents.png) | ![Profile](screenshots/09-profile.png) |

### Money features

| | |
|---|---|
| **Budgets** — overall monthly cap + per-category limits with progress meters | **Envelopes** — savings goals, tracked only (no money moves — pre-licence stance) |
| ![Budgets](screenshots/10-budgets.png) | ![Envelopes](screenshots/11-envelopes.png) |
| **Renewals / expiry list** — flat chronological view with CSV/PDF export and urgency/type filters | **Records** — month-grouped transactions with smart-category matching |
| ![Renewals](screenshots/12-renewals.png) | ![Records](screenshots/13-records.png) |
| **90-day cash-flow forecast** — daily balance simulation including renewal outflows, filterable event list | **AI Executive Summary** — monthly natural-language financial report (templates offline, optional Gemini polish) |
| ![Forecast](screenshots/14-forecast.png) | ![AI summary](screenshots/15-ai-summary.png) |

### AI & capture

| | |
|---|---|
| **Scan & OCR** — ML Kit pre-fills title, type, expiry, emirate & authority from an image | **Companion suggestions** — "businesses tracking this also track…" after adding a document |
| ![Scan](screenshots/16-scan.png) | ![Companion suggestions](screenshots/17-companion-suggestions.png) |
| **Home with tracked documents** — banners and renewal tiles populated | **Document detail** — urgency timeline (90·60·30·7), renewal checklist, history, attachments with cached thumbnails |
| ![Home with documents](screenshots/18-home-with-doc.png) | ![Document detail](screenshots/19-document-detail.png) |
| **Document detail (bottom)** — attachment card, share, renewal process | **Global search** — across names, notes, authorities, files, all collections |
| ![Document detail bottom](screenshots/20-document-detail-bottom.png) | ![Global search](screenshots/21-global-search.png) |
| **Notifications sheet** — upcoming renewals, expired docs, bill spikes, budget alerts in one place | |
| ![Notifications sheet](screenshots/22-notifications-sheet.png) | |

### Onboarding flow

| | | |
|---|---|---|
| ![Onboarding 1](screenshots/23-onboarding.png) | ![Onboarding 2](screenshots/24-onboarding-2.png) | ![Onboarding 3](screenshots/25-onboarding-3.png) |
| ![Onboarding 4](screenshots/26-onboarding-4.png) | ![Onboarding 5](screenshots/27-onboarding-5.png) | |

### Quick add — speak or type one sentence

| | |
|---|---|
| **Money record sheet** — quick add from the nav "＋" or hero Record pill | **Transaction form** — full edit with smart category pre-fill |
| ![Money record sheet](screenshots/28-money-record-sheet.png) | ![Transaction form](screenshots/28-transaction-form.png) |
| **AI category suggestion** — learns your corrections | **Records with data** — month-grouped history |
| ![AI category suggestion](screenshots/29-ai-category-suggestion.png) | ![Records with data](screenshots/30-records-with-data.png) |
| **Natural-language add** — "Paid 450 AED for DEWA yesterday" → parsed, categorized, confirmed | |
| ![Natural language add](screenshots/31-natural-language-add.png) | |

## 🗂️ Database & migrations

| File | Purpose |
|---|---|
| [`../supabase/schema.sql`](../supabase/schema.sql) | Core schema: collections, documents, reminders, custom types + RLS + pg_cron reminder scan (idempotent) |
| [`../supabase/finance_schema.sql`](../supabase/finance_schema.sql) | Finance tables: transactions, budgets, envelopes, recurring |
| [`../supabase/migrate_documents_local_only_fields.sql`](../supabase/migrate_documents_local_only_fields.sql) | Adds `location`, `renewal_history`, `custom_reminder_days` to existing projects |
| [`../supabase/migrate_companies_to_collections.sql`](../supabase/migrate_companies_to_collections.sql) | Legacy single-company model → collections |
| [`../supabase/app_version_schema.sql`](../supabase/app_version_schema.sql) | Splash update-check table |

## 🔧 Maintenance

- **Tests:** `flutter test` (23 suites, 305+ tests — sync contract, finance math, AI routing, UI redesign contracts, goldens). **Analyzer:** `flutter analyze`. **File-size budget:** `dart run tool/perf_budget_check.dart`. All three run in CI (`.github/workflows/ci.yml`).
- When a feature changes the UI materially, re-capture the relevant screenshot into `docs/screenshots/` and update both the gallery above and the feature section in the technical documentation.
