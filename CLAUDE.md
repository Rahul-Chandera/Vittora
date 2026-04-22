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
- Add targeted tests for tax/sync/security/deletion changes.

## Fast Command Surface

- `make build-ios`
- `make build-macos`
- `make test`
- `make test-tax`
- `make test-sync`
- `make test-data`
- `make test-recurring`

## Architecture/Runbook Docs

- `Docs/Architecture/SYSTEM_MAP.md`
- `Docs/Architecture/DECISION_LOG.md`
- `Docs/Testing/TEST_MATRIX.md`
- `Docs/Runbooks/RELEASE_CHECKLIST.md`
- `Docs/Data/SCHEMA_MAP.md`
- `Docs/Security/THREAT_BOUNDARIES.md`
- `Docs/Tax/RULE_COVERAGE.md`
- `Docs/Agent/AGENT_MEMORY.md`

