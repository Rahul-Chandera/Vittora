# Vittora SwiftData Schema Map

Current schema baseline: `VittoraSchemaV1` in `Vittora/Core/Data/Persistence/VittoraMigrationPlan.swift`.

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
