# OPTIMIZATION_PLAN.md — Finavig performance & quality optimization roadmap

A living checklist of optimization work, ordered by impact. Each item names
the file(s) involved, what to do, and how to verify it. Items move to
"Done" as they ship. Statuses: ☐ TODO · ◐ IN PROGRESS · ✅ DONE.

---

## 1. App size (install footprint)

- ☐ **Audit bundled fonts (done) — next: subset them.**
  `assets/fonts/Inter-Regular.ttf` (856 KB) and `PlayfairDisplay.ttf`
  (300 KB) are variable fonts covering every weight. Run
  `flutter build apk --analyze-size` / `devtools size analysis` and, if the
  binaries dominate, swap to static-weight subsets (Inter Regular/Medium/
  SemiBold/Bold latin-only, ~40 KB each) via the google/fonts static folder
  or a subset tool (`fonttools pyftsubset`).
- ☐ **Prune mlkit OCR models.** `google_mlkit_text_recognition` pulls
  per-script models. If only latin (UAE/GCC documents in English) is
  targeted today, confirm no extra script models are referenced.
- ☐ **Run a size pass before every store submission:**
  `flutter build appbundle --analyze-size`, record results in this file.

## 2. Cold start (launch → first useful frame)

- ✅ **Bundled fonts eliminate font-fetch stall** (was: google_fonts runtime
  download → tofu + delayed first paint). See commit `a492cf7`.
- ☐ **Trim `main()` sequential awaits.** `lib/main.dart` awaits Theme →
  Supabase → AlertPreferences → BudgetAlert → StorageMigration → prewarm
  in order. Move anything not needed before the first frame into
  `unawaited(...)` post-frame work; measure with
  `PerfTracingService.markFlow(flowColdStartToHome)` (already wired).
- ☐ **Defer notification timezone init.** `NotificationService.init()`
  does `tzdata.initializeTimeZones()` during prewarm; only needed when the
  first reminder is scheduled. Lazily init on first `schedule*` call.
- ☐ **Defer `BudgetAlertService.init()`** to after first frame — it only
  matters once finance data changes.
- ☐ **Gate version check.** `AppVersionService.checkAppVersion` runs on
  every splash; add a 6–12h result cache (prefs) so offline/slow-network
  cold starts don't wait on it.
- ✅ **Permission prompt moved post-onboarding** (no OS dialog over the
  launch screen). See commit `a492cf7`.

## 3. Runtime performance

- ☐ **ListView virtualization sweep.** Verify every long list uses
  `.builder` (documents, records, expiry list, search results). No
  `Column(children: [...map])` over unbounded data. Grep for
  `children: .*\.map(` inside `SingleChildScrollView`.
- ☐ **Image caching for document photos.** Files render via Image.file;
  add `cacheWidth/cacheHeight` (or `ResizeImage`) sized to the tile so
  full-resolution photos aren't decoded per row. Biggest win on the
  Documents grid and Records attachments.
- ☐ **Avoid `setState` storms from singletons.** `FinanceService`/
  `DocumentScannerService` listeners call `setState(() {})` on the whole
  screen (`_reloadMoney`). Switch hot screens to targeted rebuilds
  (`ValueListenableBuilder`/`Selector`) or debounce bursts (sync outbox
  can notify many times in a row).
- ☐ **Cache urgency computation.** `UrgencyEngine().compute(_items)` runs
  in `build()` on Home. Memoize on item-list identity; recompute only when
  the list changes.
- ☐ **Debounce global search.** `global_search_screen` should debounce
  input ~250 ms and search the in-memory index, not hit storage per
  keystroke.
- ☐ **Frame budget CI gate.** `PerfTracingService` already records frame
  times in debug/profile. Add a nightly integration run that asserts
  p95 frame < 16 ms on tab switches (flow marks exist for tab switch,
  document open, quick actions).

## 4. Storage & sync

- ☐ **Index Supabase queries.** Confirm composite indexes exist for
  `documents(user_id, collection_id, expires_at)` and
  `finance_transactions(user_id, collection_id, occurred_at)`; add a
  migration when the first slow query shows up.
- ☐ **Batch sync outbox.** `doc_sync.dart` — push/pull in batches of 50+
  with a single `notifyListeners` at the end instead of per-row.
- ☐ **Local pagination.** `DocumentScannerService.getAllItems` loads
  everything into memory; fine to ~1k docs, but add limit/offset paging
  for the Records ledger before user data grows.
- ☐ **Prefs payload hygiene.** Error ring buffer (`finavig.error_log.v1`),
  rating counters, export lists — cap sizes and clean on sign-out.

## 5. Network

- ☐ **HTTP client reuse.** Verify Groq/Gemini/Supabase REST calls share
  one client (no `http.Client()` per call); Supabase SDK already does.
- ☐ **Timeouts + retry with backoff on AI calls** (currently a hang shows
  as a stuck sheet). 15 s timeout, 1 retry.
- ☐ **Cache AI summaries** per month/plan hash so re-opening the summary
  screen doesn't re-bill tokens (store keyed by month + data hash).

## 6. Build & CI

- ☐ **Split CI work.** `flutter analyze` + tests + perf budget run on
  every push; add caching of pub caches (`actions/cache` keyed on
  `pubspec.lock`) if CI minutes become an issue.
- ☐ **Goldens for money screens.** Add 2–3 golden tests so refactors of
  `money_summary_cards` can't silently change layout.
- ✅ **File-size ratchet** (`tool/perf_budget_check.dart`) and font/analyze
  gates already in CI.

## 7. Memory

- ☐ **Dispose sweep.** Run `flutter analyze` + custom grep for
  `AnimationController`/`PageController`/`TextEditingController` without
  matching `.dispose()`; every screen must clean up.
- ☐ **Release OCR temp buffers.** `uae_document_ocr_service` — ensure
  camera/OCR intermediates are released after extraction, not held by
  listeners.

## Done log

| Date | Item | Commit |
|---|---|---|
| 2026-09-30 | Bundled Inter + Playfair (cold-start tofu fix) | `a492cf7` |
| 2026-09-30 | Permission prompt post-onboarding | `a492cf7` |
| 2026-09-28 | File-size budgets in CI | `8231e62` |

---

How to use this file: pick the highest ☐ item you can finish in one
session, do it, move it to ✅ with a commit hash in the Done log, commit
as `Optimize: <item>`.
