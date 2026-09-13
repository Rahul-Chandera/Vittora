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

## DEC-011: Single-tier "Vittora Pro" fast-follow — pricing, gates, and trial policy (F0 follow-up)

- Status: Accepted (2026-07-14, Rahul)
- Decision: When monetization ships (per DEC-008 it remains a post-PMF fast-follow, not a launch blocker), Vittora sells **one paid tier — "Vittora Pro"** — plus a capped/seasonal lifetime unlock. The plan doc's §8 two-tier Plus/Pro ladder is formally superseded.
- Pricing (App Store tiers, adjust to nearest tier at implementation):
  - US: **$39.99/yr** hero price with **$29.99 first-year intro offer**; $4.99/mo monthly. *(The $29.99 intro offer is superseded by DEC-013 — it is not buildable alongside the 7-day trial.)*
  - India: **₹899/yr**; ₹129/mo monthly. Tax-season (Jan–Mar) In-App Event promos.
  - **Lifetime one-time**: $99.99 / ₹4,999 — capped quantity or seasonal windows only.
  - Family Sharing enabled on annual and lifetime.
- Trial policy: **7-day free trial via native StoreKit 2 introductory offer on the ANNUAL plan only** (payment method captured up front, auto-converts). No trial on monthly (or at most 3-day). The 15-day unrestricted trial stays rejected (DEC-008): unenforceable offline, non-native, gives away all value with no commitment.
- Pro gates (only real, shipped differentiators): full tax planning & regime comparison, unlimited receipt OCR (free tier keeps 5 scans/month), advanced/custom reports + PDF export, advanced debt analytics, future ML insights.
- Never gated (trust + growth invariants): iCloud sync, expense splitting (viral loop), unlimited transactions, basic budgets, CSV export (data ownership).
- Trigger to build Epic F (F1–F4, F6): D30 retention >15% or ~3–6 months post-launch, informed by ConversionEventTracker (F5) milestone data. Keep §8's value-event paywall triggers (10 transactions / first OCR / first report / limit hits) with `MonetizationConfiguration.paywallPresentationCooldownDays`.
- Why (evidence): category leaders all launched single-tier (YNAB $109/yr, Monarch $99.99/yr, Copilot $95/yr — Monarch split tiers only after scale); RevenueCat cross-industry medians put freemium download-to-paid at ~2.2% (the old plan assumed 4–7% then 15–25% stacked on top); the old ladder self-cannibalized ($10 between Plus and Pro annual, 17% annual discount vs its own 40–50% rule); Apple-native comps anchor the price (MoneyCoach $29.99/yr + $129.99 lifetime, Splitwise Pro ~$30–50/yr, Spendee Premium $35.99/yr); lifetime unlocks are proven in the Apple-indie niche and convert subscription-fatigued users.
- Marketing honesty (MON-14): paid-tier marketing lists only shipped features — no Watch/Widgets/Siri/forecasting claims until they exist.
- Revenue expectation reset: at 30K Y1 downloads, benchmark-median execution ≈ $25–40K; strong execution with tax-season spikes ≈ $50–80K. The old plan's "$150K conservative" was the optimistic case.
- Build impact (deferred until trigger): F1 StoreKit 2 products (annual+intro offer, monthly, lifetime non-consumable), F2 paywall UI (`SubscriptionStoreView` + value-event presentation), F3 entitlement gating at the gates listed above (flip `MonetizationConfiguration.isStoreKitEnabled`), F4 restore/receipt/Family Sharing, F6 subscription legal (terms, auto-renew disclosures, privacy-policy update). Nothing StoreKit-related exists in the codebase today, by design.
- Revisit: pricing/gates after first 90 days of paid data; Stage-2 household tier only if data shows a distinct audience.

## DEC-012: Brand green is #3FCFA4 with white content, accepting a WCAG AA miss

**Date:** 2026-08-01 · **Decided by:** Rahul (owner) · **Status:** accepted

**Decision.** `VColors.accent(.brandGreen)` is `#3FCFA4` — the app icon colour —
in every role: button fills, the FAB, onboarding hero icons, selected tab, and
accent foregrounds. Content on that fill is **white**.

**What this costs.** White on `#3FCFA4` measures **1.97:1**. WCAG AA asks 4.5:1
for text and 3:1 for large text, so this misses both. It is not a borderline
call and no font size rescues it.

**Why it was accepted.** Brand consistency was judged more important than the
contrast ratio on this one pairing. The alternatives were each rejected by the
owner after being shown side by side:

| option | result |
|---|---|
| `#3FCFA4` + dark label | 10.67:1, compliant — rejected, label read wrong |
| `#1F7D61` + white label | 5.04:1, compliant — rejected, green too dark |
| `#3FCFA4` + white label | 1.97:1 — **chosen** |

**Scope of the exception.** Only the contrast pairing of white-on-brand-green.
*(Extended by DEC-017 to the paywall's filled purchase CTA; that entry records what is and is not covered.)*
The audit gate is not disabled: `AccessibilityAuditUITests` still runs every
category on every screen, and the exclusion is written narrowly against this
pairing. Every other contrast rule, hit-target rule, Dynamic Type rule and
VoiceOver rule stays enforced.

**Relationship to house rule 9.** Rule 9 says a failing check is fixed by
changing the code under test, never the audit configuration. This is a
deliberate, recorded exception to that rule made by the owner — not an agent
working around a red test. It is written here so the next person to read the
audit exclusion finds the reasoning rather than guessing.

**To revisit:** if the app is ever assessed against WCAG externally, or if
customer feedback reports the labels as hard to read, reopen this and take the
`#1F7D61` + white option, which keeps white labels and clears AA at 5.04:1.

## DEC-013: The annual introductory offer is the 7-day free trial, not the $29.99 first year

- Status: Accepted (2026-09-11, Rahul)
- Decision: Vittora Pro annual sells at **$39.99/yr with a 7-day free trial** as its introductory offer. The **$29.99 first-year price from DEC-011 is dropped**, not deferred. Monthly ($4.99) and lifetime ($99.99 / ₹4,999) are unchanged, as is India annual (₹899/yr).
- Why: DEC-011 specified both a 7-day free trial *and* a $29.99 first-year intro price on the same plan. **The App Store cannot express that.** A subscription gets one introductory offer per user per subscription group, and its payment mode is exactly one of free trial, pay-as-you-go, or pay-up-front — the trial and the discounted first year are two mutually exclusive forms of the same slot. This was found while building F1, not at planning time; the `.storekit` file could not encode DEC-011 as written.
- Why the trial and not the discount: both DEC-008 and DEC-011 state the trial as *policy*, reasoned from abuse-resistance and App Store nativeness. The $29.99 price was an acquisition lever with no equivalent argument behind it. Given one slot, the reasoned commitment keeps it.
- Alternatives considered and rejected:
  - **$29.99 pay-up-front, no trial** — cheaper entry, but discards the trial policy both prior decisions committed to, and removes the try-before-you-buy step that a finance app benefits from most.
  - **Trial as the intro offer, $29.99 as an offer code** — technically viable and recommended by both the reviewing agent and the lead. Rejected by the owner in favour of a single, simpler price. Offer codes remain available for marketing and win-back per §8, so this can be revisited without a code change.
- Build impact: **none.** `Vittora.storekit` already encodes annual at $39.99 with a `free` / `P1W` introductory offer, which is exactly this decision; it was written as a placeholder pending this ruling and is now correct as-is. `StoreKitConfigurationTests` already asserts trial-on-annual-only.
- Also updated: `Docs/Vittora_Final_Plan.md` §8 pricing table, which carried the same unbuildable pairing.
- Revisit: with the first 90 days of paid data, alongside the DEC-011 pricing review. If acquisition is the constraint, an offer code is the lever to reach for first — it needs no build change.

## DEC-014: The 1.7.0 gate list — forward-looking analysis is paid, record-keeping and sharing are free

- Status: Accepted (2026-09-11, Rahul)
- Decision: Vittora Pro gates exactly the following, and nothing else.

| Vittora Pro | Always free |
|---|---|
| Full tax planning & regime comparison *(narrowed by DEC-015 — the tax profile form and its CSV export stay free; only the computed planning outputs and regime comparison are gated.)* | iCloud sync |
| Advanced / custom reports + PDF export *(narrowed by the owner ruling of 2026-09-12 — PDF export is gated only on `CustomReportView`; `ReportPDFShareLink` on `MonthlyOverviewView`, `AnnualReportView` and `SplitGroupDetailView` stays free, because splitting is never gated and monthly/annual reports are not in the Pro list.)* | Expense splitting (viral loop) |
| Cash flow forecast | Year in Review (shareable growth loop) |
| Subscription audit | Unlimited manual transactions |
| 50/30/20 report | Basic budgets and dashboard |
| Emergency fund tracker | Payee analytics |
| Unlimited receipt OCR (free: 5 scans/month) | CSV export (data-ownership promise) |
| Future ML insights (1.8.0) | **Unlimited accounts and budgets** |

- The principle: **forward-looking analysis is paid; record-keeping and sharing stay free.** This is the line to apply when a new feature arrives and the gate question comes up, rather than re-litigating feature by feature.
- Supersedes the gate list in DEC-011, which named "advanced debt analytics" and did not mention the cash flow forecast, subscription audit, 50/30/20 report or emergency fund tracker. Those four are the concrete shipped surfaces the principle points at.

### Account and budget caps are removed

- `FreeTierLimits.maxAccounts` and `maxBudgets` are **deleted, not retained unused**. A cap on how many accounts or budgets a user may keep is a cap on record-keeping, which the principle above puts on the free side.
- Deleted with them: the `accountLimitReached` and `budgetLimitReached` milestones in `ConversionMilestone`, `ConversionEventRecorder.afterAccountCreated` / `afterBudgetCreated`, and their call sites in `AccountFormView.swift` and `BudgetFormView.swift`.
- `FreeTierLimits.maxOCRScansPerMonth = 5` **stays.** It is a real gate: OCR has a per-scan cost and unlimited OCR is a named Pro feature.
- Consequence for App Review and for existing users: with the caps gone, the only enforcement F3 adds is the OCR monthly cap. **No existing user loses access to anything they already created.** That property is a requirement, not an accident — any future gate that would take away access to existing user data is an owner decision, not an implementation detail.

### Offline grace

- Entitlement resolution keeps a **16-day offline grace** (`Entitlement.swift`). Accepted as proposed. Gating must go through `EntitlementPolicy.resolve` so the grace applies uniformly rather than being re-implemented per call site.

### PDF export is Pro only on Custom Report

- Owner ruling, 2026-09-12. `ReportPDFShareLink` appears at four call sites: `CustomReportView.swift:43`, `MonthlyOverviewView.swift:35`, `AnnualReportView.swift:54` and `SplitGroupDetailView.swift:308`. Only the first is gated. Expense splitting is in the never-gated column and monthly and annual overviews are not in the Pro list, so gating their share links would take away a shipped free surface for no revenue reason.
- This is a note for F3's wiring. No gate call site is wired yet.

- Revisit: with the first 90 days of paid data, alongside DEC-011 and DEC-013.

## DEC-015: Your data stays yours; the analysis is paid — the tax feature splits at the profile form

- Status: Accepted (2026-09-12, Rahul)
- Decision: Vittora Pro gates the tax feature's **computed planning outputs and regime comparison** only. The **tax profile form and its CSV export stay free.** This narrows, but does not replace, the "Full tax planning & regime comparison" row of DEC-014's gate table.
- Why: `SDTaxProfile` holds user-entered data — annual income, regime, filing status, date of birth, custom deductions. `TaxProfileFormView` has exactly one entry point (`TaxDashboardView.swift:71`), inside the feature that would be gated, and the only tax CSV export is reached solely from within that feature. Gating the whole feature would take away data users already created: an App Store guideline **3.1.2** risk, and a direct contradiction of DEC-014's own written requirement that no existing user loses access to anything they made. Tax planning has been free since 2026-04-13, so the exposed installed base is real.
- The principle, which generalises to future gating decisions: **your data stays yours; the analysis is paid.** This sits underneath DEC-014's "forward-looking analysis is paid; record-keeping stays free" and settles the case DEC-014 did not anticipate — a feature that is analysis at the top and record-keeping underneath. The gate goes at the seam, not around the whole feature.
- Relationship to DEC-014: **annotation only.** DEC-014's gate table row is annotated in place and its text is otherwise unchanged; the eight-row table, the principle, the removed account and budget caps, and the offline grace all stand.
- Open question raised while implementing F3 (owner decision needed, not an implementation detail): the only tax CSV export is `DataExportService.exportTaxReportCSV(profile:estimate:comparison:summary:)`, and its contents are mostly the **computed analysis** — taxable income, total tax payable, effective and marginal rate, every bracket result, and the full regime comparison — over three rows of profile data. It cannot run at all without a computed estimate (`TaxEstimateViewModel.exportReport()` guards on `estimate`). So "the tax profile's CSV export" is in practice the tax *report* export. Left **ungated** pending the ruling, because keeping a surface free is reversible and carries no 3.1.2 risk, whereas gating it wrongly does. If the owner intends the principle to govern, this export is analysis and should be gated, with a profile-only export offered in its place to honour the data-ownership promise.
- **Owner ruling (2026-09-12): the tax report CSV is Pro.** `DataExportService.buildTaxReportCSV` (`Packages/VittoraCore/Sources/VittoraCore/Data/Persistence/DataExportService.swift:235`) emits taxable income, total tax payable, effective and marginal rates, every bracket result and the regime comparison. That is the analysis, not profile data, and it cannot run without a computed estimate. It is therefore gated. The data-ownership promise is served instead by `DataExportService`'s general full export, which stays **free**. This closes the open question above.
- Revisit: with the first 90 days of paid data, alongside DEC-011, DEC-013 and DEC-014.

## DEC-016: Light orange stays #AF5600 at 4.53:1, and the accent contrast floor stays 4.5

- Status: Accepted (2026-09-13, Rahul)
- Decision: `VColors.accentOnSurface(.orange)` keeps its light variant **`#AF5600`** at **4.53:1** on `VColors.groupedBackground` (#F2F2F7). Blue and purple were darkened to `#295592` and `#6D39A9` (both 6.70:1 there, 7.48:1 on white) to match `brandGreen`'s `#17604A` headroom; orange is the deliberate exception.
- Why: orange is already at **100% saturation**, so lightness is the only remaining lever, and lightness is exactly what turns an orange into a brown. Measured at hue 29.5°: 5.60:1 at `#994B00`, 6.47:1 at `#8A4400`, 6.84:1 at `#854100`. Green's 6.7:1 lands on `#864200` — within two points per channel of CSS SaddleBrown. Hue-rotating toward red buys ratio only by leaving orange faster.
- Why not a half-measure: a value in the 5.6–6.2 band was rejected outright. `VDialogButtons.swift:31-36` records that `#1F7D61` at a computed **5.05:1 still produced "contrast nearly passed" on every audit run**, so landing in that band buys a muddier colour and keeps the defect.
- Why 4.53:1 is acceptable here, where 1.97:1 needed DEC-012: this is a **user-selected accent rendered as a foreground on a light card**, and it clears WCAG AA (4.5:1) for normal text. DEC-012's brand green was white text on a saturated green **fill** — a harsher pairing that genuinely failed AA. Accepting a 0.03 margin on a colour the user chose is a different question from shipping a 1.97:1 pairing by default.
- **The `DesignTokenTests.accentOnSurfaceIsReadableOnCards` threshold stays at 4.5 and must not be raised.** Raising it to 6.0 would fail on orange, and the only way to raise it and stay green would be an orange carve-out — which is the "change the assertion so the offending input stops being produced" move AGENTS.md rule 9 forbids. The flat 4.5 is honest: it is the bar orange actually meets.
- Revisit: if the accessibility audit ever flags an orange-accented surface, or if the accent set is redesigned. Dropping Orange from the choices, or renaming it to a brown, both remain open — they were considered and declined in favour of keeping the colour the user picked.

## DEC-017: The paywall's filled purchase CTA joins DEC-012; its policy links do not

- Status: Accepted (2026-09-13, Rahul)
- Decision: The paywall `SubscriptionStoreView` tint becomes `VColors.primary` (`#3FCFA4`) with white content at 1.97:1, matching the onboarding hero CTAs. `"Try It Free"` / `"Subscribe"` are added to `AccessibilityAuditUITests`' `brandGreenFilledContent` set.
- Why: Owner decision — the primary purchase CTA must match every other hero CTA in the app (`OnboardingView` and elsewhere). The previous `VColors.primaryOnSurface` (`#17604A`) fill looked wrong next to the rest of the product.
- What is and is not covered: DEC-012 covers white-on-green **fills**. The Terms of Service and Privacy Policy links are pinned to `VColors.primaryOnSurface` (`#17604A`) via `subscriptionStorePolicyForegroundStyle` because pale green foreground text on a near-white page is not that pairing and is a real legibility regression. The marketing glyphs and the Restore Purchases label in `PaywallView` also stay `#17604A` for the same reason.
- Build impact: `PaywallView.subscriptionStore` tint + policy foreground style; `brandGreenFilledContent` labels `"Try It Free"` and `"Subscribe"` in `AccessibilityAuditUITests`.
- Revisit: if the paywall control chrome changes, or if DEC-012 itself is revisited.

