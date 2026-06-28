# VITTORA — Audit Remediation Execution Plan (Agent-Ready)

**Companion to:** `Docs/Audit/PRELAUNCH_AUDIT_2026-06-27.md`
**Audience:** coding agents (and humans) executing the remediation. Each task is small, independently executable, and carries file targets, dependencies, acceptance criteria, tests, and a verification command.
**Date:** 2026-06-27

---

## How to use this plan

- Tasks are grouped into **Epics A–M**. Within an epic, respect the `Deps:` field; across epics, most work parallelizes.
- **Start with Epic A (financial integrity)** — it is the release blocker and several tasks share one root.
- Each task is sized **S** (≤½ day), **M** (~1 day), **L** (multi-day). Split any L further if needed.
- Do not batch unrelated tasks into one PR; one task ≈ one focused change.

### Global conventions (Definition of Done for every task)

1. **Branch:** `fix/<task-id>-<slug>` off `refactoring` (the integration base, itself off `develop`). Leave `develop`/`main` untouched. See `CURSOR_HANDOFF.md` for stacking + merge-into-`refactoring` rules.
2. **Builds:** `make build-ios` **and** `make build-macos` succeed.
3. **Tests:** `make test` green (or the targeted `-only-testing:` subset named in the task, plus no regressions in related suites).
4. **No new warnings**; no force-unwraps; all user-facing strings via `String(localized:)`.
5. **Acceptance criteria** in the task are met and covered by an automated test unless explicitly "manual".
6. Update any doc the change invalidates (`SYSTEM_MAP.md`, `SCHEMA_MAP.md`, `RULE_COVERAGE.md`, `RELEASE_CHECKLIST.md`, `DECISION_LOG.md`).

### Verification command reference
`make build-ios` · `make build-macos` · `make test` · `make test-tax` · `make test-sync` · `make test-data` · `make test-recurring`
Targeted: `xcodebuild -scheme Vittora -destination 'platform=macOS' -derivedDataPath .build -only-testing:VittoraTests/<Suite> test CODE_SIGNING_ALLOWED=NO`
Static checks (use as acceptance gates where noted): `grep -rn "<pattern>" Vittora --include='*.swift'`

### Suggested execution order (critical path)
```
A1 ─┬─ A3 ─ A4 ─┐
A2 ─┘            ├─ A6 ─ A7 ─ A8         (Financial integrity — P0)
A5 ──────────────┘
B1..B6  C1..C6  D1..D7  E1..E5  F0       (P0, parallel to A)
   then  G,H,I,J,K,L (P1/P2)  ·  F1..F6 only if F0 = "build StoreKit"
```

---

# EPIC A — Financial Data Integrity (P0) 🔴

**Root-cause strategy (decided):** introduce a **write-side Unit-of-Work** (one `ModelContext` per business operation) for all compound writes, add **transfer leg pairing**, **correct account-change reversal**, and a **balance reconciliation/repair** safety net. (Alternative — fully derived balances — is captured as `I-ALT` for later; not required to ship the beta.)

### A1 — Introduce a single-context write Unit-of-Work
- **Finding:** DATAINTEGRITY-2 / ARCHITECTURE-01
- **Deps:** none (foundational)
- **Files:** new `Vittora/Core/Data/Persistence/LedgerWriteStore.swift`; `Vittora/App/Dependencies/DependencyContainer.swift`
- **Steps:**
  1. Create `@ModelActor LedgerWriteStore` owning one `ModelContext`, exposing operation-level methods that perform *all* inserts/updates for one business op and call `save()` exactly once, throwing (and not saving) on any failure.
  2. Seed it with `func performTransfer(...)`, `func performAdd(...)`, `func performSettle(...)`, `func performDelete(...)` signatures (bodies filled by A3/A4/A5/A6).
  3. Register in `DependencyContainer` (non-optional once available).
- **Acceptance:** a compound op issues exactly one `save()`; injected mid-op failure persists nothing.
- **Tests:** new `VittoraTests/Core/Data/LedgerWriteStoreTests.swift` with a failure-injecting context wrapper.
- **Verify:** `make test-data`

### A2 — Add `transferPairID` to model/entity/mapper + Schema V2 migration
- **Finding:** DATAINTEGRITY-1
- **Deps:** none
- **Files:** `Core/Domain/Entities/TransactionEntity.swift`, `Core/Data/Models/SDTransaction.swift`, `Core/Data/Mappers/TransactionMapper.swift`, `Core/Data/Persistence/VittoraMigrationPlan.swift`, `Core/Data/Persistence/ModelContainerConfig.swift`
- **Steps:**
  1. Add `transferPairID: UUID?` to `TransactionEntity` and `SDTransaction`; map both ways.
  2. Define `VittoraSchemaV2` (additive) + a `.lightweight` `MigrationStage` V1→V2; wire into the plan and container.
- **Acceptance:** existing on-disk V1 store opens and migrates; new transfers can carry a pair id.
- **Tests:** `VittoraTests/Core/Data/ModelContainerConfigTests.swift` — add a V1→V2 migration round-trip (seed V1 store, open as V2, assert data preserved).
- **Verify:** `make test-data`

### A3 — Rewrite `TransferFundsUseCase` (atomic + paired legs) — DONE (held)
- **Finding:** DATAINTEGRITY-1/2
- **Deps:** A1, A2
- **Files:** `TransferFundsUseCase.swift`, `LedgerWriteStore.swift`, `TransactionEntity.swift`, `SDTransaction.swift`, `TransactionMapper.swift`, `SwiftDataTransactionRepository.swift`, `UpdateTransactionUseCase.swift`, `VittoraMigrationPlan.swift`, `ModelContainerConfig.swift`, `Features/Accounts/Views/TransferFormView.swift`.
- **Decisions (implemented — Option A, two legs + explicit direction):**
  1. Additive optional `TransferDirection` (.debit/.credit) on `TransactionEntity`/`SDTransaction` (+mapper/repo) → **Schema V3** (`transferDirectionRawValue`) + `.lightweight` V2→V3 + round-trip test. Preserves the one-row-one-account invariant (rejected single-signed-record and defer options).
  2. `performTransfer` (atomic via `LedgerWriteStore`): both legs share one `transferPairID`; source=.debit, dest=.credit; both balances applied; one save; rollback on missing account.
  3. **Canonical `TransactionEntity.signedBalanceEffect`** (direction-signed for `.transfer`, replacing `balanceEffect(.transfer)==0`); adopted in `LedgerWriteStore` + `UpdateTransactionUseCase` + `MockLedgerWriting` + A7 `ReconcileAccountBalanceUseCase` (resolves the A6 duplicated-`balanceEffect` nit; all copies deleted).
  4. `TransferFundsUseCase` depends on a REQUIRED concrete `LedgerWriteStore` (no repo fallback; drops `transactionRepository`). Switch to `any LedgerWriting` once A6's seam merges.
- **Schema-version collision (resolved):** A3 (`transferDirection`) merged first → V3; A7 (`openingBalance`) rebased → V4. Carry the I4 caveat: migration tests aren't fully faithful until a frozen per-version snapshot exists.
- **Follow-ups (done on rebase):** A6's `performAdd` rejects `.transfer` (`LedgerWriteError.transferNotSupported`); A7 now includes direction-carrying transfers (each leg's `signedBalanceEffect` on its `accountID`), only legacy nil-direction legs stay skipped.
- **Acceptance:** after a transfer, `Σ(all account balances)` is unchanged; partial failure leaves *all* balances and transactions unchanged. ✅
- **Tests:** `AccountUseCaseTests.TransferFundsUseCase` — `transferIsBalanceNeutral`, `transferRollsBackOnPartialFailure` (+ paired debit/credit legs/one-save, rejects-same-account); `ModelContainerConfigTests.onDiskStoreRoundTripsTransferDirection` + `migrationPlanShape` (V3/V4). On a real in-memory container + real `LedgerWriteStore`.
- **Verify:** `xcodebuild ... -only-testing:VittoraTests/AccountUseCaseTests test` ✅ (build-ios/build-macos ✅).

### A4 — Handle `.transfer` in Delete/Update/Bulk (reverse BOTH legs)
- **Finding:** DATAINTEGRITY-1
- **Deps:** A1, A2, A3
- **Files:** `Core/Domain/UseCases/DeleteTransactionUseCase.swift`, `UpdateTransactionUseCase.swift`, `BulkOperationsUseCase.swift`
- **Steps:** replace each `case .transfer: break` with logic that looks up the paired leg by `transferPairID`, reverses both accounts' deltas, and deletes/updates **both** legs atomically via `LedgerWriteStore`.
- **Acceptance:** create→delete transfer is balance-neutral and leaves no ghost leg; editing a transfer amount re-adjusts both accounts.
- **Tests:** `TransactionUseCaseTests` — `deleteTransferReversesBothAccounts`, `deleteTransferRemovesBothLegs`, `editTransferAmountAdjustsBothAccounts`.
- **Verify:** `make test`
- **Implemented (A4 — branch `fix/A4-transfer-delete-update`, off `refactoring` post-A8 merge):**
  - **Atomic store ops (new):** `LedgerWriteStore.performDelete`, `performUpdate`, and `performUpdateTransfer` added (all via `commit`, one save, rollback on failure). Declared on `LedgerWriting`; `MockLedgerWriting` implements all three against its mock repos.
  - **performDelete (both legs):** for an A3 transfer leg it fetches BOTH legs by `transferPairID`, reverses each leg's `signedBalanceEffect` on its own account, and deletes both rows in one save. Non-transfer rows reverse the single effect and delete. A missing account is skipped (nothing to reverse) rather than failing the delete.
  - **Delete + Update routed atomically:** `DeleteTransactionUseCase` and `UpdateTransactionUseCase` now depend on `any LedgerWriting` and route through `performDelete`/`performUpdate` (no more manual repo balance math). `DeleteTransactionUseCase` still deletes linked documents first; `executeBulk` skips ids already removed as a transfer partner.
  - **Bulk routed atomically:** `TransactionListViewModel.deleteSelected` now calls `DeleteTransactionUseCase.executeBulk` (transfer-aware, atomic, document-aware). The old non-atomic, transfer-unaware `BulkOperationsUseCase.bulkDelete` was removed (its `accountRepository` dep dropped); `recategorize`/`bulkTag` remain.
  - **Generic-path guard (Option B):** `UpdateTransactionUseCase` fetches the existing row and throws if either the existing or the incoming type is `.transfer` (clear localized message → use the transfer screen). Defense-in-depth: `performUpdate` also rejects `.transfer`. Transfer edits go through the dedicated `UpdateTransferUseCase` → `performUpdateTransfer` (reverse both old legs, re-point/re-amount, apply both new — one save).
  - **Legacy nil-`transferPairID` transfers (best-effort + documented):** a legacy transfer leg has `signedBalanceEffect == 0` (no direction), so delete removes only the selected row with no balance change (matches historical behavior); the unlinkable symmetric partner is left untouched, and `performUpdateTransfer` rejects legacy nil-direction pairs (not balance-derivable).
  - **Tests:** store-level (`LedgerWriteStoreTests`): `performDeleteReversesNonTransfer`, `performDeleteReversesBothTransferLegs`, `performDeleteThrowsWhenMissing`, `performUpdateNetsSameAccount`, `performUpdateMovesAccount`, `performUpdateRejectsTransfer`, `performUpdateTransferReamountsBothLegs`, `performUpdateTransferMovesAccounts`. Use-case level: `TransactionUseCaseTests.deleteTransferReversesBothLegs` and `updateRejectsTransferLeg`; `AccountUseCaseTests.UpdateTransferUseCaseTests` (edit amount; reject same-account).
- **Follow-up (non-blocking, F-A4a):** there is no transfer-EDIT UI entry yet — tapping a transfer opens the generic form, which now safely rejects the edit. Wiring `UpdateTransferUseCase` to a dedicated transfer-edit screen is a separate UI task; data is protected by the guard meanwhile.

### A5 — Fix account-change reversal in `UpdateTransactionUseCase`
- **Finding:** DATAINTEGRITY-3
- **Deps:** A1
- **Files:** `Core/Domain/UseCases/UpdateTransactionUseCase.swift`
- **Steps:** fetch OLD account via `existingTransaction.accountID` and reverse the old effect there; fetch NEW account via `entity.accountID` and apply the new effect there; when they differ update **both** atomically.
- **Acceptance:** editing an expense/income to a different account decrements the old account and increments the new one correctly.
- **Tests:** `TransactionUseCaseTests` — `editChangingAccountUpdatesBothBalances`.
- **Verify:** `xcodebuild ... -only-testing:VittoraTests/Features/Transactions/TransactionUseCaseTests test`

### A6 — Make Add/Settle compound writes atomic
- **Finding:** DATAINTEGRITY-2
- **Deps:** A1
- **Files:** `Core/Domain/UseCases/AddTransactionUseCase.swift`, `SettleDebtUseCase.swift`
- **Steps:** route create-tx + update-account (Add) and create-tx + update-account + update-debt (Settle) through `LedgerWriteStore`.
- **A3 follow-up (REQUIRED on rebase):** `performAdd` MUST reject `.transfer` (throw) — transfers may only flow through `performTransfer`. Also adopt the canonical `TransactionEntity.signedBalanceEffect` in the store and `MockLedgerWriting` instead of a local `balanceEffect`.
- **Acceptance:** partial failure leaves balances/debt unchanged; adding a `.transfer` via `performAdd` is rejected.
- **Tests:** `TransactionUseCaseTests`, `DebtUseCaseTests` — partial-failure rollback cases.
- **Verify:** `make test-data`

### A7 — Balance reconciliation + repair
- **Finding:** DATAINTEGRITY-12 / ARCHITECTURE-07
- **Deps:** none (independent safety net; valuable even before A1)
- **Files:** new `Core/Domain/UseCases/ReconcileAccountBalanceUseCase.swift`; `Features/Sync/SyncStatusView.swift`; `Core/Domain/Entities/AccountEntity.swift`, `Core/Data/Models/SDAccount.swift`, `AccountMapper.swift`, `SwiftDataAccountRepository.swift`, `CreateAccountUseCase.swift`, `UpdateAccountUseCase.swift`, `VittoraMigrationPlan.swift`, `ModelContainerConfig.swift`, `Core/Domain/Repositories/TransactionRepository.swift` (+ impls/mocks).
- **Decisions (implemented; rebased onto A3):**
  1. **Opening balance** = additive optional `openingBalance: Decimal?` on `SDAccount`/`AccountEntity` → **Schema V4** `.lightweight` (V3→V4; renumbered off A3's V3). New accounts seed `openingBalance = balance`; manual balance edits in `UpdateAccountUseCase` re-baseline opening by the delta (so repair won't revert them). **Legacy `nil`-opening accounts:** implied opening (`balance − Σ effects`) is derived **on read** and treated as reconciled — **never auto-persisted** (CloudKit txns may be unsynced; pinning a baseline would lock in a wrong value).
  2. **Check:** `expected = openingBalance + Σ(signedBalanceEffect)` using the canonical `TransactionEntity.signedBalanceEffect` (A7's local `balanceEffect` deleted); flag accounts where `stored != expected`. Repair writes `balance = expected` (opening untouched), idempotent.
  3. **Transfers (A3 enables; transfer TODO closed):** direction-carrying transfer legs are now reconciled — each leg's `signedBalanceEffect` (`.debit` −, `.credit` +) is replayed on its own `accountID`. Only **LEGACY `nil`-direction** transfer legs remain non-derivable; any account touched by one is SKIPPED (never flagged/repaired) so repair can't wipe a real transfer effect.
  4. **Uncapped pass:** added `TransactionRepository.fetchAllForReconciliation()` (no 500-row cap). "Repair Account Balances" action wired into `SyncDetailView`.
- **Acceptance:** seeded drift is detected and repaired to the transaction-derived value (incl. direction-carrying transfers); legacy `nil`-direction-transfer-touched and legacy `nil`-opening accounts are skipped; the pass replays >500 rows.
- **Tests:** `ReconcileAccountBalanceUseCaseTests` — detect+repair (idempotent), reconciled-not-flagged, legacy-nil-opening-skipped, legacy-nil-direction-transfer-skipped, **direction-carrying-transfer-reconciled**, uncapped(>500); `ModelContainerConfigTests.onDiskStoreRoundTripsOpeningBalance` + `migrationPlanShape` (V4).
- **Verify:** `make test-sync` (runs `ReconcileAccountBalanceUseCaseTests` + `SyncConflictHandlerTests`).

### A8 — Recurring generation idempotency + catch-up
- **Finding:** DATAINTEGRITY-4, DATAINTEGRITY-10
- **Deps:** A2 (if adding a unique constraint, do it as a Schema V5 stage — V3 is A3's `transferDirection`, V4 is A7's `openingBalance`)
- **Files:** `Core/Domain/UseCases/GenerateRecurringTransactionsUseCase.swift`, `Core/Infrastructure/BackgroundTaskScheduler.swift`, `VittoraApp.swift`
- **Steps:** serialize generation behind a single actor/lock so launch + BGTask cannot overlap; add an idempotency key `(recurringRuleID, occurrenceDay)` (unique attr or pre-create existence check inside the serialized critical section); loop `advanceRule` while `nextDate <= now` to catch up; anchor monthly recurrence to the rule's original day-of-month; match existing by calendar-day not exact `Date`.
- **Acceptance:** concurrent `execute()` produces no duplicates; a 3-months-stale rule generates all missed periods; a Jan-31 monthly rule does not drift.
- **Tests:** `RecurringUseCaseTests` — `concurrentExecuteNoDuplicates`, `staleRuleCatchesUp`, `monthEndAnchorStable`.
- **Verify:** `make test-recurring`
- **Implemented (A8 — branch `fix/A8-recurring-idempotency`, off `refactoring` post-A6 merge):**
  - **Serialization (no schema change):** new `RecurringGenerationCoordinator` actor holds a single in-flight `Task`; a second caller arriving during a run awaits the same run (coalesce) instead of starting its own. Built once in `DependencyContainer` and shared by both entry points (app-launch `seedDefault…` path in `VittoraApp` and `BackgroundTaskScheduler`), so launch + BGTask can't interleave their check-then-create windows. Chose lock/serialization over a unique constraint to stay schema-independent (avoids V3/V4 collision with A3/A7).
  - **Atomic write:** generation routes create+balance through the merged A6 `LedgerWriting.performAdd` (one save, rollback on failure). The use case now takes a REQUIRED `any LedgerWriting`; the old manual `accountRepository.update` + best-effort rollback block is gone.
  - **Idempotency:** keyed by `(recurringRuleID, calendar day)` via `calendar.startOfDay`, matched against existing rule transactions and the in-run created set — matches by day, not exact `Date`. A failure between the atomic `performAdd` and the separate rule-pointer `update` is self-healed on the next run (skip + advance), never double-charging.
  - **Catch-up:** per due rule, loop while `occurrence <= now` (and `<= endDate`), generating each missed occurrence; advance the persisted `nextDate` once at the end. Safety break if a frequency fails to advance (e.g. `custom(days: 0)`).
  - **Month-end anchor:** `addMonths` preserves an end-of-month anchor — a date that is the last day of its month maps to the last day of the target month (Jan-31 → Feb-28 → Mar-31), other days clamp only when the target is shorter. **Known limitation (no schema field):** a non-last-day day > 28 (e.g. the 30th) that gets clamped in February then sticks to month-end thereafter; a fully faithful per-rule anchor would need an additive `anchorDay` field, deliberately deferred to avoid a schema-version collision with A3/A7.
  - **Testability:** injected `calendar` (gregorian default) + `nowProvider` so catch-up/anchor are deterministic.
  - **Test name mapping:** `concurrentExecuteNoDuplicates`→`recurringCoordinatorCoalescesConcurrentRuns`; `staleRuleCatchesUp`→`generateRecurringTransactionsCatchesUpStaleRule`; `monthEndAnchorStable`→`generateRecurringTransactionsKeepsMonthEndAnchor`; plus `…MatchesExistingByCalendarDay` and `…SelfHealsRuleUpdateFailure`.
- **Status:** MERGED into `refactoring` (reviewer-approved, Epic A gate).
- **Approved follow-ups (non-blocking):**
  - **F-A8a — original-day-of-month anchor:** anchor monthly recurrence to the rule's ORIGINAL day-of-month so day-29/30 rules don't permanently promote to month-ends after a February clamp. Needs an additive `anchorDay` (or derive from the rule's start date) — schedule as the next schema bump after the current V4 tip. Add a `Jan30→Feb28→Mar30` regression test.
  - **F-A8b — recurring income/salary:** recurring generation is currently expense-only (no template transaction type), so recurring income/salary is unsupported. Track as a separate feature (template carries `type`/category), out of the audit-remediation scope.

### A9 — Centralized locale-aware money parser
- **Finding:** DATAINTEGRITY-5 / CODEQUALITY-2
- **Deps:** none
- **Files:** new `Core/Extensions/Decimal+Parsing.swift`; replace `Decimal(string:)` money sites in `TransactionFormViewModel`, `DebtFormViewModel`, `BudgetFormViewModel`, `TransferViewModel`, `AccountFormViewModel`, `SettlementFormView`, `ReceiptReviewViewModel`, `TaxProfileFormViewModel`, `SavingsGoalFormView/DetailViewModel`, `OnboardingViewModel`, `AddGroupExpenseViewModel`, `TransactionFilterViewModel`.
- **Steps:** add `Decimal(localizedAmount:locale:)` using a locale-aware `NumberFormatter`; **reject** unparseable input (surface validation error) instead of defaulting to `0`.
- **Acceptance:** "1,000" / "1.000,50" / "1,5" parse correctly per locale; unparseable → validation error, never silent 0.
- **Tests:** new `VittoraTests/Extensions/MoneyParsingTests.swift` across `en_US`, `de_DE`, `fr_FR`.
- **Verify (gate):** `grep -rn "Decimal(string:" Vittora/Features --include='*.swift'` returns no money-input sites.
- **Implemented (A9 — branch `fix/A9-locale-money-parser`, off `refactoring` post-A4 merge):**
  - **Parser:** new `Decimal+Parsing.swift` with failable `Decimal(localizedAmount:locale:)` using `NumberFormatter` (`.decimal` style, locale-aware grouping/decimal separators). Returns `nil` for empty/unparseable/non-finite — never silent zero.
  - **Replaced all money-input `Decimal(string:)` sites** in the listed Features view models/views: `TransactionFormViewModel`, `TransferViewModel`, `AccountFormViewModel`, `DebtFormViewModel`, `BudgetFormViewModel`, `OnboardingViewModel`, `TransactionFilterViewModel`, `AddGroupExpenseViewModel`, `SavingsGoalFormView`, `SavingsGoalDetailViewModel`, `TaxProfileFormViewModel`, `TaxProfileFormView` (AddDeductionSheet), `SettlementFormView`, `ReceiptReviewViewModel`, `RecurringFormViewModel`; preview literals in `RecurringRowView`/`SubscriptionCard` use `en_US_POSIX`.
  - **Validation:** forms now gate `canSave`/`save()` on successful parse (`parsedAmount != nil`) and throw/show localized errors instead of coercing to `0`. `AddGroupExpenseViewModel` keeps a display-only `amount` for live split math but persists via `parsedAmount`.
  - **Tests:** `MoneyParsingTests` (en_US/de_DE/fr_FR + reject-unparseable + zero-valid); `TransactionFormViewModelTests` updated for no-silent-zero behavior.
  - **Gate:** `grep -rn "Decimal(string:" Vittora/Features --include='*.swift'` → empty ✅.
- **Status:** MERGED into `refactoring` (reviewer-approved). Amended to drop accidentally committed `.build-integration` artifacts; added `/.build-*` to `.gitignore`.
- **Approved follow-ups (non-blocking):**
  - **F-A9a — OCR receipt amounts:** `ReceiptParserService.swift:69,123` still uses `Decimal(string:)` for regex-extracted OCR amounts (same locale issue). Fold into OCR/receipt work (**FUNCTIONAL-15**); user-editable path already uses `Decimal(localizedAmount:)` via `ReceiptReviewViewModel`.
  - **F-A9b — AmountInputView keyboard filter:** `AmountInputView` still filters to `.` only; locale parsing handles pasted/external-keyboard input; wiring the filter to locale decimal separator is a separate UI polish.
  - **AddGroupExpenseViewModel.amount:** NOT dead — `AddGroupExpenseView` footer (exact-split “Remaining:” diff, lines 76–78) reads `vm.amount` for live UI math; persistence uses `parsedAmount` so unparseable input never saves as zero.

### A10 — Delete cascade/nullify for category & recurring rule
- **Finding:** DATAINTEGRITY-6 / ARCHITECTURE-05
- **Deps:** A1
- **Files:** `Core/Domain/UseCases/DeleteCategoryUseCase.swift`, `DeleteRecurringRuleUseCase.swift`, `LedgerWriting.swift`, `LedgerWriteStore.swift`, `CategoryListView.swift`, `RecurringListView.swift`
- **Steps:** before deleting a category, either block when dependents exist (like accounts/payees) **or** nullify `categoryID` on dependent transactions/budgets/recurring templates atomically; for recurring rule deletion, nullify `recurringRuleID` on generated transactions.
- **Acceptance:** no dangling `categoryID`/`recurringRuleID` after deletion.
- **Tests:** `CategoryUseCaseTests`, `RecurringUseCaseTests`, `LedgerWriteStoreTests` — cascade assertions.
- **Verify:** `make test`
- **Status:** Approved; committed on `fix/A10-delete-cascade`. Implemented nullify path via `performDeleteCategory` / `performDeleteRecurringRule` (one save); use cases + list views wired through `any LedgerWriting`.

### A11 — Debt partial-settlement one-to-many link
- **Finding:** DATAINTEGRITY-7
- **Deps:** A1, A2 (schema change)
- **Files:** `Core/Domain/Entities/DebtEntry.swift`, `Core/Data/Models/SDDebt.swift`, `DebtMapper.swift`, `SettleDebtUseCase.swift` (+ migration stage)
- **Steps:** replace single `linkedTransactionID` with `linkedTransactionIDs: [UUID]` (or a `Settlement` child); append on each settlement.
- **Acceptance:** two partial settlements both remain linked and reversible.
- **Tests:** `DebtUseCaseTests` — `twoPartialSettlementsRetained`.
- **Verify:** `xcodebuild ... -only-testing:VittoraTests/Features/Debt/DebtUseCaseTests test`
- **Status:** Merged into `refactoring`. Schema V5 adds `linkedTransactionIDsJSON` (CloudKit-safe); computed `linkedTransactionIDs` accessor; legacy single link merged on read; `performSettle` appends atomically.

### A12 — Split rounding correctness
- **Finding:** DATAINTEGRITY-9
- **Deps:** none
- **Files:** `Core/Domain/UseCases/AddGroupExpenseUseCase.swift`, `SimplifyDebtsUseCase.swift`, `SplitRounding.swift`, `AddGroupExpenseViewModel.swift`
- **Steps:** validate `Σ percentages == 100` (tolerance); round components before summing so `Σ shares == amount`; clamp last-member remainder `≥ 0` and redistribute; use one shared epsilon in SimplifyDebts and round transfers consistently so they net to zero.
- **Acceptance:** for equal/percentage/shares, `Σ shares == amount` exactly; simplify transfers net to zero.
- **Tests:** `SplitGroupUseCaseTests` — property tests over member counts/amounts.
- **Verify:** `xcodebuild ... -only-testing:VittoraTests/Features/Splits/SplitGroupUseCaseTests test`
- **Status:** Merged into `refactoring`.

### A13 — India surcharge marginal relief + capital-gains cap (tax correctness)
- **Finding:** DATAINTEGRITY-8
- **Deps:** none
- **Files:** `Core/Infrastructure/Tax/IndiaTaxCalculator.swift`; `Docs/Tax/RULE_COVERAGE.md`
- **Steps:** implement surcharge marginal relief (cap incremental surcharge at income-above-threshold) mirroring the existing rebate relief; cap the surcharge rate at 15% on the equity LTCG/STCG (111A/112A) portion; update RULE_COVERAGE.
- **Acceptance:** boundary vectors at ₹50L/₹1Cr/₹2Cr/₹5Cr match official calculator within ₹1.
- **Tests:** `TaxCalculatorRegressionTests` — add the four boundary vectors.
- **Status:** Merged into `refactoring`.

# EPIC B — Security / App Lock (P0) 🔴

| ID | Finding | Files | Change | Acceptance / Test | Eff |
|---|---|---|---|---|---|
| B1 | SECURITY-1 | `VittoraApp.swift`, `Core/Security/AppLockService.swift` | Store `lastBackgrounded`; on `.active` lock if `now-lastBackgrounded ≥ lockTimeout`; expose timeout setting (Immediately/1m/5m); make the dead inactivity timer live **or** delete it. | App re-locks after timeout; not before. Extract `shouldLock(backgroundedAt:now:timeout:)` pure fn + unit test boundaries. | M | **Merged** |
| B2 | SECURITY-5 | `Features/Security/AppLockView.swift` | Nil `appLockService` → stay **locked** + error/retry (fail-closed). | `AppLockServiceTests`: nil-service path does not unlock. | S | **Merged** |
| B3 | SECURITY-3 | `Features/Settings/Views/SettingsSectionViews.swift`, `Features/Sync/DataManagementView.swift` | Require `BiometricService.authenticate()` before disabling App Lock and before factory reset; abort on failure. | Manual + VM test: cancel → action aborted. | M | **Merged** |
| B4 | SECURITY-2 | `AppLockView.swift`, `Core/Security/BiometricService.swift` | Consume `allowPasscodeFallback`: hide "Use Passcode" and use biometrics-only policy when disabled. | Test both toggle states. | S | **Merged** |
| B5 | SECURITY-4 | `Core/Security/AppLockService.swift`, `KeychainService.swift` | Persist `consecutiveFailures`/`cooldownExpiresAt` to Keychain; re-arm on init. | Test: cooldown survives relaunch. | M | **Merged** |
| B6 | SECURITY-6 | `Core/Security/EncryptionService.swift` | Single-flight `Task<SymmetricKey,Error>?` cache for key get-or-create; idempotent re-check after exclusivity. | Concurrency test: parallel `encrypt()` on fresh keychain creates one key. | M | **Merged** |
| B7 | SECURITY-12 | `KeychainService.swift`, `EncryptionService.swift` | Map OSStatus/CFError to localized non-diagnostic UI messages; keep raw codes in `os.Logger` only. | No raw SE CFError reaches the lock screen. | S | **Merged** |

---

# EPIC C — Notifications (P0) 🔴

| ID | Finding | Files | Change | Acceptance / Test | Eff |
|---|---|---|---|---|---|
| C1 | FUNCTIONAL-1 | new `Core/Infrastructure/NotificationService.swift` | Wrap `UNUserNotificationCenter`: auth request, schedule/cancel, register categories, deep-link on tap. | Service unit-tested with a protocol seam + mock center. | M |
| C2 | FUNCTIONAL-21 | `Features/Onboarding/...` | Soft permission-priming step (after value, not first launch); defer the system prompt to feature-enable. | `OnboardingViewModelTests` covers new step. | S |
| C3 | FUNCTIONAL-2 | `Core/Domain/UseCases/CheckBudgetThresholdUseCase.swift`, transaction-save flow | Invoke threshold check on save/refresh; dedupe per-threshold per-period; dispatch via C1. | `BudgetUseCaseTests`: fires at 50/75/90/100 once each. | M |
| C4 | FUNCTIONAL-4 | `Features/Accounts/...`, `AccountEntity`/`SDAccount` (+migration) | Add optional `dueDayOfMonth`/`statementDate` to credit cards; schedule pre-due notification. | Field persists; reminder scheduled. | M |
| C5 | FUNCTIONAL-16, M1.4.3 | `GenerateRecurringTransactionsUseCase`, `Debt` use cases | Recurring pre-notification + self debt reminders (contact reminder = ShareLink/message draft, never silent send). | Scheduling tested. | M |
| C6 | UX-4 | `NotificationsSettingsView.swift`, `SettingsViewModel.swift` | Wire toggles to real scheduling; master toggle triggers system permission prompt. | Toggling reflects in scheduled requests. | S |

---

# EPIC D — Compliance / Release Configuration (P0/P1) 🔴

| ID | Finding | Pri | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|---|
| D1 | COMPLIANCE-1 | P0 | `Vittora/PrivacyInfo.xcprivacy` | Add `NSPrivacyAccessedAPICategoryUserDefaults` reason `["CA92.1"]`. | Manifest validates; matches the only required-reason API in use. | S |
| D2 | COMPLIANCE-2/4, SECURITY-9 | P0 | `Info.plist`, `Vittora.entitlements` | Remove `remote-notification` UIBackgroundMode; remove `aps-environment` (no push) **or** set `production` via per-config entitlements; keep `fetch` only if BGAppRefresh needs it. | No unused push capability; release uses production. | S |
| D3 | COMPLIANCE-3 | P1 | new `Vittora-macOS.entitlements`, `project.pbxproj` | Add `com.apple.security.app-sandbox` + `network.client` (CloudKit), `device.camera`, `personal-information.photos-library`, `...addressbook` for macOS. | macOS build sandboxed; camera/contacts/photos verified on a real Mac. | M |
| D4 | COMPLIANCE-6 / MULTIPLATFORM-1 | P1 | `project.pbxproj` | Remove `xros xrsimulator` from `SUPPORTED_PLATFORMS` and `7` from `TARGETED_DEVICE_FAMILY` until a real visionOS release is scoped. | Build targets match QA'd platforms. | S |
| D5 | COMPLIANCE-5 | P1 | `Vittora/Resources/AppStoreMetadata/*` | Restrict description/keywords/screenshots/paywall copy to shipped features (no Watch/Widgets/Siri/Vision). | Metadata = shipped scope. | M |
| D6 | COMPLIANCE-9 | P1 | `Docs/Architecture/SYSTEM_MAP.md`, `Docs/Runbooks/RELEASE_CHECKLIST.md` | Fix dead paths (`EncryptedDocumentStorageService.swift`, `Privacy_Compliance_Checklist.md`); add checklist items for required-reason APIs + unused-capability audit. | Docs point at real files. | S |
| D7 | COMPLIANCE-10 | P1 | `Info.plist` | Remove `NSPhotoLibraryUsageDescription` (PhotosPicker needs none) unless direct PHPhotoLibrary access is added. | No over-declared strings. | S |
| D8 | COMPLIANCE-8 | P1 | `RELEASE_CHECKLIST.md` | Record `ITSAppUsesNonExemptEncryption=false` rationale (Apple AES/SE for user data → exempt). | Decision auditable. | S |

---

# EPIC E — Accessibility (P0/P1) 🔴

| ID | Finding | Pri | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|---|
| E1 | ACCESSIBILITY-1 / UX-1 | P0 | `DesignSystem/Tokens/VTypography.swift` | Rebuild every token on relative text styles (`.system(.body)` / `.system(size:relativeTo:)`); rounded amounts on `.title/.largeTitle`. | Text scales with Dynamic Type at all sizes; no clipping at XXL. | L |
| E2 | ACCESSIBILITY-5 | P0 | `Features/Transactions/Components/AmountInputView.swift` | Add `accessibilityLabel("Amount")` + value; scalable font. | VoiceOver announces the field + value. | S |
| E3 | ACCESSIBILITY-2 | P1 | `AccountFormView`, `CategoryColorPicker`, `OnboardingView` | Add `.accessibilityAddTraits(.isSelected)` + labels to selection controls. | Selection state spoken. | M |
| E4 | ACCESSIBILITY-3/11 | P1 | `TransactionListView`, `TransactionRowView` | Make row a `Button`/`NavigationLink` (gets `.isButton`); `.accessibilityAction(named:"Select")`; include time + selection in label. | Row activates + multi-select via rotor. | M |
| E5 | ACCESSIBILITY-4 | P1 | `Assets.xcassets/V{Income,Expense,Warning}.colorset` | Darken light values to ≥4.5:1 on white; add High-Contrast appearance entries; stop using amber as foreground text. | WCAG AA met; high-contrast variant present. | M |
| E6 | ACCESSIBILITY-6/7/8/9/10/12/13/14/15 | P1 | components/views per finding | `@ScaledMetric` on fixed controls; `VProgressBar` GeometryReader width; reduce-motion guard on `.symbolEffect`; 44pt hit targets; labels for icon-only controls; group stat/legend rows; `.isHeader` traits; localize a11y labels. | Each sub-item has a matching assertion or manual check. | M |

---

# EPIC F — Monetization (P0 decision → P1 build) 🔴

### F0 — DECISION TASK (do first): launch model
- **Finding:** MONETIZATION-01/04, BUSINESS-1
- **Output:** record in `DECISION_LOG.md` one of:
  - **(Recommended for beta) Launch FREE** — defer revenue; make CloudKit sync a free baseline; descope Plus/Pro from the first release. Unblocks beta without StoreKit. → only F6 (legal cleanup) applies now.
  - **Build monetization** — one paid tier at launch (not Plus+Pro). → execute F1–F6.
- **Acceptance:** decision logged; downstream tasks gated accordingly.

> Tasks F1–F5 execute **only if F0 = build**. Each is independently testable.

| ID | Finding | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|
| F1 | MONETIZATION-01 | new `Core/Monetization/EntitlementStore.swift`; entitlements; `Products.storekit` | StoreKit 2: IAP capability, products, `@Observable EntitlementStore` (`Product.products`, `Transaction.updates`, `currentEntitlements`). | Entitlement derives from current transactions; `.storekit` local test passes. | L |
| F2 | MONETIZATION-02 | new `Features/Monetization/PaywallView.swift` | `SubscriptionStoreView`-based paywall; Settings "Upgrade" entry. | Renders localized price + intro eligibility; restore built-in. | M |
| F3 | MONETIZATION-03 | new `Core/Monetization/FeatureGate.swift`; use-case call sites | `Feature` enum + `gate(_:)` at the **use-case** layer; enforce free caps (accounts/budgets/OCR/month). | Each gate boundary unit-tested. | L |
| F4 | MONETIZATION-06/09 | `EntitlementStore`, Keychain | Restore flow; cache last-verified entitlement (tier+expiry) sync-excluded; honor Grace Period; fail-closed only after expiry+grace. | Offline-while-subscribed works; offline-after-expiry+grace gates. | M |
| F5 | MONETIZATION-08 | new `Core/Monetization/ConversionEventTracker.swift` | On-device milestone counters (10 tx, first OCR/report/split, cap-hit) → `shouldPresentPaywall(for:)` with frequency cap. | Triggers fire once per milestone. | M |
| F6 | MONETIZATION-05/13 | `Resources/Legal/TermsOfService.md`, `RELEASE_CHECKLIST.md` | Add auto-renewable subscription disclosures (title/price/period/renewal/cancel) + Terms/Privacy links on paywall; add monetization gates to checklist. | ToS has required clauses (only relevant if F0=build). | S |

---

# EPIC G — Code Quality / Correctness (P1)

| ID | Finding | Files | Change | Acceptance / Verify | Eff |
|---|---|---|---|---|---|
| G1 | CODEQUALITY-1 | `TransactionDetailViewModel.swift`, `TransactionFormView.swift`, `FetchTransactionsUseCase.swift` | Add `execute(id:)`→`repository.fetchByID`; switch detail/edit off `filter:nil`+`first(where:)`. | Open the oldest of >500 tx succeeds; regression test added. | S |
| G2 | CODEQUALITY-6 | new `Core/Extensions/CurrencyFormatter.swift`; ~17 helper sites | One shared currency formatter + one compact abbreviator; replace local helpers. | `grep -rn "func format.*Amount" Vittora/Features` → 0. | L |
| G3 | CODEQUALITY-4 | `AccountEntity`, `TransactionEntity` enums + ~10 sites | Add localized `displayName`; delete `rawValue.capitalized`/`replacingOccurrences` display. | No `rawValue.capitalized` in views. | M |
| G4 | CODEQUALITY-5 | `Features/Categories/Components/CategoryPicker.swift` | Localize `Section` titles + default title via `String(localized:)`. | No raw English literals in body. | S |
| G5 | CODEQUALITY-7 | `Core/Infrastructure/AppUserDefaults.swift`, `SettingsViewModel.swift` | Centralize `vittora.*` keys as constants; route reads/writes through them. | `grep -rn '"vittora\.' Vittora/Features` → 0. | M |
| G6 | CODEQUALITY-8 | `SettingsViewModel.swift` | Await keychain writes (or revert on failure); serialize; user-facing error mapping. | No fire-and-forget `Task{}` setters. | M |
| G7 | CODEQUALITY-10/12 | `DashboardView.swift`, `Core/Extensions/Color+Hex.swift` | Currency fallback via `formatted(.currency)`; convert colorspace before reading components; handle grayscale. | No `"$0.00"` literal; hex round-trips on grayscale. | S |

---

# EPIC H — Performance (P1)

| ID | Finding | Files | Change | Acceptance / Verify | Eff |
|---|---|---|---|---|---|
| H1 | PERFORMANCE-01/02 | `SwiftDataTransactionRepository.swift`, `TransactionRepository.swift` | Push `typeRawValue`/`accountID`/`categoryID` equality + date into `#Predicate`; add `fetchByAccount(id:limit:)`; hard limit on no-date branch. | Account/payee detail no longer full-table scans (instrument). | M |
| H2 | PERFORMANCE-03 | `TransactionListView.swift`, `TransactionListViewModel.swift` | Debounce search (`.task(id:)` + 250ms cancellable sleep); cancel prior task. | No fetch per keystroke. | S |
| H3 | PERFORMANCE-12 | `SwiftDataBudgetRepository.swift` | Remove `|| true` no-op; push period filter into predicate. | `grep "|| true"` → 0; fewer rows fetched. | S |
| H4 | PERFORMANCE-04 | `CustomReportUseCase.swift`, `DashboardDataUseCase.swift`, `CategoryBreakdownUseCase.swift` | Build `[UUID:Entity]` maps once (like `DataExportService`); O(1) lookups. | No `first(where:)` inside per-tx loops. | S |
| H5 | PERFORMANCE-06/07 | repo + `DataExportService.swift` | Add `fetchOffset` pagination; paged/streamed export; infinite-scroll list. | Export complete >500; list pages. | M |
| H6 | PERFORMANCE-08/09 | `TransactionRowView.swift`, `BalanceChartView.swift` | Precompute formatted amount + color into row VM; memoize chart min/max. | No per-render allocation in row body. | S |
| H7 | PERFORMANCE-05 / ARCHITECTURE-04 | `AppState.swift` + list VMs | Replace global `dataRefreshVersion` with `@Query` or per-domain signals. | Mutations refresh only affected screens. | L |

---

# EPIC I — Architecture (P1)

| ID | Finding | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|
| I1 | ARCHITECTURE-02/06 | `DependencyContainer.swift`, `EnvironmentValues+DI.swift`, 40 views | Make deps non-optional, eager at composition root; add a `make<Feature>ViewModel()` factory; views receive finished VMs. | No `guard let dep ... return nil` in views; `DEBUG` trap on missing config. | L |
| I2 | ARCHITECTURE-03 | `project.pbxproj` | `SWIFT_VERSION = 6.0` (or `SWIFT_STRICT_CONCURRENCY = complete`); resolve diagnostics; update docs. | Builds in Swift 6/strict; docs match. | M |
| I3 | ARCHITECTURE-08 / CODEQUALITY-13 | `VittoraApp.swift`, `AppState.swift`, `AppTabView`, `SidebarNavigation`, `DashboardView` | Replace `.vittoraNewTransaction`/`.vittoraOpenSettings` NotificationCenter with typed `AppState` presentation enum. | No custom `Notification.Name` for navigation. | M |
| I4 | ARCHITECTURE-09 / DATAINTEGRITY-11 | `VittoraMigrationPlan.swift`, tests | Freeze V1; establish V2 + stage convention; add forward-migration test (overlaps A2). | Migration test exists; additive-only policy documented. | M |

> **I4 follow-up (from A2 review):** A2's `VittoraSchemaV2.models` currently just *aliases* `VittoraSchemaV1.models` (both reference the live model types), so there is no real V1↔V2 schema snapshot difference and only additive/lightweight changes are safe. I4 must add a **faithful V1→V2 migration test** that seeds an on-disk store using a **frozen `SDTransactionV1` snapshot** (no `transferPairID`) referenced *only* by `VittoraSchemaV1`, then opens it as V2 and asserts the column is added and data preserved. Establish per-version frozen snapshots before any **non-additive** schema change.
| I-ALT | (root alt) | ledger layer | *Optional later:* fully derive `balance` from transactions (additive CloudKit merges). Supersedes parts of A7/ARCH-07/-11. | Balance computed on read + cached; not required for beta. | L |

---

# EPIC J — Multi-platform (P1/P2)

| ID | Finding | Pri | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|---|
| J1 | MULTIPLATFORM-2 | P1 | `ContentView.swift`, `AppTabView.swift`, `SidebarNavigation.swift` | Adopt `TabView { }.tabViewStyle(.sidebarAdaptable)`; 3-column `NavigationSplitView` for list/detail features; stop using bare size-class as the only signal. | iPad gets sidebar/3-column; Split View not iPhone layout. | L |
| J2 | MULTIPLATFORM-3 | P1 | new SPM package / framework; `Vittora.entitlements` | Extract Core (Domain+Data) into a shared package; add app-group; route ModelContainer through it. Remove UIKit/AppKit import from `AttachDocumentUseCase`. | Core links from a would-be extension target; domain has no UI imports. | L |
| J3 | MULTIPLATFORM-4 / UX-15 | P1 | 9 feature roots, `SidebarNavigation.swift`, `AppTabView.swift` | Container owns the NavigationStack exactly once; feature roots render content + `.navigationDestination` only. | No nested stacks on iPad/macOS. | M |
| J4 | MULTIPLATFORM-5 | P2 | list rows | `.contextMenu` (edit/delete/duplicate) on primary rows; `.hoverEffect`/`.onHover`; replace tap-gestures with Buttons. | Pointer feedback + context menus present. | M |
| J5 | MULTIPLATFORM-6 | P2 | `VittoraApp.swift` `.commands` | Move commands out of `#if os(macOS)`; add iPad Cmd-shortcuts (new tx, search, save) + Cmd-number tab switching. | iPad keyboard shortcuts work. | M |
| J6 | MULTIPLATFORM-7 | P2 | `VittoraApp.swift` | macOS `Settings { }` scene (drop Cmd-, hack); `windowResizability(.contentMinSize)`/min frame; flesh out menu bar. | Native macOS Settings + min window. | M |
| J7 | MULTIPLATFORM-8/9/10 | P2 | `VittoraApp.swift`, `DashboardView.swift`, `SidebarNavigation.swift` | `@SceneStorage` for tab/nav path; NSUserActivity for Handoff; size-class not `UIDevice.idiom`; bind sidebar selection directly to `appState.selectedTab`. | State restores; single selection source. | M |

---

# EPIC K — Functional Gaps (P1/P2)

| ID | Finding | Pri | Files | Change | Acceptance | Eff |
|---|---|---|---|---|---|---|
| K1 | FUNCTIONAL-6 | P1 | `TaxEntity.swift`, `IndiaTaxCalculator.swift`, `TaxProfileFormView.swift` | Section-aware deduction model with statutory caps (80C ₹1.5L, 80CCD(1B) ₹50k, 80D age tiers) + HRA exemption calc + 80C utilization view. | Caps enforced; HRA = min of 3 components; tested. | L |
| K2 | FUNCTIONAL-5 | P1 | `CashFlowReportView.swift`, new projection use case | Walk active recurring occurrences forward N months + avg discretionary; render projected vs actual (or rename until built). | Forecast uses future recurring data. | M |
| K3 | FUNCTIONAL-7 / BUSINESS-2 | P1 | `Features/Splits/...` | ShareLink invite/summary (image/deep link) + per-group report export; decide CKShare vs share-out for V1. | A non-user can be invited; group exports. | L |
| K4 | FUNCTIONAL-8 | P1 | `Features/Reports/...` | `ImageRenderer`/`PDFDocument` export for Annual/Monthly/Custom via ShareLink. | Reports export to PDF. | M |
| K5 | FUNCTIONAL-18 | P2 | new CSV import flow | Column mapping + duplicate-aware insert (reuse DuplicateDetection); generic + Mint/YNAB profiles. | Imports a sample CSV correctly. | M |
| K6 | FUNCTIONAL-3 | P2 | `SmartCategorizeUseCase.swift` | Rule-based first pass (keyword→category, editable) on merchant/OCR text/note; fallback to payee history. | Rules categorize known merchants. | M |
| K7 | FUNCTIONAL-10/9 | P2 | `Features/Savings`, US tax profile | Savings auto-allocation (`required = (target-current)/months`); US 401k/IRA/HSA contribution inputs + headroom. | Suggested monthly + projected date shown. | M |
| K8 | FUNCTIONAL-11/12/13, UX-14 | P2 | per finding | Wire or remove `BatchScanUseCase` + multi-page; add edit audit trail; saved filters; resolve `QuickEntryView` (wire as fast-add or delete; remove 300ms sleep). | Dead code removed or wired; features tested. | M |

---

# EPIC L — Testing & CI (P1)

| ID | Finding | Files | Change | Verify | Eff |
|---|---|---|---|---|---|
| L1 | TESTING-8 | new `.github/workflows/ci.yml` (or Xcode Cloud) | `make build-ios` + `make build-macos` + `make test` on every PR; upload xcresult; fail on red; gate merges. | CI green on a PR. | M |
| L2 | TESTING-9 | `VittoraTests/Core/Mocks/*` | Add `failOnNextWrite`/`failForID` to repo mocks; `MockKeychainService` records access class; `MockBiometricService` throws LAError variants. | Use-case error/rollback paths reachable. | M |
| L3 | TESTING-2 | `ModelContainerConfigTests.swift` | On-disk V1→V2 migration round-trip fixture (overlaps A2/I4). | `make test-data`. | M |
| L4 | TESTING-3 | new `SyncIntegrityValidatorTests` | Seed each invalid shape (NaN, neg asset, overpaid debt, bad currency) + balance-drift; assert violations/repair. | `make test-sync`. | M |
| L5 | TESTING-4 | `EncryptionServiceTests` (device-gated) | SE generate/wrap/unwrap round-trip + legacy→SE migration; or factor migration decision into a pure tested fn + manual device step in checklist. | Device test or documented manual. | M |
| L6 | TESTING-5 | new `ReceiptParserServiceTests` | Table-driven synthetic receipts ($/₹, comma grouping, date formats, total-keyword, no-amount). | New suite green. | S |
| L7 | TESTING-6 | `AppLockServiceTests` + UI test | `shouldLock(...)` boundary tests (overlaps B1) + background/foreground UI test. | Lock appears after background. | M |
| L8 | TESTING-7 | `DecimalCurrencyTests.swift` | Exact `Decimal` equality; assert rounding mode on .5 boundaries; JPY no fraction; pinned locale strings. | `make test`. | S |

---

# EPIC M — Business / GTM (non-code decisions)

These are **decision/strategy** items (not agent-codable); track in `DECISION_LOG.md`:
- **BUSINESS-5:** sequence launch to ONE Wave-1 market (recommend India-first on the tax wedge) — do not parallelize US+India.
- **BUSINESS-3/4/8/11:** correct UVP + competitive matrix + tier marketing to shipped scope; lead with privacy + tax; treat OCR/ML/multi-currency/Watch/Widgets/Vision as roadmap.
- **BUSINESS-6:** pick one positioning ("money OS" vs honest "privacy-first tracker with tax") and make the product embody it.
- **BUSINESS-7:** externalize tax rule sets to a signed, fetchable data file with cached fallback + freshness indicator (engineering follow-up once K1/A13 land).
- **BUSINESS-10/12:** rebuild KPI model bottom-up from a single-market soft-launch with real trial-start/convert numbers; gate spend on hitting pre-launch KPIs.

---

## Milestone definitions

- **M1 — Beta-safe (flip NO GO → GO WITH CONDITIONS):** Epic A (A1–A10), Epic B (B1–B3), Epic C (C1, C3, C6), Epic D (D1–D2), Epic E (E1–E2), F0 decision, plus G1 and UX category-row fix. Add L1 (CI) to lock it in.
- **M2 — Public-launch-ready:** remaining D/E, Epic F (if monetizing), Epic G/H/I, K1–K4, L2–L8, metadata reconciliation.
- **M3 — Scale/roadmap:** Epic J, remaining K, derived-balance (I-ALT), tax remote config.

*Generated from the 2026-06-27 pre-launch audit. Each task is independently shippable; respect intra-epic `Deps`. Update this plan as tasks land.*
