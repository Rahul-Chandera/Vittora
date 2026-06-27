# F0 — Monetization Launch-Model Decision Brief

**Purpose:** decide *how* Vittora monetizes at first release, so the team knows whether to build the StoreKit layer (Epic F: F1–F6) now or defer it. This is a **founder/business decision**, not an agent task — Cursor is gated here until this is signed off.
**Inputs:** audit findings MONETIZATION-01..14, BUSINESS-1/10, MON-04 (sync-gating), and the audit brief's explicit request to challenge a "15-day unrestricted free trial."
**Status:** DRAFT recommendation, awaiting decision. Record the chosen option in `Docs/Architecture/DECISION_LOG.md` (stub at the bottom).

---

## 1. The situation (why this decision is *not* on the critical path)

- The first public release is **NO GO for non-monetization reasons** (financial-integrity Criticals, no notifications, accessibility, compliance). So a beta/first-launch does **not** require StoreKit to ship.
- **Nothing is built:** no StoreKit, paywall, entitlement, or feature-gating (MON-01/02/03). The one feature the plan sells as paid — **iCloud sync — is currently on for everyone** (MON-04), i.e. the intended free/paid boundary is inverted.
- The product is **pre-PMF** in the most crowded consumer category. The two real, defensible value props are **privacy + country tax**; OCR/splitting-virality/ML/multi-currency are weak or absent (BUSINESS-3/4/8). So premium value that is *real today* = **tax planning, unlimited OCR, advanced reports/PDF, (optionally) sync**.
- The plan's **two-tier Plus+Pro** model doubles funnel complexity for a pre-PMF app (BUSINESS-1) and several Plus "benefits" (Watch/Widgets/Siri) **don't exist** (MON-14).

**Implication:** building monetization now spends scarce effort on a revenue system you cannot validate until you have retained users — and adds App Store subscription-review risk to an already-risky first submission.

---

## 2. Options

### Option A — **Launch FREE; monetize as a fast-follow** ✅ *Recommended*
First public release ships with **no IAP**. Make iCloud **sync a free baseline** (resolves MON-04 cleanly). Ship the **ConversionEventTracker (F5) now, free**, to measure value-events (10 tx, first OCR/report/split, cap-hits) and optionally a soft "Pro is coming" interest tap — gathering willingness-to-pay signal **without** a paywall. Introduce a single paid tier only after retention/PMF is demonstrated.

- **Engineering now:** small. Only `F5` (tracker, free) + make sync intentionally-free (trivial change in `ModelContainerConfig`/remove tier assumption) + `D5` (strip paid-feature marketing) + legal docs already clean (no subscription clauses needed yet). **Defer F1–F4, F6.**
- **Pros:** removes an entire release-blocking workstream; fastest path to launch and to PMF/retention data; zero subscription-review risk at v1; strongest privacy/no-dark-patterns story; lets you set price/gating from real data, not guesses.
- **Cons:** no launch revenue; you must later introduce a paywall to an existing free base (manageable via **grandfathering** early adopters); slight "trained to expect free" risk.
- **Effects:** Conversion/revenue **deferred**; Retention/PMF learning **maximized**; Churn **N/A**; App Store acceptance **easiest**; Timeline **shortest**.

### Option B — **Build ONE paid tier at launch (StoreKit 2)**
A single "Vittora Pro" tier gating the real differentiated value (tax + unlimited OCR + advanced reports/PDF), with a **generous free tier**, a **value-event hard paywall**, and a **7-day annual intro free trial** (see §3).

- **Engineering now:** large — full `F1–F6` *plus* the **offline entitlement cache (F4) is mandatory** for an offline-first app (MON-09).
- **Pros:** revenue from day 1; validates willingness-to-pay directly; built right once.
- **Cons:** adds a heavy workstream to an already-blocked release; subscription App Store review surface (disclosures, restore, terms — MON-05/06); high risk of tuning price/gating **before** PMF; pricing against entrenched incumbents with an unproven moat.
- **Effects:** Conversion **unknown** (pre-PMF); Revenue **on**; Churn risk **higher** (untested funnel); App Store acceptance **adds risk**; Timeline **longer**.

### Option C — **Build full Plus + Pro two-tier (plan as written)** ❌ *Not recommended*
Defer. Two paid tiers pre-PMF multiply funnel and pricing risk (BUSINESS-1). Collapse to one tier first; split later only if data justifies it.

---

## 3. The "15-day unrestricted free trial" — **reject it** (audit brief asked us to challenge this)

A 15-day *unrestricted* trial is the wrong instrument:
- **Unenforceable offline** without an entitlement cache (which doesn't exist) — an offline-first app can't reliably expire it (MON-09).
- **Gives away all value with no payment commitment** → low trial→paid; trains users to extract value then leave.
- **Abuse-prone** (reinstall / new Apple ID).
- **Contradicts the plan's own value-event model** (plan:700-705) and the >15% trial→paid KPI is unrealistic for this pattern.
- **Not first-class in StoreKit** — you'd hand-roll trial-expiry logic instead of using Apple's primitives.

**Recommended trial strategy (when monetizing, Option A fast-follow or Option B):**
- A **usable free tier** underneath (habit formation), plus
- **StoreKit 2 introductory offer = 7-day free trial on the ANNUAL plan only, payment method captured up front** → auto-converts, abuse-resistant via Apple per-Apple-ID eligibility, and pushes the **annual mix that churns ~3× less** (plan:810), plus
- **Value-event-triggered paywall** (after 10 tx / first OCR / first report / first split / cap hit), not a first-launch wall.
- Optional shorter **3-day trial on monthly** for the hesitant.

**Expected effects vs 15-day unrestricted:** higher trial→paid (payment on file + scarcity), lower involuntary leakage, lower abuse, cleaner App Store compliance (intro offers are native to `SubscriptionStoreView`), better annual-mix economics.

---

## 4. Recommended feature split (when the single tier ships)

| Tier | Includes |
|---|---|
| **Free** (generous, habit-forming) | Unlimited manual transactions, all core categories, accounts & budgets (uncapped pre-PMF — caps are retention friction; revisit later), dashboards (current + historical), CSV export, **iCloud sync (free baseline)**, a few OCR scans/month |
| **Paid (one tier)** | **Full tax planning & regime comparison**, **unlimited OCR**, **advanced/custom reports + PDF export**, recurring automation, advanced debt/split, future ML insights |

- **Do not** gate sync (MON-04 option a): gating it creates a downgrade-migration nightmare and a worse privacy/UX story; re-anchor paid value on tax/OCR/reports.
- **Do not** market Watch/Widgets/Siri/Vision as paid value until those extensions exist (MON-14).
- **Pricing (set with data, not now):** single tier ≈ US **$4.99–5.99/mo**, **$39.99–49.99/yr** (intro), undercutting YNAB; India custom **INR ~199/mo, ~999–1,299/yr** via per-storefront price points (MON-11) — never Apple's auto-conversion. **Family Sharing** decided per-product at creation (MON-10) — defer.

---

## 5. Recommendation

**Choose Option A: launch free, instrument the funnel now, introduce a single paid tier as a fast-follow once retention/PMF is shown** — with the §3 trial strategy and §4 split when you monetize.

Why: monetization isn't on the critical path to beta; pre-PMF the scarce resource is *learning*, not revenue; Option A ships fastest, carries the least App Store risk, tells the cleanest privacy story, and lets you price from data. Build StoreKit once you can see which features retain users and what they'd pay for.

If revenue-at-launch is a hard business constraint, take **Option B with ONE tier** (never the two-tier plan) — and budget F1–F6 **including** the mandatory offline entitlement cache.

---

## 6. What this changes for the build queue

- **If Option A:** Cursor executes `F5` (tracker, free), a small "sync is free baseline" change, and `D5` (marketing scope); **skip F1–F4**; keep `F6` legal cleanup minimal (no subscription clauses yet). Add a backlog epic "Monetization fast-follow (single tier)" for post-PMF.
- **If Option B:** Cursor executes `F1–F6` in full (F4 offline cache mandatory), single-tier only; reconcile App Store metadata (D5) and ToS subscription disclosures (F6) before submission.
- **Either way:** the `D5` (metadata reflects shipped scope) and `MON-14` (no nonexistent paid features) cleanups apply.

---

## 7. Decision record stub (paste into `DECISION_LOG.md` once decided)

```
### <date> — Monetization launch model (F0)
Decision: <Option A: launch free + fast-follow single tier | Option B: single paid tier at launch>
Rationale: <one paragraph>
Trial strategy: 7-day intro free trial on annual (payment on file) + value-event paywall; 15-day unrestricted trial rejected (unenforceable offline, abuse-prone, low convert).
Paid value: tax planning, unlimited OCR, advanced reports/PDF. Sync = free baseline. No Watch/Widget/Siri marketing until shipped.
Build impact: <F5 + sync-free + D5 / defer F1–F4  |  full F1–F6 single-tier>
Pricing: set with data; single tier ~US$4.99–5.99/mo, $39.99–49.99/yr intro; India custom INR price points.
Owner: <name>   Revisit: after <N> weeks of retention data.
```
