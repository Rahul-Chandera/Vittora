# Vittora — Feature Status

Completed and pending features, measured against `Docs/Vittora_Final_Plan.md`.

**As of 2026-09-19.** Last shipped release: **1.7.0** (live on the App Store).
**1.7.1 is not versioned yet** — `MARKETING_VERSION` is still `1.7.0` and no `v1.7.1` tag exists. Its work is merged on `develop` and needs a version bump before submission.

## How this was compiled

Each line was checked against the source tree, not recalled. Where a feature is marked complete, an implementation exists under `Vittora/`, `VittoraWatch/`, `VittoraWidgets/` or `Packages/VittoraCore/`. Where it is marked pending, no implementation was found. Two caveats worth stating up front:

- **Present in code ≠ verified on device.** Several areas are covered only by unit tests; see *Known verification gaps* at the end.
- Plan module IDs (`M1.2.7` etc.) are carried through so this can be read beside the plan.

---

## Release history

| Version | Status |
|---|---|
| 1.4.0 – 1.6.0 | Shipped |
| **1.7.0** | **Shipped — current App Store release** |
| 1.7.1 | Merged on `develop`, **not yet versioned or tagged** |

### What 1.7.1 contains

A bug-fix and hardening release. No new user-facing features beyond two paywall additions.

- **Paywall rebuilt** as a custom StoreKit 2 screen (option C), replacing `SubscriptionStoreView`. Fixes plan cards being below the fold on iPhone/iPad/Mac, the "Accept Offer" CTA label, the macOS footer drawing over the plan cards, and the iPad overlap recorded as DEC-026. Lifetime is now a third selectable plan rather than a competing button.
- **Family Sharing is stated on the paywall** (HIG requirement; Annual and Lifetime are Family Shareable per DEC-013).
- **The store is hidden when `AppStore.canMakePayments` is false** — Screen Time restrictions and managed devices previously saw a paywall that failed opaquely on tap.
- **Entitlement copy is accurate per source** — a family member is no longer told to cancel a plan they do not own, and Lifetime owners are no longer told to manage a renewal.
- **Intro-offer eligibility** is resolved explicitly and defaults to "no trial" on every failure path (Guideline 3.1.2 exposure).
- **iOS 27 audit** — the app builds clean on the iOS 27 SDK with the floor held at iOS 26. See *iOS 27* below.
- **Build and CI** — Xcode 27 compatibility, a pre-commit hook blocking Xcode's `Info.plist`/`pbxproj`/Watch-catalogue churn, the accessibility audits split onto their own CI leg, an audit sampling race fixed, and 16 of 23 Xcode warnings cleared.
- **The StoreKit scheme path was broken** and is fixed — it pointed at `../../../Vittora.storekit`, which Xcode resolves against the project directory, so running from Xcode silently used the real sandbox instead of the local configuration.

---

## Phase 1 — MVP: Core Ledger & Sync — **complete**

| Module | Status | Notes |
|---|---|---|
| 1.1 Accounts & Ledger | ✅ | Multi-account, transfers, per-account balances, credit-card due reminders |
| 1.2 Transaction Management | ⚠️ **2 gaps** | See below |
| 1.3 Categories | ⚠️ **1 gap** | Presets, custom, category budgets present; **sub-categories (M1.3.4) not implemented** |
| 1.4 Recurring Transactions | ✅ | Frequencies, auto-generation, pre-notification, rule management, subscription tracking |
| 1.5 Payees / Parties | ✅ | Directory, linking, Contacts import, per-payee analytics, autofill |
| 1.6 Documents & OCR | ⚠️ **1 gap** | VisionKit scanning, extraction, correction, batch scan, preview all present; **multi-page scanning (M1.6.6) not implemented** |
| 1.7 Dashboards & Reports | ⚠️ **1 gap** | Dashboard, monthly overview, category breakdown, trends, balance summary, custom ranges present; **net worth tracked over time (M1.7.7) is a point-in-time figure only** |
| 1.8 Data Sync & Backup | ✅ | CloudKit sync, offline-first, conflict resolution, sync status, CSV export, encryption |
| 1.9 Security & Privacy | ✅ | App lock, AES-GCM attachment encryption, Keychain, no third-party analytics |
| 1.10 Budgets | ⚠️ **1 gap** | Per-category and overall budgets, progress, alerts, rollover present; **budget templates (M1.10.6) not implemented** |

**Phase 1 gaps**

| ID | Feature | Status |
|---|---|---|
| M1.2.10 | Saved views / filters | ❌ Not implemented |
| M1.3.4 | Sub-categories (one level of nesting) | ❌ Not implemented |
| M1.6.6 | Multi-page scanning | ❌ Not implemented |
| M1.7.7 | Net worth **over time** | ⚠️ Partial — current net worth exists, no history |
| M1.10.6 | Budget templates (copy from previous month) | ❌ Not implemented |

---

## Phase 2 — V1: Subscription-Worthy — **largely complete**

| Module | Status | Notes |
|---|---|---|
| 2.1 Expense Splitting | ✅ | Groups, split methods, simplify-debts, running balances, settlement, share links, group reports |
| 2.2 Debt & Credit Ledger | ✅ | Lending/borrowing, per-party balances, settlement history, aging, due dates, reminders |
| 2.3 Tax Planning (India + US) | ✅ | India: regime comparison, 80C/80D/80CCD(1B), HRA, standard deduction, liability, progress. US: federal brackets, standard vs itemized, 401(k)/IRA, HSA, state-tax note |
| 2.4 Smart Investment Planning | ❌ **Not implemented** | Entire module pending |
| 2.5 Savings Goals | ⚠️ **1 gap** | Goals, account linking, progress, auto-allocation present; **sinking funds (M2.5.5) not implemented** |
| 2.6 Apple Watch App | ⚠️ **2 gaps** | Quick entry, complications, Smart Stack, recents present; **voice entry (M2.6.2) and haptic budget alerts (M2.6.6) not implemented** |
| 2.7 Widgets & System Integration | ⚠️ **1 gap** | Home/Lock Screen widgets, StandBy, Siri Shortcuts, Spotlight, Handoff present; **interactive widgets (M2.7.5) not implemented** |
| 2.8 Advanced Reports & Export | ✅ | PDF reports, CSV export, CSV import, annual summaries, cash-flow forecast, custom report builder, subscription audit |

**Phase 2 gaps**

| ID | Feature | Status |
|---|---|---|
| M2.4.1–M2.4.5 | Smart Investment Planning (80C recommendations, optimal allocation, retirement optimisation, "tax saved" calculator, maturity timeline) | ❌ Whole module pending |
| M2.5.5 | Sinking funds | ❌ Not implemented |
| M2.6.2 | Watch voice entry ("Add 500 for groceries") | ❌ Not implemented |
| M2.6.6 | Watch haptic budget alerts | ❌ Not implemented |
| M2.7.5 | Interactive widgets (add transaction from widget) | ❌ Not implemented |

---

## Phase 3 — V2: Deepen the Moat — **partially started**

| Module | Status | Notes |
|---|---|---|
| 3.1 Vision Pro App | ❌ | No visionOS target |
| 3.2 Advanced ML & Intelligence | ⚠️ **mostly pending** | Rule-based categorisation exists (`CategorizationRule`); no Core ML classifier, predictions, anomaly detection, health score, what-if, Apple Intelligence or predictive entry |
| 3.3 Live Activities & Dynamic Island | ❌ | No ActivityKit usage |
| 3.4 Family / Household Sharing | ⚠️ **partial** | `CKShare` used for split-group sharing; **shared household budgets, permission levels not implemented.** StoreKit Family Sharing (M3.4.4) ✅ done |
| 3.5 Tax Expansion (UK/CA/AU) | ❌ | India and US only |
| 3.6 Financial Guidelines | ⚠️ **partial** | 50/30/20 ✅, emergency fund ✅, India compliance tips ✅; **anomaly alerts (M3.6.4) and budget optimisation (M3.6.5) pending** |
| 3.7 Additional Enhancements | ⚠️ **partial** | See below |

**Module 3.7 detail**

| ID | Feature | Status |
|---|---|---|
| M3.7.1 | FinanceKit (Apple Card/Cash import) | ❌ Not implemented |
| M3.7.2 | Multi-language | ✅ **Exceeds plan** — English, Hindi **and Spanish** (1,622 keys, fully translated) |
| M3.7.3 | Custom themes | ✅ Light, dark, system, OLED black |
| M3.7.4 | Data import | ✅ CSV import |
| M3.7.5 | Year-in-Review | ✅ Implemented |
| M3.7.6 | Accessibility | ✅ VoiceOver, Dynamic Type, contrast-safe charts, audited in CI |
| M3.7.7 | Notification customization | ✅ Implemented |

---

## iOS 27 (assessed for 1.7.1)

Deployment target stays **iOS 26.0**; no iOS 27 API is used and no availability branch was needed.

| Item | Outcome |
|---|---|
| TabView crash on hidden selection | Already safe — clamp existed, now pinned by tests |
| Control env values reset in sheets | Not affected — all uses are leaf-applied |
| Text selection gestures | Verified by running it; no custom Text gestures exist |
| Menu symbol images hidden | No change needed — every menu item is an action |
| `.roundedBorder` soft-deprecated | Left as-is; `.bordered` is iOS 27+ and emits no diagnostic |
| `swipeActions(onPresentationChanged:)` | **Not adopted** — DEC-028; the defect it would fix was already fixed by moving to `.alert` |
| `SKTestSession` purchase coverage | **Still not viable** — `xcodebuild` ignores the scheme's StoreKit configuration |

---

## Deferred (post-V2, per plan §12)

Explicitly out of scope and unchanged: bank aggregation / open banking, brokerage integrations, payment rails, chat or social layer, marketplace lending, Android or web parity, PDF invoice parsing, enterprise tier, affiliate partnerships, bill payment.

---

## Known verification gaps

These are not missing features — they are things the test suite cannot prove, and they matter before any submission.

1. **The intro-offer *consumed* path is not covered.** The *eligible* direction now is: `IntroOfferEligibilityTests` builds an `SKTestSession` from `Vittora.storekit` and asserts `PurchaseService` resolves `isEligibleForIntroOffer == true`. The opposite direction — an account that has already used the trial — cannot be asserted in-suite, because a process that has already queried StoreKit never sees the purchase. Production defaults to `false` on every failure path, so this is the direction the code already leans towards. Details in `Docs/Testing/TEST_MATRIX.md`.
2. **Purchase, restore and Family Sharing inheritance are device-only.** `SKTestSession` serves products, but a purchase made through it never reaches `Transaction.currentEntitlements` in the same process. Recorded in `Docs/Testing/TEST_MATRIX.md`.
3. **The accessibility audit leg is still intermittent.** A real cause was found and fixed in 1.7.1 — the audit sampled pixels before scrolling settled — and it bought three consecutive green-first-time runs (#243, #244, #245). It did not close the problem: #246 failed first time on `testNewReportsAccessibilityAudit` with "Contrast failed", the same test and the same symptom. The settle wait narrowed the window rather than eliminating it.
4. **1.7.1 is versioned but not tagged.** `MARKETING_VERSION` is `1.7.1`, `CURRENT_PROJECT_VERSION` is `11`; no `v1.7.1` tag exists yet.

---

## Suggested next scope

Ordered by user value against effort, not by plan order.

1. **M2.4 Smart Investment Planning** — the only whole module missing from Phase 2, and it sits directly on the tax engine that already exists. The largest single gap in the paid proposition.
2. **M1.3.4 sub-categories** and **M1.2.10 saved views** — small Phase 1 gaps that users of a mature ledger notice.
3. **M2.7.5 interactive widgets** — App Intents infrastructure already exists (`AddExpenseIntent`), so this is mostly surface.
4. **M3.6.4/M3.6.5 anomaly alerts and budget optimisation** — rules-based versions need no ML and complete Module 3.6.
5. **M1.7.7 net worth over time** — the data is already recorded; this is history plus a chart.
