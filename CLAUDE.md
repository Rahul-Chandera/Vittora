# Vittora Contributor Guide

This file mirrors `AGENTS.md` for compatibility with tools that look for `CLAUDE.md`.
Use `AGENTS.md` as the canonical version.

## Project Snapshot

- App source: `Vittora/`
- Tests: `VittoraTests/` and `VittoraUITests/`
- Project: `Vittora.xcodeproj`
- Platforms: iOS/iPadOS/macOS
- Stack: SwiftUI + SwiftData + CloudKit

## Core Rules

- Localize all user-facing text with `String(localized:)`.
- Do not use force unwraps in production code.
- Keep third-party dependencies out unless explicitly requested.
- Preserve offline-first behavior and secure handling of financial data.
- Never build a `Decimal` money value from a float literal (`15.49`); use
  `Decimal(string: "15.49")!` or integer literals. Float literals go via `Double`,
  break exact equality, and fold differently on CI than locally.
- Add targeted tests for tax/sync/security/deletion changes.
- To make a failing check pass, change only the code under test — never the assertion,
  the audit config, or the fixture so the offending input stops being produced.

## Fast Command Surface

- `make build-ios`
- `make build-macos`
- `make test`
- `make test-tax`
- `make test-sync`
- `make test-data`
- `make test-recurring`

## Xcode Churn Guard

Xcode rewrites three tracked files on almost every build: it strips the four
required keys out of `Vittora/Info.plist` and duplicates them into
`INFOPLIST_KEY_*` build settings in `project.pbxproj`, and it regenerates
`VittoraWatch/Localizable.xcstrings` instead of `Scripts/ci/sync-watch-strings.py`.
The Info.plist one is an App Store rejection that no build or test catches.

A pre-commit hook blocks all three. Install it once per clone:

```
git config core.hooksPath Scripts/hooks
```

`git commit --no-verify` skips it, which is the right answer for a deliberate
change — a genuine new usage description, or normalising catalogue key order.

## CI (Epic L1)

GitHub Actions **CI / build-and-test** on push/PR to `develop` and `main` (flow: develop → main for release). A `build` job (`make build-ios`, `make build-macos`, localization checks), a `build-for-testing` job that compiles the simulator test bundle once, and four `test (…)` jobs (the suites of `make test`, run against that prebuilt bundle) run concurrently; `build-and-test` is the aggregating required check. See `.github/BRANCH_PROTECTION.md`.

## Architecture/Runbook Docs

- `Docs/Architecture/SYSTEM_MAP.md`
- `Docs/Architecture/DECISION_LOG.md`
- `Docs/Testing/TEST_MATRIX.md`
- `Docs/Runbooks/RELEASE_CHECKLIST.md`
- `Docs/Data/SCHEMA_MAP.md`
- `Docs/Security/THREAT_BOUNDARIES.md`
- `Docs/Tax/RULE_COVERAGE.md`
- `Docs/Agent/AGENT_MEMORY.md`

