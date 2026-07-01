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

- **Epic K (PRs #17–#20, 2026-06-30):** CSV import; smart categorization; savings auto-allocation + US contribution headroom; **K8** quick entry (global fast-add), edit audit trail (UserDefaults, 20/txn cap, post-commit side effects), saved filter presets, batch receipt scan (partial success). **Non-blocking follow-ups:** K5 import atomicity/`($50)` edges; K6 payee-history full-table fetch; K7 SECURE 2.0 60–63 + HSA 55+ + 2026 limits; K8 SwiftData edit-history migration; K3 CKShare viral loop; J2 Core extraction finish.
- **Epic J (PR #12):** sidebarAdaptable tabs, NavigationSplitView list/detail, macOS Settings scene, SceneStorage/Handoff, keyboard shortcuts, context menus; `VittoraCore` SPM (108 files — partial J2; see `Packages/VittoraCore/README.md` J2 follow-up).
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
