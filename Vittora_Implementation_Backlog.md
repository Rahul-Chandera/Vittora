# Vittora Ordered Implementation Backlog

Derived from Section 13 of `Vittora_Full_Code_Audit_Report.md`, reordered for safe execution dependency flow.

## Phase 1 (Execute Now)

1. **Fix tax profile first-save field loss**
   - Target: `SwiftDataTaxProfileRepository.save` create path.
   - Why first: prevents silent tax input corruption on initial save.
   - Done when: first save round-trips all `TaxProfile` fields.

2. **Preserve advanced tax inputs in form save path**
   - Target: `TaxProfileFormViewModel`.
   - Why second: avoids overwriting fields once persistence path is fixed.
   - Done when: form edits do not wipe advanced inputs, DOB, or metadata context.

3. **Cascade document deletion from transaction deletion**
   - Target: transaction deletion flow + document repository safety.
   - Why third: closes consistency/privacy gap with direct user impact.
   - Done when: deleting a transaction removes linked document metadata + encrypted payload.

4. **Make factory reset behavior truthful and comprehensive**
   - Target: `DataManagementService.factoryReset` and related UI wording.
   - Why fourth: high-trust privacy/compliance requirement.
   - Done when: backend truly clears declared scope and UI copy exactly matches behavior.

5. **Enforce lock-on-open behavior when app lock enabled**
   - Target: app activation/launch lock state path.
   - Why fifth: security-critical user expectation and access control.
   - Done when: app content is gated by unlock whenever lock setting is enabled.

6. **Introduce SwiftData migration scaffolding (pre-launch hardening)**
   - Target: persistence schema strategy and tests.
   - Why sixth: important before first public release, but lower urgency pre-production.
   - Done when: schema versioning/migration path exists with baseline test coverage.

## Phase 2 (After Phase 1)

7. Unify `SettingsViewModel` ownership.
8. Remove production mock fallback wiring.
9. Rework sync conflict review semantics.
10. Improve recurring generation atomicity/idempotency.
11. Reconcile release entitlements/config consistency.

## Phase 3 (Optimization and Maintainability)

12. Optimize document count/statistics path.
13. Optimize sync integrity validation strategy.
14. Cache PDF parsing in preview.
15. Standardize navigation architecture and prune dead routing abstractions.
16. Add privacy manifest and compliance artifacts in-repo.
