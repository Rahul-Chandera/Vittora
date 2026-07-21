# Privacy & Compliance Checklist

Use before App Store / Mac App Store submission.

## Privacy manifest (`Vittora/PrivacyInfo.xcprivacy`)

- [ ] `NSPrivacyAccessedAPITypes` lists every required-reason API the app uses.
- [ ] UserDefaults declared with reason `CA92.1` (app functionality / user preferences).
- [ ] No tracking domains; collected-data types match App Store Connect privacy labels.

## Capabilities audit

- [ ] No unused push capability (`aps-environment`, `remote-notification` background mode).
- [ ] Background modes match shipped behavior (`fetch` only for BGAppRefresh recurring generation).
- [ ] macOS entitlements include App Sandbox + only the permissions the app uses (camera, contacts, photos, network client, CloudKit).
- [ ] Info.plist usage strings match real permission prompts (no over-declared keys).

## Encryption export

- [ ] `ITSAppUsesNonExemptEncryption=false` documented in `Docs/Runbooks/RELEASE_CHECKLIST.md`.
- [ ] Rationale: user data encrypted with Apple OS/crypto APIs only (Keychain, Secure Enclave, AES-GCM) — exempt standard encryption.

## Platform scope

- [ ] Build targets match QA'd platforms (iOS, iPadOS, macOS only — no visionOS until explicitly scoped).

## On-device Search (Spotlight)

- [ ] Transaction Spotlight indexing is on-device only (default Core Spotlight).
- [ ] Settings → Search Privacy → "Show transactions in Search" defaults ON; OFF clears the index.
- [ ] Delete All Data / factory reset clears the Spotlight domain so financial amounts do not outlive the ledger.

## Metadata

- [ ] App Store copy in `Vittora/Resources/AppStoreMetadata/` describes shipped features only (no Watch, Widgets, Siri, or visionOS claims), states **iOS 26+ / macOS 26+** device requirements (DEC-009 / M0), and uses per-market listing treatments for en-IN vs en-US (DEC-010 / M1 #5).
