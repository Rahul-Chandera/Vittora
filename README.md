# Vittora

Vittora is a privacy-first, offline-first personal finance app for Apple platforms.

- Platforms: iOS, iPadOS, macOS
- Language: Swift 6
- UI: SwiftUI + `@Observable`
- Persistence: SwiftData
- Sync: CloudKit (Apple-only, no third-party backend)

## Highlights

- Account, transaction, budget, debt, savings, split, and payee management
- Tax estimation for India and US workflows
- Encrypted document and receipt handling
- App lock, biometric support, and security audit logging
- Offline-first local workflows with CloudKit sync status/conflict surfaces

## Tech Stack

- SwiftUI
- SwiftData + CloudKit integration
- Security + CryptoKit + LocalAuthentication
- OSLog
- Swift Testing (`@Suite`, `@Test`, `#expect`)

No third-party SDKs are required for core app behavior.

## Repository Layout

- `Vittora/` - app source, features, core services, design system, resources
- `VittoraTests/` - unit/integration tests
- `VittoraUITests/` - UI test target
- `Docs/` - project documentation and compliance artifacts
- `Vittora.xcodeproj/` - Xcode project

## Requirements

- Xcode 26+
- macOS with current Apple SDK support

## Build

### iOS compile

```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build-ios \
  build CODE_SIGNING_ALLOWED=NO
```

### macOS compile

```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build-macos \
  build CODE_SIGNING_ALLOWED=NO
```

### Run full tests

```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test
```

### Run a targeted suite

```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  -only-testing:VittoraTests/USTaxCalculatorTests \
  test
```

## Security and Privacy Notes

- App lock and biometric gating for sensitive flows
- Keychain-backed secure settings/secrets
- Encrypted document storage path
- Privacy manifest baseline: `Vittora/PrivacyInfo.xcprivacy`
- Compliance checklist: `Docs/Compliance/Privacy_Compliance_Checklist.md`

## Additional Project Docs

- Architecture/development guide: `AGENTS.md`
- Recurring feature notes: `Vittora/Features/Recurring/RECURRING_README.md`
- Budget feature docs: `Vittora/Features/Budgets/README.md`
