# Vittora SwiftData Schema Map

Current schema version: **`VittoraSchemaV8`** (baseline **`VittoraSchemaV1`**) in `Packages/VittoraCore/Sources/VittoraCore/Data/Persistence/VittoraMigrationPlan.swift`.

## Schema Versions

- **V1** — initial baseline. Uses frozen snapshot `SDTransactionV1` (no transfer columns).
- **V2** — adds optional `SDTransaction.transferPairID: UUID?` linking the two
  legs of a transfer (DATAINTEGRITY-1). Uses frozen snapshot `SDTransactionV2`.
  Additive only; the V1→V2 step is a CloudKit-safe `.lightweight` `MigrationStage`.
- **V3** — adds optional `SDTransaction.transferDirectionRawValue: String?`
  (`TransferDirection` .debit/.credit) so a transfer leg's balance effect is
  derivable from a single row (DATAINTEGRITY-1, A3). Additive only; the V2→V3 step
  is a CloudKit-safe `.lightweight`
  `MigrationStage`. Legacy transfer legs keep `nil` and stay non-derivable.
- **V4** — adds optional `SDAccount.openingBalance: Decimal?`, the balance before
  any transaction, used by balance reconciliation (DATAINTEGRITY-12, A7). Additive
  only; the V3→V4 step is a CloudKit-safe `.lightweight` `MigrationStage`.
  Legacy rows keep `openingBalance == nil`; reconciliation derives the implied
  opening (`balance − Σ effects`) on read rather than persisting a baseline.
- **V5** — adds `SDDebt.linkedTransactionIDsJSON` for multi-leg settlement links (A11).
- **V6** — adds optional `SDAccount.statementDayOfMonth` / `dueDayOfMonth` (C4).
- **V7** — adds optional `SDCategory.spendingBucketRawValue` (G1 coupling) and
  `SDSavingsGoal.isEmergencyFund` with a `false` default (G2).
- **V8** — adds optional `SDTransaction.categorySuggestionRawValue: String?`,
  recording what the smart categorizer proposed at creation so 1.8.0's on-device
  classifier (M3.2) has a labelled accept-vs-override corpus. Additive only; the
  V7→V8 step is a CloudKit-safe `.lightweight` `MigrationStage`. Instrumentation
  only — nothing user-facing reads it, and it never leaves the device or the
  user's own iCloud.

  The column is a sentinel-encoded `CategorySuggestion` so that one optional
  column carries three distinct states, which a bare `UUID?` could not:

  | Stored value | Meaning |
  |---|---|
  | `nil` | not instrumented — the row predates V8 (**never backfilled**) |
  | `""` | the categorizer ran and proposed nothing |
  | a UUID string | the categorizer proposed that category |

  "Accepted" is then `categorySuggestion == .suggested(categoryID)`; "overridden"
  is the pair of differing ids. Written once at creation — `TransactionMapper.updateModel`
  deliberately does not touch it, so a later re-categorisation preserves the
  original proposal (which is exactly the override signal).

> **Merge-order versioning (resolved):** A3 (`transferDirection`) merged into
> `refactoring` first and kept V3; A7 (`openingBalance`) rebased onto that tip and
> took V4. The two additive changes are independent (V3 → `SDTransaction`, V4 →
> `SDAccount`).

## Frozen Snapshots (I4)

Per-version **frozen `@Model` snapshots** live under
`Packages/VittoraCore/Sources/VittoraCore/Data/Persistence/SchemaSnapshots/`. Each snapshot is referenced
**only** by its matching `VittoraSchemaVN` entry so lightweight migrations have
a real schema diff at each step.

| Version | Transaction type | Notes |
|---------|------------------|-------|
| V1 | `VittoraSchemaV1.SDTransaction` | No `transferPairID` / `transferDirection` |
| V2 | `VittoraSchemaV2.SDTransaction` | Adds `transferPairID` |
| V3–V7 | `VittoraSchemaV7.SDTransaction` | Adds `transferDirection`; shape held steady through V7 |
| V8+ | `SDTransaction` (live) | Adds `categorySuggestionRawValue` |

> Only the **current** version may reference a live `@Model` class. When you add a
> column to a live model, first freeze its present shape as a snapshot named for the
> **last** version that had it, and repoint every older version at that snapshot —
> V8 had to repoint five (V3–V7) in one go. Skipping this makes several versions
> share a checksum and CoreData aborts staged migration with "Duplicate version
> checksums detected", which is a crash on launch after upgrade, not an error the
> app can recover from. `MigrationPlanSchemaTests` guards this.

**Policy:** all production schema changes must be **additive** (optional columns
or new entities) so CloudKit lightweight migration remains safe. Before any
**non-additive** change, add faithful frozen snapshots for every affected entity
and a forward-migration test that seeds the prior version on disk.

**Verification:** `ModelContainerOnDiskTests` seeds real stores on disk and reopens
them through `VittoraMigrationPlan` (`make test-data`, or the suite on its own):
`onDiskStoreMigratesV1ToV2` asserts data preservation plus `transferPairID == nil`
until set post-migrate; `onDiskStoreMigratesV7ToV8` asserts a populated V7 store keeps
its rows with `categorySuggestion == nil` and round-trips all three states; and
`onDiskStoreMigratesV1ToV8` walks every stage end to end, which is what catches a
mis-repointed intermediate version.

## Registered Models (current / V8)

- `SDTransaction`
- `SDAccount`
- `SDCategory`
- `SDBudget`
- `SDPayee`
- `SDRecurringRule`
- `SDDocument`
- `SDDebt`
- `SDSplitGroup`
- `SDGroupExpense`
- `SDTaxProfile`
- `SDSavingsGoal`

## Practical Relationship Notes

- Transactions reference accounts/categories/payees and optional recurring rule IDs.
- Documents store metadata in SwiftData; binary payloads/thumbnails are in secure storage service.
- Recurring rules produce transactions and advance `nextDate`.
- Split groups and group expenses are linked via group IDs.
- Tax profiles store country, filing/regime context, deductions, and advanced inputs.

## Deletion/Reset Semantics

- Transaction deletion path should cascade linked documents via use-case orchestration.
- Factory reset should clear financial/tax/doc domains and relevant keychain namespace values.
- Document deletion should remove metadata + encrypted payload + thumbnail artifacts.

## Migration Notes

- Container creation uses migration plan wiring:
  - `ModelContainerConfig.makeContainer(...)`
  - `VittoraMigrationPlan`
- Any model shape change requires:
  - frozen snapshot update (when the prior version must remain addressable)
  - migration artifact update
  - repository tests update
  - migration safety test update (`make test-data`)

## Performance Notes

- Prefer count/fetchCount APIs for stats paths.
- Avoid document thumbnail hydration for simple counts.
- Avoid full-table scans in sync/integrity paths when bounded checks can be used.
