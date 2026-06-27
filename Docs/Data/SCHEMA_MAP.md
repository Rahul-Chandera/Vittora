# Vittora SwiftData Schema Map

Current schema version: `VittoraSchemaV4` (baseline `VittoraSchemaV1`) in `Vittora/Core/Data/Persistence/VittoraMigrationPlan.swift`.

## Schema Versions

- **V1** — initial baseline.
- **V2** — adds optional `SDTransaction.transferPairID: UUID?` linking the two
  legs of a transfer (DATAINTEGRITY-1). Additive only; the V1→V2 step is a
  CloudKit-safe `.lightweight` `MigrationStage`.
- **V3** — adds optional `SDTransaction.transferDirectionRawValue: String?`
  (`TransferDirection` .debit/.credit) so a transfer leg's balance effect is
  derivable from a single row (DATAINTEGRITY-1, A3). Additive only; the V2→V3
  step is a CloudKit-safe `.lightweight` `MigrationStage`. Legacy transfer legs
  keep `nil` and stay non-derivable.
- **V4** — adds optional `SDAccount.openingBalance: Decimal?`, the balance before
  any transaction, used by balance reconciliation (DATAINTEGRITY-12, A7). Additive
  only; the V3→V4 step is a CloudKit-safe `.lightweight` `MigrationStage`.
  Legacy rows keep `openingBalance == nil`; reconciliation derives the implied
  opening (`balance − Σ effects`) on read rather than persisting a baseline.

> **Merge-order versioning (resolved):** A3 (`transferDirection`) merged into
> `refactoring` first and kept V3; A7 (`openingBalance`) rebased onto that tip and
> took V4. The two additive changes are independent (V3 → `SDTransaction`, V4 →
> `SDAccount`).

## Registered Models

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
  - migration artifact update
  - repository tests update
  - migration safety test update

## Performance Notes

- Prefer count/fetchCount APIs for stats paths.
- Avoid document thumbnail hydration for simple counts.
- Avoid full-table scans in sync/integrity paths when bounded checks can be used.
