# Finavig — Complete App Test Report

Date: 2026-10-05
Branch: `main`
Scope: complete user flows + screen-by-screen UI flow across the whole app

## Summary

| Check | Command | Result |
| --- | --- | --- |
| Full test suite | `flutter test` | **400/400 passing**, exit 0 |
| Complete flow + UI suite (new) | `flutter test test/complete_app_flow_test.dart` | **23/23 passing**, exit 0 |
| Static analysis (lib + new suite) | `flutter analyze lib test/complete_app_flow_test.dart` | 403 issues — **0 errors**, 33 warnings + 370 `info`, all pre-existing |
| Static analysis (new suite only) | `flutter analyze test/complete_app_flow_test.dart` | **No issues found** |

45 test files in `test/` (plus the simulator-only pitch tour in
`integration_test/`). Nothing regressed in this pass — the suite grew from 377
to 400 tests.

## What this pass adds

`test/complete_app_flow_test.dart` — 23 tests in two layers:

1. **Complete user flows** through the *real* router (`lib/router.dart`), the
   way a person actually moves through the app (7 tests).
2. **UI flow — screen by screen** mounting every routed screen directly and
   guarding its primary UI contract (16 tests).

The app runs in local-only mode under test: Supabase is unconfigured, so the
auth redirect is off and no live cloud/OS dependencies are exercised.

## Complete flows verified

| # | Flow | Route(s) / actions | Asserted outcome |
| --- | --- | --- | --- |
| 1 | Bottom-nav round-trip | `/home` → Money → Documents → Profile → Home | Home `Net this month`; each tab shows its heading + live status line |
| 2 | Document lifecycle | seed via `DemoDocumentService` → `/documents` → `/document/:id` → overflow menu | Document listed in the vault; detail shows its name; `Mark as renewed` offered |
| 3 | Money lifecycle | log income + 2 expenses → `/money` → `/records` | Money shows `Net this month`; Records lists every logged title |
| 4 | Budget + envelope creation | `upsertBudget`, `addEnvelope` → `/budgets` → `/envelopes` | Budget shows its category; envelope shows its name |
| 5 | Full-screen route tour | `/expiry-list`, `/cash-flow-forecast`, `/ai-summary`, `/ai-budget-plan`, `/alerts-reminders`, `/search` | Each route resolves to its own heading with no build exception |
| 6 | Settings surface | `/profile` | `Subscription`, `My Collections`, `Appearance`, `Alerts & Reminders`, `AI Summary` all present |
| 7 | Quick action | tap the shell **(+)** orb | 1-tap creation menu opens without error |

## UI flow verified — screen by screen

| Screen | Primary contract asserted |
| --- | --- |
| `WelcomeScreen` | `FV` monogram, `Finavig`, `Continue to Login` CTA |
| `LoginScreen` | `GCC Edition`, `Sign in` / `Sign up` toggle, `Continue` |
| `HomeScreen` | `Net this month` hero, `Categories` grid, `Record` pill |
| `DocumentsScreen` | `Documents` hero, `Search documents…`, `Filter`, `Sort` |
| `MoneyScreen` | `Money` header, `Net this month`, `Add Record` |
| `ProfileScreen` | `Settings` header, `Subscription`, `My Collections` |
| `BudgetsScreen` | `Budgets` header, `Add category` |
| `EnvelopesScreen` | `Savings envelopes` header, `New envelope` |
| `RecordsScreen` | `Records` header |
| `GlobalSearchScreen` | `Search all your documents` empty state |
| `ExpiryListScreen` | `Upcoming Expiries` header |
| `CashFlowForecastScreen` | `90-Day Cash-Flow Forecast` header, filter chips |
| `AiSummaryScreen` | `AI Executive Summary` header |
| `AiBudgetPlanScreen` | `AI Budget Planner` header |
| `AlertsRemindersScreen` | `Renewal notifications`, `Budget alerts` switches |
| `DocumentScanScreen` | `Upload document` header, `Document Title *` field |

Every UI-flow test also asserts `tester.takeException()` is null, so a throwing
build fails the test even when the text anchor is present.

## Existing domain coverage (unchanged, still green)

The new suite sits on top of the 42 pre-existing domain/widget suites, which
continue to pass. Highlights by area:

- **Finance & budgets** — `finance_test.dart`, `cash_flow_test.dart`,
  `natural_language_money_test.dart`, `recurring_test.dart`,
  `monthly_summary_test.dart`, `budget`/`tier_pricing_test.dart`.
- **Documents & expiry** — `documents_redesign_test.dart`,
  `document_enhancements_test.dart`, `scan_screen_test.dart`,
  `renew_document_dialog_test.dart`, `uae_authority_catalog_test.dart`.
- **AI** — `ai_intent_router_test.dart`, `ai_budget_plan_test.dart`,
  `groq_ai_summary_test.dart`, `ask_finavig_sheet_test.dart`,
  `natural_language_parser_test.dart`, `smart_category_engine_test.dart`.
- **Auth / app lock** — `app_lock_test.dart` (35 tests, see
  [`app-lock-test-report.md`](app-lock-test-report.md)),
  `welcome_screen_test.dart`, `first_run_guide_banner_test.dart`.
- **Alerts / settings** — `alerts_reminders_screen_test.dart`,
  `alert_preferences_test.dart`, `settings_redesign_test.dart`,
  `anomaly_detection_test.dart`.
- **Cross-cutting** — `connectivity_and_export_test.dart`,
  `error_capture_test.dart`, `shimmer_skeleton_test.dart`, `golden_test.dart`.

## Notable findings

- **The bottom-nav shell is the flow backbone.** Every full-screen route
  (`/budgets`, `/records`, `/cash-flow-forecast`, …) is pushed above the
  `StatefulShellRoute`, so the flow tests navigate with `router.go(route)`
  while the four tab branches stay mounted. Tab state survives route pushes.
- **Splash timing matters in tests.** `SplashScreen` schedules a 1000 ms
  navigation future and a 1800 ms animation; the flow helper pumps 2 s before
  redirecting so no pending timer leaks into the assertion window.
- **Singleton caches must be cleared per test.** `DocumentScannerService` and
  `FinanceService` hold cross-test state; `setUp` calls `clearCache()` so
  seeded documents/transactions stay isolated.
- **Local-only mode is a real product mode.** Because `SupabaseService` is
  unconfigured under test, the auth gate is off and the app is fully usable
  signed-out — the flows above are the genuine offline experience, not a
  downgraded stub.

## Limitations

- **Auth against live Supabase is not covered here.** Sign-up, email
  confirmation and post-auth refresh are host-dependent; `app_lock_test.dart`
  and `welcome_screen_test.dart` cover the client-side gate logic instead.
- **Platform channels (OCR, notifications, speech, biometrics) are not
  exercised.** The AI summary/plan screens are pumped for their first frame
  only; network/LLM paths degrade gracefully (services are wrapped in
  try/catch) but their live output is not asserted.
- **The pitch tour** (`integration_test/app_pitch_screenshots_test.dart`) walks
  every screen on a simulator for the screenshot deck; it is not part of
  `flutter test` and was not re-run in this pass.
- **Pre-existing analyzer noise.** 33 warnings (unused imports/fields) and 370
  `info` deprecations (`withOpacity`) remain in `lib/`; none are errors and
  none are in the new suite. `flutter analyze` exits 0 (warnings do not fail
  the analyzer's exit code configured here).
- The README's "131 passing tests" figure was stale; it now reads 400.

## Commands used

```bash
flutter test
flutter test test/complete_app_flow_test.dart
flutter analyze lib test/complete_app_flow_test.dart
flutter analyze test/complete_app_flow_test.dart
```
