# Vittora Test Matrix

Use this map to pick the fastest meaningful tests after changes.

## Tax changes

- Touch points: tax calculators, tax entities, tax profile persistence, tax form VM.
- Run:
  - `make test-tax`
  - `xcodebuild ... -only-testing:VittoraTests/TaxProfileFormViewModelTests test`
  - `xcodebuild ... -only-testing:VittoraTests/SwiftDataTaxProfileRepositoryTests test`

## Sync/conflict changes

- Touch points: sync status, conflict handler, CloudKit monitor, integrity validator.
- Run:
  - `make test-sync`
  - `xcodebuild ... -only-testing:VittoraTests/SyncStatusServiceTests test`

## Data deletion/reset/documents

- Touch points: `DataManagementService`, document repositories/storage, delete use cases.
- Run:
  - `make test-data`
  - `xcodebuild ... -only-testing:VittoraTests/TransactionUseCaseTests test` (if transaction delete path changed)

## Recurring generation

- Touch points: recurring use cases, rule repositories, background generation.
- Run:
  - `make test-recurring`
  - `xcodebuild ... -only-testing:VittoraTests/SwiftDataRecurringRuleRepositoryTests test`

## Security/app lock

- Touch points: app lock, biometric service, startup/foreground lock gating.
- Run:
  - `xcodebuild ... -only-testing:VittoraTests/AppLockServiceTests test`
  - `xcodebuild ... -only-testing:VittoraTests/BiometricServiceTests test`
  - `xcodebuild ... -only-testing:VittoraTests/SettingsViewModelTests test`

## Build confidence checks

- Compile checks:
  - `make build-ios`
  - `make build-macos`
- Broader regression:
  - `make test`

## Notes

- Prefer targeted suites first for quick feedback, then broaden if touching shared infrastructure.
- For risk-heavy refactors across tax/sync/security/data, run both platform compile checks plus full tests.
