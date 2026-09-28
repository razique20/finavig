# Finavig App — UI/UX & Performance Optimization Roadmap

This document outlines the **next wave** of architectural, visual, and interaction enhancements designed to make **Finavig** feel **frictionless, lightning-fast, and premium** across all devices. The previous wave (shimmer skeletons, quick-action speed dial, pinch-to-zoom viewer, Money tab modularization, unified Ask Finavig AI sheet) is fully shipped.

---

## 1. Profile Screen Modularization *(pending)*
* **Is:** `lib/screens/profile_screen.dart` is the largest file in the app (~2,240 lines), mixing account cards, Groq/Gemini key management, app-guide entry points, and settings rows in one widget tree.
* **Plan:** Split into `lib/screens/profile/` modules — `profile_sections.dart` (shared `SectionHeader`/`TintedCardBox` primitives), `account_cards.dart`, `ai_providers_section.dart` (Groq + Gemini key fields), `settings_rows.dart`, and dedicated form sheets. Make every section widget `const`-constructible so it rebuilds independently.
* **Impact:** Smaller rebuild scopes, faster Profile tab open, and a file the team can actually navigate.

---

## 2. Document Detail Screen Modularization *(pending)*
* **Is:** `lib/screens/document_detail_screen.dart` (~2,139 lines) contains the detail layout, the full-screen image viewer, the non-image info sheet, share/export logic, and attachment tiles in one file.
* **Plan:** Extract `_FullScreenImageViewer` into `lib/widgets/viewers/full_screen_image_viewer.dart`, attachment card + share actions into `lib/widgets/documents/attachment_card.dart`, and the info sheet into `lib/screens/documents/detail_info_sheet.dart`.
* **Impact:** Reusable viewer for future screens (expiry list previews, records), and faster compile/iterate cycles on the most feature-dense screen.

---

## 3. Lazy Lists Everywhere (`ListView.builder` Sweep) *(pending)*
* **Is:** Several screens still build the whole child tree eagerly via `ListView(` — `documents_screen.dart`, `budgets_screen.dart`, `envelopes_screen.dart`, `records_screen.dart`, `alerts_reminders_screen.dart`, `cash_flow_forecast_screen.dart`, and the quick-action companion sheet.
* **Plan:** Convert to `ListView.builder` / `SliverList` with `itemBuilder`, and `addAutomaticKeepAlives: false` + `addRepaintBoundaries: true` where children are stateless. Long lists (documents, records) should also be sharded with `PagedListView`-style chunks if item counts grow.
* **Impact:** Constant-memory scrolling and 60–120 FPS on the tabs users hit dozens of times a day.

---

## 4. Cached Image Pipeline for Document Attachments *(pending)*
* **Is:** `document_detail_screen.dart` renders attachments with raw `Image.file` / `Image.network` — no downsampled decode, no disk cache for cloud URLs.
* **Plan:**
  * Pass `cacheWidth`/`cacheHeight` sized to the viewport so a 12 MP scan never decodes at full resolution in the list view.
  * Adopt `cached_network_image` (with blur-hash placeholder matching the shimmer aesthetic) for Cloud/URL attachments.
  * Pre-warm thumbnails when a document row becomes visible.
* **Impact:** Instant attachment previews, dramatically lower memory on the Documents tab, fewer jank frames when scrolling between scans.

---

## 5. Ask Finavig AI — Persistent Token Budget & Cross-Session Memo *(pending)*
* **Is:** `ai_intent_router_service.dart` already enforces a per-session escalation budget (max 4 Groq escalations) and memoizes exact inputs — but the memo and budget die when the sheet closes.
* **Plan:**
  * Persist the exact-input memo cache (LRU, ~200 entries) to disk so repeat utterances across sessions stay at $0 tokens.
  * Upgrade the per-session budget to a rolling daily budget shared by all AI entry points (quick-action sheet, money form, document form).
  * Surface remaining budget subtly in the sheet ("AI assist: 3/4 today") so power users understand degradation.
* **Impact:** Near-zero Groq spend becomes durable, not just per-session; graceful degradation stays predictable.

---

## 6. Home & Documents Screen Modularization *(pending)*
* **Is:** `home_screen.dart` (~1,542 lines) and `documents_screen.dart` (~1,615 lines) still carry their full bento layouts, alert ladders, and search/filter logic inline.
* **Plan:** Follow the Money tab precedent — extract `home/` and `documents/` widget modules with shared section primitives, and move the expiry-alert ladder card into `lib/widgets/cards/` so Expiry List and Home reuse one implementation.
* **Impact:** Independent rebuilds per card, faster tab switches, one source of truth for the 90·60·30·7-day alert UI.

---

## 7. App Guide & FAQ Content Split *(pending)*
* **Is:** `app_guide_dialog.dart` (~952 lines) and `faq_sheet.dart` (~615 lines) inline large amounts of static content, inflating widget files and first-build cost.
* **Plan:** Move content data to `lib/config/app_guide_content.dart` / `faq_content.dart` (plain Dart constants), and render from a generic paged sheet. Consider lazy-loading the content file on first open.
* **Impact:** Smaller core bundle, content edits without touching widget code, cheaper cold start.

---

## 8. Performance Instrumentation & Regression Guards *(pending)*
* **Is:** No ongoing measurement exists to prove the optimizations above stay fast as features land.
* **Plan:**
  * Add DevTools timeline tracing checkpoints (frame build/raster times) around critical flows: cold start → Home, tab switch, document open, quick-action sheet open.
  * Golden tests for the shimmer skeleton views and Money section cards so visual refactors can't silently regress.
  * A `flutter analyze --no-pub` + `dart format` CI gate with a file-size budget warning (e.g., flag any widget file > 1,000 lines).
* **Impact:** Optimizations become measurable and permanent instead of one-off wins.

---

## Next Action Plan

Select an optimization to implement:
1. **Profile Screen Modularization** — biggest file first.
2. **Document Detail Screen Modularization** — extract the reusable full-screen viewer.
3. **Lazy Lists Everywhere** — `ListView.builder` sweep across all tabs.
4. **Cached Image Pipeline** for document attachments.
5. **Ask Finavig AI persistent token budget** & cross-session memo.
6. **Home & Documents Screen Modularization**.
7. **App Guide & FAQ content split**.
8. **Performance instrumentation & regression guards**.

Recommended order: **3 → 4 → 1 → 2 → 6 → 7 → 5 → 8** (user-perceived speed wins first, then structural cleanups, then measurement to lock everything in).
