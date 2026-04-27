# Vittora Decision Log

Lightweight ADR-style history for major architectural decisions.

## DEC-001: Apple-only dependency policy

- Status: Accepted
- Decision: Keep core app stack to Apple frameworks and first-party services only.
- Why: Privacy and trust requirements for a finance app.
- Impact: No analytics SDKs or external APIs by default; CloudKit is the only sync backend.

## DEC-002: Offline-first with CloudKit sync

- Status: Accepted
- Decision: Local SwiftData is authoritative; CloudKit sync is asynchronous reconciliation.
- Why: App must remain usable with intermittent/no network.
- Impact: Sync status/conflict surfaces exist, but local usage never blocks on network.

## DEC-003: Security-first local data handling

- Status: Accepted
- Decision: Use keychain, biometric/passcode lock, encrypted document storage, and audit logging.
- Why: Sensitive financial and tax records require higher local protections.
- Impact: Security flows and reset/delete behavior must be regression-tested.

## DEC-004: Versioned SwiftData migration scaffolding

- Status: Accepted
- Decision: Use `VersionedSchema` + `SchemaMigrationPlan` baseline before public release.
- Why: Avoid unsafe ad hoc schema evolution after persisted data exists.
- Impact: Schema changes must update migration artifacts and tests.

## DEC-005: Actionable sync review semantics

- Status: Accepted
- Decision: Show review badges only for actionable conflicts (ambiguous/integrity), not informational auto-merges.
- Why: Reduce false-positive warning noise for users.
- Impact: `SyncConflictHandler` separates actionable and informational events.

## DEC-006: Reset/delete must be comprehensive

- Status: Accepted
- Decision: Full reset paths clear documents, metadata, supplemental domains, and relevant keychain keys.
- Why: Finance-app trust requires truthful “delete all data” semantics.
- Impact: Reset and delete paths are high-risk and require broad tests.

## DEC-007: Prefer focused command surface via Makefile

- Status: Accepted
- Decision: Standardize build/test entry points through repo `Makefile`.
- Why: Faster, repeatable local and AI-agent workflows.
- Impact: Agents should prefer `make` targets for compile and targeted test suites.
