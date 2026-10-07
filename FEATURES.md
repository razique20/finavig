# Finavig — Complete Feature List

> A full inventory of everything the app actually ships. Every line below is
> taken from the code in this repository (`lib/`, `supabase/`) rather than from
> marketing copy, and the last section lists the things that are deliberately
> **not** built yet so nothing here reads as aspirational.

**Finavig** is an AI-powered budgeting & cash-flow app for personal and small-business
use, built for the GCC (Gulf Cooperation Council), that also tracks every document
expiry (trade licences, visas, Emirates ID, tenancy contracts, …) and forecast the
renewal fees behind them.

---

## 1. Platforms & technology

| Area | What is used |
| :--- | :--- |
| App framework | Flutter / Dart 3.11+ (`pubspec.yaml`, version `1.0.0+1`) |
| Targets | iOS, Android, Web (`flutter run` with no platform lock-in) |
| Routing | `go_router` — `StatefulShellRoute.indexedStack` 4-tab shell + full-screen flows |
| State | Singleton `ChangeNotifier` services, no external DI/state library |
| Backend | Supabase — PostgreSQL with Row Level Security, Storage buckets |
| AI transport | Supabase Edge Function `groq-proxy` (Deno/TypeScript) holding the Groq key |
| Local persistence | `shared_preferences` + `path_provider` + `flutter_secure_storage` |
| OCR | `google_mlkit_text_recognition` (on-device) |
| Speech | `speech_to_text` (on-device voice capture) |
| Biometrics | `local_auth` |
| Notifications | `flutter_local_notifications` + `timezone` |
| Reporting | `pdf`, `printing`, CSV exporter, `share_plus` |
| Security primitives | `crypto` (salted, iterated SHA-256 for the App Lock hash) |
| Reviews | `in_app_review` |
| Fonts / assets | Bundled Inter + Playfair Display, GCC flag set, splash + welcome artwork |

---

## 2. Access, onboarding & account security

- **Splash screen with update check** — branded backdrop, then `AppVersionService`
  reads the `app_versions` table; `AppVersionDialog` surfaces a forced/optional
  update notice.
- **Welcome screen** — first-launch dark brand landing: the Finavig headline, a
  WhatsApp-style quote thread with a quoted reply, and a single **Continue to Login**
  CTA that sets `hasSeenWelcome`.
- **Quiz-style login / sign-up** — one question per step with per-step validation:
  - Step 0 asks what kind of user you are and branches.
  - Sign-in branch: 3 steps. Sign-up branch: 6 steps (email → password → date of
    birth → GCC country → phone).
  - Always renders the dark brand theme so welcome → login reads as one flow.
  - Hosts the Terms/Privacy consent links; legal dialogs are built in.
- **Onboarding screen** for first-run product explanation (guarded by `hasOnboarded`).
- **Auth gate** — with Supabase configured, every route except `/`, `/welcome` and
  `/login` requires a session; sign-in routes redirect to `/home` when a session
  exists. With no credentials the gate is off and the app runs fully local-only.
- **App Lock (optional)** —
  - 6-digit re-entry passcode with a shaking `PasscodePad` and per-digit feedback.
  - Biometric unlock via `BiometricService`, which collapses every failure mode
    (no hardware, no enrolment, cancel) to `false` instead of throwing.
  - Only a salted, iterated SHA-256 hash is stored — in iOS Keychain / Android
    Keystore — never the passcode itself.
  - `AppLockGate` overlays the whole router when locked; 30-second grace period
    before re-locking; never locks while signed out.
  - **Persisted escalating lockout** after repeated wrong entries.
  - **"Forgot passcode" signs the user out** (re-authenticate with the password)
    rather than weakening the lock.
  - Set-up/change/turn-off flows reused by both the Profile Security section and the
    one-time post-login prompt.
- **Account management** — editable identity details (role, phone), sign out, and
  **account deletion** backed by `supabase/delete_account_function.sql` (removes the
  `auth.users` row).
- **Theme service** — System / Light / Dark, persisted and applied instantly through
  the root `MaterialApp`, plus a quick dark-mode toggle in the Home hero.

---

## 3. Home dashboard

- **Navy gradient hero** — greeting, active-collection switcher, dark-mode toggle,
  notification bell, and the month balance (net this month).
- **Cross-tier dashboard** — pulls documents *and* money into one view (the "tier 1 +
  tier 2" concept in `ARCHITECTURE.md`).
- **Categories grid** — bento tiles routing to Documents, Renewals, Envelopes,
  Records, Forecast, AI Summary, AI Planner, and search.
- **"Next renewals · N"** — the three nearest expiring documents with a colour-coded
  days-remaining counter (red ≤7d, amber ≤30d, green beyond) and **View all** into the
  full expiry list.
- **Empty state** — standard Material icon + *"Nothing tracked yet"* and a
  **Try a demo document** button (`DemoDocumentService` inserts one clearly-labelled
  sample trade licence so alerts and the urgency ladder are visible immediately).
- **Getting Started checklist card** — interactive, collapsible, dismissible
  (`gettingStartedChecklistDismissed`).
- **First-run guide banner** — slim, non-blocking *"New here? Take the 1-minute guided
  tour"* prompt that opens the full app guide dialog.
- **Plan/entitlement banners** — amber banner when the plan expired or collections
  are locked.
- **Monthly summary card** and **urgency timeline card** (vertical step timeline over
  status circles).
- **Live nav badges** — Documents dot when any document needs action (≤30 days);
  Money dot amber at ≥80% budget use, red at ≥100% (hidden entirely when budget
  alerts are switched off in Profile).

---

## 4. Documents — expiry & compliance tracking

- **Collections (workspaces)** — one built-in **Personal** collection plus custom
  **Company/Business** collections; create, rename, delete, switch active workspace,
  with tier locks on extra company collections.
- **Pre-configured document types** — Emirates ID / Civil ID, Trade Licence,
  Commercial Registration, Visa, Passport, Vehicle Registration, Tenancy Contract,
  Insurance, software subscriptions — each with its own renewal cycle and icon.
- **Custom document types** — user-defined types with custom validity periods and
  issuing authority, Supabase-backed with a SharedPreferences fallback.
- **Scan & attach** — camera/gallery/file-picker capture, on-device OCR
  (`UaeDocumentOcrService`) that extracts expiry dates and vendor/authority fields,
  plus PDF and image attachments.
- **Attachment handling** — a shared cached image pipeline (`AttachmentThumbnail`,
  `cached_network_image` + `flutter_cache_manager`) and a **full-screen image viewer**
  with pinch-zoom (1×–5×), double-tap-to-zoom and one-tap share.
- **Document detail screen** — full metadata, urgency status, attachment preview,
  and workflow actions.
- **Per-document actions** (`document_action_sheets.dart`) — renew, update date,
  assign, delete.
- **Renewal flow** — `showRenewDocumentDialog` confirms the new expiry date and fee,
  optionally swaps in a replacement file, and records a **renewal history entry**
  (`RenewalRecord`, `renewal_recent_history`).
- **Urgency engine** — `urgencyLevel` 0–4 on days remaining: 4 urgent (≤7), 3 soon
  (≤30), 2 approaching (≤60), 1 watch (≤90), 0 comfortable, plus an `isExpired`
  state when days remaining goes negative; drives card tinting, sorting and the Home
  badge.
- **Documents tab layout** — navy hero header with Ask Finavig AI + global search, a
  live status/filter line, status filter chips + sort orders, two insight tiles
  (nearest upcoming document, total upcoming renewal fees), document cards with an
  urgency-tinted left edge, and shimmer skeleton loading states.
- **Expiry list screen** — the full list with status/sort filtering, and **PDF + CSV
  report export** (`expiry_report.dart`) gated to Plus and above.
- **Reminders per document** — 90/60/30/7-day escalation ladder by default, custom
  alert-day offsets on Plus and above.

---

## 5. Money — ledger, budgets & cash flow

- **Unified transaction ledger** — income and expense rows tagged by collection,
  category, payment method, date, and an optional linked document.
- **Category budgets** — monthly caps across renewals, salaries, rent, utilities,
  suppliers, marketing, transport, software, sales and more, with utilization bars and
  **80% / 100% threshold alerts** (`BudgetAlertService`).
- **Savings envelopes** — virtual goals with monthly contributions and progress
  tracking (tracked only — no real money moves).
- **Recurring schedules** — monthly / quarterly / annual templates that log fixed
  costs automatically.
- **90-day cash-flow forecast** — daily balance simulation folding in recurring bills
  and upcoming renewal fees, with **dip / lowest-balance detection** and an
  interactive line chart (`CashFlowForecastChart`). Plus-and-above feature.
- **Renewal cost outlook** on the Money tab — what the next renewals will cost.
- **Money sheet index** — every section is collapsible and starts minimised
  (budgets, pace, weekly, categories, top, renewal breakdown, recurring, envelopes,
  credit, transactions).
- **Monthly executive summary card** — template narrative immediately, LLM-polished
  when AI is available.
- **Bill-spike anomaly cards** — with per-item dismissal, stateless widget over
  parent-owned state.
- **Transaction log with quick add** — latest 20 on Money, the complete log on the
  Records page, plus **CSV export**.
- **Dedicated sub-screens**: Budgets, Envelopes, Records, Cash-Flow Forecast,
  AI Summary, AI Budget Planner, Credits, Alerts & Reminders.

---

## 6. Credit book — borrowed & lent

- **Track obligations to a person** — counterparty name + phone, amount, currency,
  description, start date, deadline, and a settled state.
- **Extensions** with a preserved history (`extension_history`) via the dedicated
  extend sheet.
- **Deadlines & overdue math** — "Overdue by N days" / due-soon chips; settled
  obligations are never marked overdue.
- **WhatsApp follow-up** — a pre-filled follow-up message per counterparty.
- **Optional ledger linkage** — creating or settling a credit can write the matching
  cash movement into the ledger, tagged `credit_id` + `credit_leg =
  disbursement | settlement`.
- **No double counting** — credit-linked ledger rows carry a **Credit** badge and are
  excluded from income/expense totals, budgets, category spend, charts, anomaly
  detection and AI prompts (`FinanceMath.summaryForMonth`, `spendByCategory`).
- **Settle sheet** — records the settlement leg, marks the entry settled, and can
  reconcile against the ledger.

---

## 7. AI engine & smart automation

- **AI Executive Summary** — merges document expiries, pending renewal fees, monthly
  spend and net position into a short narrative with actionable insight cards;
  reached from Home, Money and its own page.
- **AI Budget Planner** — the user states a goal (e.g. *"buy a delivery van for
  AED 25,000"*) and target date; the model works from the real 3-month average spend
  and upcoming renewals to produce concrete steps (create an envelope, cap a category,
  trim flexible spend). Includes ready-made templates (**Comfortable / Balanced /
  Goal-first**), interactive sliders and a live goal-health meter.
- **Server-side quota enforcement** — the `groq-proxy` Edge Function requires a real
  user JWT (the public anon key gets `401`), holds the Groq key as a function secret,
  meters the tier quota through the `consume_ai_quota` SQL function, and **refunds the
  credit** on upstream failure (`502 groq_error`, never a fake `401`).
- **Quota UX** — explicit "use 1 credit from your monthly quota?" confirmation before
  generating, and the previous summary/plan stays readable without spending quota.
- **Ask Finavig AI** — a unified sheet (nav "+" long-press, or the "Say it once —
  money or documents, hands-free" entry) that parses one sentence into either a money
  record or a document to track, then confirms before persisting.
- **Natural-language quick add (text)** — `NaturalLanguageParserService` extracts
  amount, currency, kind, category and date from freeform sentences.
- **Voice quick add** — `VoiceInputService` streams live transcription from
  `speech_to_text` into the same parser.
- **AI intent router** — decides which flow a freeform request belongs to (money vs
  document vs memo) with an in-memory escalation counter and persisted routing
  preferences.
- **Smart auto-categorization** — pure-Dart engine combining dictionary rules, fuzzy
  **Levenshtein** matching, GCC vendor dictionaries (Talabat, Salik, DEWA, Etisalat, …)
  and **persistent user-habit learning**.
- **Bill spike & anomaly detection** — moving-average + standard-deviation engine that
  flags outliers (e.g. a DEWA bill 35% above the 3-month baseline) and ignores
  credit-linked rows; severities and recent-anomaly sorting.
- **Companion suggestions** — after adding a document, suggests related GCC document
  types the user doesn't track yet (a trade licence implies visas, national IDs,
  labour cards) and can create them in one tap.
- **Monthly narrative engine** — `MonthlySummaryService` builds the category moves,
  budget overruns and envelope projections shown on the summary card.
- **Optional Gemini polish** — `GeminiApiService` supports a user-supplied key for an
  on-demand copy-polish pass alongside the Groq path.

---

## 8. Alerts, reminders & notifications

- **Alert preferences service** gates every surface an alert can appear on (banner,
  card, nav badge) so switching one off hides it everywhere.
- **Alerts & Reminders screen** — dedicated page for every alert toggle and document
  expiry reminder lead times.
- **Local notification engine** — scheduled via `flutter_local_notifications` +
  `timezone`, with the 90/60/30/7 escalation ladder and custom offsets. Reminders are
  cancelled/rescheduled whenever a document's expiry changes.
- **Notification tap routing** — `NotificationTapService` deep-links straight to the
  tapped document's detail screen, including from a cold start, instead of dropping
  the user on Home.
- **Notification bell + pill** in the Home hero.
- **Budget alerts** — 80% warning / 100% exceeded, driving the Money nav dot.

---

## 9. Search

- **Global search** across every collection, matching document name, record numbers,
  notes/authority fields, assignee, file name and type name.
- Reachable from the Home categories grid, the Documents hero and the quick actions.
- Empty-state variants for "no query" versus "no match" (standard icon scenes).

---

## 10. Profile & settings

- **Navy hero Profile** consistent with Home and Documents, over a rounded content
  sheet.
- **Appearance** — theme-mode segmented control persisted by `ThemeService`, plus
  the data-export action (writes the JSON file through the platform save dialog and
  falls back to the share sheet).
- **Account card** — editable identity (role, phone), active-collection shortcut.
- **Collections section** — group documents per company: switch workspace, rename,
  delete, tier locks.
- **Subscription section** — current tier, plan-duration choices, and the paywall.
- **Security section** — App Lock on/off, set-up, change, biometrics.
- **Backup nudge** — dismissible "your scans live on this device" notice until storage
  backup ships.
- **Support & feedback** — `SupportService` / `UpgradeRequestService` create and track
  requests against the `support_requests` table with local caching.
- **Searchable FAQ sheet** — categorised questions, expandable accordions, and a
  direct link into the support flow.
- **Legal & about sheets** — Terms & Conditions, Privacy Policy, About, Support.
- **Full app guide dialog** — the interactive tour of the whole product.
- **Rating prompt** — `RatingPromptService` policy (pure, unit-tested) driving the
  native in-app review sheet via `in_app_review`.
- **Data portability** — **"Download my data"** bundles documents (with renewal
  history), the finance ledger and profile prefs into one portable JSON file, saved
  or shared from the settings section, backing the UAE PDPL / GDPR-style access right.
- **Sign out** and **delete account**.

---

## 11. Subscription tiers & entitlements

Source of truth: `lib/models/subscription_tier.dart` (`TierLimits`) and the matching
table inside `supabase/functions/groq-proxy/index.ts`. The tier itself is granted
server-side in the `user_tiers` table — the app only reads it.

| Capability | Free | Plus | Business |
| :--- | :---: | :---: | :---: |
| Tracked documents | 10 | Unlimited | Unlimited |
| Personal collections | 1 | 1 | 1 |
| Company collections | 0 | 1 | Unlimited |
| 90-day cash-flow forecast | — | ✅ | ✅ |
| PDF / CSV report export | — | ✅ | ✅ |
| Custom alert days per document | — | ✅ | ✅ |
| AI monthly executive summary | — | ✅ | ✅ |
| Document assignment to team members | — | — | ✅ |
| Renewal audit history | — | — | ✅ |
| Team / bulk export | — | — | ✅ |
| AI summary quota | 3 / month | 15 / month | 40 / month |
| AI budget plan quota | 2 / month | 10 / month | 25 / month |
| Price | Free | AED 25 / mo · 69 / 3 mo · 240 / yr | AED 99 / mo · 269 / 3 mo · 999 / yr |

- Gates are centralised in `EntitlementService` / `EntitlementFeature`, and every
  blocked action routes to the paywall dialog.
- **Upgrade is a request flow**, not an in-app purchase: `UpgradeRequestService`
  builds a pre-filled email to the Finavig team, and `support_requests` tracks it.

---

## 12. GCC regionalisation

- **All six GCC currencies** — AED, SAR, QAR, KWD, BHD, OMR — applied to calculations,
  money parsing and AI prompts based on the user's active country.
- **Country model + flags** (`GccCountry`, `assets/images/flags`) covering UAE, Saudi
  Arabia, Qatar, Kuwait, Bahrain and Oman.
- **Authority catalogs** — `GccAuthorityCatalog` plus a detailed UAE catalog
  (`UaeAuthorityCatalog`: the seven emirates + federal jurisdiction) mapping emirate →
  issuing authority → document type, with **department logo badges**.
- **UAE OCR parser** — provider-specific field extraction for UAE business and
  identity documents.

---

## 13. Data, sync & offline-first

- **Local cache is the source of truth for the UI**; Supabase syncs underneath it, so
  the app is fully usable offline and signed out.
- **Document sync logic** — `doc_sync.dart` is pure (UI-free, I/O-free) with an outbox
  of queued mutations (`local_documents_outbox_v1`), so writes survive offline and
  flush later.
- **Offline banner** pinned above the shell explaining queued sync instead of letting
  silence read as "broken" (`ConnectivityService` probe, stubbable in tests).
- **Local-only fallback** for finance, credit, collections, custom document types,
  alerts and AI quota caches.
- **Storage migration** — one-time move of documents from the legacy
  `<app docs>/wazy/documents` folder to `<app docs>/finavig/documents`.
- **Backend schema** (all idempotent, additive SQL): `collections`, `documents`,
  `reminders`, `custom_document_types`, `finance_transactions`, `category_budgets`,
  `savings_envelopes`, `recurring_transactions`, `credit_entries`, `user_tiers`,
  `ai_quota_usage`, `app_versions`, `support_requests`, plus RLS policies, the
  `consume_ai_quota` function and the delete-account function.

---

## 14. App plumbing & instrumentation

- **Performance tracing** on the critical flows: cold start → Home, tab switch,
  document open, quick-action sheet open (`PerfTracingService`).
- **Tab scroll registry** — each tab's `ScrollController` is registered so tapping the
  active tab returns to the top.
- **Local crash & error capture** — `ErrorCaptureService` persists message, origin,
  timestamp and the first stack frames to SharedPreferences (wired in `main.dart`).
- **Demo data service** — one-tap sample document for first-run exploration.
- **Shimmer skeletons** — reusable pulsating placeholders and a full Documents-page
  skeleton.
- **Shared UI kit** — frosted-glass hero buttons, bento icon tiles, progress rings,
  urgency timeline, offline banner, notification pill, brand logo, empty states.

---

## 15. Screen & route inventory

| Route | Screen |
| :--- | :--- |
| `/` | Splash (+ version check) |
| `/welcome` | Welcome |
| `/login` | Quiz login / sign-up |
| `/onboarding` | Onboarding |
| `/home` | Home dashboard (tab 1) |
| `/money` | Money (tab 2) |
| `/documents` | Documents (tab 3) |
| `/profile` | Profile / Settings (tab 4) |
| `/scan` | Scan / add document |
| `/document/:id` | Document detail |
| `/document/:id/edit` | Edit document |
| `/search` | Global search |
| `/expiry-list` | Expiry list (+ PDF/CSV export) |
| `/cash-flow-forecast` | 90-day forecast |
| `/budgets` | Budgets |
| `/envelopes` | Savings envelopes |
| `/records` | Full transaction log |
| `/credits` | Credit book |
| `/ai-summary` | AI executive summary |
| `/ai-budget-plan` | AI budget planner |
| `/alerts-reminders` | Alerts & reminders settings |

Full-screen flows (scan, document detail/edit, search, expiry list, forecast, the
sub-screens) push above the 4-tab shell; the shell carries the floating nav pill with
a centre **+** universal quick action (long-press for Ask Finavig AI).

---

## 16. Service inventory (`lib/services/`)

| Service | Responsibility |
| :--- | :--- |
| `document_scanner_service` | Document store (Supabase + local cache), renewals |
| `doc_sync` | Pure offline-first sync + outbox |
| `uae_document_ocr_service` | On-device OCR field extraction |
| `uae_authority_catalog` / `gcc_authority_catalog` | Authority & document-type catalogs |
| `custom_document_type_service` | User-defined document types |
| `collection_service` | Personal + company workspaces |
| `finance_service` | Transactions, budgets, envelopes, recurring |
| `credit_service` | Credit obligations + ledger tagging |
| `monthly_summary_service` | Monthly narrative builder |
| `anomaly_detection_service` | Bill-spike statistics |
| `budget_alert_service` | 80% / 100% budget alerts |
| `urgency_engine` / `expiry_report` | Urgency levels; list filters, CSV & PDF |
| `notification_service` + `notification_tap_service` | Scheduling + deep-link taps |
| `alert_preferences_service` | Global alert gating |
| `ai_executive_summary_service` / `ai_budget_plan_service` | AI features + quota bookkeeping |
| `groq_api_service` / `gemini_api_service` | LLM transports |
| `ai_intent_router_service` | Route freeform input to the right flow |
| `natural_language_parser_service` / `voice_input_service` | Text & speech parsing |
| `smart_category_engine` | Auto-categorization + habit learning |
| `companion_suggestion_service` / `companion_document_factory` | Related-document suggestions |
| `entitlement_service` | Tier resolution and feature gates |
| `auth_service` / `supabase_service` | Auth, session, account deletion, client |
| `app_lock_service` / `biometric_service` | Passcode hash, lockout, biometrics |
| `theme_service` / `connectivity_service` | Persisted theme; online/offline probe |
| `support_service` / `upgrade_request_service` | Support tickets, upgrade requests |
| `user_data_export_service` | Portable JSON data export |
| `storage_migration_service` | Legacy folder migration |
| `app_version_service` / `rating_prompt_service` (+ `rating_prompt_ui`) | Update check; review policy |
| `error_capture_service` / `perf_tracing_service` / `tab_scroll_registry` | Diagnostics & plumbing |
| `demo_document_service` | First-run sample document |

---

## 17. Honest gaps (not shipped)

- **No real money movement** — budgets, envelopes and forecasts are planning tools;
  nothing connects to a bank, card or payment rail.
- **No in-app purchase** — tier upgrades are request-by-email, granted server-side by
  the admin console (a separate codebase, not in this repository).
- **No data import / restore** — the JSON export is one-way; there is no import path.
- **Cloud backup of scan files is not shipped** — the Profile nudge ("your scans live
  on this device") stays visible until it is.
- **Team features (assignment, audit history, team export) are gated in the UI but
  depend on the Business tier being granted** — the app cannot enable them itself.
- **Client-embedded Groq fallback key** — the Edge Function is the intended path, but
  `AppCredentials` still carries an in-app default key for out-of-the-box use; it is
  protected only by Groq-side spend limits and the per-tier quota counters.
- **No fine / penalty calculation inside the app.** `README.md` and
  `FINAVIG_APP_EXPLAINER.md` advertise "Penalty & Fine Risk Estimates" (e.g. *Driver
  Licence expired → fine 500 + 12 black points*), but no such code exists: there is
  no penalty field on `ExpiryItem`, no amount in the authority catalogs, and no
  string like `penalty`/`blackPoints` anywhere in `lib/`. Treat that claim as
  roadmap, not shipped behaviour.
- **Web admin console, multi-currency settlement and native desktop builds** are
  outside this app's scope today.

---

## 18. Where to read more

- [`README.md`](README.md) — setup, backend bootstrap and stack summary
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — system diagram, nav map, workflows, data model
- [`FINAVIG_APP_EXPLAINER.md`](FINAVIG_APP_EXPLAINER.md) — product walkthrough
- [`docs/technical-documentation.md`](docs/technical-documentation.md) — developer deep dive
- [`docs/credit-money-sync.md`](docs/credit-money-sync.md) — the credit ↔ Money design
- [`MONETIZATION.md`](MONETIZATION.md) — tier strategy and pricing rationale
- [`docs/README.md`](docs/README.md) — screenshot gallery of the shipped screens
