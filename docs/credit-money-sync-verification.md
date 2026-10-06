# Credit ↔ Money sync — verification report

**Date:** 2026-10-06
**Scope:** end-to-end check of the optional credit↔Money sync added in
`docs/credit-money-sync.md`.
**Method:** dedicated automated suites plus code-path audit of every Money-tab
consumer of transaction data.
**Suites run:**
`test/credit_test.dart`, `test/finance_test.dart`,
`test/credit_money_sync_test.dart`, `test/credit_money_sync_report_test.dart`.

## Verdict

**The sync works.** Origin and settlement write the correct legs, link them in
both directions, are idempotent, and survive a cold start.

**On "does it show in the Money tab": it depends which part of the tab.**
A synced loan leg is **visible in the transaction log** (and Records), but is
**deliberately excluded from every income/expense analytic** — the month
summary, budgets, charts, biggest-expenses, budget alerts and the AI. That is
correct accounting (a loan is not earnings or spending) and the row is now
labelled **“Credit”** so the difference isn’t mistaken for a maths bug.

Two analytics leaks were found during this verification and **fixed** (see
“Bugs found & fixed”). Before the fix, a loan repayment *did* distort the
“Last 6 weeks” chart and the “Biggest expenses” card.

## 1. Sync mechanics — verified

| Behaviour | Result |
|---|---|
| Borrowed credit with origin sync → `income` leg, `creditLeg=disbursement`, linked from the credit | ✅ |
| Lent credit with origin sync → `expense` leg | ✅ |
| No origin sync → **no** Money row written | ✅ |
| Repaying a borrowed loan → `expense` leg, `creditLeg=settlement`, credit `settledAt` set | ✅ |
| Money received on a lent loan → `income` leg | ✅ |
| Settling twice → no second leg (idempotent) | ✅ |
| Attaching an existing repayment → that row is tagged `creditLeg=settlement`, not merely pointed at | ✅ |
| Settling with `disbursementTransactionId` → a hand-logged principal is tagged `creditLeg=disbursement` and drops out of the income total | ✅ |
| A leg already owned by another credit is never re-tagged | ✅ |
| Settled credit leaves outstanding totals (`CreditMath.totals` → 0) but stays listed | ✅ |
| Links survive a cold start (SharedPreferences round-trip) | ✅ |
| Currency + collection carried from the credit onto the leg | ✅ |

Evidence: `Sync mechanics — origin` and `Sync mechanics — settlement` groups in
`test/credit_money_sync_report_test.dart`; service-level cases in
`test/credit_test.dart`.

## 2. Where a synced value IS shown

| Surface | Includes loan legs? | Notes |
|---|---|---|
| Money tab → transaction log (`TransactionsSection`) | **Yes** | Row shows the amount and a **Credit** tag |
| Records screen (`/records`) | **Yes** | Same rows |
| Money tab record count — “October · N records” | **Yes** | Counts every record, including loan legs |
| Cash-flow forecast (90-day) | **Yes** | Intentional — a loan is real cash moving |
| Credit section totals | No (settled), yes (open) | Settled entries drop to the bottom with a “Settled” badge |

## 3. Where a synced value is EXCLUDED (by design)

| Surface | Why |
|---|---|
| Money tab hero — income / expense / net | `FinanceMath.summaryForMonth` skips `isCreditLinked` |
| Budgets + budget alerts | `FinanceMath.spendByCategory` skips `isCreditLinked` |
| “Last 6 weeks” chart | `WeeklySpendChart` skips `isCreditLinked` *(fixed)* |
| “Biggest expenses” card | `TopExpensesCard` skips `isCreditLinked` *(fixed)* |
| Bill-spike alerts | `AnomalyDetectionService` skips them and their history *(fixed)* |
| AI Executive Summary | `MonthlySummaryAggregator` skips them + prompt note |
| AI Budget Planner | Prompt loops skip them + explicit instruction |
| Home dashboard hero | Same `summaryForMonth` path |

Evidence: `Money tab — what is shown` group — the key assertion
*“loan legs are EXCLUDED from the Money summary totals”* proves the loan is
counted in the log (`activeTransactions.length == 2`) while `summary.income`
stays at the real salary only.

## 4. Bugs found & fixed during this verification

1. **“Last 6 weeks” chart counted loan repayments as spending.**
   `WeeklySpendChart._buckets()` summed every expense. Fixed to skip
   `isCreditLinked`.
2. **“Biggest expenses” listed loan repayments.**
   `TopExpensesCard._top()` filtered only by kind/date. Fixed to skip
   `isCreditLinked`.
3. **Attaching an already-logged repayment did not tag it.**
   `CreditService.settleCredit` only stored `settlementTransactionId` on the
   credit, leaving the reused transaction untagged: it kept counting inside the
   income/expense totals, showed no "Credit" badge, and could be attached to a
   second credit. Fixed: attached records are now tagged `creditId` /
   `creditLeg = settlement`.
4. **A hand-logged loan principal could not be reconciled.** A credit made
   without origin sync left its Money record as ordinary income/spending
   forever. Fixed: the settle sheet now links (and tags) the principal, which
   `settleCredit` accepts as `disbursementTransactionId`.
5. **Bill-spike detection could flag loan legs and skew on them.**
   `AnomalyDetectionService.detectRecentAnomalies` both evaluated loan legs and
   fed them into the historical averages. Fixed: history and candidates are now
   filtered to non-credit rows.
6. **Credit form’s Save button never re-enabled while typing** (no rebuild after
   text entry) — added `onChanged` rebuilds. Found by the earlier widget tests.
7. **Settle sheet defaulted to “skip” when no candidate records existed**,
   contradicting the “mirror the repayment by default” intent — removed.

## 5. Known limitations (not tested as passing, stated honestly)

- **Settlement is single-shot.** No partial/installment repayments; one
  `settledAt` and one `settlementTransactionId` per credit.
- **SQL not executed.** The new columns in `supabase/credit_schema.sql` and
  `supabase/finance_schema.sql` are idempotent by inspection; cloud sync needs
  the user to run those files. Local-only mode works today.
- **No bank feed.** “Automatic” means the single settle action writes both
  records; the app cannot observe that money actually arrived.
- **Verified via widget tests, not a running device.** The sheets and cards are
  exercised through the widget layer, not a manual on-device pass.

## 6. Reproduce

```bash
flutter test test/credit_test.dart \
             test/finance_test.dart \
             test/credit_money_sync_test.dart \
             test/credit_money_sync_report_test.dart
# full suite
flutter test
```

Latest results: the four targeted suites pass, and the full suite is
**478/478**. `flutter analyze` reports no new issues in the touched files
(repo-wide pre-existing warnings only).
