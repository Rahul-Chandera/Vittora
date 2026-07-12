# M2 — GTM Execution Plan (Wave-1: Parallel US + India)

**Independent Review Board · Confidential · 2026-07-02**
**Executes under:** F0 = launch free (DEC-008) · M0 = iOS 26/macOS 26 floor (DEC-009) · **M1 = parallel US + India** (DEC-010) with board de-risk conditions (asymmetric GTM, per-market KPIs, 60–90-day checkpoint, US tax honesty, D5 ×2).
**Status:** ✅ adopted · **M2-D1 measurement = (a) ASC-only, decided 2026-07-02** (§3)
**Owner:** Rahul (GTM) · Cursor (engineering follow-ons) · board (checkpoint review).

---

## 1. Positioning & UVP (corrected to shipped scope — repo-verified)

**Shipped and claimable:** transactions + quick entry, budgets with real threshold alerts, recurring, accounts/transfers, debts, savings goals + US contribution headroom, splits (share summary/invite + PDF), receipt OCR scan, reports + PDF export, CSV import (Mint/YNAB/generic), smart categorization, India + US tax estimates, app lock (Face ID), iCloud sync, offline-first, transaction edit history, saved filters.
**Never claim (verified absent):** bank linking/sync, widgets, Apple Watch, Siri, tax *filing*, collaborative real-time splitting.

| | 🇮🇳 India (ACTIVE market) | 🇺🇸 US (PASSIVE market) |
|---|---|---|
| One-liner | *"The private money app that actually understands Indian taxes."* | *"Budgeting with zero bank linking — your money data never leaves your devices + iCloud."* |
| Lead pillars | 1. Regime-aware tax estimate (old vs new, 80C/80D/HRA, surcharge relief) 2. Splitting with friends 3. Privacy/offline-first (no SMS reading, no account linking, **no analytics**) | 1. Privacy vs Plaid-linked incumbents (**zero analytics — not even first-party**) 2. Mint/YNAB CSV import (switching path) 3. Budgets + **federal** tax estimate + 401(k)/IRA/HSA headroom |
| Tax claim discipline | Tax estimate is a **first-class pillar** (engine is market-complete, validated vs incometax.gov.in) | Tax is a **supporting feature, never the headline**, always labeled *"Federal estimate — state taxes not included"* (M1 condition #1) until a state engine ships |

## 2. D5 — store listing spec ×2 (mechanism: per-locale metadata on one app)

One binary, one App Store listing, **localized metadata per storefront** + custom product pages for campaign links later. *Mechanics note (corrects earlier `en-IN` reference): App Store Connect has no "English (India)" locale — the India storefront serves **English (U.K.)** metadata when present (verify on ASC setup; consider Hindi `hi` later). So `en-US` = primary/US treatment, `en-GB` = India treatment.*

- **en-GB (→ India storefront):** title/subtitle around *money + India tax planning*; keywords target income-tax-calculator/80C/HRA/regime/salary intents. Screenshots: ₹ lakh-formatted dashboard → regime-comparison tax screen → 80C/HRA utilization → split summary → budget alert. Description opens with the tax pillar. **Full copy: `M2_T3_STORE_METADATA_PACKS.md`.**
- **en-US:** title/subtitle around *private budgeting, no bank linking*; keywords target privacy/expense/CSV intents (competitor names kept OUT of the keyword field per guideline 2.3.7 — Mint/YNAB compatibility stated factually in the description instead). Screenshots: $ dashboard → budget alerts → CSV import flow → federal-estimate screen **with the honesty label visible** → savings headroom. Description leads with privacy. **Full copy: `M2_T3_STORE_METADATA_PACKS.md`.**
- **Both:** device/OS requirement stated plainly (iOS 26+/macOS 26+, per M0/DEC-009); privacy nutrition label consistent with the manifest (**no tracking, no analytics of any kind** — per M2-D1(a) this is now a verifiable, first-class marketing asset — feature it); no claims from the "never claim" list.

## 3. Measurement (M2-D1 — ✅ DECIDED: (a) ASC-only, 2026-07-02)

**Fact (verified):** the app has **zero usage telemetry** — no analytics SDK, no network egress; `ConversionMilestone`s are on-device only. The M1 checkpoint needs per-market data. Options considered:

| | **(a) App Store Connect only — CHOSEN** | **(b) + Opt-in first-party ping** |
|---|---|---|
| What you get | Downloads, product-page conversion, retention estimates (opt-in panel), sessions, crashes — **by territory**. Zero work. **Preserves the strongest possible privacy claim.** | ASC **plus** real activation/engagement via an opt-in anonymous CloudKit counter. ~1–2 days work + privacy-label update. |

**Decision (Rahul, 2026-07-02): (a) — ASC-only for the first release.** Rationale: the product's promise and marketing lead is privacy; shipping with **zero analytics of any kind — not even first-party — is itself a verifiable, marketable claim** (privacy nutrition label stays pristine), and it is highlighted in both listings (§1/§2). The board records the accepted trade-off: the day-75 checkpoint runs on ASC territory data (opt-in panel) — conversion, downloads, D1/D7/D28 retention estimates, sessions, crashes, ratings — **not** in-app activation/engagement.
**Revisit triggers for (b):** (i) day-75 data too thin or ambiguous to make the concentration call — build (b) *before* extending the test; (ii) StoreKit work (F1–F4) begins (paywall tuning needs event data anyway). `ConversionMilestone`s remain on-device and untouched either way.

## 4. KPI framework (per-market, never blended — M1 condition #3; ASC-based per M2-D1(a))

Baselines set **from the soft launch, not aspiration** (audit directive). Per market, per week — all from App Store Connect by territory:
- **Acquisition:** impressions → product-page conversion → downloads.
- **Retention (the activation proxy under (a)):** ASC D1/D7/D28 retention estimates + sessions per active device. In-app activation (`tenthTransaction` etc.) is **not measured in Wave-1**.
- **Engagement (qualitative under (a)):** in-app engagement (tax-estimate use, splits, CSV imports) is not instrumented — proxy via review/rating themes, TestFlight feedback, and support mail; tag these by market.
- **Quality:** crash-free sessions (ASC), rating velocity + average, refund/complaint themes.
- **Checkpoint composite (pre-committed, M1 condition #4; ASC-based):** at **day 75** post-public-launch compute per market `product-page conversion × D28 retention (ASC panel) × weekly organic download growth` (ratings velocity as tiebreak). If one market ≥ **2×** the other → formally concentrate active GTM there (the other stays passive/listed). **If the data is too thin to call, that itself triggers building (b) before extending to day 150** (§3 revisit trigger i).

## 5. Launch sequencing & seasonal timing

| Phase | When (target) | What |
|---|---|---|
| **0 — Launch-readiness** | July 2026 | Merge docs PRs (#36/#37 + this one); honesty-label PR through CI; E6 hit-targets; **on-device SE checklist §2 pass + macOS-host run** (the last verification condition); D5 metadata ×2 drafted |
| **1 — Closed TestFlight beta** | July–Aug 2026 | Two recruited cohorts, tracked separately: 🇮🇳 recruit **during ITR season (July, deadline Jul 31)** when tax attention peaks — finance subreddits (r/IndiaInvestments, r/personalfinanceindia), X/Twitter finance circles, personal network; 🇺🇸 small privacy/YNAB-manual cohort (r/ynab, r/privacy adjacents). Exit criteria: crash-free ≥99.5%, onboarding completion ≥70% (TestFlight feedback + beta survey — beta is the one window with direct cohort visibility under (a)), no Sev-1 feedback themes |
| **2 — Public parallel soft launch** | Sept 2026 | Release worldwide (one binary). **Active GTM = India** (founder-led content: regime-comparison explainers, 80C/HRA planning threads, launch posts, App Store India editorial pitch — the privacy+tax+no-analytics angle is featurable). **Passive GTM = US** (optimized listing + ASO only; press kit page exists, no outreach push). No paid spend anywhere yet |
| **3 — Seasonal pushes** | Dec 2026–Apr 2027 | 🇮🇳 **Dec–Mar tax-saving season** (80C rush) = the big India push window; 🇺🇸 **Jan–Apr 15 tax season** = the US window *only if* the checkpoint kept the US active and the honesty-label story holds |
| **4 — Checkpoint** | ~Day 75 (≈Nov 2026) | Run §4 composite → concentrate or continue (or trigger (b) if data too thin). Board reviews with Rahul |
| **5 — Wave-2 triggers** | Post-PMF | StoreKit F1–F4 (monetize the market that converted — also §3 revisit trigger ii); CKShare join-in loop; US state-tax engine → only then may US positioning lead with tax |

## 6. Channel plan (asymmetric — M1 condition #2)

- **India (active, founder-led, ~zero CAC):** authentic build-in-public + tax-content marketing (regime comparisons, "what 80C actually saves you", HRA exemption walkthroughs — the calculator content *is* the product demo); community launches (finance subreddits, X finance circles, relevant Telegram/WhatsApp groups — always disclosure-first, value-first); App Store India editorial pitch (privacy-first finance + India-tax depth + zero-analytics is a featuring-worthy story); ASO iteration on the en-IN keyword set. **No paid acquisition in Wave-1.**
- **US (passive):** listing + ASO only; a single honest "I built this" post in r/ynab-adjacent communities at launch; press-kit page for inbound. Nothing else until the checkpoint says otherwise.

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Split focus despite "asymmetric" intent | The passive-market rule is bright-line: **listing + ASO only, zero bespoke US effort** until checkpoint |
| Checkpoint runs on thin data (accepted under (a)) | Pre-committed: thin/ambiguous day-75 data → build (b) before extending; beta phase used aggressively for direct cohort learning while we have it |
| US reviewers punish federal-only estimates | Honesty label in-product + in-listing; tax never the US headline |
| India reviews punish manual entry | Position no-SMS-reading as *privacy feature* (it is); OCR receipt scan + CSV as the effort-reducers |
| Seasonal miss (launch after ITR July peak) | Beta rides the July peak for recruiting; the *public* push targets the Dec–Mar saving season — bigger and better-fitting anyway |
| 26-floor confusion ("why won't it install?") | Device/OS requirement stated in both listings (M0/DEC-009 follow-on) |

## 8. Task register

| ID | Task | Owner |
|---|---|---|
| M2-D1 | ~~Decide measurement (a)/(b)~~ → **DECIDED (a)**, 2026-07-02 | Rahul ✅ |
| M2-T1 | US federal-estimate honesty label (in-product) | Cursor ✅ *(implemented; PR pending)* |
| M2-T2 | ~~Opt-in anonymous milestone counter~~ — **deferred** (D1 = (a)); build on §3 revisit triggers | — |
| M2-T3 | en-GB (India) + en-US metadata packs (title/subtitle/keywords/descriptions/screenshot scripts) per §2 | ✅ drafted by board → `M2_T3_STORE_METADATA_PACKS.md`; Rahul reviews/enters in ASC |
| M2-T4 | Beta cohort recruiting posts (India ITR-season + US privacy niche) + beta feedback survey (the (a)-world activation window) | Rahul |
| M2-T5 | Press-kit page (screenshots, privacy story incl. zero-analytics, founder note) | Rahul |
| M2-T6 | Day-75 checkpoint review (calendar it now: ~Nov 2026) | Rahul + board |
| M2-T7 | DEC log entries: ~~M1~~ ✅ (DEC-010) + M2 plan adoption incl. D1=(a) | Cursor |

## 9. Adoption record

| Field | Value |
|---|---|
| Plan adopted | ✅ yes (2026-07-02) |
| M2-D1 measurement | ✅ **(a) ASC-only** — privacy-first positioning; zero analytics as a marketable claim; revisit triggers in §3 |
| Decided by / date | Rahul · 2026-07-02 |
