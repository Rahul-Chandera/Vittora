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
  - `Scripts/ci/check-placeholder-order.py` (reads the catalogue; no build needed)
- Counted strings must use .xcstrings plural variations, never a `(s)` suffix, because Hindi and Spanish have real plural rules.
- Coverage and placeholder order answer different questions. Coverage: is the key there and translated? Order: does the translation's format match the key's? A translation can be complete and still crash — #257 reordered `%lld` ahead of `%@` in Hindi, which type-checks as a pointer read as an integer. Fix a reported `order` with positional specifiers (`%1$@`, `%2$lld`); the check then treats the reordering as equivalent.
- `check-placeholder-order.py --self-test` asserts the detector still catches #257. Run it if you change the parser — a green catalogue scan alone cannot tell you the detector works.

## Build confidence checks

- Compile checks:
  - `make build-ios`
  - `make build-macos`
- Broader regression:
  - `make test`

## In-app purchase

**Products and intro-offer eligibility are covered in-test. Purchase and restore are still
device-only.** The dividing line is the app-facing entitlement cache, not the configuration.

`xcodebuild` does not honour a scheme's `StoreKitConfigurationFileReference` — that is an
IDE-only setting, so under `make test` the scheme contributes no StoreKit configuration.
`SKTestSession(contentsOf:)` does not depend on the scheme: it builds its own environment
from `Vittora.storekit`, resolved from `#filePath`. `IntroOfferEligibilityTests` uses this
and does serve products, which is what closed the intro-offer gap — `PurchaseService`
resolving `isEligibleForIntroOffer == true` for a fresh account is now asserted, where
previously only the "no trial" direction was covered anywhere.

What is still not reachable is a purchase the app can *see*. `SKTestSession.buyProduct()`
works on iOS 27 (the release-note fix below is real — it no longer throws `.notEntitled`)
and the session records the transaction in `allTransactions()`. But a test process that has
already queried StoreKit keeps serving the entitlement cache it warmed:
`Transaction.currentEntitlements` stays empty and eligibility stays true. The same test
passes when it is the only one in the process, and `AppStore.sync()` hangs rather than
reconciling. So the consumed-trial direction was left uncovered rather than committed as a
flaky test — see the note in `IntroOfferEligibilityTests`.

> "Fixed: Purchases of non-subscription In-App Purchases made using the
> `SKTestSession.buyProduct()` method might fail with an invalid product error." (181842500)

Purchase, restore and Family Sharing inheritance therefore remain device-only.

What this means in practice:

- `PurchaseService` logic is unit-tested around the boundary: entitlement resolution,
  offline grace, family-shared vs owned, intro-offer eligibility defaults.
- **Buying, restoring and Family Sharing inheritance must be exercised on a device before
  each release**, and the intro-offer *eligible* path needs a sandbox account that has not
  consumed the trial. Nothing in CI covers it.
- **Last device verification: 2026-09-22 (Rahul).** Purchase, restore, Family Sharing
  inheritance and the intro-offer *consumed* direction were all confirmed on a real device.
  That closes them as open questions; it does not close the automation gap, so this line
  needs renewing each release rather than being read as permanent coverage.
- Running from Xcode (⌘R) does apply `Vittora.storekit`, so manual verification there is
  the supported path. The scheme's path to that file was broken until #237 — it pointed at
  `../../../Vittora.storekit`, which Xcode resolves against the project directory, so the
  configuration silently never loaded and the real sandbox answered instead.

## Notes

- Prefer targeted suites first for quick feedback, then broaden if touching shared infrastructure.
- For risk-heavy refactors across tax/sync/security/data, run both platform compile checks plus full tests.
