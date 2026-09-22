# Vittora — Feature Status

Completed and pending features, measured against `Docs/Vittora_Final_Plan.md`.

**As of 2026-09-22** (re-verified against the source tree; every line below was read from the code, not recalled). Last shipped release: **1.7.1** (live on the App Store).
`MARKETING_VERSION` is `1.7.1`, `CURRENT_PROJECT_VERSION` is `11`, tag `v1.7.1` exists. Site version bump follows Rahul’s deploy.

## How this was compiled

Each line was checked against the source tree, not recalled. Where a feature is marked complete, an implementation exists under `Vittora/`, `VittoraWatch/`, `VittoraWidgets/` or `Packages/VittoraCore/`. Where it is marked pending, no implementation was found. Two caveats worth stating up front:

- **Present in code ≠ verified on device.** Several areas are covered only by unit tests; see *Known verification gaps* at the end.
- Plan module IDs (`M1.2.7` etc.) are carried through so this can be read beside the plan.

---

## Release history

| Version | Status |
|---|---|
| 1.4.0 – 1.6.0 | Shipped |
| 1.7.0 | Shipped |
| **1.7.1** | **Shipped — current App Store release** |

### What 1.7.1 shipped

A bug-fix and hardening release (now live). No new user-facing features beyond two paywall additions.

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
| 1.2 Transaction Management | ✅ | Entry, edit, split, search, bulk actions, saved views/filters |
| 1.3 Categories | ✅ | Presets, custom, category budgets, sub-categories (one level) |
| 1.4 Recurring Transactions | ✅ | Frequencies, auto-generation, pre-notification, rule management, subscription tracking |
| 1.5 Payees / Parties | ✅ | Directory, linking, Contacts import, per-payee analytics, autofill |
| 1.6 Documents & OCR | ⚠️ **1 gap** | VisionKit scanning, extraction, correction, batch scan, preview all present; **multi-page scanning (M1.6.6) not implemented** |
| 1.7 Dashboards & Reports | ✅ | Dashboard, monthly overview, category breakdown, trends, balance summary, custom ranges, net worth history + chart |
| 1.8 Data Sync & Backup | ✅ | CloudKit sync, offline-first, conflict resolution, sync status, CSV export, encryption |
| 1.9 Security & Privacy | ✅ | App lock, AES-GCM attachment encryption, Keychain, no third-party analytics |
| 1.10 Budgets | ✅ | Per-category and overall budgets, progress, alerts, rollover. M1.10.6 is moot here — see below |

**Phase 1 gaps**

| ID | Feature | Status |
|---|---|---|
| M1.2.10 | Saved views / filters | ✅ **Shipped** — `SavedTransactionFilterPreset` + `SavedTransactionFilterStore`, CRUD covered by tests. This entry was stale |
| M1.3.4 | Sub-categories (one level of nesting) | ✅ **Shipped** (#254) — `CategoryHierarchy` holds the nesting rules, the form offers only eligible parents, and the list groups children under parents. The schema half was already in place; this added the surface |
| M1.6.6 | Multi-page scanning | ❌ Not implemented |
| M1.7.7 | Net worth **over time** | ✅ **Shipped** (#256) — `CalculateNetWorthHistoryUseCase` derives the series from transaction history, so no new model and no migration. Totals stay per-currency; accounts whose past balance cannot be derived are excluded and named in the view |
| M1.10.6 | Budget templates (copy from previous month) | **Moot, not pending.** Budgets here never expire: `BudgetEntity` advances its window from `startDate` in whole periods, and `SwiftDataBudgetRepository.fetchActive` notes "Budgets roll forward, so the startDate predicate alone decides active". There is no month boundary to copy a budget across, so the feature the plan describes has nothing to do. Removing it from the backlog rather than building it |

---

## Phase 2 — V1: Subscription-Worthy — **largely complete**

**Module 2.4 shipped after 1.7.1.** It is educational and scenario-based per the plan's scope note: Vittora states what is statutory (lock-in, section, backing, maturity taxation, contribution limits) and the user supplies every return assumption. No return figure is shipped, and a test enforces that.

| Module | Status | Notes |
|---|---|---|
| 2.1 Expense Splitting | ✅ | Groups, split methods, simplify-debts, running balances, settlement, share links, group reports |
| 2.2 Debt & Credit Ledger | ✅ | Lending/borrowing, per-party balances, settlement history, aging, due dates, reminders |
| 2.3 Tax Planning (India + US) | ✅ | India: regime comparison, 80C/80D/80CCD(1B), HRA, standard deduction, liability, progress. US: federal brackets, standard vs itemized, 401(k)/IRA, HSA, state-tax note |
| 2.4 Smart Investment Planning | ✅ | Tax-saved scenarios, 80C instrument comparison and allocation, US 401(k)/HSA contributions, maturity timeline with reminders |
| 2.5 Savings Goals | ⚠️ **1 gap** | Goals, account linking, progress, auto-allocation present; **sinking funds (M2.5.5) not implemented** |
| 2.6 Apple Watch App | ⚠️ **1 gap** | Quick entry, complications, Smart Stack, recents, haptic budget alerts present; **voice entry (M2.6.2) not implemented** |
| 2.7 Widgets & System Integration | ✅ | Home/Lock Screen widgets, StandBy, Siri Shortcuts, Spotlight, Handoff, interactive widgets |
| 2.8 Advanced Reports & Export | ✅ | PDF reports, CSV export, CSV import, annual summaries, cash-flow forecast, custom report builder, subscription audit |

**Phase 2 gaps**

| ID | Feature | Status |
|---|---|---|
| M2.5.5 | Sinking funds | ❌ Not implemented |
| M2.6.2 | Watch voice entry ("Add 500 for groceries") | ❌ Not implemented |
| M2.6.6 | Watch haptic budget alerts | ✅ **Already implemented; this entry was stale.** `VittoraWatch/WatchSnapshotStore.swift` plays a haptic on threshold crossing, covered by `VittoraTests/Core/Watch/WatchBudgetHapticWiringTests.swift`. Nothing was built for it on 2026-09-22 — it was found by reading the source |
| M2.7.5 | Interactive widgets (add transaction from widget) | ✅ **Shipped** (#255) — preset buttons run an App Intent in the widget extension, which queues one UserDefaults key per entry; the host app drains it on next launch |

---

## Phase 3 — V2: Deepen the Moat — **partially started**

| Module | Status | Notes |
|---|---|---|
| 3.1 Vision Pro App | ❌ | No visionOS target |
| 3.2 Advanced ML & Intelligence | ⚠️ **mostly pending** | Rule-based categorisation exists (`CategorizationRule`); no Core ML classifier, predictions, anomaly detection, health score, what-if, Apple Intelligence or predictive entry |
| 3.3 Live Activities & Dynamic Island | ❌ | No ActivityKit usage |
| 3.4 Family / Household Sharing | ⚠️ **partial** | `CKShare` used for split-group sharing; **shared household budgets, permission levels not implemented.** StoreKit Family Sharing (M3.4.4) ✅ done |
| 3.5 Tax Expansion (UK/CA/AU) | ❌ | India and US only |
| 3.6 Financial Guidelines | ✅ | 50/30/20, emergency fund, India compliance tips, spending anomaly alerts (M3.6.4), budget optimisation (M3.6.5) |
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

These are not missing features — they are things the test suite cannot prove, and they still matter for the next submission.

1. **The intro-offer *consumed* path is not covered.** The *eligible* direction now is: `IntroOfferEligibilityTests` builds an `SKTestSession` from `Vittora.storekit` and asserts `PurchaseService` resolves `isEligibleForIntroOffer == true`. The opposite direction — an account that has already used the trial — cannot be asserted in-suite, because a process that has already queried StoreKit never sees the purchase. Production defaults to `false` on every failure path, so this is the direction the code already leans towards. Details in `Docs/Testing/TEST_MATRIX.md`.
2. **Purchase, restore and Family Sharing inheritance are device-only.** `SKTestSession` serves products, but a purchase made through it never reaches `Transaction.currentEntitlements` in the same process. Recorded in `Docs/Testing/TEST_MATRIX.md`.
3. **The accessibility audit leg was intermittent; the cause is now understood.** The settle wait added in #243 never actually waited — it watched `descendants(matching: .staticText).firstMatch`, which resolves to the navigation title and does not move when the content scrolls, so it returned on the first comparison. It bought three green runs (#243, #244, #245) by adding ~150ms, then failed both runners on #247. Two adaptive replacements were correct and unaffordable (a tree query per iteration took the leg to 1835s; screenshot comparison to 1578s, both timing out the OLED audit). #248/#249 settled on a flat wait, raised to 1.5s after 0.8s lost on a slower runner. A fixed wait is a bet against runner speed: if the contrast failure returns, raise the number rather than reaching for a cleverer wait.

   **It returned.** #253 raised the settle to 2.5s. #254 then failed twice more, each with a different signature — first a 15s timeout on `transaction-list-root`, then `testNewReportsAccessibilityAudit` "Contrast failed" again — and passed on a plain re-run with no code change. Two things were learned. First, #252 had raised a timeout at the wrong call site: its comment claimed the site was "the only navigation wait in the file that runs at AccessibilityXL", but that test sets an OLED appearance and never sets AccessibilityXL, while the genuine AccessibilityXL site was left at 15s and later failed. Both now read one `accessibilityXLListTimeout` constant. Second, `Scripts/ci/resolve-ios-simulator-destination.sh` is deterministic *per machine*, not across machines: CI resolves to `iPhone 17 Pro Max`, while a Mac whose newest runtime is iOS 27.0 resolves to `iPhone 17`, because that runtime ships no Pro Max. Reproducing a CI audit failure locally therefore means pinning the model **and** a 26.x runtime by UDID, not running the resolver. The contrast failure could not be reproduced locally on either device.

   The remaining obstacle is diagnostic, not behavioural: `performAccessibilityAudit` reports "Contrast failed" without naming the offending element, so every occurrence is a coin flip with nothing to act on. Installing an issue handler that logs the element's identifier, label, frame and computed colors is the prerequisite for any real fix.
4. ~~**1.7.1 unversioned/untagged.**~~ Closed — `MARKETING_VERSION` `1.7.1`, build `11`, tag `v1.7.1`, live on the App Store as of 2026-09-21.

---

## Suggested next scope

Ordered by user value against effort, not by plan order. Every item on the previous
list has since been built and merged (M2.4, M1.3.4, M2.7.5, M1.7.7, M3.6.4/M3.6.5), and
M1.10.6 was struck as moot rather than built. What follows is what is actually left.

1. **M2.5.5 sinking funds.** Savings Goals is otherwise complete, and sinking funds are the
   one pattern the current goal model cannot express. It overlaps conceptually with savings
   goals and deserves a design decision before code — that decision is now the blocker, not
   the implementation.
2. **M1.6.6 multi-page scanning.** VisionKit already does the scanning and extraction; this
   is batching pages into one document. Device-only verification keeps it off the top.
3. **M2.6.2 Watch voice entry.** The only remaining Watch gap. The Watch target is the one
   that has broken submissions before, per `release-bundle-gotchas`, so budget for a real
   upload rather than a green build.
4. **M3.3 Live Activities / Dynamic Island.** No ActivityKit usage anywhere yet — a whole
   module, and the largest remaining Phase 3 gap after 3.4.
5. **M3.5 tax expansion (UK/CA/AU).** The tax engine is country-pluggable, but each country
   is a research and fixture effort, not a port. Largest item on this list by a wide margin.

**Not on this list, deliberately:** M1.10.6 budget templates (moot — see Phase 1), and the
accessibility audit flakiness, which is test infrastructure rather than a feature and is
tracked under Known Gaps.
