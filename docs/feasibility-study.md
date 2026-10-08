# Finavig — Feasibility Study

> Technical, operational, financial and legal feasibility of shipping Finavig as a product.
> **Refreshed October 2026** (first draft September 2026).
> Companion to [technical-documentation.md](technical-documentation.md), [market-study.md](market-study.md) and [launch-playbook.md](launch-playbook.md).

---

## 0. What changed since the September draft

| Area | September draft | October 2026 |
|---|---|---|
| Test coverage | 49 suites / 484 tests | **54 suites / 525 tests**, all green locally and in CI |
| Scope | UAE-only document set | **GCC-wide**: 6 countries, per-country authority catalogue and per-collection currency (AED, SAR, KWD, QAR, BHD, OMR) |
| Onboarding | Welcome + quiz login | Welcome/login **redesigned** (blue copy, six-flag country pill), quiz login routing sign-in (3 steps) / sign-up (6 steps) |
| Retention plumbing | Not started | Notification **deep links**, **offline banner**, **demo document**, in-app **rate prompt**, **PDPL data export**, OEM battery guidance — all shipped |
| Crash visibility | none | `ErrorCaptureService` (last 20 errors persisted, **Sentry-ready**, not yet forwarded) |
| Release gating | Manual | CI runs analyze + file-size ratchet + full suite on every push/PR; `app_versions` update/force-update gate implemented |
| Verdict | GO for pilot | **Unchanged: GO for pilot** — remaining work is release engineering, not invention |

---

## 1. Executive summary

| Dimension | Verdict | Key finding |
|---|---|---|
| **Technical** | ✅ Feasible | Core product (offline-first tracker + local notifications + finance module + credit book + AI capture) is built and tested; backend is standard Supabase. Remaining work is release engineering, not invention |
| **Operational** | ✅ Feasible | Single-maintainer friendly: free-tier infra, no servers to run, small support surface |
| **Financial** | ✅ Feasible | Runs inside free tiers to thousands of users; biggest cost is time, not cash |
| **Legal / regulatory** | ⚠️ Feasible with care | As a *tracker* it is low-regulation. The moment it touches payments or files anything with government, the compliance envelope changes materially. GCC-wide scope now means multiple national data-protection regimes, not one |
| **Overall** | **GO** for a pilot launch after the release-blocking checklist (§7) | Validation-first: 20–50 real users before any paid marketing |

---

## 2. Technical feasibility

### 2.1 What already works (evidence)

- **Full feature set implemented and tested:** document CRUD with OCR pre-fill, the shared 90·60·30·7 urgency ladder, custom alert offsets, finance ledger with budgets / envelopes / recurring templates, the **credit book** (borrowed/lent obligations with deadlines, extensions, WhatsApp follow-up and an optional, properly-tagged link into the ledger), 90-day cash-flow simulation, bill-spike detection, CSV/PDF exports, PDPL data export, App Lock (passcode + biometric), the redesigned welcome/quiz-login onboarding flow, and the unified **Ask Finavig AI** voice/text quick-add (local-first routing with Groq escalation server-held behind the `groq-proxy` Edge Function, which enforces per-tier quotas server-side).
- **Coverage is machine-checked:** **54 test suites / 525 tests** cover the pure-logic core (sync contract, finance math, credit ↔ Money sync, recurrence, anomaly thresholds, AI intent routing incl. persistence, notification policy) plus UI redesign contract tests, the App Lock flow, and goldens for the three skeleton views. CI (`.github/workflows/ci.yml`) runs `flutter analyze`, `dart run tool/perf_budget_check.dart` and the full suite on every push and PR.
- **GCC-wide, not UAE-only:** `GccCountry` models all six member states with per-country document titles (Emirates ID / Iqama / Civil ID / QID / CPR / Resident ID), tenancy and labour bodies (Ejari / Ejar, MOHRE / QIWA-GOSI / PAM / LMRA …) and currency; collections carry a `country_code` so one account can hold a UAE personal workspace and a Saudi company workspace side by side.
- **Offline-first architecture proven:** local-only mode is a first-class citizen (it is how unit tests run). Backend outages degrade to "sync later", never to data loss. An `OfflineBanner` now makes that visible instead of looking broken.
- **Performance wave shipped and guarded:** all four tab screens modularized into section modules, lazy `SliverList.builder` scrolling everywhere, cached/downsampled attachment pipeline, and the CI file-size ratchet keeps the wins from regressing — see `OPTIMIZATION_PLAN.md`.
- **Backend is boring-on-purpose:** Supabase Postgres + RLS, with client-side row sanitization against a column whitelist so schema drift cannot silently kill sync (technical documentation §4.2).
- **Retention plumbing is in place**, which matters more at pilot than any new feature: notification tap → document deep link (cold start included), pre-permission explainer before the OS prompt, demo document for 30-second time-to-first-value, soft rate prompt gated to happy moments, and OEM battery-saver guidance.

### 2.2 Remaining technical risk

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Attachment files are device-local; uninstall = loss | Certain today | Medium — metadata survives, bytes don't | Supabase Storage bucket (schema-ready; ~1–2 days). Until then the in-app backup/export nudge documents the limitation |
| Local-notification reliability across OEM battery savers (esp. Android) | Medium | **High** — a missed alert is the core promise broken | Guidance tile shipped; real-device QA on Samsung/Xiaomi/Huawei still required; the server-side `reminders` table + FCM path (§6) is the durable fix |
| No remote crash visibility | Medium | Medium | `ErrorCaptureService` already funnels every error through one hook and persists the last 20 — forwarding to Sentry is a half-day, not new plumbing |
| ML Kit OCR accuracy on real-world scans | Medium | Low–medium | The flow treats OCR as *pre-fill for human review*, never auto-save; worst case is manual entry |
| Groq API availability / pricing changes | Low | Low — graceful by design | Local lexicon resolves the majority of utterances; router degrades to manual choice; key lives server-side with per-tier quotas and a persisted daily escalation budget on top |
| GCC-wide label catalogue drifts from reality | Low–medium | Low | `GccAuthorityCatalog` is data, not logic — correctable per country without a schema change |
| Multiple currencies in one forecast | Low | Medium | Each collection carries its own currency; cross-currency aggregation is deliberately out of scope for the pilot and should stay visible in the UI |
| Single-postgres-vendor lock-in | Low | Low | Schema is plain SQL; portable |
| Flutter web as a demo surface | Known | Low | Web is docs/demo only; ML Kit and notifications degrade there by design |

### 2.3 Engineering effort to public launch

| Workstream | Estimate | Status |
|---|---|---|
| CI (analyze + file-size ratchet + full suite) | — | ✅ done |
| In-app retention set (deep link, pre-permission, demo doc, rate prompt, offline banner, backup nudge, PDPL export) | — | ✅ done |
| Update/force-update gate (`app_versions`) | 1 hr | ⏳ schema + seed exist — **run the smoke test** on the production project |
| Android release signing + iOS distribution setup | 0.5–1 day | ⏳ |
| Crash reporting (Sentry) + basic analytics | 0.5 day | ⏳ local capture ready; forwarding pending |
| Supabase Storage for attachments + upload UI | 1–2 days | ⏳ optional for pilot if the limitation is messaged |
| Store listing assets, privacy policy, data-safety forms | 1 day | ⏳ icons/store art exist in `assets/store/`; privacy URL already wired in `AppLinks` |
| Real-device notification QA (3–5 Android OEMs + iOS) | 1–2 days | ⏳ **highest-value remaining item** |
| **Total** | **~4–6 focused days** | |

`tool/perf_budget_check.dart` and the golden tests mean a solo maintainer gets regression protection for free — the effort above is mostly external (stores, devices, policies), not code.

## 3. Operational feasibility

- **Team:** the codebase was built and is maintained by one developer. Services are singletons with pure-logic cores — features are testable without a backend, so the single maintainer is not the bottleneck on correctness.
- **Support surface:** no servers to operate (Supabase free/Pro is managed). Expect issues concentrated in (a) notifications not firing on aggressive OEMs and (b) OCR misses — both have in-app mitigations already (battery guidance, manual re-scan, manual entry).
- **Release cadence:** the `app_versions` splash check supports forced update gating, so a broken build can be pushed out of circulation without waiting on store review of the fix itself.
- **Pilot operating load:** realistic to run as a side project — the cadence in [launch-playbook.md](launch-playbook.md) §4 assumes ~1 hour/day, not full-time.

## 4. Financial feasibility

### 4.1 Cost structure (bootstrapped pilot → early scale)

| Item | Pilot (0–1k users) | Growth (10–50k users) |
|---|---|---|
| Supabase | **Free** (500 MB DB / 1 GB storage / 50k MAU) | **$25/mo** Pro, likely sufficient for years at this usage profile |
| Local notifications (the alert engine) | **$0** — on-device | $0 + push infra only if the FCM path is added (Firebase free tier) |
| AI calls (Groq via `groq-proxy`) | Cents/month at pilot volume; per-tier quotas cap the tail | Low hundreds of $/mo if heavy users max their quotas |
| Crash reporting | **Free** (Sentry/Crashlytics dev tiers) | ~$26/mo |
| App-store fees | $100/yr Apple + $25 one-off Google | same |
| **Total cash burn** | **≈ $125 first year** | **≈ $600–1,200/yr** |

The economics are dominated by the fact that the core alert engine is on-device and the database stores small rows — even 50k documents is well under 100 MB. AI is the only usage-shaped cost, and it is metered server-side per tier by design.

### 4.2 Revenue plausibility

Aligned with `MONETIZATION.md` (prices there are the source of truth):

- Free tier drives volume; **Plus AED 25/mo** and **Business AED 99/mo** are the paid tiers.
- 10k registered users × 3% paid × ~AED 300/yr blended ≈ **AED 90k/yr** — covers costs several times over and proves willingness to pay.
- The PRO/business tier is the economically interesting one: a few dozen Business accounts would exceed the entire consumer tier, with no payments or filing to license.

**Break-even is trivially reachable; the question is not money, it is retention.**

## 5. Legal & regulatory feasibility

> Not legal advice — a checklist of the envelopes that matter.

| Topic | Assessment |
|---|---|
| **App category** | A personal productivity/tracker app is **low-regulation**. No licence is required merely to remind users of dates or to keep a private expense ledger |
| **GCC-wide scope** | The app now supports six jurisdictions, so the privacy posture must satisfy more than one regime: UAE PDPL, Saudi PDPL, Qatar Law 13/2016, Bahrain PDPL, Kuwait CITRA rules and Oman's PDPA (RD 6/2022). The local-first architecture is the same defence in all of them; the **privacy policy should state which regions store data and where** (Supabase region = data residency question worth answering in the policy) |
| **Handling payments / filing renewals on users' behalf** | This **would** change the picture (payment-service and agency/BPO considerations, plus CBUAE licensing if funds are held). The roadmap explicitly parks "renewal concierge" until post-PMF, and the savings-envelope feature is tracking-only by design |
| **Data protection** | Purpose limitation, secure storage, deletion on request are all implemented (RLS-scoped server rows, local-first storage, delete account, "Download my data" export). Store listings still require a privacy policy URL and data-safety declarations |
| **Document attachments** | Storing scans of IDs/licences is the sensitive case. The current device-local design is the *most* defensible posture. If/when Storage sync ships: private bucket, per-owner path policy, consider client-side encryption at rest |
| **AI processing** | The Groq key lives server-side in the Edge Function; user prompts leave the device when AI assists. Say so plainly in the privacy policy — it is a disclosure item, not a blocker |
| **WhatsApp alerts** | Only via the official Meta Cloud API from a server; UI already labels it "coming soon" |

## 6. Go-to-market feasibility (summary — the playbook is [launch-playbook.md](launch-playbook.md))

- **Channel 1 — communities:** UAE/GCC expat and founder groups (Reddit r/dubai, Facebook business groups, free-zone newsletters). The screenshots are self-explanatory; the fine-avoidance angle writes its own copy.
- **Channel 2 — PRO/service agents:** they feel the multi-client pain daily; the multi-collection model maps 1:1 to "one workspace per client". A handful of friendly PROs are ideal design partners and the Business-tier path.
- **Channel 3 — ASO:** "document expiry reminder UAE", "trade licence renewal", "visa expiry tracker", "Iqama expiry" — searched, specific, and contested only by government apps that each do one silo.
- **Validation metrics (pilot, 30 days):** D7 retention >25%, ≥40% of users with ≥1 tracked document firing an alert, ≥25% alert→renewal completion within window, <2% uninstall-within-48h-after-alert (the fatigue tell).

## 7. Go / no-go checklist

**Must be green before pilot launch:**

- [ ] Android release signing; iOS distribution profile
- [x] CI running analyze + file-size budget + the full 525-test suite on every push/PR
- [x] In-app retention set shipped (deep link, pre-permission, demo doc, rate prompt, offline banner, backup nudge, PDPL export)
- [x] Supabase fields migration applied and smoke-tested (`migrate_documents_local_only_fields.sql`, `gcc_migration.sql`)
- [ ] `app_versions` smoke test run on the production project (verify the dialog appears and that a *force* update halts navigation)
- [ ] `groq-proxy` Edge Function deployed to production with `GROQ_API_KEY` set (shared-key AI calls fail without it)
- [ ] Notification QA passed on Samsung + Xiaomi + iOS (the OEM battery-saver pass)
- [ ] Sentry wired (local `ErrorCaptureService` already funnels every error; just forward from `record()`)
- [ ] Frame-time pass on a mid-tier device using `PerfTracingService`; record a baseline jank ratio
- [ ] Attachment limitation either fixed (Storage bucket) or explicitly messaged in-app
- [ ] Privacy policy live and **covers GCC data residency + AI processing**; store data-safety forms completed
- [ ] 20–50 pilot users recruited with a feedback channel open

**Deliberately out of scope for the pilot:** push notifications (FCM/APNs), WhatsApp/email alert server wiring, payments, renewal concierge, team collaboration, Arabic localization, cross-currency aggregation.

## 8. Conclusion

Finavig is feasible on every axis that matters at this stage: the hard software is written, covered by 525 tests and CI-guarded; the operating costs are negligible; the regulatory envelope for a tracker stays light as long as the product stays a tracker; and the GCC scope widens a market study that already identified reachable early adopters whose pain is quantifiable in avoided fines. The two highest-leverage investments before scale are (1) real-device notification QA — because on-device alerts are the one component the developer cannot fully control — and (2) the server-side push path, for which the `reminders` table is already the ready data source. Proceed to the §7 pilot, using [launch-playbook.md](launch-playbook.md) as the operating manual.
