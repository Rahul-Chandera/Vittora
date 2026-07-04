# M1 — Wave-1 Launch-Market Decision Brief

**Independent Review Board · Confidential · 2026-07-02**
**Decision owner:** Rahul · **Analysis:** review board · **Status:** ✅ **DECIDED — Option C (parallel US + India)**, 2026-07-02 · *board dissent recorded, see §6*
**Prerequisites decided:** F0 = launch-free (DEC-008) · M0 = iOS 26/macOS 26 floor (2026-07-02). Both materially shape this decision.
**Audit anchor:** the 2026-06-27 business analysis directed a **single Wave-1 market** (do not parallelize US+India), UVP corrected to shipped scope, KPIs rebuilt bottom-up after a soft launch.

---

## 1. The question — and what Wave-1 is *for*

Which single market gets the public launch: **India**, the **US**, or both-sequenced (and which first)?

**Framing that decides most of it:** F0 already deferred monetization until post-PMF. Therefore **Wave-1's objective is not revenue — it is PMF signal**: activation, D30 retention, the splitting loop, tax-feature engagement, and learning velocity per unit of spend. Optimize Wave-1 for *learning and adoption economics*; optimize Wave-2 for *revenue*.

## 2. Repo-verified product-asset fit (what we actually shipped, per market)

| Shipped asset (verified on `refactoring`) | India | US |
|---|---|---|
| Tax engine completeness | ✅ **Market-complete for its system**: dual regime (old/new), FY-aware slabs (Apr–Mar labels), 80C/80D/80CCD(1B)/HRA with caps, surcharge marginal relief **validated against incometax.gov.in** (A13/K1). India has no state income tax → federal-only == complete. | ⚠️ **Federal-only — zero state-tax modeling**, with an explicit in-code disclaimer ("modeled only at the federal level"). A CA/NY/NJ user's real burden is understated by roughly the state's 5–13% — a **credibility risk** for a finance app whose differentiator is tax. 401(k)/IRA/HSA headroom (K7) is genuinely strong. |
| Import / switching lever | Generic CSV only (Indian banks don't export Mint/YNAB formats) | ✅ **Mint + YNAB CSV profiles** (K5) — but the post-Mint-shutdown land grab (2024–25) has largely settled by mid-2026 |
| Splitting (K3 share-out) | ✅ Strong cultural fit — group-expense splitting is mainstream behavior (Splitwise's biggest markets); viral loop potential higher | Useful, less central to the wedge |
| Locale/money correctness | ✅ INR lakh/crore-aware parser (A9), ₹ formatting | ✅ USD |
| Privacy/offline-first moat | Moderately differentiating | ✅ **Strong narrative** vs Plaid-linked incumbents (Monarch/Copilot/Rocket) |
| No bank sync (manual entry) | **Smaller handicap on iOS**: Indian trackers auto-track via SMS parsing, which iOS forbids — so *every* iOS finance app in India is effectively manual. Level field. | **Bigger handicap**: US incumbents all sync via Plaid; manual-first sells only to the privacy/YNAB-manual niche |

## 3. Market factors *(directional estimates — verify before signing; a deep-research pass is available on request)*

- **TAM under the 26-floor (M0):** US active iPhone base ~140–155M, nearly all iOS-26-capable → floor ≈ costless. India active iPhones ~45–60M and growing fast; iPhone 11+ (26-capable) is the large majority since the 11/12/13 were India's volume sellers — but the excluded XR/XS cohort is disproportionately Indian (accepted in M0; sized here, not ignored). India's ~6–8% iPhone share *is* the affluent, tax-paying, App-Store-paying segment — which is exactly Vittora's user.
- **Competition:** US is crowded and settled post-Mint (Monarch, Copilot, YNAB, Rocket Money, Origin) — differentiation must be privacy+tax, against well-funded incumbents. India iOS has **no strong expense-tracker + tax-planner combo**: ClearTax owns *filing* (not year-round planning), bank apps own payments, Splitwise owns splitting but has no ledger/tax. Vittora's shipped combo is **more distinctive in India**.
- **Distribution/CAC:** India App Store finance keywords are far cheaper; founder is India-based (IST, en_IN environment, the India tax depth itself) → founder-market fit, local beta recruiting, community GTM at near-zero CAC. US CAC in finance is among the highest anywhere.
- **Willingness-to-pay:** US ≫ India for subscriptions. This is the strongest *US* argument — but F0 made it a **Wave-2 concern by design**.

## 4. Options

| | **A — India Wave-1, US Wave-2 (recommended)** | **B — US first** | **C — Parallel** |
|---|---|---|---|
| Wave-1 goal fit (PMF/learning) | ✅ Cheap CAC, founder-local, distinctive product, splitting virality | ⚠️ Expensive learning; niche wedge (privacy-manual) vs incumbents | ❌ Rejected by the audit: splits focus/spend of a small team |
| Product readiness | ✅ Tax engine launch-complete | ⚠️ Federal-only tax gap undercuts the differentiator | — |
| Revenue timing | Deferred anyway (F0); US carries Wave-2 revenue with StoreKit F1–F4 | Earlier WTP access, but no paywall exists yet | — |
| Key risk | India learnings ≠ US WTP; iOS-only in an Android-dominant market (mitigation: the iPhone segment *is* the target segment) | Launch credibility hit from state-tax gap; high CAC for learning | Both risks at once |

## 5. Recommendation — Option A: India Wave-1, US as a gated Wave-2

1. **Wave-1 = India** (soft launch → India App Store): the shipped product is most complete and most differentiated there, the founder advantage is real, CAC-per-learning is lowest, and the splitting loop gets its best test. The M0 reach cost is accepted and sized.
2. **Wave-2 = US, gated on three things:** (a) **state-tax modeling** (or explicit "federal estimate" repositioning) — the credibility gap must close before tax is the US pitch; (b) **StoreKit F1–F4** — enter the high-WTP market able to monetize; (c) **CKShare join-in loop** — arrive with the viral mechanic complete.
3. **UVP correction (per audit):** India pitch = *"The private, offline-first money app that actually understands Indian taxes — expenses, budgets, splits, and a regime-aware tax estimate in one place."* Drop any claim the shipped scope doesn't support (no bank sync, no filing, no widgets/watch).
4. **KPI rebuild (bottom-up, post-soft-launch):** activation = onboarding-complete + 10 transactions in week 1; D30 retention; % users running a tax estimate in month 1; splitting invites sent/user; CSV imports; crash-free sessions. Set targets from the soft launch, not aspiration.
5. **D5 metadata follow-through:** India-first store listing (INR screenshots, regime/80C/HRA language), device/OS requirement stated (M0), US listing deferred to Wave-2.

## 6. Decision record

| Field | Value |
|---|---|
| Decision | ✅ **C — parallel US + India Wave-1** |
| Decided by / date | Rahul · 2026-07-02 |
| Board note | **Dissent recorded:** the board and the 2026-06-27 audit both recommended a single Wave-1 market; C takes both risk sets simultaneously with a small team (split GTM focus, doubled metadata/positioning work, US federal-only tax credibility gap now launch-relevant). Decision owner accepts these; the de-risk conditions below are the board's execution requirements under C. |
| **De-risk conditions (board-required under C)** | **(1) US tax honesty before launch:** the federal-only gap must be handled — minimum: explicit "Federal estimate — state taxes not included" labeling in the tax UI + US store listing (cheap, honest); better: a simplified state-tax table engine as fast-follow (same slab-engine pattern as existing code). Do **not** lead US positioning with tax until state coverage exists. **(2) Asymmetric parallel:** one global binary, but concentrate *active* GTM spend/effort on one market (recommended: India — founder-local, cheap CAC) while the other runs passive (listing + ASO only) — parallel presence without parallel burn. **(3) Per-market KPIs from day one** (never blended): activation, D30, tax-estimate usage, splitting invites — measured separately so the 60–90-day checkpoint is decidable. **(4) 60–90-day concentration checkpoint:** if one market clearly outperforms, formally shift to concentrated GTM there (pre-committing this converts C's focus risk into a data-driven A/B). **(5) D5 ×2:** two store-listing treatments (INR/regime language vs USD/privacy-vs-Plaid language), both scoped to shipped features, device/OS requirements stated (M0). |
| Follow-on | UVP per market per §5.3 (India) + US variant ("private, offline-first, no bank linking — with a federal tax estimate"); KPI baselines from the parallel soft launch; StoreKit F1–F4 and CKShare remain post-PMF fast-follows for whichever market converts. |
