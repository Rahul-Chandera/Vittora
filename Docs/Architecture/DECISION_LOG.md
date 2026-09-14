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
*(DEC-017 briefly extended this to the paywall's filled purchase CTA; DEC-018 reversed that, so the paywall is NOT covered by this exception.)*
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

- Status: **Reversed by DEC-018 (2026-09-13, Rahul).** The tint decision below is no longer in force; the paywall is back on `VColors.primaryOnSurface` (`#17604A`) and claims no DEC-012 exemption. The entry is kept intact as the record of what was tried and why it was undone. Originally: Accepted (2026-09-13, Rahul)
- Decision: The paywall `SubscriptionStoreView` tint becomes `VColors.primary` (`#3FCFA4`) with white content at 1.97:1, matching the onboarding hero CTAs. `"Try It Free"` / `"Subscribe"` are added to `AccessibilityAuditUITests`' `brandGreenFilledContent` set.
- Why: Owner decision — the primary purchase CTA must match every other hero CTA in the app (`OnboardingView` and elsewhere). The previous `VColors.primaryOnSurface` (`#17604A`) fill looked wrong next to the rest of the product.
- What is and is not covered: DEC-012 covers white-on-green **fills**. The Terms of Service and Privacy Policy links are pinned to `VColors.primaryOnSurface` (`#17604A`) via `subscriptionStorePolicyForegroundStyle` because pale green foreground text on a near-white page is not that pairing and is a real legibility regression. The marketing glyphs and the Restore Purchases label in `PaywallView` also stay `#17604A` for the same reason.
- Build impact: `PaywallView.subscriptionStore` tint + policy foreground style; `brandGreenFilledContent` labels `"Try It Free"` and `"Subscribe"` in `AccessibilityAuditUITests`.
- Revisit: if the paywall control chrome changes, or if DEC-012 itself is revisited.

## DEC-018: The paywall tint reverts to the house primary `#17604A`; DEC-017 is undone

- Status: Accepted (2026-09-13, Rahul — owner approved). **Reverses DEC-017.**
- Decision: `PaywallView`'s `SubscriptionStoreView` tint returns to `VColors.primaryOnSurface` (`#17604A`). The marketing bullet glyphs return to monochrome `#17604A` discs with the check knocked out in white. The lifetime button keeps its white label, now on a `#17604A` capsule. The `"Try It Free"` / `"Subscribe"` labels and the `paywall-lifetime-button` identifier are **removed** from the DEC-012 exemptions in `AccessibilityAuditUITests`, because nothing on the paywall needs one any more.
- Why DEC-017 was wrong on its own premise: DEC-017 justified brand green as matching "the app's other hero CTAs". It does not. The app's primary filled action is `VDialogButtonMetrics.confirmFill` = `#17604A` (`Vittora/DesignSystem/Components/VDialogButtons.swift:36`), and the comment directly above that constant already rejected brand green for this exact role — white on `#3FCFA4` is the 1.97:1 DEC-012 pairing, while white on `#17604A` computes to 7.48:1. Moving the paywall to `#3FCFA4` made it the outlier, not the match.
- What it cost while it was in force: the lifetime button fell from 3.80:1 to 1.97:1; the bullet checks fell from 7.48:1 to 1.97:1; and `SubscriptionStoreView` derived a **black** purchase-button label, because black beats white against `#3FCFA4`. Two knowing sub-AA pairings and a CTA label colour the app did not choose.
- Why the label could not simply be fixed: `SubscriptionStoreView` exposes no API to override its purchase button's label colour. `subscriptionStoreButtonLabel(_:)` selects *which text* the button shows, not what colour it is drawn in; the foreground is derived from the tint. So on a brand-green tint the black label is not a bug to patch — it is the only lever StoreKit offers, and it is StoreKit's lever, not ours. Setting the tint to `#17604A` makes StoreKit derive white at 7.48:1 with no exemption and no override.
- Why the exemptions were removed rather than left in place: a dead exemption silently excuses a future regression. Each was deleted and the audit re-run to confirm the paywall passes without it.
- Build impact: `Vittora/Features/Paywall/PaywallView.swift` (tint, bullet glyph rendering, comments); `VittoraUITests/AccessibilityAuditUITests.swift` (`brandGreenFilledContent` loses `"Try It Free"` and `"Subscribe"`; the `paywall-lifetime-button` identifier check is deleted; the `testPaywallAccessibilityAudit` doc comment is corrected).
- Unchanged by this: DEC-012 itself still stands for onboarding CTAs, the FAB, and the Net Worth card. `subscriptionStorePolicyForegroundStyle(VColors.primaryOnSurface)` is kept even though it now matches the tint — StoreKit's policy links do not otherwise inherit the tint, and pinning them is what keeps them at `#17604A`.
- Revisit: if DEC-012 itself is revisited, or if StoreKit ever exposes a purchase-button foreground API.

## DEC-019: StoreKit's subscribe-button offer caption is exempted from the contrast audit — the first exemption for Apple's own chrome

- Status: Accepted (2026-09-14, Rahul — owner approved).
- Decision: `AccessibilityAuditUITests.performCoreFlowAudit()` excuses contrast findings on the `SubscriptionStoreView` subscribe-button caption ("7 days free, then $39.99/year") on the Vittora Pro paywall, and only there. It is matched by Apple's own accessibility identifier `Subscription Store View Standard Picker Style Subscribe Button Caption`, with a frame-intersection fallback against that same node.
- Measured: `#828289` on `#F1F1F6` = **3.39:1**, under the 4.5:1 AA bar for small text.
- Why it cannot be fixed: this is Apple's text, drawn by `SubscriptionStoreView`. No public API restyles it. `StoreButtonKind` has no case for the caption; `.subscriptionStoreControlStyle` changes the control's shape, not the caption's colour; `.productDescription(.hidden)` hides the plan-card descriptions, not this line. A custom control style would mean rebuilding the whole purchase surface, and `preferredSubscriptionOffer` changes which offer is advertised — both were rejected as redesign and App Review risk rather than accessibility fixes. The caption is alpha-composited over the scrolling marketing content, so lightening the background behind it lowers the ratio rather than raising it.
- Why accepting it loses nothing: the caption is a **duplicate**. The selected Yearly plan card carries the identical sentence as its `Product View Secondary Text` in black, and VoiceOver never reads the grey caption in isolation — it is folded into the subscribe button's own label, `"7 days free, then $39.99 per year, Try It Free"`. A user who cannot read the grey line still receives the offer terms twice over. Note the plan card sits **below** the caption in the scroll, not above it: on a 852pt screen the caption is at y=666 and the card at y=1009, so reaching the card takes a scroll. The duplication is real; its position is not.
- **This is a new precedent, and it is bounded.** Every prior exemption in that file — DEC-012's brand-green CTAs, the FAB, the Net Worth card, `form-section-header`, `debt-entry-delete` — covers paint Vittora chose, where the alternative was to change our own colour. This is the first entry excusing text the system renders and we cannot address. It does **not** license exempting system-rendered text generally. It is scoped to one identifier on one screen, and it was accepted only because all three of these held together: (1) no public API can change it, (2) the same information is present elsewhere in accessible contrast, and (3) VoiceOver already conveys it. An Apple-chrome contrast miss that fails any one of those three is a defect to escalate, not a case to add here. Aggregate nil-element liquid-glass findings elsewhere in the file are sampler artifacts, which is a different claim from this one: those are cases where the pixels pass and the sampler is wrong, whereas this caption genuinely is 3.39:1.
- Caveat on verification: `testPaywallAccessibilityAudit` does not report this finding on every run. Eight isolated runs on identical code produced one failure and seven passes, all eight reaching the loaded-store branch. The caption's measured ratio depends on what the scroll has composited behind it at the instant the audit samples, so a green run is not evidence the exemption is unnecessary. This matches the flakiness already recorded for the audit suite.
- Build impact: `VittoraUITests/AccessibilityAuditUITests.swift` only. No production code changes.
- Revisit: if StoreKit ever exposes a foreground style for the subscribe-button caption, or if the plan card stops repeating the offer terms — the second would remove the whole basis for accepting this.

## DEC-020: The contrast audit gains a top-side viewport rule, mirroring the bottom-bar one — and it is not a fix for the sampler false positives

- Status: Accepted (2026-09-14, Rahul — owner approved).
- Decision: `AccessibilityAuditUITests.performCoreFlowAudit()` gains a top-side counterpart to the tab-bar exemption that already sits above it. It is **two checks, deliberately separate**: (A) a contrast finding on an element whose `frame.maxY <= app.frame.minY` — entirely above the window — is ignored; (B) a contrast finding on an element whose `frame.minY < navigationBar.frame.maxY`, when a navigation bar exists with a real frame, is ignored. An element whose `minY` clears the bar is fully on screen and is still audited.
- Why there was an asymmetry: the bottom rule has existed for some time; there has never been a top-side counterpart. That asymmetry is why `testNewReportsAccessibilityAudit` fails while sibling screens pass — the sibling screens simply do not scroll content up under the navigation bar in the same way.
- Measured on the Emergency Fund screen (navigation bar `{{0,59},{393,54}}`, window height 852): the element `months covered` reports y -69.8 to -52.5, entirely off the top of the window; `3-month target` reports y 33.0 to 57.3, in the status-bar strip above the bar; `6-month target` reports y 63.3 to 87.6, behind the bar.
- Why those frames exist at all: `EmergencyFundReportView` is a `ScrollView` around a plain `VStack`, so SwiftUI keeps every row in the accessibility tree at its true frame even when the scroll has carried it off the top. A lazy container would not publish them; a plain `VStack` does.
- Why occluded-by-chrome is not a real contrast defect: XCTest samples pixels at the reported frame and measures whatever is painted there. For these three that is navigation-bar material, the status-bar strip, or nothing — the resulting element screenshots are blank or half-sliced. The ratio it computes describes chrome, not text. No user ever sees those pixels as the element's text, so there is nothing there for a contrast bar to protect.
- Anchored to the bar, not to a constant: check (B) reads `navigationBar.frame.maxY` at the moment the audit runs, so it follows the bar across devices, orientations and large-title collapse. The bottom rule's hardcoded `120` is a wart and was deliberately not copied.
- Why two checks and not one: one condition would cover both cases, but off-the-window and occluded-by-chrome are different facts and a future reader needs to be able to tell which one fired. An element at y -69.8 is not being hidden by the navigation bar; it is not on the screen at all.
- **This rule is not a fix for the sampler false positives, and must not be read as one.** The three findings it covers are the chrome-occluded ones. `Monthly essentials`, `To reach 3 months` and `Contributing Accounts` are genuinely visible, crisp, fully on-screen text belonging to the `form-section-header` sampler false-positive class already documented in the file, and they are deliberately **NOT** exempted here. Whether to excuse that class is a separate owner decision and was not authorised with this one. The success criterion for this change is that chrome-occluded findings stop being reported while everything genuinely on screen keeps being audited — not a green test.
- Verification, and a discrepancy worth recording: `testNewReportsAccessibilityAudit` was expected to stay red on the remaining three findings. It did not. On the local `iPhone 16` / iOS 26.5 simulator (`C7B59D69-56FC-4FD6-A5D6-18DB5DCBC852`) it **passed on all three post-change runs**, in two full-suite runs and one targeted run, with the full UI core suite at 70 passed / 0 failed / 5 skipped both times. Either the remaining three findings are themselves intermittent — which matches the audit-suite nondeterminism already recorded for DEC-019 — or they do not reproduce on this device at all. A green run is therefore not evidence that the `form-section-header` question has gone away, and it is still open.
- Also landed in the same change (a harness defect, not an exemption): the pre-scroll `for _ in 0..<10` loop that preceded `UITestSupport.scrollToElement(emergency, in: app)` was deleted from both places it appeared in the file. Its break condition, `frame.maxY <= app.frame.maxY - 120` (= 732 on this window), was **unsatisfiable** — the Emergency Fund card's `maxY` bottoms out at 753 — so the loop always burned all ten swipes, over-scrolled the report list, and left `scrollToElement` to undo the damage. `scrollToElement` already does this job properly, against the real navigation-bar and tab-bar frames rather than a constant. Deleting it is the shortest correct fix, and it was deleted in both copies because the same dead loop had been pasted twice.
- Build impact: `VittoraUITests/AccessibilityAuditUITests.swift` only. No production code changes.
- Open, and explicitly not decided here: the bottom rule exempts everything below `app.frame.maxY - 120` on any screen with a tab bar — the bottom 120pt, roughly 14% of an 852pt window. That band is wider than the floating tab bar itself and may be hiding real findings. Narrowing it to the tab bar's own measured frame, the way check (B) is anchored, is the obvious follow-up and is left open.
- Revisit: if the bottom rule is narrowed to the tab bar's measured frame; if the `form-section-header` sampler class is ever decided one way or the other; or if the report views move to lazy containers, which would stop publishing off-screen rows and make check (A) dead code.


## DEC-021: The contrast audit's bottom-side viewport rule is narrowed from a 120pt band to the tab bar's own measured frame

- Status: Accepted (2026-09-14, Rahul — owner approved). Closes the follow-up left open by DEC-020.
- Decision: the bottom-side exemption in `AccessibilityAuditUITests.performCoreFlowAudit()` no longer uses a hardcoded band. It was `self.app.tabBars.firstMatch.exists && element.frame.maxY > self.app.frame.maxY - 120`; it is now `bottomBar.exists && bottomBar.frame.minY > 1 && element.frame.minY > bottomBar.frame.minY`, where `bottomBar` is `self.app.tabBars.firstMatch`. The magic `120` is gone. The `minY > 1` guard rejects a degenerate/zero tab-bar frame, mirroring the top-side rule's `topBar.frame.maxY > 1`. The two rules now read as one concept: each is anchored to the chrome it describes.
- What the band was, measured: on window `(0, 0, 393, 852)` the floating tab bar's frame is `(0, 769, 393, 83)`, so the bar begins at y=769. `app.frame.maxY - 120` put the exemption band's top at y=732. The 37pt strip from y=732 to y=769 is fully visible on-screen content that no contrast audit has ever sampled.
- What it hid: confirmed genuinely-visible elements inside that strip — **Budgets**: `Spent` (733.0–750.3), `$27.35` (756.3–779.7), `Remaining` (733.0–750.3), `$72.65` (756.3–779.7), `Progress` (736.0–753.3), `27%` (759.3–776.7) — the entire spent/remaining/progress row of a budget card, the numbers that screen exists to show; **Dashboard**: `Recent Transactions` (754.2–775.2), `See All` (753.0–776.3); **Transactions**: the `Sat, 12 Sep` date header (756.0–800.3).
- Deliberately still audited: an element that *overlaps* the bar but starts above it. Only an element whose `minY` is at or below the bar's own top edge is skipped. That is the entire point of the change, and it is what produces the findings below.
- Verification, three full UI-core runs on `C7B59D69-56FC-4FD6-A5D6-18DB5DCBC852` (iPhone 16 / iOS 26.5), plus the onboarding leg:
  - run 1 — 75 total, 64 passed, **6 failed**, 5 skipped
  - run 2 — 75 total, 64 passed, **6 failed**, 5 skipped (identical set to run 1)
  - run 3 — 75 total, 59 passed, **11 failed**, 5 skipped
  - onboarding — 1 total, 1 passed, 0 failed
  - Baseline at `72901ebb` was 70 passed / 0 failed / 5 skipped, so every failure below is new.
- Newly surfaced findings. A stable core of six fails every run: `testDashboardAccessibilityAudit`, `testPaywallAccessibilityAudit`, `testTaxSurfacesAccessibilityAudit`, `testReportsHomeAndMonthlyOverviewAccessibilityAudit`, `testOLEDBlackAccessibilityAuditForCoreFlows`, `testAccessibility3ScreenshotsForCoreFlows`. Run 3 added five more: `testBudgetsAccessibilityAudit`, `testAddTransactionAccessibilityAudit`, `testNewReportsAccessibilityAudit`, `testSettingsSectionsAccessibilityAudit`, `testTransactionListAndDetailAccessibilityAudit`. Every failure is `Contrast failed for SwiftUI.AccessibilityNode`; the 6-of-6 core is reproducible, the extra five are intermittent in the way already recorded for DEC-019.
- **No genuine contrast defect was found, and none has been fixed or suppressed.** Every exported element screenshot shows ordinary, legible text: `Recent Transactions` (dark grey on light grey), `Custom Report`, `Basic Tax`, `Savings Rate` and `Spent` (black on white), `Recent Transactions` again in the OLED pass (light on black), `$27.35` (brand green on white), `27%` (dark grey on white). What they have in common is that the crop runs into the floating tab bar's glass material at the bottom edge, or, on the paywall, into off-window black below `app.frame.maxY`. The sampler is averaging chrome and off-window pixels into text it is supposed to be measuring.
- Consequence, stated plainly: `release/1.7.0` is red on the UI core leg as of this change. That is the intended outcome of restoring coverage, not a regression to paper over. The rule was **not** widened back, no exemption was added, and no production code was touched.
- Open, and explicitly **not** decided here — owner calls, all of them:
  1. Whether the straddling class (element starts above the bar, extends under it) should be excused at all, and if so on what evidence rather than on a constant. Excusing it is a new exemption and was not authorised with this change.
  2. Whether the bottom side needs an off-window counterpart to the top rule's check (A). The top rule ignores an element entirely above the window (`maxY <= app.frame.minY`); there is no bottom-side equivalent, so the paywall element whose frame extends past `app.frame.maxY` is now audited against black pixels that are not on the screen at all.
  3. Why `testBudgetsAccessibilityAudit` — the case predicted as most likely to flag — passed in runs 1 and 2 and failed only in run 3, with all six strip elements reported. The strip content is identical in all three runs.
- Build impact: `VittoraUITests/AccessibilityAuditUITests.swift` only, inside the `auditType == .contrast` branch. No production code changes, no new dependencies, no `XCTSkip`.
- Revisit: when any of the three open questions above is decided; or if the floating tab bar stops being a capsule with transparent gutters, which is what makes the sampler average chrome into straddling elements in the first place.
