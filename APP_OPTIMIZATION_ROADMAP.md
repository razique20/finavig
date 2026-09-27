# Finavig App — UI/UX & Performance Optimization Roadmap

This document outlines key architectural, visual, and interaction enhancements designed to make **Finavig** feel **frictionless, lightning-fast, and premium** across all devices.

---

## 1. ✅ Initial Loading & Shimmer Skeletons (Zero-Lag Experience) *(implemented)*
* **Was:** When opening the app or navigating to a tab (*Documents* or *Money*) for the first time, data hydrated asynchronously with a blank frame first.
* **Implemented:** Modern **Shimmer Skeleton Loaders** on `HomeScreen`, `DocumentsScreen`, and `MoneyScreen` (`lib/widgets/shimmer_skeleton.dart`). While data hydrates, users instantly see an elegant pulsating card outline that seamlessly transitions into their real data:
  * Reusable `ShimmerSkeleton` primitive + ready-made `TileSkeletonLoader`.
  * Full-page layouts: `HomeSkeletonView`, `DocumentsSkeletonView`, `MoneySkeletonView` — each mirroring the real screen's structure.
  * Covered by `test/shimmer_skeleton_test.dart`.
* **Impact:** Eliminates perceived loading delay and ensures continuous visual feedback.

---

## 2. ✅ Speed Dial / Universal Quick Action Button *(implemented)*
* **Was:** To scan a document, log an expense, or create an envelope, users had to navigate to specific tab screens first.
* **Implemented:** A violet **Universal Action Button (`+`)** sits at the center of the floating nav pill (`_QuickActionButton` in `lib/router.dart`). It opens `showQuickActionSheet` (`lib/widgets/dialogs/quick_action_sheet.dart`), a 1-tap quick menu:
  * 📄 **Scan / Add Document** — Free-tier quota enforced, then the full-screen scanner.
  * 💸 **Log Expense or Income** — `TransactionFormSheet` with smart category matching.
  * 🎙️ **Voice AI Log (Talk to Finavig)** — Natural language + voice input, auto-categorized.
  * ✉️ **Create Savings Envelope** — Instant target allocation via `EnvelopeFormSheet`.
* **Impact:** 1-tap access to every core feature from anywhere in the app; entitlement gates stay enforced by reusing the same flows as the tabs.

---

## 3. 📄 Document Details: Full-Screen Pinch-to-Zoom & Quick Share *(implemented)*
* **Was:** Uploaded document scans and PDF receipts rendered inside a fixed rectangular preview box in `DocumentDetailScreen`.
* **Implemented:**
  * **Interactive Full-Screen Viewer:** Tapping *View* (or *Details*) opens `_FullScreenImageViewer` (`lib/screens/document_detail_screen.dart`) — a black-out full-screen modal with pinch-to-zoom (1×–5×), double-tap-to-zoom at the tapped point, and smooth fade-in.
  * **One-Tap Export & Share:** A *Share* action on the attachment card, the viewer's app bar, and the non-image info sheet calls `SharePlus.instance.share` (`share_plus`) so users can instantly send their scanned Emirates ID / Ejari / Mulkiya via WhatsApp or Mail. Cloud (URL) attachments share the link; missing local files show a helpful "re-upload on this device" sheet.
* **Impact:** Turns Finavig into a true professional document scanner & manager.

---

## 4. ✅ Money Tab Modularization & Smooth Frame-Rates *(implemented)*
* **Was:** `money_screen.dart` was a heavy file (117 KB) rendering charts, envelope cards, recurring payment ladders, and transaction lists in a single widget tree.
* **Implemented:** Refactored into modular, `const`-constructible component cards under `lib/screens/money/`:
  * `money_sections.dart` — shared `SectionHeader`, `HintCard`, `TintedCardBox`, `InsetDivider`.
  * `money_summary_cards.dart` — analytics cards (bill-spike alerts, renewal outlook, cash-flow teaser, spending pace, weekly-spend chart, category breakdown, top expenses, renewal breakdown).
  * `money_planning_cards.dart` — `BudgetsSection`, `RecurringSection`, `EnvelopesSection`, `TransactionsSection`.
  * `money_rows.dart` — `BudgetRow`, `EnvelopeCard`, `TransactionTile`, `RecurringCard`.
  * `money/forms/` — `TransactionFormSheet`, `RecurringFormSheet`, `EnvelopeFormSheet`, budget form sheets.
  * The screen file itself is down from 117 KB to ~32 KB (860 lines), and each section widget rebuilds independently.
* **Impact:** Ultra-smooth 60–120 FPS scrolling and instant tab switching.

---

## 5. ✅ Unified "Ask Finavig AI" Universal Voice Assistant *(implemented)*
* **Was:** Separate dialogs existed for Document Natural Language add (`NaturalLanguageAddDialog`) and Money Natural Language add (`NaturalLanguageMoneyAddDialog`) — two sheets, two parsers, duplicated save logic, and a double-add bug on money records.
* **Implemented:** Merged into one **Universal AI Voice Sheet** (`lib/widgets/dialogs/ask_finavig_sheet.dart`). Users speak or type naturally:
  * *"Log DEWA bill of 450 AED"* $\rightarrow$ auto-categorized into Utilities.
  * *"Add Emirates ID expiring 14 Oct 2027"* $\rightarrow$ auto-fills document fields with the 90·60·30·7-day expiry alert ladder.
* **Token-consumption optimization (Groq cost controls):**
  * **Local-first routing** (`lib/services/ai_intent_router_service.dart`): a deterministic keyword lexicon resolves the overwhelming majority of utterances offline — $0 tokens. Groq is escalated **only** for the ambiguous remainder.
  * **Cheapest escalation model:** classification runs on `openai/gpt-oss-20b` (~8× cheaper per token than the 120B workhorse used for prose features); the router needs a 3-way label pick, not reasoning.
  * **Compact prompt:** ~90-token system prompt (down from ~330) requesting one small JSON object.
  * **Tight completion cap:** `max_tokens: 60` — the reply is one JSON object, so runaway reasoning is cut off.
  * **Exact-input memo:** re-analyzing the same utterance (debounce re-fire, sheet re-open, chip re-tap) replays the previous verdict instead of paying for a second identical request. Transport failures are *not* memoized, so a transient network drop never pins a dead verdict.
  * **Per-session escalation budget:** max 4 Groq escalations per sheet session; past the budget the router degrades gracefully to the manual flow-choice card ("AI assist paused for this session").
  * **Trimmed payload:** user input is capped at the first 160 characters before it is sent — intent signals (keywords, amount, date) live up front.
  * **Hermetic test seam:** `escalationOverride` lets the test suite exercise the full escalation path (memo, budget, JSON parsing) with zero network and zero token spend.
* **Impact:** Hands-free management powered by Groq AI with near-zero token usage: the common case is free, the ambiguous case is cheap, and bursts are capped.

---

## Next Action Plan

Select an optimization to implement:
1. ~~**Shimmer Skeleton Loaders** for Home, Documents, and Money tabs.~~ ✅ Done — see feature #1 above.
2. ~~**Universal Quick Action Speed Dial (`+`)** button.~~ ✅ Done — see feature #2 above.
3. ~~**Full-Screen Pinch-to-Zoom Viewer & Quick Share** in Document Details.~~ ✅ Done — see feature #3 above.
4. ~~**Money Tab Performance Modularization**.~~ ✅ Done — see feature #4 above.
5. ~~**Unified "Ask Finavig AI" Universal Voice Assistant** (with Groq token-consumption optimization).~~ ✅ Done — see feature #5 above.

**All roadmap optimizations are implemented.** Next: pick a follow-up from `FEATURE_IDEAS.md` or add a new roadmap item.
