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

## 7b) Build number — bump it every release, on every target

`CURRENT_PROJECT_VERSION` must be **higher than the last build uploaded for
that platform**, and iOS and Mac keep **separate** upload histories under the
same version string. That asymmetry is what catches people: 1.7.0 was accepted
on iOS at build 1 and rejected on Mac, because the last Mac upload was build 9.

- [ ] Bump `CURRENT_PROJECT_VERSION` at release time, ahead of the highest build
      already uploaded on **either** platform. Do not restart at 1 for a new
      version string — the Mac history does not reset with it.
- [ ] Bump it on **all 12 build configurations**, not just the app. Verify with:

```
grep -o "CURRENT_PROJECT_VERSION = [0-9]*;" Vittora.xcodeproj/project.pbxproj | sort | uniq -c
```

  One line, count 12. Xcode's target editor changes only the target in front of
  you, which is how 1.7.0 ended up with the app at 10 and the Watch app, Watch
  widgets and iOS widgets still at 1. An upload validates every embedded target,
  so a mismatch fails there — the same late-failing class as the Watch
  `MARKETING_VERSION` drift that only a real upload caught in 1.4.0.

## 8) Branch flow, and the step everyone forgets

Releases go **`develop` → `main`**. There is no QA branch.

`staging` was dropped on 2026-09-15 by owner decision, to cut a step out of the
merge cycle, and the branch was deleted. It had been a persistent source of
friction rather than of QA: 1.4.0 and 1.5.0 were both cut `release/x.y.z` →
`main` and skipped it anyway, after which staging sat on a 1.3-era snapshot from
18 July until someone reconciled it. QA now happens on `develop` before the
release PR is opened.

- [ ] QA `develop` — this is the last gate before `main`.
- [ ] Open the release PR from **`develop`** → `main`. Hold it for owner approval.
- [ ] **After the release merges, back-merge `main` into `develop`.**

That last step is the one that bites. `main` accumulates release-line commits —
version bumps, and hotfixes like the 1.4.0 Watch-icon fix (`6a7fec9d`) — that
never return to `develop`. Skip it and the *next* release PR conflicts in
`Vittora.xcodeproj/project.pbxproj` on `MARKETING_VERSION`, which is exactly what
happened to 1.5.0. Resolving it on the release branch does not help the release
after that; only the back-merge does.

The BEHIND trap still applies, now between `develop` and `main`: under "require
branches to be up to date" a release PR reads BEHIND until `main`'s release-line
commits are back in `develop`, which is the same back-merge named above. Doing
it right after each release is what keeps the next PR mergeable.
