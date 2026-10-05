# ARCHITECTURE.md — Finavig workflows & diagrams

How Finavig is built: one Flutter client, local-first storage with a sync
outbox, Supabase for auth/cloud sync/tiers, and LLM providers for the AI
features. Everything below is grounded in the actual code — file names
referenced in each section.

> View on GitHub (Mermaid renders natively) or in VS Code with a Mermaid
> preview extension.

---

## 1. System overview

```mermaid
flowchart TB
    subgraph Device["📱 Flutter app (iOS / Android)"]
        UI["Screens & widgets<br/>lib/screens, lib/widgets"]
        BIZ["Domain services<br/>lib/services"]
        STORE[("Local store<br/>prefs + files<br/>(local-first)")]
        OUTBOX["Sync outbox<br/>doc_sync.dart"]
    end

    subgraph Cloud["☁️ Supabase"]
        AUTH["Auth<br/>(email + password)"]
        DB[("Postgres / RLS<br/>documents, finance,<br/>collections, tiers")]
    end

    subgraph AI["🤖 AI providers"]
        GROQ["Groq API<br/>(in-app default key<br/>or user key)"]
        GEM["Gemini API<br/>(optional user key)"]
    end

    OS["🔔 OS notifications<br/>flutter_local_notifications"]

    UI <--> BIZ
    BIZ <--> STORE
    STORE -- "queued changes" --> OUTBOX
    OUTBOX <-- "sync when online" --> DB
    BIZ -- "restore session" --> AUTH
    BIZ -- "summaries / plans /<br/>intent routing" --> GROQ
    BIZ --> GEM
    BIZ -- "schedule 90/60/30/14/7/1" --> OS
```

Key rule: **the app is fully usable offline and signed-out** (local-only
mode). Supabase is optional at runtime — `SupabaseService.hasCredentials`
gates every cloud call, and services fall back to local defaults.

---

## 2. Cold-start workflow (`lib/main.dart`)

```mermaid
flowchart TD
    A[main() starts] --> B["ErrorCaptureService.install()<br/>(capture startup crashes)"]
    B --> C["PerfTracingService frame monitor<br/>+ markFlow(coldStartToHome)"]
    C --> D["ThemeService.init()<br/>(theme before first frame)"]
    D --> E["SupabaseService.initialize()<br/>(no-op when unconfigured)"]
    E --> F["AlertPreferencesService.load()<br/>(before alert engine)"]
    F --> G["BudgetAlertService.init()<br/>(listens for finance changes)"]
    G --> H["StorageMigrationService.migrate()<br/>(one-time legacy folder move)"]
    H --> P["Prewarm services"]
    subgraph P["Prewarm (parallel)"]
        P1["UrgencyEngine.init()"]
        P2["NotificationService.init()<br/>(no permission prompt here)"]
    end
    P --> Q{"Signed in?<br/>AuthService.isSignedIn"}
    Q -- "yes" --> R["CustomDocumentTypeService.init()"]
    R --> S["Collections + Scanner +<br/>Finance + Entitlements init<br/>(parallel)"]
    S --> T["BudgetAlertService.evaluateNow()"]
    T --> U["NotificationService.resyncAll()<br/>(rebuild reminder ladder)"]
    Q -- "no" --> V["skip cloud services"]
    U --> W["runApp(FinavigApp)"]
    V --> W
```

Notes:
- Session restore happens inside `SupabaseService.initialize()`
  (supabase_flutter reads secure storage), so `isSignedIn` is already
  correct here.
- Notification **permission** is never requested at startup — it is
  requested from the onboarding "Allow notifications" page
  (`NotificationService.requestPermission()`).

---

## 3. Navigation map (`lib/router.dart`)

```mermaid
flowchart TD
    ROOT["/ splash"] -->|"onboarded=true"| HOME
    ROOT -->|"first launch"| WELCOME["/welcome"]
    WELCOME --> LOGIN["/login"]
    LOGIN -->|"quiz flow:<br/>email → password → DOB →<br/>country → phone"| ONB["/onboarding"]
    ONB -->|"5 pages,<br/>notification ask on p3"| HOME

    subgraph SHELL["Bottom-nav shell (StatefulShellRoute)"]
        direction LR
        HOME["/home<br/>dashboard"]
        MONEY["/money<br/>budgets · envelopes · records"]
        DOCS["/documents<br/>expiry vault"]
        PROFILE["/profile<br/>plan · collections · settings"]
    end

    HOME -.-> FS
    MONEY -.-> FS
    DOCS -.-> FS

    subgraph FS["Full-screen routes"]
        SCAN["/scan (+ /document/:id/edit)"]
        DETAIL["/document/:id"]
        SEARCH["/search"]
        EXPIRY["/expiry-list"]
        CASH["/cash-flow-forecast"]
        BUD["/budgets"]
        ENV["/envelopes"]
        REC["/records"]
        AIS["/ai-summary"]
        AIB["/ai-budget-plan"]
        ALERTS["/alerts-reminders"]
    end

    AUTHGATE{"Auth gate (redirect)"}
    AUTHGATE -->|"no session"| LOGIN
    AUTHGATE -->|"session"| SHELL
```

Shell chrome: floating pill nav with a gradient **+** quick-action orb
(scan / log money / voice / envelope; long-press = Ask Finavig AI). Live
badges: Documents dot when any doc ≤30 days, Money dot amber at ≥80%
budget, red at ≥100% (`_AppShell`).

---

## 4. Document lifecycle (scan → alert → renew)

```mermaid
flowchart TD
    A["Scan / pick / manual add<br/>DocumentScanScreen"] --> B["OCR extraction<br/>uae_document_ocr_service<br/>(dates, fees, vendor, type)"]
    B --> C{"Fields confident?"}
    C -- "yes" --> D["Prefilled draft ExpiryItem"]
    C -- "no" --> E["Manual form"]
    E --> D
    D --> F["Save locally<br/>DocumentScannerService"]
    F --> G["Map to GCC authority +<br/>companion suggestions<br/>(gcc_authority_catalog,<br/>companion_suggestion_service)"]
    G --> H["Queue in sync outbox<br/>doc_sync.dart"]
    H --> I["Notify listeners → UI<br/>(home, documents, badges)"]
    I --> J["UrgencyEngine ranks by<br/>days remaining"]
    J --> K["NotificationService.resyncAll<br/>schedules 90/60/30/14/7/1 ladder"]
    K --> L["Alerts center + deep link<br/>notification_tap_service<br/>→ /document/:id"]
    L --> M["User renews → updates<br/>expiry date → RenewalRecord<br/>audit history"]
```

Renewal ladder lead times are user-configurable (Plus gate: custom alert
days).

---

## 5. Money logging & budget workflow

```mermaid
flowchart TD
    A["Input: typed sentence,<br/>voice, or form"] --> B["NaturalLanguageParserService<br/>'Spent 85 AED on Uber'"]
    B --> C["SmartCategoryEngine<br/>(learns user corrections)"]
    C --> D["FinanceService.addTransaction"]
    D --> E["Recurring engine:<br/>auto-log when due"]
    E --> F["AnomalyDetectionService<br/>(35%+ jump in recurring)"]
    F --> G["BudgetAlertService evaluates<br/>per-category thresholds"]
    G -->|"≥80%"| H["amber warning +<br/>Money tab dot"]
    G -->|"≥100%"| I["red exceeded alert<br/>+ OS notification"]
    D --> J["90-day cash forecast<br/>FinanceMath.calculate90DayCashFlow<br/>(balance + recurring + renewal fees)"]
    J --> K["MonthlySummaryService →<br/>AI executive summary (Plus)"]
```

---

## 6. Sync & connectivity

```mermaid
sequenceDiagram
    participant App as App (local-first)
    participant Outbox as doc_sync outbox
    participant Sup as Supabase

    App->>App: Every write lands locally first
    App->>Outbox: enqueue change (doc/type/collection)
    loop When connectivity restored (ConnectivityService)
        Outbox->>Sup: push queued changes (authed, RLS-scoped)
        Sup-->>Outbox: ack
        Outbox->>App: pull remote changes, merge
        App->>App: single notifyListeners burst
    end
    Note over App,Sup: OfflineBanner explains queued sync.<br/>Sign-out clears local queues/prefs.
```

---

## 7. Auth & entitlements

```mermaid
flowchart TD
    A["Login screen quiz"] -->|"signUp(email, password,<br/>DOB) + save prefs<br/>userCountry / userDob / userPhone"| B["Supabase Auth"]
    B --> C{"Email confirmation<br/>required?"}
    C -- "yes" --> D["'Check your email' → sign in"]
    C -- "no" --> E["Session active"]
    D --> E
    E --> F["DB trigger creates personal<br/>collection (default AE)"]
    F --> G["App patches collection country<br/>to signup selection"]
    G --> H["Post-auth refresh:<br/>collections → custom types →<br/>documents → finance → entitlements"]
    H --> I["EntitlementService reads<br/>user_tiers (managed with<br/>service-role key, RLS-protected)"]
    I --> J{"Tier?"}
    J -->|Free| K["1 collection, ~10 docs,<br/>basic budgets"]
    J -->|Plus| L["Unlimited docs, forecast,<br/>exports, AI summary"]
    J -->|Business| M["Multi-company workspaces,<br/>team exports"]
    L & M --> N["Paywall/upgrade:<br/>showTierRequestSheet →<br/>email request (support email)"]
```

The client **only reads** its tier; grants happen server-side. AI calls
use an in-app default Groq key (pilot) — moving behind a Supabase Edge
Function is a documented pre-scale requirement (see OPTIMIZATION_PLAN).

---

## 8. AI feature workflows

```mermaid
flowchart LR
    Q["Ask Finavig (voice/text)<br/>long-press + orb"] --> R["AIIntentRouterService"]
    R -->|"log money"| NLP["parse → transaction"]
    R -->|"plan"| BPS["AI budget plan flow"]
    R -->|"summarize"| SUM["Executive summary"]
    R -->|"navigate"| NAV["deep link to screen"]

    SUM --> KEY{"LLM key?"}
    BPS --> KEY
    KEY -->|"user set"| UK["User's Groq/Gemini key"]
    KEY -->|"default"| DK["In-app Groq key<br/>(quota-metered)"]
    UK & DK --> RES["Rendered plan/summary →<br/>saved caches keyed by<br/>month + data hash"]
```

---

## 9. Data model (core entities)

```mermaid
erDiagram
    GCC_COUNTRY ||--o{ DOCUMENT_TYPE : defaults
    DOCUMENT_COLLECTION ||--o{ EXPIRY_ITEM : contains
    EXPIRY_ITEM ||--o{ RENEWAL_RECORD : history
    EXPIRY_ITEM }o--|| CUSTOM_DOCUMENT_TYPE : "optional registry type"
    DOCUMENT_COLLECTION ||--o{ FINANCE_TRANSACTION : scopes
    FINANCE_CATEGORY ||--o{ FINANCE_TRANSACTION : classifies
    FINANCE_CATEGORY ||--o{ BUDGET : limits
    FINANCE_CATEGORY ||--o{ ENVELOPE : saves-for
    RECURRING_TRANSACTION ||--o{ FINANCE_TRANSACTION : generates
    USER ||--|| USER_TIER : entitlement
    USER ||--o{ DOCUMENT_COLLECTION : owns

    GCC_COUNTRY {
        string code AE_SA_KW_QA_BH_OM
        string displayName
        string currency
        string phoneCode
    }
    EXPIRY_ITEM {
        string id
        string displayName
        date expiresAt
        int daysRemaining
        double renewalFee
    }
    FINANCE_TRANSACTION {
        string id
        double amount
        string kind income_expense
        date occurredAt
    }
    USER_TIER {
        string tier free_plus_business
        date planEndsAt
    }
```

---

## 10. Build, test & release pipeline

```mermaid
flowchart LR
    PUSH["git push"] --> CI["CI gates"]
    subgraph CI
        A["flutter analyze --no-pub<br/>(0 errors required)"]
        B["flutter test --no-pub<br/>(400 tests)"]
        C["dart run tool/perf_budget_check.dart<br/>(file-size ratchet)"]
    end
    CI --> REL["Store build<br/>flutter build appbundle/ipa<br/>--analyze-size"]
    REL --> SHOTS["Pitch/screenshot tour<br/>integration_test/app_pitch_screenshots_test.dart<br/>+ tool/capture_pitch_shots.sh"]
    SHOTS --> DECK["tool/md_to_pdf.dart<br/>PITCH.md → PDF"]
```

Docs that pair with this file: `PITCH.md` (product story),
`MONETIZATION.md` (revenue tracks), `OPTIMIZATION_PLAN.md` (perf backlog),
`PRE_DEPLOYMENT_CHECKLIST.md` (launch checklist).
