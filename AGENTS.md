# Vittora Agent Guide

This file is the primary in-repo guidance for AI agents and contributors.

## Project Snapshot

- App name: Vittora
- Bundle ID: `com.enerjiktech.vittora`
- Platforms: iOS/iPadOS/macOS
- Language: Swift 6
- UI: SwiftUI + `@Observable`
- Data: SwiftData + CloudKit
- Tests: Swift Testing (`@Suite`, `@Test`, `#expect`)

## Correct Repository Layout

- App source: `Vittora/`
- Unit/integration tests: `VittoraTests/`
- UI tests: `VittoraUITests/`
- Docs: `Docs/`
- Project: `Vittora.xcodeproj`

## Core Development Rules

1. Keep user-facing strings localized via `String(localized:)`.
2. Avoid force unwraps in production code.
3. Prefer `async/await` and Sendable-safe patterns.
4. Keep dependency injection via environment/initializers; avoid ad hoc global state.
5. Do not add third-party SDKs/services without explicit approval.
6. Treat finance, tax, security, sync, and deletion flows as high-risk: add/update tests.
7. Preserve offline-first behavior; local workflows must not depend on network presence.
8. Never build a `Decimal` money value from a float literal. `Decimal(15.49)` and a bare
   `15.49` in a `Decimal` context both round-trip through `Double` and are imprecise, so
   exact equality fails even when the printed values match — and whether an expression like
   `15.49 * 12` folds as `Double` or as `Decimal` differs between local Xcode and CI, so it
   can pass locally and fail on CI. Use `Decimal(string: "15.49")!` (or integer literals,
   which are exact) in production, tests, and fixtures. Do not paper over a mismatch with an
   epsilon/tolerance comparison: exact equality is the correct assertion for money — the
   inputs are what must be built precisely.

## High-Risk Modules (extra caution)

- Tax logic: `Vittora/Core/Infrastructure/Tax/`
- Sync/conflicts/integrity: `Vittora/Core/Sync/`
- Security + app lock + keychain: `Vittora/Core/Security/`, `Vittora/ContentView.swift`, `Vittora/VittoraApp.swift`
- Data deletion/reset/document storage: `Vittora/Core/Data/Persistence/`, `Vittora/Core/Data/Repositories/`

## Recommended Command Surface

Use `Makefile` targets for consistency:

- `make build-ios`
- `make build-macos`
- `make test`
- `make test-tax`
- `make test-sync`
- `make test-data`
- `make test-recurring`

## CI (Epic L1)

GitHub Actions workflow **CI / build-and-test** runs on push/PR to `develop`, `staging`, and `main` (flow: develop → staging for QA → main for release):

- `make build-ios`, `make build-macos`, `make test` (unit + UI on iOS Simulator; see `.github/BRANCH_PROTECTION.md`)
- Uploads `.build-ci/*.xcresult` artifacts; US locale pinned on the runner

See `.github/BRANCH_PROTECTION.md` to require the check before merging.

## Additional Agent Docs

- System map: `Docs/Architecture/SYSTEM_MAP.md`
- Decision log: `Docs/Architecture/DECISION_LOG.md`
- Test matrix: `Docs/Testing/TEST_MATRIX.md`
- Release checklist: `Docs/Runbooks/RELEASE_CHECKLIST.md`
- Schema map: `Docs/Data/SCHEMA_MAP.md`
- Security boundaries: `Docs/Security/THREAT_BOUNDARIES.md`
- Tax rule coverage: `Docs/Tax/RULE_COVERAGE.md`
- Durable context memory: `Docs/Agent/AGENT_MEMORY.md`

## Commit Style

- Use conventional commit format: `type(scope): summary`
- Keep commits focused and atomic
- Prefer separate commits for independent risk areas

