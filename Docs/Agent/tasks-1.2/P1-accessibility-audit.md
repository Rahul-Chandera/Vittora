# P1 — Accessibility audit: VoiceOver, Dynamic Type, contrast

**Branch:** `feature/p1-accessibility` · **PR into:** `develop` ·
**Review tier: B** · **No dependencies** (parallel-safe with WA track)

## Context

Plan M3.7.6, pulled forward: accessibility is a launch-quality property,
not a V2 feature, and it's cheapest before surface area grows. The app
already has scattered `accessibilityLabel`s; this task makes it
systematic.

## Scope

1. **VoiceOver pass over the five core flows** (iPhone): dashboard,
   add-transaction, transaction list + detail, budgets, reports home +
   one report. Every interactive element gets a meaningful label/hint;
   decorative images get `accessibilityHidden(true)`; amount labels read
   as currency (not digit soup); charts get `accessibilityValue`
   summaries (the R1/R3 pattern with per-element values already exists —
   extend it, don't invent a new one).
2. **Dynamic Type**: audit at `.accessibility3`. Fix clipped/truncated
   text in the five core flows — prefer layout that adapts
   (`ViewThatFits`, vertical fallbacks) over `minimumScaleFactor`
   everywhere.
3. **Contrast**: check VColors text/secondary/muted pairs against WCAG AA
   (4.5:1 normal text) in light and dark; adjust the failing tokens in
   `VColors` only — do not fork per-screen colors. Include a
   before/after token table in the PR.
4. Fix what the audit finds **in these five flows only**; file a
   follow-up list (in the PR description) for anything found outside
   them. Keep the diff reviewable — this is an audit + targeted fixes,
   not a rewrite.
5. Add `AccessibilityAuditUITests`: XCUITest's `performAccessibilityAudit()`
   on the five flows (iOS 17+ API), so regressions fail CI.

## Non-goals

macOS/iPad-specific keyboard navigation (follow-up), Watch surfaces
(WA tasks carry their own labels), localization of labels beyond the
existing String(localized:) pattern.

## Acceptance criteria

- [ ] `performAccessibilityAudit()` passes for the five flows.
- [ ] Screenshots at `.accessibility3` for each flow — no clipped text.
- [ ] Contrast table in PR; failing tokens fixed in `VColors`.
- [ ] Follow-up list for out-of-scope findings included in the PR.
- [ ] `make test` green; no committed binaries.
