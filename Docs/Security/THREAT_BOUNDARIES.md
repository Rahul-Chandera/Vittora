# Vittora Threat Boundaries

This document defines practical security boundaries for engineering and AI-agent changes.

## Sensitive Data Classes

- Financial records (transactions, balances, debts, savings goals, tax profiles)
- Tax inputs and derived estimates
- Attached document payloads and thumbnails
- Security state and key material (keychain and encryption keys)

## Trust Boundaries

- Device local boundary:
  - SwiftData store + keychain + encrypted document files
- Cloud boundary:
  - CloudKit sync only
- Application boundary:
  - UI/state transitions must not expose private data while locked

## Allowed External Surface

- CloudKit/iCloud services only (project policy)
- No default external analytics/telemetry SDKs
- No third-party document processing APIs

## Security Controls in Place

- App lock service with biometric/passcode fallback and cooldown behavior
- Keychain-backed secure settings and key material
- Encrypted document storage flow
- Security audit logging events
- Privacy shield behavior on app lifecycle transitions

## Engineering Guardrails

- Never log raw sensitive values in production logs.
- Preserve lock gating on launch and on foreground activation when enabled.
- Keep reset/delete paths truthful and comprehensive.
- Ensure conflict/integrity surfaces do not silently hide actionable data quality issues.
- Treat tax calculations as correctness-sensitive and test-backed changes only.

## Validation Expectations

- Security-related changes require targeted tests plus platform compile checks.
- Release preparation requires privacy manifest and entitlement review.
