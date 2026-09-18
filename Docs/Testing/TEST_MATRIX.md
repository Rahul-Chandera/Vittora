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

## In-app purchase

**Purchase and restore are device-only. This is a limitation of the harness, not an
oversight, and it has now been re-tested twice.**

`xcodebuild` does not honour a scheme's `StoreKitConfigurationFileReference` — that is an
IDE-only setting. So under `make test` the process has no StoreKit configuration at all:
`Product.products(for:)` returns nothing, which is exactly what
`emptyProductLoadIsReportedAsFailure` in `PurchaseServiceTests` observes and asserts on.
An `SKTestSession` built in-test cannot rescue this; the app process still reads an empty
StoreKit environment, so `Transaction.currentEntitlements` stays empty after a purchase.

Re-probed on iOS 27 (2026-09-18) because the release notes fixed a related bug:

> "Fixed: Purchases of non-subscription In-App Purchases made using the
> `SKTestSession.buyProduct()` method might fail with an invalid product error." (181842500)

That fix is real and visible: `buyProduct()` no longer throws `.notEntitled`, which is what
it did in every configuration tried before. But the purchase still does not become an
entitlement the app can see, for the configuration reason above. The probe was deleted
rather than committed as a disabled test.

What this means in practice:

- `PurchaseService` logic is unit-tested around the boundary: entitlement resolution,
  offline grace, family-shared vs owned, intro-offer eligibility defaults.
- **Buying, restoring and Family Sharing inheritance must be exercised on a device before
  each release**, and the intro-offer *eligible* path needs a sandbox account that has not
  consumed the trial. Nothing in CI covers it.
- Running from Xcode (⌘R) does apply `Vittora.storekit`, so manual verification there is
  the supported path. The scheme's path to that file was broken until #237 — it pointed at
  `../../../Vittora.storekit`, which Xcode resolves against the project directory, so the
  configuration silently never loaded and the real sandbox answered instead.

## Notes

- Prefer targeted suites first for quick feedback, then broaden if touching shared infrastructure.
- For risk-heavy refactors across tax/sync/security/data, run both platform compile checks plus full tests.
