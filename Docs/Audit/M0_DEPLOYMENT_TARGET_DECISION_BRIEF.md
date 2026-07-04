# M0 — Deployment-Target / Market-Reach Decision Brief

**Independent Review Board · Confidential · 2026-07-02**
**Decision owner:** Rahul · **Analysis:** review board · **Status:** ✅ **DECIDED — Option A (keep iOS 26 / macOS 26)**, 2026-07-02
**Companion to:** `F0_MONETIZATION_DECISION_BRIEF.md` (same decide-before-build pattern) · flagged as the top open business input in `RESCORE_2026-06-30.md` §4.1 and `FINAL_VERIFICATION_2026-07-02.md` §5.

---

## 1. The question

The app currently ships with a **minimum OS of iOS 26 / macOS 26** (all 12 build settings). The original plan targeted **iOS 18 / macOS 15**. Requiring the newest OS as the floor caps addressable devices — most sharply on older iPhones (a large cohort in India) and Intel Macs. Which floor do we launch with?

**Key finding that reframes the decision:** a full API audit of `refactoring` (2026-07-02) found **zero iOS-26-only API usage** — no Liquid Glass (`glassEffect`, glass buttons), no FoundationModels, no `#available(iOS 26)`/`#available(macOS 26)` anywhere. The floor-setting APIs actually in use are:

| API in use | Count | Minimum OS |
|---|--:|---|
| `.tabViewStyle(.sidebarAdaptable)` + `Tab(_:image:value:)` | 1 + 9 | **iOS 18 / macOS 15** ← the true floor |
| `@Observable` / SwiftData / `ContentUnavailableView` / `symbolEffect` | 51 + 16 | iOS 17 |
| `ImageRenderer` / `ShareLink` | 16 | iOS 16 |
| `Settings{}` scene / `windowResizability` | 1 | macOS 13 |

**The 26.0 floor is an incidental SDK default, not an engineering constraint.** Lowering to exactly 18/15 requires **no code fallbacks at all** — only build settings, a CI leg, and QA.

## 2. Market evidence

*Numbers below are review-board estimates from public adoption patterns (knowledge basis: early-2026); **verify against App Store Connect → App Analytics and Apple's developer adoption page before finalizing.***

- **iOS version adoption:** iOS 26 (rel. Sept 2025) is plausibly ~75–85% of recent-4-year devices by now, and becomes **N-1 when iOS 27 ships (~Sept 2026)** — so for a fall-2026 public launch, a 26 floor covers ~85–90%+ of *OS-upgradable* devices.
- **The sharper edge is hardware, not willingness to update:** iOS 26 **dropped iPhone XR / XS / XS Max (2018)**; iOS 18 supports them. A 26 floor permanently excludes that cohort — small in the US, **materially larger in India**, where iPhone service life is long and the XR was a top seller. If **Wave-1 = India** (which the India tax engine — our differentiator — implies), this cohort is real target-market loss.
- **macOS:** Tahoe (26) dropped most 2018–2019 Intel Macs and adoption lags iOS (~55–65% of active Macs by now, est.); Sequoia (15) reaches 2018+ broadly. A 26 floor meaningfully shrinks the Mac audience — though Mac is the companion platform, not primary.
- **US-only premium segment:** skews current hardware/OS; a 26 floor is nearly costless there by fall.

## 3. Engineering cost & a hidden benefit (evidence-based)

**Cost of lowering to 18/15** (small, because the audit proves no fallbacks needed):
1. Flip 12 `*_DEPLOYMENT_TARGET` build settings (app + tests + VittoraCore package platforms).
2. Add an **iOS 18 simulator CI leg** so the floor is continuously proven (keep the iOS 26 leg).
3. **Runtime-risk QA, the real work:** SwiftData + CloudKit behavior on iOS 18.x differs in maturity from 26 — run the full suite + manual pass on an 18.x simulator and at least one physical 18 device (migration V1→V6, sync, app-lock, notifications). Budget the QA seriously even though the code compiles unchanged.
4. Dual visual QA: classic (18–25) vs Liquid Glass (26) rendering — SwiftUI handles it, but screens should be eyeballed on both.
5. Estimated effort: **~2–4 Cursor-days + one QA sweep**, then ongoing two-OS-generation QA per release.

**Hidden benefit of macOS 15:** GitHub's `macos-15` runners **cannot execute our macOS-26-target tests today** (why CI runs everything on the iOS simulator). A macOS 15 floor lets CI run the macOS-host unit suites natively (`make test-tax/test-sync/test-data`, the `#if os(macOS)` paths) — **partially closing TESTING-4**, one of the public-launch verification conditions.

## 4. Options

| | **A — Keep 26/26** | **B — Lower to 18/15 (recommended if India is Wave-1)** | **C — Split: iOS 18 / macOS 26** |
|---|---|---|---|
| Eng cost | 0 | ~2–4 days + QA sweep | ~2–3 days (iOS only) |
| Reach | Fine for US-centric fall launch (N-1 by then); excludes 2018 iPhones + Intel Macs; weak for India | Max reach; matches original plan; recovers XR/XS cohort + Intel Macs | Recovers the iPhone cohort where reach matters; Mac stays modern |
| Ongoing QA | 1 OS gen | 2 OS gens (iOS + macOS) | 2 gens iOS only |
| CI | Status quo (mac tests can't run natively) | **+ native macOS CI tests (TESTING-4 win)** | No mac-CI win |
| Risk | Market-reach risk in India | SwiftData-on-18.x runtime unknowns (QA-able) | Mixed floors = slight config/story complexity |

## 5. Recommendation

1. **Beta (now): keep 26/26.** Zero cost, beta testers skew current-OS, nothing blocks TestFlight today.
2. **Decide Wave-1 market first (Epic M) — the floor is downstream of it:**
   - **Wave-1 includes India → Option B (iOS 18 / macOS 15)** before public launch. The XR/XS cohort + reach math + the TESTING-4 CI benefit justify the ~2–4 days; the audit proves it's cheap.
   - **Wave-1 = US-only → Option A is defensible** for launch (26 is N-1 by fall); schedule B as a fast-follow when India ships.
3. Either way, **verify the live App Store Connect device/OS data** before signing the decision — this brief's adoption figures are estimates.
4. If B is chosen, run it as a scoped epic (**N1**): settings flip → iOS 18 CI leg green → SwiftData/CloudKit QA on 18.x sim + 1 physical device → dual visual pass → flip. Do not lower the floor without the CI leg proving it.

## 6. Decision record

| Field | Value |
|---|---|
| Decision | ✅ **A — keep iOS 26 / macOS 26** |
| Decided by / date | Rahul · 2026-07-02 |
| Stated rationale | (1) Best-in-class UI — adopt **Liquid Glass**, unavailable on older OSes. (2) Planned advanced features (**OCR, AI**) will need frameworks unavailable on older versions (e.g. FoundationModels / Apple Intelligence is iOS 26+; newest Vision/ML APIs track the latest OS). |
| Board note | Forward-looking platform bet: accepts the reach cost (2018-iPhone cohort — significant in India — and pre-Tahoe Intel Macs) in exchange for a single modern design/runtime target. Coherent; the reach cost must now be priced into the Wave-1 market analysis. |
| Follow-on | **(a)** Wave-1/GTM TAM math must use **iOS-26-capable devices** (iPhone 11+/SE2+; Apple-Silicon-era Macs). **(b)** *Use what we're paying for:* log roadmap epic to actually adopt 26-only capabilities — Liquid Glass UI pass, FoundationModels-powered categorization (K6 upgrade), latest-Vision OCR (receipt parsing upgrade) — else the floor costs reach and buys nothing. **(c)** Caveat for AI features: Apple Intelligence has **hardware** gates beyond the OS floor (recent-generation iPhones) — design AI features as progressive enhancement, not core-path. **(d)** TESTING-4 stays manual (macOS-host CI tests remain blocked until GitHub ships macOS-26 runners — the benefit arrives free when they do). **(e)** D5 metadata: state device/OS requirements plainly. **(f)** No N1 epic; the 26.4→26.0 alignment already done stands. |
