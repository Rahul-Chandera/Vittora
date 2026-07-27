# Vittora Release Checklist

Use this checklist before TestFlight/App Store submission.

## 1) Build/compile gates

- [ ] `make build-ios` succeeds.
- [ ] `make build-macos` succeeds.
- [ ] `make test` succeeds (or approved targeted waiver).
- [ ] GitHub Actions **CI / build-and-test** green on the release branch (see `.github/BRANCH_PROTECTION.md`).

## 2) Security and privacy gates

- [ ] App lock flow verified on cold launch and foreground transitions.
- [ ] Keychain + encryption paths verified for expected data classes.
- [ ] **Secure Enclave (physical device only — CI/simulator uses legacy test path):**
  - [ ] Fresh install on a biometric-capable device: enable app lock, encrypt a document, force-quit, relaunch — data decrypts after unlock.
  - [ ] Legacy→SE upgrade: install a build that wrote `com.vittora.encryption.key`, upgrade to current — existing ciphertext still decrypts; legacy key removed and `com.vittora.encryption.key.se_wrapped` present.
  - [ ] Record device model + OS version in the internal release log.
- [ ] Document delete and factory reset verified for full cleanup behavior.
- [ ] `Vittora/PrivacyInfo.xcprivacy` reviewed and updated as needed.
- [ ] Required-reason APIs in the privacy manifest match actual SDK usage (`grep` UserDefaults / file timestamps / other APIs).
- [ ] Unused capabilities removed (no push entitlement if only local notifications; background modes match BGAppRefresh only).
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

- [ ] `Vittora/Info.plist` usage descriptions are accurate and user-readable (no over-declared photo-library string unless direct PHPhotoLibrary access is added).
- [ ] `Vittora/Vittora.entitlements` (iOS/iPadOS) and `Vittora/Vittora-macOS.entitlements` match intended iCloud + sandbox setup.
- [ ] `ITSAppUsesNonExemptEncryption=false` is intentional: financial/document data uses Apple-provided encryption (Keychain, Secure Enclave, AES-GCM via CryptoKit) only — standard exempt encryption, no custom proprietary crypto.
- [ ] In-app legal docs (`Vittora/Resources/Legal/`) reviewed.
- [ ] App Store metadata (`Vittora/Resources/AppStoreMetadata/`) matches shipped platform and feature scope.
- [ ] Monetization: v1 launches free (DEC-008); no StoreKit/IAP until post-PMF fast-follow. Conversion milestones instrumented locally (F5).

## 6) Bundle/distribution gates (run against the actual archive)

Two 1.4.0 release blockers came from the Watch target being added in 1.2
without full distribution wiring — no version bump, then no app icon.
**Neither is detectable by CI, `make test`, or the simulator.** Only building a
Release archive and inspecting the embedded bundles finds them, so do that
before every upload:

```bash
xcodebuild archive -scheme Vittora -destination 'generic/platform=iOS' \
  -configuration Release -archivePath /tmp/Vittora.xcarchive -allowProvisioningUpdates

A=/tmp/Vittora.xcarchive/Products/Applications/Vittora.app
find "$A" -name Info.plist -not -path "*/Frameworks/*" | while read p; do
  id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$p" 2>/dev/null) || continue
  sv=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$p" 2>/dev/null)
  bv=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$p" 2>/dev/null)
  [ -n "$id" ] && printf "%-52s %s (%s)\n" "$id" "$sv" "$bv"
done | sort -u
```

- [ ] **Every embedded bundle reports the same version and build.** Apple rejects
      an upload whose embedded WatchKit app version differs from the containing
      app. Bumping versions with a literal `sed` on the main app's value silently
      misses the Watch bundles — match on the setting name, not the value.
- [ ] **Every app/extension bundle has an app icon.** Check `Assets.car` exists in
      each, and that `CFBundleIconName` resolves. For watchOS, `actool` only
      writes the nested `CFBundleIcons.CFBundlePrimaryIcon` key, so the Watch
      target also needs an explicit top-level `CFBundleIconName` in its
      `Info.plist`.
- [ ] **When a new target is added in any release**, confirm before its first
      submission: version/build wired to the shared bump, app icon asset catalog
      plus `ASSETCATALOG_COMPILER_APPICON_NAME`, entitlements, and privacy
      manifest. A target can build, test, and run in the simulator for several
      releases while remaining unshippable.

## 7) Final smoke checks

- [ ] App launches and navigates core tabs on iOS and macOS.
- [ ] Add/edit/delete flows work for accounts, transactions, and documents.
- [ ] Local notification permission + reminder toggles verified on a device.
- [ ] No obvious placeholder/debug UI left in production paths.
