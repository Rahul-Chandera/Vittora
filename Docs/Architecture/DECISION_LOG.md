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

## DEC-008: Launch free; defer StoreKit to post-PMF fast-follow (F0)

- Status: Accepted (2026-06-28)
- Decision: First public release ships **without IAP**. iCloud sync remains a **free baseline** for all users. Instrument conversion milestones on-device (F5) to learn willingness-to-pay before building a single paid tier.
- Why: Monetization is not on the beta critical path; pre-PMF learning outweighs launch revenue; avoids subscription App Store review risk at v1; aligns with privacy-first positioning.
- Trial strategy (when monetizing): 7-day intro free trial on annual (payment on file) + value-event paywall; reject 15-day unrestricted trial (unenforceable offline, abuse-prone).
- Paid value (fast-follow): tax planning, unlimited OCR, advanced reports/PDF. Do not gate sync. No Watch/Widget/Siri marketing until shipped.
- Build impact: F5 conversion tracker + sync-free documentation now; defer F1–F4 StoreKit/paywall/gating; minimal F6 (no subscription clauses until IAP ships).
- Revisit: after retention/PMF data from conversion milestones.

## DEC-009: Keep iOS 26 / macOS 26 deployment floor (M0)

- Status: Accepted (2026-07-02, Rahul)
- Decision: **Option A** — maintain **iOS 26.0 / macOS 26.0** as the minimum supported OS for v1. No N1 back-deployment epic.
- Why: Forward-looking platform bet for Liquid Glass UI and planned OCR/AI features on 26-only frameworks (Foundation Models, latest Vision); single modern design/runtime target.
- Brief: `Docs/Audit/M0_DEPLOYMENT_TARGET_DECISION_BRIEF.md` (§6 decision record)
- Build impact: D5 metadata states device/OS requirements plainly (M0 follow-on **(e)**); no `#available` back-deployment work pre-launch.
- Roadmap: Epic N — adopt 26-only capabilities post-launch (Liquid Glass UI pass, FoundationModels categorization upgrade, latest-Vision OCR); AI features = progressive enhancement with hardware gates beyond the OS floor.
- Revisit: Wave-1 TAM math must use iOS-26-capable devices; verify App Store Connect device/OS data before public launch.

## DEC-010: Wave-1 parallel US + India with de-risk conditions (M1)

- Status: Accepted (2026-07-02, Rahul; board dissent recorded)
- Decision: **Option C — parallel US + India Wave-1** — one global binary; asymmetric GTM (active India recommended, passive US listing + ASO).
- Why: Test PMF in both markets under F0 (launch-free); India tax engine market-complete; US federal engine supports a supporting (not headline) tax feature with honest labeling.
- Brief: `Docs/Audit/M1_WAVE1_MARKET_DECISION_BRIEF.md` (§6 decision record + board-required de-risk conditions)
- De-risk conditions (binding, match brief §6 exactly):
  1. **US tax honesty before launch** — explicit *"Federal estimate — state taxes not included"* in tax UI + US store listing; do not lead US positioning with tax until state coverage exists; simplified state-tax table engine as fast-follow backlog (slab-engine pattern).
  2. **Asymmetric parallel** — concentrate active GTM on one market (India recommended); other runs passive (listing + ASO only).
  3. **Per-market KPIs from day one** — activation, D30, tax-estimate usage, splitting invites measured separately (never blended).
  4. **60–90-day concentration checkpoint** — if one market clearly outperforms, formally shift to concentrated GTM there.
  5. **D5 ×2** — two store-listing treatments (en-IN: INR/regime language vs en-US: USD/privacy-vs-Plaid language); both scoped to shipped features; device/OS requirements stated (M0).
- Build impact: `USTaxFederalEstimateLabel` on US tax results surfaces (M2-T1); D5 localized metadata ×2 follow-on.
- Revisit: checkpoint outcome (~60–90 days post-public launch); US state-tax engine before tax-led US positioning.
