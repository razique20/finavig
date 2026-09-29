# Finavig — Pre-Deployment Feature Checklist (v1.0.0)

> **Progress note:** Tier 1 items 1–6 and Tier 2 items 8–11 are now
> **implemented** (marked ✅ below), with unit tests in
> `test/rating_prompt_test.dart`, `test/error_capture_test.dart`,
> `test/connectivity_and_export_test.dart` and `test/demo_document_test.dart`.
> Remaining: run the `supabase/app_versions_seed.sql` smoke test (#3) and
> everything in Tier 3.

> Simple, low-effort, high-impact additions to finish **before** releasing to the
> Play Store / App Store. Everything here is scoped to days, not weeks, and does
> not change the app's architecture.
>
> Companion to `docs/feasibility-study.md` §7 (go/no-go checklist) — this file
> covers the *product* polish; that one covers release engineering.

---

## 🟢 Tier 1 — Do before launch (small, high impact)

### 1. ✅ Notification tap → open the document (deep link)
**Done:** `NotificationTapService` + tap hook in `NotificationService.init()`;
taps route to `/document/:id`, cold start included.
**Why:** this is the moment of highest intent — a user who taps the alert wants
the document, not the home feed. Biggest retention lever for the least code.

### 2. ✅ Crash/error capture (local now, Sentry-ready)
**Done:** `ErrorCaptureService` installs `FlutterError.onError` +
`PlatformDispatcher.onError` hooks from `main.dart`; keeps the last 20 errors
persisted. When Sentry arrives, forward from `record()` — everything funnels
through it.
**Why:** the first week of a release is exactly when silent crashes happen, and
there is no way to see them today.

### 3. ⏳ "Update available" prompt — schema exists, smoke test pending
`AppVersionService` + `AppVersionDialog` already support optional and force
updates. The schema + v1.0.0 seed + per-release runbook already live in
`supabase/app_version_schema.sql` — **Remaining:** run that file in the Supabase
SQL editor (if not already applied), then verify the dialog appears (and that a
*force* update halts navigation).
**Why:** your first hotfix path must be proven *before* you need it.

### 4. ✅ Permissions pre-permission screens (notifications)
**Done:** new onboarding page explains the 90/60/30/7 alert value before the OS
prompt fires on first init.
**Why:** users who deny notifications lose the core promise; a 2-line explainer
measurably raises grant rates.

### 5. ✅ In-app "Rate the app" prompt (soft ask)
**Done:** `RatingPromptService` + `RatingPromptUi` (in_app_review), triggered
after every renewal success moment. Policy: never before 2 renewals, 90-day
cooldown, max 3 asks per install — unit-tested.
**Why:** store ratings gate ASO (channel 3 in the feasibility study), and happy
moments are when users say yes.

### 6. ✅ Export / backup nudge (data safety reassurance)
**Done:** dismissible `ProfileBackupNudge` banner on the Profile tab pointing
at the CSV/PDF exporters.
**Why:** turns the #1 data-loss complaint into a documented, in-app expectation.

### 7. Rate-limit feedback for AI quota exhaustion
The quota flow already blocks at the tier limit. When exhausted, instead of a
plain error, show remaining resets + an upgrade CTA to the Plus tier
(`EntitlementService` knows the tier; `upgrade_request_service.dart` exists).
**Why:** monetization moment handed to you at peak frustration.

---

## 🟡 Tier 2 — Fast follows (same week if possible)

### 8. ✅ Offline / connection banner
**Done:** `ConnectivityService` (DNS probe against supabase.co, 30s poll +
resume re-check, test-safe) and an animated `OfflineBanner` above the app
shell. No new dependency.
**Why:** the app is offline-first, but users don't know that; silence reads as
"broken".

### 9. ✅ Android OEM battery-saver guidance
**Done:** "Ensure reminders work" tile in Profile → Preferences links to
don't-kill-my-app.com.
**Why:** feasibility study lists missed notifications as the highest-impact
operational risk.

### 10. ✅ First-run sample data
**Done:** "Try a demo document" button in both empty states (Home + Documents).
`DemoDocumentService` adds one labelled "Demo: Sample Trade Licence" expiring
in 21 days (shows the amber urgency band); removed like any document.
**Why:** time-to-first-value drops from "figure it out" to ~30 seconds.

### 11. ✅ Data-export for PDPL (GDPR-style compliance)
**Done:** "Download my data" tile in Profile → Preferences. `UserDataExportService`
bundles documents, finance ledger and profile prefs into one JSON file
(save-to-file with share-sheet fallback).
Deletion already existed (`profile_sheets.dart` — delete account).

### 12. Arabic-ready strings check (no UI change)
Don't localize yet — just sweep hardcoded strings into a constants file and turn
on `flutter analyze` lint for string literals where practical. RTL support is
listed out-of-scope for the pilot, but prep work now saves a rewrite later.

---

## 🔵 Tier 3 — Post-launch hardening (next 2–4 weeks)

### 13. WhatsApp / email alert server path
`NotificationService.sendWhatsAppAlert` / `sendEmailAlert` are stubs awaiting the
Supabase Edge Function + Meta Cloud API. This is the durable fix for
OEM notification unreliability (the `reminders` table is the ready data source).

### 14. Supabase Storage attachment sync
Schema-ready, ~1–2 days per the feasibility study. After this ships, remove the
Tier-1 #6 banner and flip it to "Backed up ✓".

### 15. `amount_due` on documents + renewal reminders that carry the cost
Phase-0 item from `FINTECH_ROADMAP.md` ("deadlines become transactions") —
reminder copy becomes "Ejari renews in 30 days — AED 12,400 due". No payments
yet, pure data.

### 16. Feature flags
Simple `app_config` table + cached bools so paid features and AI models can be
toggled per cohort without a store release.

---

## ✅ Already covered (no work needed)

- Update/force-update dialog (splash → `AppVersionService`)
- Delete account + privacy policy links (profile sheets, `AppLinks`)
- Terms acceptance copy on login
- Empty states + pull-to-refresh across all main screens
- App icon + adaptive icon + store assets (`assets/store/`)
- Budget 80/100% alert engine + OS channels
- Local-only (offline) mode as first-class citizen
- CI: analyze + file-size ratchet + full 305-test suite

---

## Suggested order of attack

| # | Feature | Effort | Impact | Status |
|---|---|---|---|---|
| 1 | Notification deep link | ½ day | ★★★ | ✅ done |
| 2 | Crash capture (local, Sentry-ready) | ½ day | ★★★ | ✅ done |
| 3 | app_versions smoke test | 1 hr | ★★ | ⏳ schema exists (`supabase/app_version_schema.sql`) — run + verify |
| 4 | Notification pre-permission | 2 hrs | ★★ | ✅ done |
| 5 | Rate prompt | ½ day | ★★ | ✅ done |
| 6 | Backup/export nudge | 2 hrs | ★★ | ✅ done |
| 7 | Quota-exhausted upgrade CTA | 2 hrs | ★★ | already existed |
| 8 | Offline banner | ½ day | ★★ | ✅ done |
| 9 | OEM battery guidance | 2 hrs | ★★ | ✅ done |
| 10 | Demo document | 2 hrs | ★ | ✅ done |

Tier 1 ≈ 2 focused days. Tier 2 adds ~1.5 days. Everything above slots in
*before* the store-listing work already estimated in the feasibility study.
