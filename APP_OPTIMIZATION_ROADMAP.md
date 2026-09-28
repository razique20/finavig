# Finavig App — UI/UX & Performance Optimization Roadmap

This document outlines the **next wave** of architectural, visual, and interaction enhancements designed to make **Finavig** feel **frictionless, lightning-fast, and premium** across all devices. The previous wave (shimmer skeletons, quick-action speed dial, pinch-to-zoom viewer, Money tab modularization, unified Ask Finavig AI sheet) is fully shipped.

---

## 1. ✅ Profile Screen Modularization *(implemented)*
* **Was:** `lib/screens/profile_screen.dart` was the largest file in the app (~2,240 lines), mixing account cards, Gemini key management, app-guide entry points, and settings rows in one widget tree.
* **Implemented:** Split into `lib/screens/profile/` modules, mirroring the Money tab precedent:
  * `profile_sections.dart` — shared primitives: `ProfileSectionGroup`, `ProfileSettingsTile`, `ProfileUsageMeter`, `ProfilePlanNotice`, `profileTileBg`.
  * `profile_hero.dart` — `ProfileHeroHeader` (identity, plan/sync badges, sign out).
  * `profile_account_section.dart` — `ProfileAccountCard` + `ProfileAiSection` (Gemini key).
  * `profile_subscription_section.dart` — `ProfileSubscriptionSection` with self-contained document-count future.
  * `profile_collections_section.dart` — `ProfileCollectionsSection` (switch/rename/delete/lock).
  * `profile_appearance_section.dart` — `ProfileAppearanceSection` + `ProfilePreferencesSection`.
  * `profile_sheets.dart` — stateless bottom sheets: edit-profile, Gemini key, submit-request, request history, `ProfileSupportRequestCard`.
  * The screen file is down from ~2,240 to ~423 lines; dead alert-toggle state left over from the standalone Alerts & Reminders screen was removed.
* **Impact:** Smaller rebuild scopes, faster Profile tab open, and a settings screen the team can actually navigate. Covered by `settings_redesign_test.dart` + `plan_restriction_and_collection_locking_test.dart`.

---

## 2. Document Detail Screen Modularization *(pending)*
* **Is:** `lib/screens/document_detail_screen.dart` (~2,139 lines) contains the detail layout, the full-screen image viewer, the non-image info sheet, share/export logic, and attachment tiles in one file.
* **Plan:** Extract `_FullScreenImageViewer` into `lib/widgets/viewers/full_screen_image_viewer.dart`, attachment card + share actions into `lib/widgets/documents/attachment_card.dart`, and the info sheet into `lib/screens/documents/detail_info_sheet.dart`.
* **Impact:** Reusable viewer for future screens (expiry list previews, records), and faster compile/iterate cycles on the most feature-dense screen.

---

## 3. ✅ Lazy Lists Everywhere (`ListView.builder` Sweep) *(implemented)*
* **Was:** Several screens built their whole child tree eagerly via `ListView(` — Alerts & Reminders, Budgets, Envelopes, Cash-Flow Forecast, the document-type filter sheet, the Home collection switcher, the notifications sheet, and the quick-action companion sheet.
* **Implemented:**
  * **Data-driven rows → true lazy builders:** Budgets & Envelopes moved to `CustomScrollView` + `SliverList.builder` (headers as `SliverToBoxAdapter`, empty states preserved); Cash-Flow event days to `SliverList.builder` with `SliverPadding`; document-type sheet and collection switcher to `ListView.builder` with `shrinkWrap` retained.
  * **Bounded sheets → `ListView.builder` over prepared rows:** notifications sheet and companion-suggestion sheet build their row widgets once, then lay out only the visible portion (sheets are height-capped, so this eliminates the bulk of layout cost without changing the data flow).
  * **Static form kept as a short list:** Alerts & Reminders is a fixed ~6-section settings form — converted to `CustomScrollView` + `SliverChildListDelegate` so off-screen portions of the scrollable no longer lay out; Records' empty state is a 2-child list left as-is (nothing to lazify).
* **Impact:** Constant-memory scrolling and 60–120 FPS on the tabs users hit dozens of times a day. All 300 tests pass, and the analyzer shows no new issues on converted files.

---

## 4. ✅ Cached Image Pipeline for Document Attachments *(implemented)*
* **Was:** `document_detail_screen.dart` rendered attachments with raw `Image.file` / `Image.network` — no downsampled decode (a 12 MP scan decoded at full resolution inside a 44 px card) and no disk cache for cloud URLs (every open re-downloaded).
* **Implemented:** New shared pipeline in `lib/widgets/attachment_thumbnail.dart`:
  * `AttachmentImage` — **local files decode downsampled** (`cacheWidth` = layout width × device pixel ratio); **cloud URLs** go through `cached_network_image` with a persistent disk cache and a pulsating placeholder matching the shimmer aesthetic; smooth fade-in frame builder; styled error states.
  * **Attachment card previews:** the detail screen's 44 px file tile now shows a real downsampled thumbnail instead of a generic paperclip icon.
  * **Full-screen viewer:** switched to `AttachmentImage` with no cache bounds (native resolution, crisp zoom) and a progress-free cached load.
  * **Pre-warm helper:** `prewarmAttachmentImage` decodes local images into the shared image cache via `precacheImage` (exact-provider match, incl. `ResizeImage` width) and disk-caches cloud files via `flutter_cache_manager`; `DocumentsScreen._prewarmThumbnails()` warms the first 24 image attachments after each list load.
  * Added `cached_network_image` + explicit `flutter_cache_manager` dependencies.
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

## 6. ✅ Home & Documents Screen Modularization *(implemented)*
* **Was:** `home_screen.dart` (~1,542 lines) and `documents_screen.dart` (~1,615 lines) carried their full bento layouts, alert ladders, and search/filter logic inline — including duplicate hero pill/icon-button widgets between the two screens.
* **Implemented:** Followed the Money tab precedent —
  * `lib/screens/home/` — `home_hero_header.dart` (hero + notification bell & alert sheet), `home_collection_switcher.dart` (tier-aware switcher sheet + apply flow), `home_banners.dart` (plan-restriction, attention, expired alerts), `home_categories_grid.dart`, `home_upcoming_section.dart`. Screen file: 1,542 → 259 lines.
  * `lib/screens/documents/` — `documents_hero_header.dart`, `documents_filters.dart` (search field, status chips, active-filters row, type/sort sheets, `DocFilter`/`DocSort` enums), `documents_insights_section.dart`, `document_card.dart`, `document_action_sheets.dart`. Screen file: 1,615 → 394 lines.
  * `lib/widgets/hero_widgets.dart` — shared `HeroIconButton` + `HeroActionPill`, now used by Home, Documents, *and* Profile heroes (three copies deleted).
  * `lib/widgets/cards/urgency_timeline_card.dart` — the shared 90·60·30·7-day alert ladder card; `document_detail_screen.dart` now renders `UrgencyTimelineCard.withIndicator` instead of its private copy (2,139 → 1,879 lines).
* **Impact:** Independent rebuilds per card, faster tab switches, and one source of truth for the hero chrome and urgency-ladder UI. All 300 tests pass, including the Home/Documents/Profile redesign suites.

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
1. ~~**Profile Screen Modularization** — biggest file first.~~ ✅ Done — see feature #1 above.
2. **Document Detail Screen Modularization** — extract the reusable full-screen viewer.
3. ~~**Lazy Lists Everywhere** — `ListView.builder` sweep across all tabs.~~ ✅ Done — see feature #3 above.
4. ~~**Cached Image Pipeline** for document attachments.~~ ✅ Done — see feature #4 above.
5. **Ask Finavig AI persistent token budget** & cross-session memo.
6. ~~**Home & Documents Screen Modularization**.~~ ✅ Done — see feature #6 above.
7. **App Guide & FAQ content split**.
8. **Performance instrumentation & regression guards**.

Recommended order: **~~3~~ → ~~4~~ → ~~1~~ → 2 → ~~6~~ → 7 → 5 → 8** — user-perceived speed wins first, then structural cleanups, then measurement to lock everything in.
