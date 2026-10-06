# Credit ↔ Money sync — how it would work

> Status: **implemented** (settlement-first). See §10 for what shipped and the
> one deviation from this proposal.
> Related: [`lib/models/credit.dart`](../lib/models/credit.dart),
> [`lib/models/finance.dart`](../lib/models/finance.dart),
> [`lib/services/credit_service.dart`](../lib/services/credit_service.dart),
> [`lib/services/finance_service.dart`](../lib/services/finance_service.dart)

## 1. The idea in one line

A credit obligation and a money movement are two views of the same cash event.
Today Finavig keeps them deliberately separate, so the user has to log the same
money twice. The proposal is to let them **opt in** to a link: creating a credit
can mirror its principal as a Money transaction, and settling it can mirror the
repayment — leaving a clean four-leg cash ledger.

## 2. The full lifecycle (your description, verified)

Yes — what you described is coherent, and it's the classic cash-basis view of a
loan. Both directions use the same rule: **the money leaving the user is an
expense; the money arriving is income.**

| Step | Direction | Event | Money leg |
|---|---|---|---|
| 1 | Borrowed | User receives the principal | **Income** |
| 2 | Borrowed | User repays the lender | **Expense** |
| 3 | Lent | User hands over the principal | **Expense** |
| 4 | Lent | Counterparty repays the user | **Income** |

So:

- **Borrow**: +income at creation, −expense at repayment.
- **Lend**: −expense at creation, +income at repayment.

Read across the net: borrow then repay nets to zero cash (correct — you received
and gave back the same amount); the value you got was liquidity, not income.
Lend then repay also nets to zero. That is why this scheme is *internally*
consistent.

### The one caveat

Where it breaks is **not** the ledger — it's the reporting that sits on top of it:

- `FinanceMath.summaryForMonth` (`lib/models/finance.dart`) sums every
  `income`/`expense` transaction. A borrowed principal counted as income, or a
  lent principal counted as expense, inflates those totals. A loan is not
  earnings and not spending.
- The AI services already report credit separately —
  `ai_executive_summary_service.dart` emits a `CREDIT OBLIGATIONS` block and a
  `Credit Position` insight, and `ai_budget_plan_service.dart` is explicitly told
  not to treat money owed to the user as cash until repaid. If the principal is
  *also* logged as income/expense, the same amount is counted twice.

**Conclusion:** the sync is worth building, but the mirrored transactions must be
tagged so the reporting layers can tell a loan leg apart from real income/spend.
That tag is the core of the design below.

## 3. Data model

### CreditEntry (`lib/models/credit.dart`)

Add three nullable fields (all survive older rows):

- `settledAt` (`DateTime?`) — when the obligation closed. Drives the "Settled"
  badge and drops the entry out of `CreditMath.totals` / overdue math.
- `disbursementTransactionId` (`String?`) — the Money transaction for the
  principal (step 1 / step 3).
- `settlementTransactionId` (`String?`) — the Money transaction for the
  repayment (step 2 / step 4).

`copyWith` needs the existing `_unset` sentinel treatment for all three, plus
`fromJson` / `toJson`. `toJson` feeds the local JSON cache; `_creditModelToRow`
(`credit_service.dart`) maps to `settled_at`, `disbursement_transaction_id`,
`settlement_transaction_id`, and `_creditRowToModel` reads them back.

If installments are ever wanted, replace the two single ids with a list:
`List<CreditSettlement> { amount, at, transactionId }`. Start single; the two
fields above are the minimal shape.

### FinanceTransaction (`lib/models/finance.dart`)

Already has a precedent: `documentId` links a payment back to an expiry-tracked
document. Mirror it with a credit link:

- `creditId` (`String?`) — the `CreditEntry.id` this leg belongs to.
- `creditLeg` (`CreditLeg { disbursement, settlement }`) — which edge of the
  lifecycle this row is.

`_txModelToRow` / `_txRowToModel` (`finance_service.dart`) gain
`credit_id` / `credit_leg`. This tag is what lets the reporting layers exclude
loan legs (see §6).

### DDL

`supabase/credit_schema.sql` — same idempotent pattern as the `start_date` /
`description` backfills already there:

```sql
alter table credit_entries add column if not exists settled_at date;
alter table credit_entries add column if not exists disbursement_transaction_id uuid;
alter table credit_entries add column if not exists settlement_transaction_id uuid;
```

`supabase/finance_schema.sql` — mirror:

```sql
alter table finance_transactions add column if not exists credit_id uuid;
alter table finance_transactions add column if not exists credit_leg text;
```

Both stay local-only until the user runs the scripts, exactly as with the
existing credit columns.

## 4. How the two flows work at runtime

Both reuse the existing write paths — there is nothing new to invent.

### Money write path (unchanged)

Every entry point does the same three steps (`money_screen.dart:604`,
`records_screen.dart:55`, `home_screen.dart:242`,
`quick_action_sheet.dart:78`):

1. `showModalBottomSheet(builder: (_) => const TransactionFormSheet())`
2. the sheet builds a `FinanceTransaction` (`id: const Uuid().v4()`,
   `collectionId` = active, `occurredAt: now`) and does
   `Navigator.pop(context, transaction)`
3. the caller does `await FinanceService.instance.addTransaction(created)`

`addTransaction` inserts at `_transactions[0]`, learns the category, persists,
and `notifyListeners()`.

### Origin sync (optional, default **off**)

In `CreditFormSheet._submit`, after building the `CreditEntry`:

1. If the user ticked **"Also log this in Money"**:
   - build a `FinanceTransaction` with the mirrored kind —
     `borrowed → income`, `lent → expense` — `occurredAt: startDate`,
     `creditId: entry.id`, `creditLeg: CreditLeg.disbursement`;
   - `await FinanceService.instance.addTransaction(tx)`;
   - store `tx.id` as `disbursementTransactionId` in
     `CreditService.instance.addCredit(...)`.
2. Unchecked → nothing changes from today.

### Settlement sync (the "whenever it comes back" part)

Add a **"Mark settled" / "Money received"** action to `_CreditCard`
(`credit_section.dart:222`) next to Edit / Extend / Delete. The sheet offers
either path, since the user may have already logged the cash by hand:

- **Create new** — build a `FinanceTransaction` with the *opposite* kind
  (`borrowed → expense`, `lent → income`), `occurredAt: settlement date`,
  `creditLeg: CreditLeg.settlement`; `addTransaction`; keep its id.
- **Attach existing** — pick from `FinanceService.instance.activeTransactions`
  (the same list the duplicate guard already reads); keep the chosen id.
- **Skip** — checkbox off; just `settledAt`.

Then one call:
`await CreditService.instance.updateCredit(entry.copyWith(settledAt: date, settlementTransactionId: id))`.

Both writes land, both services notify, and the card shows a "Settled" badge.

### Is it automatic?

Not by money-detection — Finavig has no bank feed, so it cannot observe a
repayment. "Automatic" here means the user performs **one** action and both
records are written. That's the honest version of your requirement, and it's what
the checkbox model delivers.

## 5. Where the link should attach (the options)

`linkedTransactionId` on the credit is a one-way pointer
(`CreditEntry → finance_transactions.id`). For a four-leg lifecycle you need two
of them, one per edge:

- `disbursementTransactionId` — the principal leg
- `settlementTransactionId` — the repayment leg

Keeping them separate lets a card show "Borrowed (logged) · Repaid (logged)"
independently, and lets the settle flow attach a pre-existing transaction without
touching the origin leg. No schema change on the finance side beyond the tag.

## 6. Consequences to handle

- **`CreditMath.totals` / `sortedForDisplay` / `isOverdue`** should skip entries
  with `settledAt != null`, so settled loans stop nagging and leave the totals.
  Keep them in history for the extension trail.
- **`FinanceMath.summaryForMonth`** should exclude (or set aside) transactions
  where `creditId != null`, so loan legs don't inflate income/expense.
- **AI services** already read credits; with settled entries filtered out of
  `CreditMath`, their prompts stay correct — but they also need to *ignore*
  credit-linked transactions when summarising cash, or the principal/repayment
  legs will double-count against the credit block they already emit.
- **Budget / category math** should ignore loan legs for the same reason.
- **Category suggestion**: a `FinanceCategory.other` leg is fine, or add a
  dedicated `loans` category if you want the legs visible as their own line.

## 7. Edge cases

- **Partial repayments / installments** — the two-single-id design can't express
  them; move to a `List<CreditSettlement>` if you need it.
- **Deleted linked transaction** — clear the link on the credit (or the settle
  silently breaks). Add a cleanup when a transaction is deleted.
- **Editing a linked transaction's amount** — either sync the credit amount or
  warn; don't let them silently drift.
- **Double-linking** — guard that one transaction can't settle two credits.
- **Currency** — the leg should inherit the credit's `currency`; the two must
  agree.
- **Collection scoping** — both records must share `collectionId`; use
  `activeCollectionId` / `activeTransactions` so they do.
- **Idempotency** — settling twice must not create two legs; check
  `settledAt == null` before writing.

## 8. Implementation plan (smallest useful slice)

1. **Model only** — add the three `CreditEntry` fields + `creditId`/`creditLeg`
   on `FinanceTransaction`, threading `copyWith` / JSON / row mapping. Idempotent
   DDL. Tests for round-trips and legacy fallbacks.
2. **Settle flow** — the "Mark settled" card action with create-new /
   attach-existing / skip. This is the highest-value half: it fixes loans that
   currently nag forever.
3. **Tag-aware reporting** — filter `creditId != null` out of the finance math
   and AI cash summaries; filter `settledAt != null` out of `CreditMath`.
4. **Origin flow (opt-in, default off)** — the `CreditFormSheet` checkbox with
   the double-count warning.
5. **Tests** — `test/credit_test.dart`, `test/finance_test.dart`, plus a new
   suite for the settle flow; run `flutter test` and `flutter analyze` on the
   touched files.

Steps 1–3 are safe and self-consistent. Step 4 should not ship before step 3,
otherwise the reporting double-counts.

## 9. Verdict

It's a good idea **if it stays opt-in and the legs are tagged** — the tag is what
keeps the Money dashboard and the AI honest. Without the tag the origin sync
double-counts; with it, you get exactly the four-leg lifecycle you described,
with zero friction after a single "Mark settled" tap.

Do not auto-link without user intent, and do not treat a loan leg as real income
or spending anywhere reporting is shown.

## 10. Implementation status

Shipped:

- `CreditEntry` gained `settledAt`, `disbursementTransactionId`,
  `settlementTransactionId` (`isSettled`, `markSettled`) — JSON + row mapping +
  idempotent DDL in `supabase/credit_schema.sql`.
- `FinanceTransaction` gained `creditId` / `creditLeg` (`isCreditLinked`) —
  JSON + row mapping + DDL in `supabase/finance_schema.sql`.
- `CreditMath` skips settled entries in `totals`, never reports them overdue,
  sinks them in `sortedForDisplay`, and exposes `openOnly`.
- `CreditService.settleCredit` and `addCreditWithDisbursement` orchestrate the
  two writes (settle is idempotent). Attaching an already-logged record now
  **tags** it (`creditId` / `creditLeg = settlement`) instead of only pointing
  at it, so a reused row stops counting as real income/spending and cannot be
  attached to a second credit.
- Settle UI: `lib/screens/money/forms/credit_settle_sheet.dart`, a
  "Mark as repaid / Money received back" card action, and a "Settled" badge
  (`credit_section.dart`) — wired in both `money_screen.dart` and
  `credits_screen.dart`.
- **Principal reconciliation on settle** — when the loan amount was logged in
  Money by hand (origin sync left off), the settle sheet shows a "Money you
  received / Money you paid out" section listing candidates, preselecting one
  when a single record matches the credit's amount, and tags the chosen row as
  the `disbursement` leg. Settling therefore repairs a hand-entered loan
  instead of leaving the principal counted as real income/spending.
- Origin opt-in checkbox in `CreditFormSheet` (new entries only), default off.
- Tag-aware reporting: `FinanceMath.summaryForMonth` / `spendByCategory`,
  `MonthlySummaryAggregator`, and the AI budget-plan loops ignore credit-linked
  rows; both AI prompts say so explicitly.

Deviation from the proposal: settlement is **single-shot** (one `settledAt` and
one `settlementTransactionId`), not a list of installments — partial repayments
would need the `List<CreditSettlement>` shape noted in §3. The settle sheet
defaults to **creating** the Money record (that is the "automatic when the money
comes back" behaviour), and offers attaching an existing record or skipping.

Tests: `test/credit_test.dart`, `test/finance_test.dart`, and
`test/credit_money_sync_test.dart` (model round-trips, settled math, the service
flow, and widget-level sheet behaviour). Full suite green.
