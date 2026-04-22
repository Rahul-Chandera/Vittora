# Vittora Release Checklist

Use this checklist before TestFlight/App Store submission.

## 1) Build/compile gates

- [ ] `make build-ios` succeeds.
- [ ] `make build-macos` succeeds.
- [ ] `make test` succeeds (or approved targeted waiver).

## 2) Security and privacy gates

- [ ] App lock flow verified on cold launch and foreground transitions.
- [ ] Keychain + encryption paths verified for expected data classes.
- [ ] Document delete and factory reset verified for full cleanup behavior.
- [ ] `Vittora/PrivacyInfo.xcprivacy` reviewed and updated as needed.
- [ ] `Docs/Compliance/Privacy_Compliance_Checklist.md` reviewed.

## 3) Data/sync gates

- [ ] CloudKit entitlement values align with bundle identity and target environment.
- [ ] Sync conflict UI only flags actionable events for review.
- [ ] Integrity validator behavior reviewed for large datasets.
- [ ] Migration scaffolding (`VittoraMigrationPlan`) remains valid after schema changes.

## 4) Tax correctness gates

- [ ] Tax regression suites green (`make test-tax`).
- [ ] US preferential gain stacking vectors validated.
- [ ] Export assumptions/warnings/disclaimer outputs reviewed after tax changes.

## 5) Legal/configuration gates

- [ ] `Vittora/Info.plist` usage descriptions are accurate and user-readable.
- [ ] `Vittora/Vittora.entitlements` matches intended iCloud/notification setup.
- [ ] In-app legal docs (`Vittora/Resources/Legal/`) reviewed.

## 6) Final smoke checks

- [ ] App launches and navigates core tabs on iOS and macOS.
- [ ] Add/edit/delete flows work for accounts, transactions, and documents.
- [ ] No obvious placeholder/debug UI left in production paths.
