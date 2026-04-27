# Vittora Agent Memory

This file captures stable context to speed up future AI-agent tasks.

## Canonical Paths

- App source: `Vittora/`
- Unit/integration tests: `VittoraTests/`
- UI tests: `VittoraUITests/`
- Project file: `Vittora.xcodeproj`
- Workspace guidance: `AGENTS.md`

## Key Architecture Notes

- SwiftUI app using `@Observable` state models and environment injection.
- Data layer uses SwiftData models/repositories with CloudKit sync integration.
- Domain logic is use-case driven (tax, recurring, sync, documents, etc.).
- Security-sensitive flows include app lock, keychain, encryption, and audit logs.

## High-Risk Areas (test after changes)

- US/India tax calculators and tax profile persistence.
- Delete and reset workflows (`DeleteTransactionUseCase`, document delete cascade, factory reset).
- App lock lifecycle (`VittoraApp`, `ContentView`, security settings).
- Sync conflict handling and integrity validation.

## Current Command Shortcuts

- iOS compile: `make build-ios`
- macOS compile: `make build-macos`
- Full tests: `make test`
- Focused suites:
  - `make test-tax`
  - `make test-sync`
  - `make test-data`
  - `make test-recurring`

## Recent Hardening (already landed)

- Tax profile save path preserves advanced fields on first save.
- Tax form save keeps full loaded profile context.
- Transaction delete cascades linked documents.
- Data reset/factory reset expanded and keychain cleanup hardened.
- App lock gating enforced on launch/activation.
- Versioned SwiftData migration scaffolding in place.
- Settings VM ownership unified via environment instance.
- Sync review badges only for actionable conflicts.
- Document stats use count path (no thumbnail hydration).
- Recurring generation idempotency/rollback hardened.
- Entitlements aligned to CloudKit container identifier.
- Sync integrity validator capped to recent records for scalability.
- PDF preview parsing cache added.
- Dead `Router` abstraction removed.
- Privacy manifest and compliance checklist added.
