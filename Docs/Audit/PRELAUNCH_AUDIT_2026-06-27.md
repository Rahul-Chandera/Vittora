# VITTORA — PRE-LAUNCH ENTERPRISE AUDIT & RELEASE-READINESS ASSESSMENT

**Independent Review Board** · Confidential · 2026-06-27
**Scope:** Full pre-launch audit against `Docs/Vittora_Final_Plan.md` and the source tree on branch `develop`.
**Build state at audit:** iOS target compiles clean (1 benign warning: *"No AppIntents.framework dependency found"*); macOS `VittoraTests` suite **green, 0 failures**. App source ≈ 35.9k LOC / 354 Swift files; tests ≈ 15k LOC / 88 files.

---

## Method & Evidence Integrity

This audit was conducted by 13 specialist auditors (CPO, Startup Advisor, Market Research Director, Principal Apple Architect, Distinguished Swift Engineer, Senior Security Engineer, Senior QA Director, HIG Specialist, Performance Engineer, Release Manager — mapped onto 13 review dimensions), followed by adversarial verification. Findings carry per-item severity, evidence (`file.swift:line`), impact, effort, and confidence.

**Every Critical and High finding in this report was independently re-verified against source** (grep + file reads). Items personally confirmed by the lead reviewer are marked **[verified]**. Where verification *reduced* a severity, the adjusted value is used (e.g. several monetization "Criticals" collapse to one root cause — "no StoreKit yet" — which is expected for a pre-monetization MVP and is a *milestone* blocker, not a present defect).

**Total findings: 170** (18 Critical, 45 High, 63 Medium, 44 Low as reported; consolidated below).

---

## 1. Release Gate — **NO GO** (public production release)

This is an unambiguous NO GO for the launch described in the plan. It is a **recoverable** NO GO: the engineering foundation is above average and every blocker has a bounded fix. But the following are individually disqualifying:

| # | Blocker | Class | Evidence |
|---|---|---|---|
| 1 | **Editing or deleting a transfer corrupts/orphan balances** | Data corruption | `TransferFundsUseCase.swift:50-86` + `Delete/Update/BulkOperationsUseCase` `break` on `.transfer`; no `transferPairID` **[verified]** |
| 2 | **Changing a transaction's account corrupts both balances** | Data corruption | `UpdateTransactionUseCase.swift:22,30-53` reverses old effect against the NEW account **[verified]** |
| 3 | **Multi-step money writes are non-atomic** (partial failure desyncs balances) | Data corruption | `TransferFundsUseCase.swift:61-86`, `AddTransactionUseCase.swift:66-84`, separate `@ModelActor` contexts, no Unit-of-Work **[verified]** |
| 4 | **Budget alerts never fire** — fails a stated MVP exit criterion | MVP/Functional | no `UNUserNotification*` anywhere; `CheckBudgetThresholdUseCase` has 0 callers **[verified]** |
| 5 | **Privacy manifest empty while using UserDefaults** → automatic App Store Connect upload rejection | Compliance | `PrivacyInfo.xcprivacy` empty `NSPrivacyAccessedAPITypes`; UserDefaults in 8 files **[verified]** |
| 6 | **Entire paid revenue system unbuilt** (for a paid app) | Monetization | no StoreKit/paywall/entitlement anywhere **[verified]** |
| 7 | **Dynamic Type non-functional app-wide** | Accessibility | `VTypography.swift:5-29` fixed point sizes, 598 uses |

Secondary release blockers: **no App Sandbox entitlement** (Mac App Store impossible), `aps-environment=development` with no push code, and `SUPPORTED_PLATFORMS` shipping `xros xrsimulator` (visionOS) + device family `7` with **zero** visionOS code — i.e. the build is configured to ship for platforms that have never been built or QA'd.

**To reach "GO WITH CONDITIONS" for a closed TestFlight beta** (not public launch): fix blockers 1-3 (atomic writes + transfer pairing + correct account reversal + a balance-reconciliation check), ship the notification engine (4), fix the privacy manifest (5), decide to launch **free** or build StoreKit (6), and correct the build's platform/sandbox/aps configuration. Dynamic Type (7) and the headline UX/correctness bugs should ride along before any public release.

---

## 2. Executive Summary

Vittora is a **competently engineered, privacy-first, Apple-native personal-finance tracker** (iPhone/iPad/Mac) with a genuinely strong, tested tax engine. It is wrapped in a business plan that materially overstates what exists, and — critically for money software — its core ledger write-path is **not yet reliable**.

**Genuine strengths (verified):**
- Clean build, **zero code warnings**; macOS unit suite green. No production force-unwraps; **no deprecated APIs** (`NavigationView`, `UIScreen.main`, old `onChange`, `UIApplication.shared` all absent).
- **Money is `Decimal` end-to-end** (`TransactionEntity.amount`, `AccountEntity.balance`, debt/budget/tax intermediates); `Double` appears only in chart scaling/abbreviation — correct.
- **Tax slab engine is correct and year-aware**: progressive bracketing (`TaxCalculatorProtocol.swift:25-49`), US TY2024-26 brackets, standard deductions, LTCG 0/15/20 stacking (`USTaxCalculator.swift:165-187`), NIIT, payroll wage caps; rates built from `Decimal(string:)` literals to avoid float drift. This is the one real, defensible differentiator.
- **Strong data-at-rest crypto**: AES-256-GCM with the key **Secure-Enclave-wrapped** and biometry-gated (`EncryptionService.swift:36-118`); keychain pinned `WhenUnlockedThisDeviceOnly`; attachments encrypted and local-only; CSV formula-injection neutralized.
- Real **Clean Architecture/MVVM**: domain protocols, 68 single-responsibility use cases, `@ModelActor` SwiftData repositories, mappers; Core layer essentially UI-free (one leak).
- `PrivacyInfo.xcprivacy` present; accurate Info.plist usage strings; in-app data deletion + factory reset; no account system (so Guideline 5.1.1(v) is genuinely N/A); recovery-mode startup handling.

**The disqualifying gaps:**
- **Financial integrity (score 3/10):** transfer edit/delete corruption; update-against-wrong-account; non-atomic writes; no `balance == Σ(transactions)` reconciliation; recurring double-generation race; UUID-FK deletes orphan dependents; locale-blind money parsing that silently zeroes "1,000".
- **Functional completeness vs the team's own MVP:** no notification layer → budget/bill/recurring/debt alerts and *every* retention loop are dead; "smart categorization" is a payee-frequency stub; "cash-flow forecast" is historical; splitting has no invite/share; PDF export, CSV import, saved views, audit trail absent.
- **Monetization (2/10):** 0% built; the one coded "paid" feature (CloudKit sync) is on for everyone.
- **Accessibility (4/10):** Dynamic Type broken app-wide; income/expense/warning palette fails WCAG AA; the primary amount field is unlabeled for VoiceOver.
- **Apple compliance (4/10):** empty privacy manifest, push declared with no code, no App Sandbox, visionOS in build config with no code, metadata markets nonexistent Watch/Widget/Siri features.
- **Multi-platform (4/10):** an iPhone app with a macOS veneer — iPad collapses to the iPhone 9-tab layout; Core cannot be shared with future widget/watch targets without refactoring.
- **Business/GTM (Market Fit 4, Model 3):** moat reduces to privacy + tax once OCR (a regex parser), splitting virality (absent), and "5 platforms" (it's 3) are reconciled; simultaneous US+India Wave-1 optimizes for two opposite products.

**Consolidated Critical themes (after verification):**

1. **Financial-data corruption cluster** — transfer edit/delete, update-against-new-account, non-atomic writes *(3 verified Criticals)*
2. **No notification subsystem** → budget-alert MVP exit criterion fails *(verified)*
3. **Privacy manifest auto-rejection** *(verified)*
4. **Monetization unbuilt** for a paid app *(verified; milestone blocker)*
5. **Dynamic Type broken app-wide**
6. **Viral splitting loop absent** *(strategy Critical; verified)*
7. **Build ships for visionOS with no visionOS code** *(verified)*

---

## 3. Business Analysis  *(Market Fit 4 · Business Model 3)*

Coherent prose; the moat is largely unbuilt.

- **UVP reconciliation (plan §1):** of six differentiators, **two are real** (privacy/offline; country tax). "OCR that actually works" is `ReceiptParserService.swift` — hardcoded `$`/`Rs` regexes, 4 date formats, "merchant = first non-numeric line" (**BUSINESS-3**). "Viral splitting loop" has **no invite/share/CKShare** (members are local UUIDs) → k-factor ~0 (**BUSINESS-2 [verified]**). "5 platforms native" is **3** (**BUSINESS-4 [verified]**). "ML categorization" is rule-based (no Core ML import).
- **Two-market Wave-1 (plan §4):** US (WTP 9/10, "Very High" competition, $6-10/mo) and India (iOS 6%, WTP 2/10, ~$2/mo, Apr-Mar tax year, July ITR) demand near-opposite products → **sequence, don't parallelize** (**BUSINESS-5**).
- **Positioning inconsistent:** plan says "money operating system"; onboarding says "all-in-one personal finance companion" (`OnboardingView.swift:160`) (**BUSINESS-6**).
- **Hardcoded tax rules** (`IndiaTaxCalculator.swift:127-128`) contradict M2.3.15's "not hardcoded; remote config" promise — trust/maintenance risk during ITR season (**BUSINESS-7**).
- **KPIs aspirational** (**BUSINESS-10**) — they depend on a paywall, a viral loop, and notification retention that all don't exist; category trial→paid is typically 3-8% vs the planned >15%; the plan's own CPA table tops out at $8 against ~$50-60/yr ARPU.

**Recommendation:** concentrate on the one durable wedge — **Apple-native, tax-aware money management, India-first during ITR season** — and reframe the rest as roadmap (the website already does this honestly).

---

## 4. Product Analysis — Functional Completeness  *(Product 5)*

Broad, reachable offline ledger; falls short of the team's **own** MVP/V1 spec.

| ID | Sev | Gap | Evidence |
|---|---|---|---|
| FUNCTIONAL-1 | **Critical** | No local-notification subsystem at all | `grep UN* → 0`; only in-process `CommandNotifications.swift` **[verified]** |
| FUNCTIONAL-2 | **Critical** | Budget threshold alerts never fire (MVP exit criterion) | `CheckBudgetThresholdUseCase` 0 callers **[verified]** |
| FUNCTIONAL-3 | High | "Smart categorization" = payee-frequency stub | `SmartCategorizeUseCase.swift:10-36`; no Core ML/NL |
| FUNCTIONAL-4 | High | Credit-card due-date reminders absent (no due-date field) | `Features/Accounts` has no `dueDate` |
| FUNCTIONAL-5 | High | "Cash-flow forecast" is historical, not projected | `CashFlowReportView.swift:34-36` |
| FUNCTIONAL-6 | High | Tax omits headline deductions (80C ₹1.5L, 80D, 80CCD(1B), HRA) | `TaxEntity.swift:92-105` free-form sum |
| FUNCTIONAL-7 | High | Splitting has no share/invite/group export | no `ShareLink`/`CKShare` in `Features/Splits` |
| FUNCTIONAL-8 | High | No PDF report generation | no `ImageRenderer`/`PDFDocument` in `Features/Reports` |

Plus (Medium/Low): US 401k/IRA/HSA are static text not tracking (F-9); savings auto-allocation absent (F-10); `BatchScanUseCase` dead code (F-11); no edit audit trail (F-12), saved views (F-13), CSV import (F-18), multi-currency FX (F-14); OCR has no confidence/accuracy instrumentation (F-15); onboarding lacks permission priming (F-21). **Correctly out of MVP scope:** Watch, Widgets, Siri/App Intents, ML — absent, fine for an MVP, but the **V1 promise is far off**.

---

## 5. Architecture Audit  *(Architecture 5 · Maintainability 6 · Scalability 5)*

Textbook layout, undermined at the seams that matter for money. (Score lowered from the structural 6 because the financial-integrity defects in §6 are architectural — the write path has no transactional boundary.)

- **ARCHITECTURE-01 — Critical [verified]: no Unit-of-Work.** Compound operations issue multiple awaited writes across **independent `@ModelActor` contexts** with no shared transaction/rollback (`TransferFundsUseCase.swift:61-86`). See DATAINTEGRITY-2.
- **ARCHITECTURE-02 — High: all-optional DI; views are the composition root.** Every repo/service optional (`DependencyContainer.swift:7-28`); views guard-unwrap and silently render nothing on nil (`TransactionListView.swift:239-266`); 89 use-case instantiations across 40 views. **Fix:** non-optional eager composition + a factory vending finished view models.
- **ARCHITECTURE-03 — High [verified]: Swift 5 language mode.** `SWIFT_VERSION = 5.0` in all 6 configs; `SWIFT_STRICT_CONCURRENCY` absent. Data-race safety not compiler-enforced despite the documented "Swift 6 strict concurrency" claim.
- **ARCHITECTURE-04/05/07/11 — Medium:** global `dataRefreshVersion` counter as an app-wide cache-bus (23 writers/24 readers → blunt full refetches); no referential integrity on UUID-FK deletes; hand-mutated balances with no reconciliation; CloudKit conflict resolution is advisory-only LWW — concurrent amount edits silently lost (`CloudKitSyncMonitor.swift:79-94`).
- **ARCHITECTURE-09/10 — Low/Medium:** migration plan is an empty V1 baseline; `fetchAll` caps at 500 with no pagination contract → aggregates reason over partial data.

---

## 6. Financial Data Integrity & Reliability  *(Data Integrity 3/10 — the single most important score in this report)*

`Decimal` is used correctly and the tax engine is accurate; **balance correctness is the weak spot**, and it is where money software cannot afford to be weak.

| ID | Sev | Issue | Evidence |
|---|---|---|---|
| DATAINTEGRITY-1 | **Critical** | Editing/deleting a transfer leaks balance and orphans the mirror leg (no `transferPairID`) | `TransferFundsUseCase.swift:50-86`; `Delete/Update/BulkOperationsUseCase` `break` on `.transfer` **[verified]** |
| DATAINTEGRITY-2 | **Critical** | Non-atomic balance mutations across separate `@ModelActor` contexts corrupt on partial failure | `AddTransactionUseCase.swift:66-84`, `SettleDebtUseCase.swift:42-54`; `SyncIntegrityValidator` does no balance reconciliation **[verified]** |
| DATAINTEGRITY-3 | **Critical** | `UpdateTransactionUseCase` reverses the old effect against the NEW account → both balances corrupt on account change | `UpdateTransactionUseCase.swift:22,30-53` **[verified]** |
| DATAINTEGRITY-4 | High | Recurring generation can double-generate (launch + BGTask, check-then-act race, no unique constraint) | `VittoraApp.swift:233`, `BackgroundTaskScheduler.swift:63`, `GenerateRecurringTransactionsUseCase.swift:36-61` |
| DATAINTEGRITY-5 | High | Locale-blind `Decimal(string:)` with 3 inconsistent comma strategies silently zeroes/distorts input | `TransactionFormViewModel.swift:23` (no handling) vs `AddGroupExpenseViewModel.swift:34` (`,`→`.`) vs `SavingsGoalFormView.swift:24` (strip) |
| DATAINTEGRITY-6 | High | `DeleteCategoryUseCase` orphans transactions/budgets/recurring rules | `DeleteCategoryUseCase.swift:10-15` (no guard/nullify) |
| DATAINTEGRITY-7 | Medium | Repeated partial debt settlements orphan all but the last linked transaction | `DebtEntry.swift:26` single `linkedTransactionID`; `SettleDebtUseCase.swift:51` overwrites |
| DATAINTEGRITY-8 | Medium | India surcharge has no marginal relief and is applied on special-rate capital gains (over-taxes) | `IndiaTaxCalculator.swift:234-253` (conf: Medium — validate vs official) |
| DATAINTEGRITY-9 | Medium | Split rounding can yield negative/!=total last share; %/shares not validated to sum | `AddGroupExpenseUseCase.swift:80-122`; `SimplifyDebtsUseCase.swift:29-54` |
| DATAINTEGRITY-10 | Medium | Recurring catch-up advances only one period/run; matches by exact `Date` equality; month-end drift | `GenerateRecurringTransactionsUseCase.swift:24-123` |
| DATAINTEGRITY-11/12 | Medium | Empty migration plan; integrity validator never reconciles `balance == Σ(tx)` and caps at 500 rows | `VittoraMigrationPlan.swift:24-32`; `SyncIntegrityValidator.swift:24-42` |
| DATAINTEGRITY-13 | Low | Duplicate detection misses payee-less/transfer tx; prefilter range disagrees with same-day predicate | `DuplicateDetectionUseCase.swift:17-47` |

**Strengths:** `Decimal` end-to-end; correct progressive tax engine; `GenerateRecurringTransactionsUseCase` has best-effort per-rule rollback; `DeleteAccount/PayeeUseCase` correctly block deletion when dependents exist; `SyncIntegrityValidator` provides an advisory post-merge net.

**Highest-leverage fix:** make balance **derived** from transactions (or enforce a single-context Unit-of-Work for every compound write) and add a `balance == Σ(signed transactions)` reconciliation+repair pass. This single change neutralizes DI-1, DI-2, DI-3, and DI-12 at the root.

---

## 7. Code Quality Audit  *(Code Quality 6)*

Clean build, no warnings, disciplined OSLog — but correctness/consistency issues:

- **CODEQUALITY-1 — High [verified]:** detail/edit screens fetch ALL then linear-search by id against a 500-row cap (`TransactionDetailViewModel.swift:26-27`) → **transactions older than the 500 most recent cannot be opened**; the indexed `fetchByID` exists and is unused.
- **CODEQUALITY-2 — High:** locale-unsafe money parsing applied inconsistently (see DATAINTEGRITY-5).
- **CODEQUALITY-6 — Medium:** ~17 private `formatAmount` helpers / ~99 currency call sites with *disagreeing* compact formatters (`Cr/L` vs `k`).
- Medium/Low: `rawValue.capitalized` for user-facing enums (one site string-patches "Creditcard"→"Credit Card"); ~31 raw `vittora.*` UserDefaults literals despite an unused `AppUserDefaults`; fire-and-forget Tasks in settings setters; hardcoded `"$0.00"` fallback; duplicated onboarding field block.

---

## 8. Security Audit  *(Security 6)*

Cryptographic core strong; weaknesses concentrated in **App Lock — the linchpin of the threat model**.

| ID | Sev | Issue | Evidence |
|---|---|---|---|
| SECURITY-1 | **High [verified]** | No idle auto-lock; timeout/inactivity logic is dead code (locks only on background) | `recordActivity`/`lockTimeout`/`.lock()` uncalled outside `AppLockService.swift` |
| SECURITY-2 | Medium | "Passcode Fallback" toggle persisted but never read | `allowPasscodeFallback` read nowhere in unlock path |
| SECURITY-3 | Medium | No re-auth before disabling App Lock or factory reset | `SettingsSectionViews.swift:103`, `DataManagementView.swift:43-48` |
| SECURITY-5 | Medium | Nil `appLockService` silently **unlocks** (fail-open) | `AppLockView.swift:116-119` |
| SECURITY-6 | Medium | Key get-or-create has no single-flight guard; concurrent first-encrypt can orphan data | `EncryptionService.swift:89-117` |
| SECURITY-7 | Low | Financial data + payee PII sync to CloudKit without app-layer field encryption | `ModelContainerConfig.swift:14-20` (private DB only) |
| SECURITY-9 | Low | `aps-environment=development`; `remote-notification` mode declared but unused | entitlements:5-6; `Info.plist:19-23` |

---

## 9. Performance Audit  *(Performance 6)*

Fine at small data; structurally unbounded as ledgers grow.

- **PERFORMANCE-01 — High:** account/payee-only filters (no date) fetch the **entire table**, then slice in Swift (`SwiftDataTransactionRepository.swift:30-78`).
- **PERFORMANCE-02 — High:** indexed columns post-filtered in memory, not in the predicate.
- **PERFORMANCE-03 — High:** search runs a full fetch + regroup **on every keystroke** (no debounce) (`TransactionListView.swift:85-89`).
- **PERFORMANCE-12 — [verified]:** `fetchActive` predicate `… (periodRawValue != "" || true)` is a no-op → loads all budgets.
- Medium/Low: O(tx × entities) `first(where:)` lookups in report loops; CSV export silently capped at 500; no list pagination; per-row currency/hex allocation; dead thumbnail pipeline.

---

## 10. UX/UI Audit  *(UX 5 · UI 6)*

- **UX-3 — High [verified]:** the **primary** transactions list never passes `category:` to the row → **every row is an identical generic blue circle** with no icon/color/name (`TransactionListView.swift:45`).
- **UX-1 — High:** Dynamic Type effectively broken (fixed point sizes).
- **UX-2 — High:** inconsistent destructive-delete confirmation (transactions/budgets/savings delete on full swipe; accounts/categories confirm).
- **UX-4 — High:** Notifications settings screen is **dead UI** — toggles write UserDefaults; nothing is scheduled.
- Medium: 9 tabs overflow into an undesigned "More" on iPhone; 3+ inconsistent empty-state patterns; search-with-zero-results shows misleading "add your first transaction"; `VStatCard` hardcodes up=green regardless of metric.
- Low: dark-mode black shadows; no global `.tint`; no onboarding Back/Skip; undiscoverable multi-select; informational-only duplicate warning; `QuickEntryView` dead code with artificial 300ms delay; nested `NavigationStack`s on iPad/Mac.

---

## 11. Accessibility Audit  *(Accessibility 4)*

- **ACCESSIBILITY-1 — Critical:** Dynamic Type non-functional app-wide — `VTypography` is 100% fixed point sizes, consumed 598×; zero `relativeTo:`/`@ScaledMetric`.
- **ACCESSIBILITY-4 — High:** income/expense/warning palette fails WCAG AA (VWarning ~1.9:1 as foreground); no high-contrast variants.
- **ACCESSIBILITY-5 — High:** the primary amount field has no VoiceOver label and a non-scaling 32pt font.
- **ACCESSIBILITY-2/3 — High:** selection signaled by color only with no `.isSelected` trait; transaction rows driven by tap/long-press with no button trait or accessibility action.
- Medium/Low: onboarding progress invisible to VoiceOver + unguarded `.symbolEffect` vs Reduce Motion; 36pt hit targets; unlabeled icon-only controls; ungrouped stat/legend rows; missing `.isHeader` traits.

Lowest-scoring dimension and a reputational risk for an Apple-showcase app.

---

## 12. QA Report  *(Testing 6)*

Strong unit breadth (88 files, **green**), thin where a finance app needs depth.

| ID | Sev | Missing coverage |
|---|---|---|
| TESTING-1 | **Critical** | Transfer atomicity / partial-failure — structurally untestable (mocks can't inject mid-op failure) |
| TESTING-2 | High | SwiftData migration (no V1→V2 round-trip; stages empty) |
| TESTING-3 | High | `SyncIntegrityValidator` + `CloudKitSyncMonitor` have zero direct tests |
| TESTING-4 | High | Secure-Enclave wrap/unwrap path never exercised (tests run simulator/legacy + plaintext mock keychain) |
| TESTING-5 | High | `ReceiptParserService` (OCR extraction) has no unit tests |
| TESTING-6 | High | App-lock background/foreground gating untested |
| TESTING-8 | Medium | **No CI pipeline** (no `.github/workflows`); pass-status only manually verifiable |
| TESTING-7/9/10 | Medium | Money rounding tests use Double tolerance; mocks too simple to hit error/rollback paths; recurring lacks DST/month-end-clamp cases |

---

## 13. Apple Platform Compliance  *(Compliance 4)*

**Positives [verified]:** modern SwiftUI (no deprecated APIs); accurate usage strings mapped to real code; genuine AES-GCM + Secure Enclave; in-app data deletion; no account system → 5.1.1(v) N/A.

| ID | Sev | Issue | Evidence |
|---|---|---|---|
| COMPLIANCE-1 | **Critical** | Empty privacy manifest despite UserDefaults (needs CA92.1) → automatic upload rejection | `PrivacyInfo.xcprivacy` empty; UserDefaults in 8 files **[verified]** |
| COMPLIANCE-2 | High | Push/remote-notification declared everywhere; zero notification code | entitlements:5-6; `Info.plist:19-23`; no `UN*` **[verified]** |
| COMPLIANCE-3 | High | No App Sandbox entitlement → Mac App Store impossible | `Vittora.entitlements` has only iCloud+aps **[verified]** |
| COMPLIANCE-4 | High | `aps-environment=development` used for both Debug & Release | `project.pbxproj:290,339` |
| COMPLIANCE-5 | High | Metadata markets Watch/Widgets/Siri/Vision Pro that don't exist | plan:128,139,674,763 vs single app target |
| COMPLIANCE-6 | Medium | visionOS in `SUPPORTED_PLATFORMS` with no visionOS code | `project.pbxproj` `xros xrsimulator`; no code **[verified]** |
| COMPLIANCE-7 | Medium | Privacy nutrition `NSPrivacyCollectedDataTypes` empty — verify vs App Store Connect labels | `PrivacyInfo.xcprivacy:9-10` |
| COMPLIANCE-8/9/10 | Low | `ITSAppUsesNonExemptEncryption=false` undocumented; doc drift (SYSTEM_MAP/RELEASE_CHECKLIST point at non-existent files); `NSPhotoLibraryUsageDescription` over-declared (PhotosPicker needs none) | Info.plist:5,13; `SYSTEM_MAP.md:55` |

---

## 14. Multi-Platform Readiness  *(4)*

A shared SwiftUI target with a clean domain layer — the right base — but "an iPhone app with a macOS veneer."

| ID | Sev | Issue | Evidence |
|---|---|---|---|
| MULTIPLATFORM-1 | **Critical** | Binary `#if os(iOS)/#else` makes macOS the implicit fallback for visionOS, which the build config already targets | `project.pbxproj` `xros`+family `7`; 48 bare `#else` vs 5 `os(macOS)` **[verified]** |
| MULTIPLATFORM-2 | High | iPad has no dedicated experience; Split View collapses to the iPhone 9-tab TabView | `ContentView.swift:25-34` (size-class only); `SidebarNavigation.swift:11` 2-column |
| MULTIPLATFORM-3 | High | Core locked in the app target — no widget/watch/App Intents target can share it | no SPM package, no app-group; `AttachDocumentUseCase.swift` imports UIKit/AppKit |
| MULTIPLATFORM-4 | High | Nested NavigationStacks on iPad/macOS (each of 9 roots embeds its own) | `SidebarNavigation.swift:66` + per-feature stacks |
| MULTIPLATFORM-5 | High | No pointer/hover support; context menus in exactly one view | `grep hoverEffect/onHover → 0`; `contextMenu` only in `DocumentThumbnailView.swift` |
| MULTIPLATFORM-6/7/8 | Medium | Keyboard shortcuts macOS-only; thin macOS window/menu polish + Cmd-, notification hack instead of `Settings{}` scene; single WindowGroup, no state restoration | `VittoraApp.swift:131,162-176` |
| MULTIPLATFORM-9/10 | Low | `UIDevice.userInterfaceIdiom` in a feature view; dual selection sources in sidebar | `DashboardView.swift:67`; `SidebarNavigation.swift:6,59-64` |

---

## 15. Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Balance corruption (transfer edit/delete; account-change; non-atomic writes) | **High** | **Critical** | Derive balance / Unit-of-Work + transferPairID + reconciliation (DI-1/2/3) |
| Recurring double-generation (duplicate charges) | Medium | High | Serialize generation + unique (rule, date) constraint (DI-4) |
| Locale money misparse (silent 0 / 1000×) | Medium | High | One locale-aware parser; reject unparseable (DI-5) |
| Silent data loss on CloudKit concurrent edits (LWW) | Medium | High | Derive balance from additive transactions; user conflict review (ARCH-11/DI-12) |
| App Store rejection (privacy manifest, sandbox, aps, metadata, visionOS) | **High** | **High** | Fix manifest/entitlements/platforms; align metadata (COMPLIANCE-1..6) |
| Accessibility backlash / poor reviews (Dynamic Type, contrast) | High | High | Rebuild typography on text styles; fix palette (ACC-1/4) |
| Monetization unproven (no paywall/funnel) | Certain | High | Build StoreKit + instrument funnel, or launch free |
| Tax surcharge over-taxation (India) / staleness (hardcoded) | Medium (seasonal) | Med-High | Surcharge marginal relief + externalize signed rules + golden tests (DI-8/BUS-7) |

### Technical Debt Register
Optional-DI composition-in-views (ARCH-02/06) · global refresh counter (ARCH-04) · 17 duplicate currency formatters (CQ-6) · 31 raw UserDefaults keys (CQ-7) · 500-row caps, no pagination (ARCH-10, PERF-07) · empty migration plan (ARCH-09/DI-11) · dead code (`QuickEntryView`, `BatchScanUseCase`, thumbnail pipeline) · Swift 5 mode (ARCH-03) · `AttachDocumentUseCase` UIKit leak · no CI (TEST-8).

---

## 16. Prioritized Backlog

`| Priority | Area | Issue | Evidence | Recommendation | Effort | Impact |`

| P | Area | Issue | Evidence | Recommendation | Eff | Imp |
|---|---|---|---|---|---|---|
| **P0** | Data Integrity | Transfer edit/delete corrupts/orphan balances | `TransferFundsUseCase.swift:50-86` **[verified]** | Add `transferPairID`; handle `.transfer` in delete/update/bulk to reverse both legs atomically | M | High |
| **P0** | Data Integrity | Update reverses old effect against NEW account | `UpdateTransactionUseCase.swift:22,30-53` **[verified]** | Reverse on old account, apply on new; update both atomically | S | High |
| **P0** | Data Integrity | Non-atomic multi-context money writes | `TransferFundsUseCase.swift:61-86` **[verified]** | Single-context Unit-of-Work OR derive balance from transactions + reconciliation pass | L | High |
| **P0** | Functional | No notification subsystem → budget alerts dead (MVP criterion) | `grep UN*→0`; `CheckBudgetThresholdUseCase` 0 callers **[verified]** | `NotificationService` (UNUserNotificationCenter) + wire threshold/bill/recurring/debt | L | High |
| **P0** | Compliance | Privacy manifest empty w/ UserDefaults | `PrivacyInfo.xcprivacy` **[verified]** | Add `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1` | S | High |
| **P0** | Accessibility | Dynamic Type broken app-wide | `VTypography.swift:5-29` (598 uses) | Rebuild tokens on relative text styles / `@ScaledMetric` | L | High |
| **P0** | Security | No idle auto-lock; fail-open on nil service; no re-auth before reset | `AppLockService` dead timer **[verified]**; `AppLockView.swift:116-119` | Time-based lock on `.active`; fail-closed; biometric gate on destructive actions | M | High |
| **P0** | Monetization | Entire StoreKit/paywall/gating layer absent (paid-launch blocker) | `grep StoreKit→0` **[verified]** | Build StoreKit 2 + `SubscriptionStoreView` + `EntitlementStore`, OR launch free | L | High |
| **P1** | Compliance | No App Sandbox entitlement → no Mac App Store | `Vittora.entitlements` **[verified]** | Add `com.apple.security.app-sandbox` + camera/contacts/photos/network (macOS entitlements file) | M | High |
| **P1** | Compliance | Build ships visionOS + push capability with no code; aps=development | `project.pbxproj` `xros`; entitlements:5-6 **[verified]** | Remove `xros/xrsimulator`+family 7; remove push/aps or ship code; production for release | S | High |
| **P1** | Compliance | Metadata markets nonexistent Watch/Widgets/Siri/Vision | plan:674,763 | Restrict App Store listing/paywall copy to shipped features | M | High |
| **P1** | Data Integrity | Recurring double-generation race | `VittoraApp.swift:233` + `BackgroundTaskScheduler.swift:63` | Serialize generation; unique `(ruleID, occurrenceDate)` | M | High |
| **P1** | Data Integrity / Code Quality | Locale-blind money parsing (3 strategies) | `TransactionFormViewModel.swift:23` | One locale-aware parser; reject unparseable; locale tests | M | High |
| **P1** | Data Integrity | Category/recurring delete orphans dependents | `DeleteCategoryUseCase.swift:10-15` | Guard or nullify FKs atomically; cascade tests | M | Med |
| **P1** | Code Quality | Detail/edit can't open tx beyond 500 most recent | `TransactionDetailViewModel.swift:26-27` **[verified]** | Use indexed `fetchByID`; regression test >500 | S | High |
| **P1** | UX | Every transaction row renders identical blue circle | `TransactionListView.swift:45` **[verified]** | Resolve & pass `CategoryEntity` into the row | M | High |
| **P1** | Multi-platform | iPad collapses to iPhone TabView; binary platform branching | `ContentView.swift:25-34` **[verified]** | `TabView(.sidebarAdaptable)` / 3-column split; explicit per-platform branches | L | High |
| **P1** | Multi-platform | Core not shareable with future extensions | no SPM/app-group | Extract Core to a package/framework + app-group now | L | High |
| **P1** | Architecture | All-optional DI; views as composition root | `DependencyContainer.swift:7-28` | Non-optional eager DI + view-model factory | L | High |
| **P1** | Architecture | Swift 5 mode despite "Swift 6 strict" claim | pbxproj `SWIFT_VERSION=5.0` **[verified]** | Move to Swift 6 / strict complete; fix diagnostics | M | High |
| **P1** | Performance | Unbounded fetches; in-memory filtering; no search debounce | `SwiftDataTransactionRepository.swift:30-78` | Push predicates to store; hard limits; 250ms debounce | M | High |
| **P1** | UX | Inconsistent destructive-delete; dead Notifications screen | `TransactionListView.swift:54-62` | Uniform Undo/confirm; wire or hide screen | M | High |
| **P1** | Product/Tax | Missing 80C/80D/80CCD(1B)/HRA; India surcharge marginal relief | `TaxEntity.swift:92-105`; `IndiaTaxCalculator.swift:234-253` | Section-aware caps + HRA calc + surcharge marginal relief + golden tests | L | High |
| **P1** | Business | Viral splitting loop absent; "5 platforms"/OCR overstated | `Features/Splits` (no share) **[verified]** | Build invite loop OR correct UVP & GTM math | L | High |
| **P1** | Testing | No atomicity/migration/sync/SE/OCR/app-lock tests; no CI | §12 | Add the six suites + CI on PR | M | High |
| **P2** | Data Integrity | CloudKit LWW silently drops concurrent amount edits; no balance reconciliation | `CloudKitSyncMonitor.swift:79-94`; `SyncIntegrityValidator.swift:24-42` | Derive balance (additive merges); reconciliation+repair; user conflict review | L | Med |
| **P2** | Performance | `\|\| true` no-op budget predicate; O(n×m) report lookups; export 500 cap | `SwiftDataBudgetRepository.swift:67` **[verified]** | Fix predicate; dictionary lookups; paged export | S-M | Med |
| **P2** | Maintainability | 17 dup currency formatters; 31 raw UserDefaults keys; unlocalized enums | CQ-4/6/7 | Shared formatter; key constants; `displayName` | M | Med |
| **P2** | Multi-platform | No pointer/hover/context menus; thin macOS polish; no state restoration | MP-5/7/8 | `contextMenu`/`hoverEffect`; `Settings{}` scene; `@SceneStorage` | M | Med |

*(Full 170-item set is preserved in the audit artifacts; the above is the Critical/High core plus representative Mediums.)*

---

## 17. Release Readiness Scorecard

| # | Dimension | Score /10 | Note |
|---|---|---|---|
| 1 | Product | 5 | Broad tracker; misses own MVP exit criteria |
| 2 | Market Fit | 4 | Crowded category; moat largely unbuilt |
| 3 | Business Model | 3 | Coherent on paper; unbuilt + aspirational KPIs |
| 4 | Monetization | 2 | 0% built; sellable surface exists |
| 5 | Architecture | 5 | Clean skeleton; write-path integrity defects |
| 6 | Code Quality | 6 | Clean build; correctness + consistency bugs |
| 7 | Security | 6 | Strong crypto; App-Lock control gaps |
| 8 | Performance | 6 | Fine small; unbounded at scale |
| 9 | UX | 5 | Primary-screen category bug; dead notif UI |
| 10 | UI | 6 | Design system present; Dynamic Type/dark-mode gaps |
| 11 | Accessibility | 4 | Dynamic Type broken app-wide; contrast fails |
| 12 | Testing | 6 | Green + broad; missing high-risk suites; no CI |
| 13 | Maintainability | 6 | Clean arch; dup formatters/keys, refresh bus |
| 14 | Scalability | 5 | 500-caps, in-memory filtering, LWW |
| 15 | Apple Platform Compliance | 4 | Manifest/sandbox/aps/visionOS/metadata gaps |
| 16 | Multi-platform Readiness | 4 | 3-platform base; iPad/visionOS traps |
| 17 | **Release Readiness** | **3** | Financial-integrity + MVP + compliance blockers |
| — | *Financial Data Integrity (derived)* | *3* | *Most important number: 3 verified money-corruption Criticals* |

**Acceptance criteria status:** ❌ unresolved Critical defects (3 financial-integrity) · ⚠️ Swift 6 claim unmet (no deprecated frameworks) · ⚠️ App-Lock gaps · ✅ architecture organized · ⚠️ onboarding present, no permission priming · ❌ consistent UX · ⚠️ tests broad, key gaps · ❌ accessibility · ⚠️ performance OK small-scale · ❌ feature-completeness vs plan.

---

## 18. Final Decision: **NO GO** (public production release)

The engineering quality is high and every blocker has a clear, bounded fix — this is a *recoverable* NO GO, not a rewrite. Minimum bar to flip to **GO WITH CONDITIONS (closed beta)**:

1. **Financial integrity:** transfer pairing + correct account reversal + atomic/derived balances + a reconciliation check (with tests). *(P0 cluster)*
2. **App Lock:** fail-closed, idle auto-lock, re-auth before destructive actions.
3. **Notifications:** wire budget/bill/recurring/debt alerts (also unblocks retention).
4. **Compliance:** privacy manifest, App Sandbox, aps=production, drop visionOS/`xros` until built, reconcile metadata.
5. **Monetization:** explicit decision to launch **free** (defer revenue) or build StoreKit 2.

Dynamic Type, the transaction-row/category bug, and the >500-row detail bug should ship before any public launch.

> Per the audit brief, **no implementation roadmap is included** by design. On approval, each finding above will be decomposed into small, independently executable, agent-ready tasks (file targets, acceptance tests, dependencies, verification commands).

---

*Audit artifacts (per-dimension structured findings, 170 items) retained for traceability. Verification: all Critical/High items re-confirmed against source on 2026-06-27.*
