# Finavig — Launch Playbook

> How to start Finavig and get your first users. **October 2026.**
> Companion to [feasibility-study.md](feasibility-study.md) (§7 is the go/no-go gate), [market-study.md](market-study.md) (§2.1 is who you're selling to) and [PRE_DEPLOYMENT_CHECKLIST.md](../PRE_DEPLOYMENT_CHECKLIST.md) (product polish before release).

**TL;DR**

1. **Start it:** `flutter pub get` → run the Supabase SQL files in order → deploy `groq-proxy` → put your project URL + anon key in `lib/config/app_credentials.dart` → `flutter run`.
2. **Ship it:** version bump → signing → privacy policy + data-safety forms → real-device notification QA → store listing.
3. **Grow it:** 20–50 hand-held pilot users from UAE founder/PRO circles, recruited with the validation form, measured for 30 days on four numbers. No paid marketing until those hold.

---

## Part 1 — Start the app (local)

### 1.1 Prerequisites

| Need | Why |
|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.11.0`) | The app is Flutter; `pubspec.yaml` pins the SDK |
| Xcode (iOS) and/or Android Studio + SDK | Simulator/emulator or a real device |
| A [Supabase](https://supabase.com) project | Postgres + Auth + Edge Functions |
| Supabase CLI (optional but recommended) | Deploying the `groq-proxy` function and secrets |
| A Groq API key | Only for AI features; the app degrades gracefully without it |

### 1.2 Clone and install

```bash
git clone https://github.com/razique20/finavig.git
cd finavig
flutter pub get
```

### 1.3 Backend — run the SQL in this order

Supabase Dashboard → **SQL Editor**, one file at a time (all are idempotent, safe to re-run):

| # | File | What it adds |
|---|---|---|
| 1 | `supabase/schema.sql` | Collections, documents, reminders, custom types, RLS, `pg_cron` reminder scan |
| 2 | `supabase/finance_schema.sql` | Transactions, budgets, envelopes, recurring + the credit-link columns |
| 3 | `supabase/credit_schema.sql` | `credit_entries` + indexes |
| 4 | `supabase/user_tiers_schema.sql` | Subscription tier per user (read by `EntitlementService`) |
| 5 | `supabase/ai_quota_schema.sql` | Monthly AI counters |
| 6 | `supabase/ai_quota_proxy_schema.sql` | `consume_ai_quota()` — the server-side quota check the proxy calls |
| 7 | `supabase/support_requests_schema.sql` | In-app support / upgrade tickets |
| 8 | `supabase/user_dob_schema.sql` | Date of birth captured at signup |
| 9 | `supabase/app_version_schema.sql` | Splash update-check table **+ the v1.0.0 seed** |
| 10 | `supabase/migrate_documents_local_only_fields.sql` | `location`, `renewal_history`, `custom_reminder_days` |
| 11 | `supabase/gcc_migration.sql` | `collections.country_code` (GCC support) |
| 12 | `supabase/migrate_companies_to_collections.sql` | Only for a legacy single-company database |
| — | `supabase/delete_account_function.sql` | Required by "Delete account" in Profile |

> **Order matters for 5 → 6** (`consume_ai_quota` reads the tables created in 5) and for `support_requests` before you use the in-app support form.

### 1.4 Deploy the AI proxy (keeps the Groq key off the client)

```bash
supabase secrets set GROQ_API_KEY=gsk_your_real_key
supabase functions deploy groq-proxy
```

Without this, shared-key AI calls return an error — user-supplied Gemini keys still work. Rotate the key with `supabase/functions/groq-proxy/rotate-key.sh`. Full runbook: [`../supabase/functions/groq-proxy/README.md`](../supabase/functions/groq-proxy/README.md).

### 1.5 Point the app at your project

Edit `lib/config/app_credentials.dart`:

```dart
static const String supabaseUrl = 'https://YOUR-PROJECT-ref.supabase.co';
static const String supabaseAnonKey = 'YOUR_PUBLISHABLE_ANON_KEY';
```

**Security note.** These values are compiled into the binary, so **only the anon/publishable key may live here** — never a `service_role` key. That safety depends entirely on **RLS being enabled on every table** (the SQL files above do this); the anon key is designed to be public. The Groq key deliberately lives server-side in the Edge Function.

### 1.6 Run it

```bash
flutter run                 # pick your device when prompted
flutter devices             # list what's available
```

Notes:
- **iOS** needs a signing team in Xcode for a *device* run; a simulator works out of the box.
- **Web** (`flutter run -d chrome`) is a docs/demo surface — OCR and local notifications degrade there by design. Don't demo the alert promise on web.
- Local-only mode works without a backend (that's how the test suite runs), so you can explore the UI before Supabase is ready.

### 1.7 Your first 10 minutes in the app (the demo script)

Use this exact path when a new user — or you — opens the app for the first time:

1. **Welcome → Continue to Login** (blue copy, six-flag country pill) → pick *New to Finavig* → email, password, DOB, country, phone.
2. **Home** → tap **Try a demo document** in the empty state. You now have "Demo: Sample Trade Licence" with a fee and an amber urgency band — the whole value proposition in one screen.
3. **Documents** → open it → see the urgency timeline (90 · 60 · 30 · 7), renewal checklist and the spend nudge.
4. **Money** → **＋** → type *"Paid 450 AED for DEWA yesterday"* and confirm the parsed transaction.
5. **Money → Credit** → add a small borrowed/lent entry and note the **Credit** chip keeping it out of your totals.
6. **Profile → Security & App Lock** → set a 6-digit passcode (biometric unlock offered).
7. **Profile → Appearance** → flip themes (the whole app cross-fades) and check the dark mode.

That path is also the pitch demo. If a step confuses a real user, fix the step — not the script.

### 1.8 Verify before you call a build good

```bash
flutter analyze                              # CI fails on errors
dart run tool/perf_budget_check.dart         # file-size ratchet
flutter test                                 # 54 suites / 525 tests, must be green
bash tool/capture_docs_shots.sh              # refresh docs/screenshots after UI changes
```

CI (`.github/workflows/ci.yml`) runs the first three on every push and PR — green locally and green in CI should mean the same thing.

---

## Part 2 — Ship it

### 2.1 Version

Bump `version:` in `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`, etc.). Then update the `app_versions` seed so the splash gate knows about it:

```sql
update public.app_versions set latest_version = '1.0.1', min_required_version = '1.0.0' where platform = 'android';
```

Set `min_required_version` to the current version only when you need to **force** the update (a data-loss or security fix).

### 2.2 Signing & distribution

- **Android:** create the release keystore, wire `android/key.properties`, and `flutter build appbundle --release`. Play Console → internal testing track first, then closed, then production.
- **iOS:** Xcode → signing team → `flutter build ipa` → Transporter/TestFlight. TestFlight internal testers are the cheapest pilot distribution that exists — use them for the first 20 users on iOS.
- **Icons/splash:** `bash tool/generate_app_icons.sh` (icons), `python3 tool/generate_splash_bg.py` (splash). Store art already lives in `assets/store/`.

### 2.3 Store listing (one day of work, don't leave it to launch day)

- [ ] Privacy policy **live** (already wired as `AppLinks.privacy`) — and update it to cover **GCC data residency** and **AI processing** (prompts leave the device when AI assists).
- [ ] Data-safety / app-privacy forms — declare document metadata, files (stored on device) and account data.
- [ ] Title/subtitle with the wedge keywords (§3.6), 6–8 screenshots from `docs/screenshots/` (they're 1080×2400 and current), short + long description.
- [ ] Support email + in-app support form destination.
- [ ] Content rating questionnaire.

### 2.4 Prove the update path (an hour, before you need it)

Run `supabase/app_version_schema.sql` on the production project, then verify the dialog appears on an older build and that a **force** update halts navigation. Your first hotfix will depend on this working.

### 2.5 Crash reporting & analytics

`ErrorCaptureService` already hooks `FlutterError.onError` + `PlatformDispatcher.onError` and persists the last 20 errors — forward from `record()` to Sentry (half a day). Add only the funnel events you will actually read at pilot: onboarding completed, document added, first alert fired, alert → renewal marked done.

### 2.6 Real-device notification QA — the one non-negotiable

A missed renewal alert is the product's core promise broken. Before the pilot, test on **Samsung + Xiaomi + iOS at minimum** (Huawei if you can), with the screen off, after a reboot, and after a battery-saver has had a chance to kill the app. Then:

- [ ] Onboarding pre-permission explainer shows **before** the OS prompt.
- [ ] Alert taps deep-link to the document, including from a cold start.
- [ ] The Profile → "Ensure reminders work" guidance tile opens OEM instructions.
- [ ] Record what you saw per device; put the list in the release notes.

### 2.7 Post-release runbook

| Situation | Action |
|---|---|
| Crash affecting many users | Raise `min_required_version` in `app_versions` → forced update dialog; ship the fix behind it |
| Sync/billing bug | The app is offline-first, so users keep working; fix, release, and tell pilot users in your feedback channel |
| Cold-start jank | `PerfTracingService` + DevTools sections record it; compare against your baseline |

---

## Part 3 — Get your first users (0 → 100)

### 3.1 The pilot has exactly one goal

**Not** installs. The goal is to answer: *does a UAE solo founder, handed this app, keep the documents in it, act on the alert, and still be using it on day 30?*

Everything below serves one number — **D7 retention toward 30-day retention** — with three supporting numbers from the feasibility study:

| Metric | Target (30-day pilot) | How you measure it |
|---|---|---|
| D7 retention | **> 25%** | Analytics event on app open (or a weekly check-in message for the first pilot) |
| Users with ≥1 tracked document who received an alert | **≥ 40%** | Alert-fired + document-added events |
| Alert → renewal completed inside the window | **≥ 25%** | "Mark renewed" action after an alert |
| Uninstall within 48h of an alert | **< 2%** | Store-console stats + check-in messages |

### 3.2 Who to recruit (and where they are)

Recruit 20–50 **design partners**, hand-held, in this priority order:

| Priority | Who | Where they hang out | Why they say yes |
|---|---|---|---|
| 1 | **Solo founders / free-zone licence holders** | Free-zone community Slack/WhatsApp groups, incubators (in5, Dubai SME, Hub71 for KSA later), coworking spaces (AstroLabs, Nook, Letswork) | They pay real fines and can try an app the same day |
| 2 | **PRO agents / corporate services firms** | LinkedIn, free-zone partner lists, Google Maps for the small ones | Multi-client pain; a built-in Business-tier lead |
| 3 | **Expat households** | Your own network, building WhatsApp groups, school-parent groups, r/dubai | Visa/ID/insurance cycles are universal |
| 4 | **Adjacent service providers** | Accountants, insurance brokers, car-rental/fleet SMEs | They hear "I forgot to renew" all day |

Trade for participation: **founding-user pricing**, a direct line to the founder, and their requested feature shipped. Never pay for the pilot users — you want people who feel the pain, not people who like free stuff.

### 3.3 The recruitment funnel (ship it Monday)

There is already a ready-made instrument: **`tool/finavig_validation_form.gs`** generates a 14-question Google Form (pain validation, concept test, feature priorities, willingness to pay, discovery).

1. Open <https://script.google.com> → New project → paste the file → run `createFinavigValidationForm` → copy the published form URL.
2. Post it where §3.2 says people are, with one line of copy: *"2-minute survey for UAE founders: how do you currently keep track of licence/visa/insurance renewals? Building something, want your take (and founding-user perks)."*
3. For everyone who finishes the form **and** leaves an email → send the TestFlight/Play-internal invite **the same day**, in one personal message. Speed here is the whole funnel.
4. For everyone who says "I'd pay" → book a 20-minute call (the concierge session below). That call is your demand signal, your feature roadmap and your testimonial, all at once.

Batching beats broadcasting: aim for **10 personal conversations per week**, not 200 impressions.

### 3.4 The 20-minute design-partner session (concierge onboarding)

Do it on a call, screen shared, with **their real documents** — never a fictional demo:

| Minutes | Do | Watch for |
|---|---|---|
| 0–3 | Ask how they track renewals today. Write down the exact tools and the last time they got burned | The words they use ("Ejari", "Mulkiya", "Iqama") — those become your copy |
| 3–6 | Get their real licence + visa + insurance into the app *while they watch* | Every hesitation is an onboarding bug |
| 6–10 | Walk the urgency ladder and their next 90 days of renewal outflows | The "oh, that's the number" moment is the aha — record it |
| 10–13 | Show Ask Finavig with their own sentence, and the credit book | Does capture feel faster than a form? |
| 13–17 | Set the alerts up, explain the OEM battery step, add a second collection if it's a business | Do they trust it enough to install on their main phone? |
| 17–20 | Ask the three questions: what's missing, what would make you pay, who else has this problem | **The referral is the deliverable** |

Log every output in a one-line CRM (a spreadsheet is fine): name · channel · documents added · felt pain · will pay (Y/N/?) · referral given · follow-up date.

### 3.5 Channels, in the order they'll actually work

1. **Founder's own network + hand-held outreach** — highest signal, lowest volume. Do this first; it fills the pilot.
2. **Community posts** (r/dubai, r/UAE, UAE founder/expats Facebook groups, free-zone WhatsApp groups) — post the *problem*, not the app. e.g. *"I built a free tool that tells you what renewals are coming and how much they'll cost — currently track 15 document types. Want 20 people to break it."* Answer every comment.
3. **PRO / corporate-services relationships** — one friendly PRO who onboards 5 clients is worth 5 Pro users *and* your Business-tier design partner. Offer to white-label their client workflow later.
4. **LinkedIn** — slow but credible for the SME angle; post the "renewal cash-flow" number ("your next 90 days of renewals"), not downloads.
5. **ASO** (see §3.6) — accumulates for free while you do the above.
6. **Communities around the moment** — new-licence events (free-zone onboarding sessions), new-in-Dubai groups, insurance brokers' client lists.
7. **Content** — one genuinely useful piece ("UAE renewal deadlines calendar 2026", "what happens if your trade licence expires") earns links and search traffic for years.

### 3.6 ASO starter keywords

Primary (high intent, ownable): **document expiry reminder UAE**, **trade licence renewal reminder**, **visa expiry tracker**, **Emirates ID reminder**, **renewal tracker Dubai**, **Ejari reminder**. Secondary (GCC expansion): **Iqama expiry reminder**, **CR renewal Saudi**, **QID / Civil ID reminder**. Put the wedge in the store subtitle, not just the description: *"Never pay a late renewal fine again."*

### 3.7 Referral mechanic (simple, no code needed at pilot)

Give each founding user a reason to bring one peer: *say the word and I'll set up their workspace for them.* Track referrals in the same spreadsheet. A 20-user pilot with 30% referral rate doubles to 26 without a single ad dirham.

### 3.8 What NOT to do before product–market fit

- ❌ **Paid ads.** You'd be buying installs for an app whose retention you haven't measured yet.
- ❌ **Chasing installs in other GCC countries** before UAE retention holds — the product is ready, the support economics aren't.
- ❌ **Building the payments/concierge features** (see feasibility §5) — that changes your regulatory envelope.
- ❌ **Bulk-importing contacts or cold WhatsApp blasts** — Meta bans, reputations burn, and you'll get survey responses from people who don't have the problem.
- ❌ **Arabic localization, team collaboration, push notifications** — all deliberately out of pilot scope.

---

## Part 4 — The 30-day pilot cadence

Assume ~1 hour a day. Consistency beats intensity.

| Day | Focus | Deliverable by end of day |
|---|---|---|
| 1 | Generate the validation form; prepare TestFlight/Play internal build | Form link + installable build in 3 hands |
| 2–5 | 10 personal outreach conversations; 20-minute session with each interested pair | 8–10 users with **real documents** loaded |
| 6–7 | Watch them use it; fix the top 3 onboarding frictions | Small UX fixes shipped, or logged for the next build |
| 8–14 | Second wave (PRO agents + referrals); one community post | 20–30 users; first real alerts firing |
| 15 | Mid-pilot review against the §3.1 numbers | Written note: which metric is off and why |
| 16–21 | Interview every user who dropped; double down on the channel with the best retention | Retention plan for the second half |
| 22–28 | One content piece + ASO pass; ask every happy user for a store review | Reviews + improved title/subtitle |
| 29–30 | Review, decide, write it down | Go / iterate / stop — with the numbers attached |

**Weekly dashboard** (fill the same table every week; the trend matters more than the absolute):

| Week | New users | Users with ≥1 doc | Alerts fired | Renewals marked done | Active on day 7 | Uninstalls ≤48h after alert | Notes / quotes |
|---|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |

**Day-30 decision rules**

- **Hit the numbers →** keep onboarding by hand, then (only then) consider a small paid test in one channel, and start the Storage/attachment work that removes the top cancellation reason.
- **Retention low, alerts firing →** the problem is the value moment, not the audience: fix onboarding/how the aha is delivered, re-run for 2 weeks.
- **Alerts not firing →** stop everything and fix notification reliability; you are not testing the product yet.
- **Users love it but never add a second document →** the wedge is wrong for that segment; switch to PRO agents (the multi-collection model is the natural fit).

---

## Part 5 — First 90 days

| Window | Objective | Exit criteria |
|---|---|---|
| Week 1–2 | Get the app into 20–50 real hands (Part 1–3) | Build shipped, 20+ users with real documents |
| Week 3–6 | Run the pilot (Part 4), fix frictions weekly | 4 weeks of dashboard data; first testimonial |
| Week 7–10 | Hold the numbers; fill pre-launch gaps (Sentry, Storage or documented limitation, notification QA on more OEMs) | Store submission-ready; retention flat or rising |
| Week 11–13 | Public listing (Play/App Store), ASO, PRO partnerships, decide on the first paid tier | Store live, first organic installs, go/no-go on monetization |

---

## Appendix — Command reference

```bash
# run
flutter pub get
flutter run
flutter devices

# quality gates (same as CI)
flutter analyze
dart run tool/perf_budget_check.dart
flutter test

# docs & marketing assets
bash tool/capture_docs_shots.sh        # refresh docs/screenshots (integration tour)
bash tool/capture_pitch_shots.sh       # pitch-deck shots
bash tool/generate_app_icons.sh
python3 tool/generate_splash_bg.py

# backend
supabase secrets set GROQ_API_KEY=gsk_…
supabase functions deploy groq-proxy
```

**Remaining limitation of this document:** the launch plan is a plan, not a result. The numbers in §3.1 are targets from the feasibility study; replace them with your real dashboard data as soon as the pilot's first week is in — and update this file when a target turns out to be wrong.
