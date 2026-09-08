# Audit contrast false positives — two audits still deferred

**Updated 2026-08-07.** Two of the four audits this file used to cover now
pass; the root cause behind them is fixed. The remaining two are blocked by a
different problem than this file originally described.

Originally deferred: `testTaxSurfacesAccessibilityAudit`,
`testSettingsSectionsAccessibilityAudit`,
`testAccessibility3ScreenshotsForRemainingSurfaces`,
`testSplitSurfacesAccessibilityAudit`.

| audit | state |
|---|---|
| `testSplitSurfacesAccessibilityAudit` | ✅ re-enabled, passing (#196) |
| `testTaxSurfacesAccessibilityAudit` | ✅ re-enabled, passing (#196 + #197) |
| `testSettingsSectionsAccessibilityAudit` | ✅ re-enabled, passing (#197) |
| `testManagedListsFormsAndDocumentsAccessibilityAudit` | ❌ still skipped |
| `testAccessibility3ScreenshotsForRemainingSurfaces` | ❌ still skipped |

## What the original theory got right, and what caused it

This file previously said the audit "samples an element whose reported frame is
shorter than the text it renders, so it measures a clipped strip of antialiased
pixels rather than the text itself", evidenced by element screenshots showing
only the **top half of the glyphs**.

That observation was correct. The cause was found in #197:

`safeAreaInset(edge: .bottom)` — used on fifteen screens to reserve room for the
floating tab bar — places an **actual view**. Being opaque, it painted *over* the
scrolling content, and rows passing behind it were cut mid-glyph. The audit then
sampled a sliver that is ~90% background with a thin dark line, and reported a
contrast failure on text that is genuinely ~18:1.

The fix is `safeAreaPadding`, which reserves the same space without drawing.
It is applied only to screens whose content is a stack of cards; Dashboard and
the report screens keep the inset, because without something drawn there their
content renders in the gutter below the tab bar and the audit reports text with
no accessible element. See the comments at each call site.

This also explains the "reproduces only on iPhone 17 Pro Max" note: screen
height determines exactly which row lands under the strip.

## What still blocks the last two

Re-measured 2026-08-07 on iPhone 17 Pro Max / iOS 26.2, both skips removed,
full class run in order:

* The old numbers are gone. The file claimed 15 mis-sampled contrast elements
  and 3 genuine `elementDetection` findings. Actual: **3 contrast, zero
  `elementDetection`**.
* **The blocker is variance, not a count.** Two runs of near-identical code
  produced **1** and then **10** contrast findings in
  `testManagedListsFormsAndDocuments`.
* The surviving element screenshots are **clean, fully rendered** dark-on-light
  text — "Monthly", "13 Aug 2026", "Amount" — black on white or `#F2F2F7`. Not
  half-glyphs. So the frame-clipping explanation above does **not** cover what
  is left; these are a different, unexplained sampler instability.
* **The whole class is nondeterministic, not just these two.** Measured
  directly: the same commit, same device, run twice back to back —

  | run | result |
  |---|---|
  | 1 | 14/15, `testSettingsSectionsAccessibilityAudit` failed |
  | 2 | **15/15** |

  No code changed between them. This is the same property that let #196 sit
  green on CI for days over a real defect (the strip slicing the Appearance
  screen's Live Preview card) and only fail once a rebase reshuffled the run.
  **A green audit run does not establish that the audits found nothing.**

One finding is understood and not a defect: the onboarding screen at
AccessibilityXL reports a **nil-element** contrast issue, on a screen whose only
sub-AA element is the brand-green "Get Started" CTA — the accepted DEC-012 miss.
It is already exempted by label, but a nil element carries no label to match.

## Fixed along the way

* `RecurringFormView` used a bare `Text(…).font(.headline)` for its "Amount"
  heading — the last form in the app not using `VFormSectionHeader`. The audit
  exclusion keys on that component's identifier, so the outlier never matched.
  Visually identical after the swap.
* `DebtLedgerView` was a card stack still on `safeAreaInset`, and its card was
  being sliced at AccessibilityXL. Moved to `safeAreaPadding`.

## Known remaining inconsistency

`SavingsGoalListView` and `SplitGroupListView` are card stacks still on
`safeAreaInset`. Their audits pass, so they were left alone rather than changed
without evidence — but they contradict the rule the other card screens now
carry in their comments.

## What to try next

- Determine why the finding count varies run to run on identical code. Until
  that is understood these two cannot be gates: green would prove nothing.
- Retest on a newer Xcode — if the sampler instability is an Apple bug it may
  resolve upstream.
- Consider whether the class should be forced to run in a fixed order in CI.
  A green check today does not prove the audits found nothing: #196 sat green
  over a real defect for days, and only failed once a rebase reshuffled the run.

## Acceptance

- [ ] Finding count is stable across repeated runs of identical code.
- [ ] The two `XCTSkip` blocks removed.
- [ ] `testManagedListsFormsAndDocumentsAccessibilityAudit` and
      `testAccessibility3ScreenshotsForRemainingSurfaces` pass unaided on
      iPhone 17 Pro Max, across repeated runs.
