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

## Localization/string catalogue

- Touch points: Localizable.xcstrings, any String(localized:) literal, plural variations.
- Run:
  - `xcodebuild ... -only-testing:VittoraTests/PluralVariationTests test`
  - `xcodebuild ... -only-testing:VittoraTests/SpanishLocalizationCatalogTests test`
  - `DERIVED=.build-ios:.build-macos Scripts/ci/check-localization-coverage.sh` (needs make build-ios and make build-macos first)
- Counted strings must use .xcstrings plural variations, never a `(s)` suffix, because Hindi and Spanish have real plural rules.

## Build confidence checks

- Compile checks:
  - `make build-ios`
  - `make build-macos`
- Broader regression:
  - `make test`

## Notes

- Prefer targeted suites first for quick feedback, then broaden if touching shared infrastructure.
- For risk-heavy refactors across tax/sync/security/data, run both platform compile checks plus full tests.
