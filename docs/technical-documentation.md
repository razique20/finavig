# Finavig — Technical Documentation

> Version 1.0.0 · Flutter 3.x / Dart ^3.11 · Backend: Supabase (PostgreSQL + Auth)
> Audience: developers joining the project. Read this top-to-bottom once; keep [docs/README.md](README.md) bookmarked.

Finavig is an AI-powered financial budgeting & cash-flow intelligence app with integrated personal/company document expiry tracking, built for the UAE market. One Flutter codebase ships to Android and iOS; a web build exists for the demo/docs flow.

---

## Table of contents

1. [System overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Data model](#3-data-model)
4. [Offline-first sync engine](#4-offline-first-sync-engine)
5. [Feature reference (with screenshots)](#5-feature-reference-with-screenshots)
6. [Alerts & notifications](#6-alerts--notifications)
7. [Performance & testing infrastructure](#7-performance--testing-infrastructure)
8. [Project layout](#8-project-layout)
9. [Build, run, test](#9-build-run-test)
10. [Database migrations](#10-database-migrations)
11. [Known limitations & roadmap](#11-known-limitations--roadmap)

---

## 1. System overview

```
┌────────────────────────────┐         ┌─────────────────────────────────┐
│  Flutter app (iOS/Android) │         │  Supabase project               │
│                            │         │                                 │
│  UI (screens/widgets)      │  HTTPS  │  ├─ PostgreSQL (RLS per user)   │
│      │                     │ ──────► │  │    collections               │
│  Service layer             │  REST   │  │    documents                 │
│  (ChangeNotifier singletons│         │  │    finance_*                 │
│   + local cache)           │ ◄────── │  ├─ Auth (email/password)       │
│      │                     │         │  ├─ Storage (future: attachments)│
│  SharedPreferences cache   │  push   │  └─ pg_cron → reminders scan    │
│  + outbox queue            │ (local) │                                 │
└────────────────────────────┘         └─────────────────────────────────┘
```

**Design rule:** the local cache is always the source of truth for the UI. Supabase is synced in the background; failures degrade to "sync later", never to a broken screen.

**Local-only mode:** if no Supabase credentials are configured (`lib/config/app_credentials.dart`), every service silently operates on the local cache. The app is fully usable offline, forever. This is also how unit tests run.

---

## 2. Architecture

### 2.1 Layers

| Layer | Location | Pattern |
|---|---|---|
| Presentation | `lib/screens/`, `lib/widgets/` | Stateless widgets consuming service singletons; `go_router` for navigation (hash routing on web) |
| Application services | `lib/services/` | `ChangeNotifier` singletons (`X.instance`); own loading, caching, and remote sync |
| Domain models | `lib/models/` | Immutable data classes with `fromJson`/`toJson` + pure computation helpers (`FinanceMath`, `RecurrenceMath`, `DocSync`, `UrgencyLevel`) |
| Persistence | Supabase tables + `SharedPreferences` | Remote-first when configured, local-first otherwise |
| Cross-cutting | `lib/theme/`, `lib/config/` | `FinavigTheme` light/dark; credentials constants |

### 2.2 Key services

| Service | Responsibility |
|---|---|
| `SupabaseService` | One-time init, `clientOrNull` (never throws — callers degrade gracefully) |
| `AuthService` | Session restore, `currentUserId` |
| `DocumentCollectionService` | Personal + company collections; active-collection selection |
| `DocumentScannerService` | The document store: CRUD, search, renewal, outbox sync, row mapping |
| `FinanceService` | Transactions, budgets, envelopes, recurring templates, cash-flow inputs |
| `NotificationService` | OS-level reminder ladder (90/60/30/7 days) + budget alerts via `flutter_local_notifications` |
| `BudgetAlertService` / `AlertPreferencesService` | 80%/100% budget alert engine and per-user toggles |
| `SmartCategoryEngine` | Levenshtein + UAE vendor dictionary auto-categorization with habit learning |
| `AnomalyDetectionService` | Moving-average/σ bill-spike detection |
| `UaeDocumentOcrService` | ML Kit text recognition → structured UAE document fields |
| `NaturalLanguageParserService` | "Paid AED 450 for DEWA yesterday" → transaction/document drafts (shared by text and voice) |
| `AiIntentRouterService` | Routes one freeform utterance to money vs document flow: local keyword lexicon first (free), Groq `openai/gpt-oss-20b` only for the ambiguous remainder; exact-input memo (LRU 200, disk-persisted) + rolling 12-per-day escalation budget shared by every AI entry point |
| `VoiceInputService` | Speech-to-text with live partial transcripts; spoken numbers normalized ("four hundred fifty dirhams" → "450 AED") |
| `GeminiApiService` | Optional LLM polish for the AI executive summary (user-supplied key, on-device) |
| `MonthlySummaryService` | Aggregates month-over-month spend, top movers, budget overruns & envelope projections into the executive summary narrative |
| `CompanionSuggestionService` | "Businesses tracking X also track Y" pools shown after adding a document |
| `PerfTracingService` | DevTools Timeline sections for the critical flows + optional frame-time monitor (debug/profile only) |
| `AppVersionService` | Splash-time version check against an `app_versions` table |

### 2.3 Presentation architecture

The four tab screens are modularized under `lib/screens/` so each section widget rebuilds independently (each former monolith is now a thin shell composing section modules):

| Screen shell | Modules |
|---|---|
| `home_screen.dart` (259 lines) | `home/` — hero header + notification bell, tier-aware collection switcher, plan/attention/expired banners, categories grid, upcoming-renewals section |
| `money_screen.dart` (~860 lines) | `money/` — summary cards, planning cards, rows, form sheets, shared section primitives |
| `documents_screen.dart` (394 lines) | `documents/` — hero header, filters (search/chips/type/sort sheets), insight tiles, document card, action sheets |
| `profile_screen.dart` (424 lines) | `profile/` — hero, account, subscription, collections, appearance, shared section primitives, bottom sheets |

Shared cross-screen widgets: `widgets/hero_widgets.dart` (frosted `HeroIconButton` + `HeroActionPill` used by all four heroes), `widgets/cards/urgency_timeline_card.dart` (the single 90·60·30·7 alert-ladder implementation), `widgets/attachment_thumbnail.dart` (`AttachmentImage` — downsampled local decode + disk-cached cloud fetches), `widgets/viewers/full_screen_image_viewer.dart` (pinch-to-zoom viewer).

Static copy (FAQ, app guide) lives in `lib/config/` as plain data (`faq_content.dart`, `app_guide_content.dart`); the widgets render it generically, so content edits never touch widget code.

### 2.4 Navigation

`lib/router.dart` — `go_router` with an auth redirect gate (active only when Supabase is configured):

- `/` splash → `/onboarding` (first run) or `/home`
- `/login` when auth is available but no session
- Full-screen routes above the shell: `/scan`, `/document/:id`, `/document/:id/edit`, `/search`, `/expiry-list`, `/cash-flow-forecast`, plus focused Money sub-pages (`/budgets`, `/envelopes`, `/records`, `/ai-summary`, `/ai-budget-plan`, `/alerts-reminders`)
- `StatefulShellRoute.indexedStack` with 4 branches: `/home`, `/money`, `/documents`, `/profile` — bottom nav with live badges (documents needing attention; budget 80/100% dot) and a center "＋" quick-action button opening the universal quick menu

---

## 3. Data model

### 3.1 Supabase tables (see `supabase/schema.sql`, `supabase/finance_schema.sql`)

**`collections`** — one built-in Personal row per user (`is_personal`, unique per owner) + optional company collections.

**`documents`** — the core table:

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | client-generated (uuid v4) |
| `owner_id` | uuid → auth.users | RLS-scoped |
| `collection_id` | uuid → collections | FK; local pseudo ids are remapped on push |
| `doc_type` | text | built-in key (e.g. `tradeLicence`) or `custom-<uuid>` |
| `display_name` | text | |
| `expires_at` | date | |
| `reminder_days` | int | default 30 (14 for software subscriptions) |
| `status` | text | `active` / `renewed` / `expired` / `archived` |
| `assigned_to` | text | |
| `renewal_fee` | numeric(10,2) | |
| `notes` | text | description or fallback warning |
| `file_name` / `file_path` / `file_size` | text / text / bigint | attachment metadata; the file itself lives on-device |
| `location` | text | issuing authority + emirate as entered (synced since v1.1) |
| `renewal_history` | jsonb | array of `RenewalRecord` objects (synced since v1.1) |
| `custom_reminder_days` | int[] | user alert offsets overriding the 90/60/30/7 ladder (synced since v1.1) |
| `created_at` / `updated_at` | timestamptz | `updated_at` maintained by the `trg_documents_updated_at` trigger — the client never sends it |

**`reminders`** — notification log (document, `remind_at`, channel `push/email/whatsapp`, `sent_at`). Populated by the `create_due_reminders()` pg_cron job daily at 06:00 UTC.

**`custom_document_types`** — user-defined doc types (`unique(owner_id, name)`), referenced from `documents.doc_type` as `custom-<id>`.

**Finance:** `finance_transactions` (income/expense lines, optional `document_id` link), `category_budgets` (per-category monthly limits), `savings_envelopes` (goals; tracking only — no money movement, per the pre-licence fintech stance), `recurring_transactions` (templates auto-logged by `FinanceService.runDueRecurrences()`).

**`app_versions`** — used by the splash update check (`supabase/app_version_schema.sql`).

### 3.2 RLS model

Every table has row-level security enabled with per-owner policies (`auth.uid() = owner_id`), either directly (`collections`, `documents`, `custom_document_types`) or via an `exists` subquery through the parent document (`reminders`). Only the anon (publishable) key ships in the app.

### 3.3 Local cache

| Key | Contents |
|---|---|
| `local_documents_v1` | JSON array of `ExpiryItem.toJson()` |
| `local_documents_outbox_v1` | JSON array of `PendingOp` (queued mutations) |
| `financeRecords.v1` | `{transactions, budgets, envelopes, recurring, overallBudgets}` |
| `ai.router.memo.v1` | AI intent-router exact-input verdict memo (LRU 200, oldest evicted) |
| `ai.router.budget.v1` | Rolling daily AI escalation counter (`{day, count}`) |
| `hasOnboarded` | onboarding flag |
| `activeCollectionId` | collection selection |

Derived fields (`daysRemaining`, `urgency`, `isExpired`) are **recomputed on read**, never trusted from storage.

---

## 4. Offline-first sync engine

The full contract lives in `lib/services/doc_sync.dart` (pure, unit-tested) and is executed by `DocumentScannerService`.

### 4.1 Write path

```
save → local cache update (instant UI)
     → enqueue PendingOp.upsert (persisted outbox)
     → best-effort Supabase insert/update
        ├─ success → remove from outbox
        └─ failure → stays queued (replayed on next init/refresh)
```

### 4.2 Row sanitization

Every row sent to PostgREST is filtered through `_documentRowColumns`, a whitelist of real schema columns. This prevents a class of silent sync death: an app version that emits a key the table doesn't have (the historical `updated_at_client` bug) would otherwise be rejected with PGRST204 on every attempt, forever. Stale outbox entries written by older versions are sanitized at replay time.

### 4.3 Pull / merge (last-writer-wins)

On init and pull-to-refresh: queued mutations are flushed **before** pulling (so offline-created rows exist server-side), then remote rows merge into the cache via `DocSync.merge`:

- local dirty (unsynced edit) → keep local, re-queue push
- remote `updated_at` newer → take remote
- local newer → keep local
- tie / missing → remote wins (server authoritative)
- remote row gone + local clean → drop (deleted elsewhere); local dirty → keep and resurrect on next push

Collection ids: local-only pseudo ids (`personal`, `local-<ts>`) are remapped to the user's real personal-collection uuid before any push — otherwise the FK would reject the write.

### 4.4 Timestamps

`updatedAt` is stamped on every local mutation for LWW comparisons. The server-side `updated_at` trigger is authoritative for change detection; the client never transmits a timestamp column.

---

## 5. Feature reference (with screenshots)

All screenshots live in [`docs/screenshots/`](screenshots/). Click any link for full size.

### 5.1 Splash & version gate

Auto-checks the `app_versions` table; can prompt or force an update before continuing.

![Splash](screenshots/01-splash.png)

### 5.2 Onboarding & accounts

Five-panel interactive onboarding (the `hasOnboarded` flag skips it later), a quiz-style themed login flow, and the notification-permission dialog that explains value before the OS prompt.

![Onboarding](screenshots/23-onboarding.png)
![Login](screenshots/04-login.png)

### 5.3 Home dashboard

Cross-tier dashboard: categories grid (Documents, Renewals, Envelopes, Records, Forecast, AI Summary, AI Planner, Scan), plan-restriction / attention / expired banners that collapse to zero when not applicable, next-renewals tiles, a tier-aware collection switcher, notification bell with a unified alert sheet, and a live month-balance hero with Record/Budget action pills.

![Home](screenshots/06-home.png)
![Home with documents](screenshots/18-home-with-doc.png)
![Notifications sheet](screenshots/22-notifications-sheet.png)

### 5.4 Documents

The expiry radar. Every card shows urgency color, renewal-window progress, authority, fee, reminder state, and an expiry-aware warning (`effectiveRenewalWarning` — never blank). Inline search, status filter chips with live counts, document-type filter sheet, and sort (due date / urgency / name / fee). Insight tiles show the next due document and total upcoming fees.

![Documents](screenshots/08-documents.png)

### 5.5 Document detail

Full record: the shared 90·60·30·7 urgency timeline (`UrgencyTimelineCard`), reminder overrides (custom alert days), renewal process checklist, renewal history, mark-as-renewed flow, and attachment handling — the attachment card renders a real downsampled cached thumbnail and opens the reusable full-screen pinch-to-zoom viewer (`FullScreenImageViewer`); cloud attachments are disk-cached and pre-warmed before the viewer fades in.

![Document detail](screenshots/19-document-detail.png)
![Document detail bottom](screenshots/20-document-detail-bottom.png)

### 5.6 Upload / scan (OCR)

Attach PDF/DOC/XLS/PNG/JPG. Images run through ML Kit OCR (`UaeDocumentOcrService`) which pre-fills title, type, expiry, emirate, authority and document number — the user reviews before saving. Files are copied to the app documents directory; metadata is stored with the record. After saving, `CompanionSuggestionService` offers related document types one tap away.

![Scan form](screenshots/16-scan.png)
![Companion suggestions](screenshots/17-companion-suggestions.png)

### 5.7 Ask Finavig AI — universal voice/text quick add

One sheet for both flows (money + documents), reached from the nav "＋" button or its long-press shortcut: the user types or speaks one sentence; a local keyword lexicon routes it for free, Groq escalates only the ambiguous remainder (bounded by a persisted 12/day budget surfaced as a subtle "AI assist: N of 12 today" chip), the NL parser extracts the record, and one confirmation saves it. Voice input shows live partial transcripts and normalizes spoken numbers.

![Natural language add](screenshots/31-natural-language-add.png)
![Money record sheet](screenshots/28-money-record-sheet.png)

### 5.8 Expiry list & report

Flat chronological view across the collection with CSV/PDF export (`ExpiryReport`), urgency/type/status filters, and day-range presets.

![Expiry list](screenshots/12-renewals.png)

### 5.9 Global search

Fuzzy search across names, notes, authorities, assignees, file names and type names, over every collection.

![Global search](screenshots/21-global-search.png)

### 5.10 Money

Finance module home: month overview (net cash flow), bill-spike alert, overall + per-category budgets with 80/100% alert thresholds, spending pace (avg/day, projected month-end, safe-to-spend), 6-week bar chart, category breakdown, biggest expenses, executive summary, 90-day renewal outlook, upcoming renewals with fees, cash-flow forecast entry, and recurring templates.

![Money](screenshots/07-money.png)

### 5.11 Budgets & envelopes

Overall monthly cap plus per-category limits with progress meters; savings envelopes are tracked-only goals (no money moves — the pre-licence fintech stance).

![Budgets](screenshots/10-budgets.png)
![Envelopes](screenshots/11-envelopes.png)

### 5.12 Records & smart categorization

Month-grouped transaction history. `SmartCategoryEngine` matches UAE vendors (exact dictionary + fuzzy Levenshtein), learns user corrections, and can retro-apply categories.

![Records](screenshots/30-records-with-data.png)
![AI category suggestion](screenshots/29-ai-category-suggestion.png)
![Transaction form](screenshots/28-transaction-form.png)

### 5.13 90-day cash-flow forecast

Simulates daily balances from history + recurring templates + upcoming renewal fees; shows projected end balance, lowest point, and a filterable event list (all / renewals only / recurring).

![Cash-flow forecast](screenshots/14-forecast.png)

### 5.14 AI executive summary & AI budget planner

Monthly natural-language financial report: `MonthlySummaryService` aggregates this-vs-last month spend, top movers, budget overruns and envelope projections; the template narrative works fully offline, with an optional Gemini polish pass when the user supplies a key in Profile. The AI Budget Planner turns a stated goal ("save 15,000 AED for vacation in 6 months") into category caps.

![AI summary](screenshots/15-ai-summary.png)

### 5.15 Profile

Modular settings: account card, subscription (tier badge, plan-expiry countdown, usage meters, upgrade/renew), collections management, appearance (system/light/dark), preferences link to the standalone Alerts & Reminders screen, AI summary key, and help & support (FAQ sheet, interactive app guide, support requests with status tracking).

![Profile](screenshots/09-profile.png)

---

## 6. Alerts & notifications

| Mechanism | Trigger | Implementation |
|---|---|---|
| Renewal ladder | 90/60/30/7 days before `expires_at` | `NotificationService.scheduleEscalationLadder` — OS-local notifications (`flutter_local_notifications` + timezone Asia/Dubai); re-synced on every app start (`resyncAll`) |
| Custom offsets | `custom_reminder_days` overrides the ladder per document | Same engine, custom list; cancel uses the same offsets |
| Budget 80% | category spend ≥ 80% of monthly limit | `BudgetAlertService` evaluates on every finance change; one alert per budget/month/threshold (`alertKey` dedupe) |
| Budget 100% | spend ≥ 100% | same, separate dedupe key; Money-tab badge turns red |
| Bill spike | bill > baseline + σ | `AnomalyDetectionService` moving average over history |
| Alerts & Reminders screen | user-tunable cadences (reminder/task/escalation) | standalone screen re-applies the OS schedule on every change — no Save button, immediate effect |
| Server reminders | daily pg_cron `create_due_reminders()` | inserts `reminders` rows for active docs inside their reminder window (future Edge Function/FCM consumer) |

WhatsApp/email alerts are intentionally not wired: secrets must never ship in the client. The UI surfaces them as "coming soon" pending a Supabase Edge Function + provider integration.

---

## 7. Performance & testing infrastructure

### 7.1 Frame-timing tracing

`PerfTracingService` (debug/profile only, compiled away in release) instruments the critical flows with named DevTools Timeline sections: cold start → Home, tab switch, document open, quick-action sheet open. An opt-in frame monitor samples build+raster durations into a bounded ring buffer and reports >16.7 ms jank / >33 ms severe frames via `onSlowFrame` for device-lab harnesses; `jankRatio()` summarizes the last 300 frames.

### 7.2 Golden tests

`test/golden_test.dart` pins the three shimmer skeleton views (Home/Documents/Money — the loading state on every tab's cold open) at a fixed 390×844 viewport, light brightness, one settled shimmer tick, on a plain hermetic theme (no runtime font fetching). Committed goldens live in `test/goldens/`; regenerate with `flutter test --update-goldens`.

### 7.3 File-size ratchet

`dart run tool/perf_budget_check.dart` fails when any screens/widgets file exceeds 1,200 lines (config 800). Three pre-existing monoliths are grandfathered with headroom (`document_detail_screen.dart`, `ai_budget_plan_screen.dart`, `login_screen.dart`) — they must be split before further major growth. This is what keeps the modularization wave from regressing.

### 7.4 CI

`.github/workflows/ci.yml` runs on every push to `main` and every PR: `flutter analyze --no-pub` (errors fatal — the codebase carries a documented pre-existing warning/info baseline), the file-size ratchet, and the full test suite (305+ tests, 23 suites) including goldens.

---

## 8. Project layout

### 8.1 Source tree

```
lib/
  main.dart               startup: perf monitor, theme, Supabase, alert prefs, prewarm
  app.dart                MaterialApp.router + theme wiring
  router.dart             go_router config, auth gate, shell + badges + quick action
  config/
    app_credentials.dart  Supabase URL + anon key (compiled in)
    app_links.dart        deep-link config
    faq_content.dart      FAQ data (model + 15 Q&As) — widgets render it generically
    app_guide_content.dart  App-guide chapters as sealed GuideBlock data
  models/                 ExpiryItem, DocumentType(+Registry), DocumentCollection,
                          RenewalRecord, FinanceTransaction/Budget/Envelope/Recurring,
                          CashFlow*, FinanceMath, RecurrenceMath
  services/               one singleton per concern (see §2.2); doc_sync.dart = sync contract;
                          perf_tracing_service.dart = Timeline sections + frame monitor
  screens/                thin shells composing section modules:
    home/                 hero, collection switcher, banners, categories grid, upcoming
    documents/            hero, filters, insights, document card, action sheets
    money/                summary cards, planning cards, rows, form sheets
    profile/              hero, account, subscription, collections, appearance, sheets
    (splash, onboarding, welcome, login, scan, document detail, expiry list,
     global search, money, cash flow, ai summary, ai budget plan, alerts & reminders)
  widgets/
    hero_widgets.dart     shared HeroIconButton + HeroActionPill (all four tab heroes)
    cards/urgency_timeline_card.dart  the single 90·60·30·7 ladder implementation
    attachment_thumbnail.dart         AttachmentImage: downsampled decode + disk cache
    viewers/full_screen_image_viewer.dart  pinch-to-zoom attachment viewer
    shimmer_skeleton.dart Home/Documents/Money skeleton views (golden-guarded)
    dialogs/              ask_finavig_sheet, quick action, renew, upgrade, faq, app guide…
  theme/app_theme.dart    FinavigColors + light/dark themes
supabase/
  schema.sql              documents/collections/reminders/custom types + RLS + cron
  finance_schema.sql      finance tables + RLS
  app_version_schema.sql  app_versions
  migrate_companies_to_collections.sql        legacy single-company → collections
  migrate_documents_local_only_fields.sql     adds location, renewal_history,
                                              custom_reminder_days
test/                     23 suites, 305+ tests — sync contract (DocSync), finance math,
                          recurrence, anomaly, categories, AI intent routing (incl.
                          persistence), NL parser, OCR, UI redesign contracts, goldens
test/goldens/             committed golden PNGs for the three skeleton views
tool/perf_budget_check.dart  CI file-size ratchet (screens/widgets ≤ 1200 lines)
.github/workflows/ci.yml analyze + budget gate + full test suite
```

---

## 9. Build, run, test

---

## 9. Build, run, test

```bash
# Prerequisites: Flutter ^3.11, a Supabase project for sync features

flutter pub get

# Configure backend (or skip for local-only mode):
#   edit lib/config/app_credentials.dart → supabaseUrl / supabaseAnonKey
#   run supabase/schema.sql + finance_schema.sql (+ migrations) in the SQL editor

flutter run                    # device/emulator
flutter run -d chrome          # web (hash routing)
flutter build web --release
flutter build apk --release    # Android (configure signing first — see PRODUCTION_READINESS.md)

flutter analyze
flutter test                   # 23 suites, 305+ tests (goldens included)
dart run tool/perf_budget_check.dart   # file-size ratchet
```

All three gates run in CI (`.github/workflows/ci.yml`) on every push to `main` and every PR.

**Golden tests:** `test/golden_test.dart` pins the three shimmer skeleton views at a fixed 390×844 viewport on a hermetic plain theme (no runtime font fetch). If you intentionally change a skeleton, regenerate:

```bash
flutter test --update-goldens test/golden_test.dart
```

---

## 10. Database migrations

| File | When to run |
|---|---|
| `supabase/schema.sql` | fresh projects (idempotent — safe to re-run) |
| `supabase/migrate_companies_to_collections.sql` | legacy single-company projects |
| `supabase/migrate_documents_local_only_fields.sql` | all existing projects — adds `location`, `renewal_history`, `custom_reminder_days` |
| `supabase/finance_schema.sql` | any project without the finance tables |
| `supabase/app_version_schema.sql` | to enable the splash update check |

All migrations are additive and idempotent. After running the fields migration, the app uploads previously local-only fields on the next save/sync; stale outbox entries are healed by the row sanitizer (§4.2).

---

## 11. Known limitations & roadmap

| Area | Status | Notes |
|---|---|---|
| Attachment files | device-local (cached views) | metadata syncs; bytes don't. Views are cached/downsampled (`AttachmentImage`); Supabase Storage bucket is the planned fix for cross-device bytes |
| OS notification reschedule on pull | not automatic | a remote edit (e.g. custom reminder days) reschedules on next local edit/renewal, not on pull — needs post-merge resync hook |
| WhatsApp / email alerts | not wired | requires server-side provider (Meta Cloud API / SMTP) behind an Edge Function |
| Push (FCM/APNs) | not wired | local notifications only; server `reminders` rows are ready as the data source |
| Release signing | release-signed Android | signing wired with ProGuard rules for ML Kit (see PRODUCTION_READINESS.md) |
| Web platform | demo/docs only | ML Kit & local notifications degrade on web |
| Localization | English only | strings inline, RTL-ready layout not audited |
| Groq escalation budget | 12/day, persisted | resets at local midnight; shared across every AI entry point; memo prevents repeat costs |
