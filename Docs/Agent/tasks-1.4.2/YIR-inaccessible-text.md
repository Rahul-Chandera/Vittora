# YIR — "potentially inaccessible text" on iPhone 17 Pro Max

**Tracked debt, deferred from 1.4.1.** Not a regression: it exists on
`develop` today and only surfaced because PR #170 made CI's simulator
selection deterministic, pinning it to the device where it reproduces.

## Symptom

`YearInReviewAccessibilityUITests` — both `testYearInReviewAccessibilityAudit­StandardSize`
and `...XLSize` fail with:

```
This element appears to display text that should be represented using the
accessibility API.
```

**Only on iPhone 17 Pro Max.** iPhone 17 Pro and iPhone 16 pass the same
commit, on iOS 26.4 and 26.5.

## Why it is currently excluded rather than fixed

The audit attributes the issue to the **application element**, not to any
child view, and exports only a whole-window screenshot — so there is nothing
to point at. Three plausible causes were tested and **ruled out**:

1. **Card grouping.** `accessibilityElement(children: .ignore)` on the four
   cards → changed to `.combine`. No effect.
2. **Swift Charts axis labels.** Charts draws its own axis text without an
   accessibility element. An explicit `chartYAxis` was added (there was none,
   so Charts generated "3,000/2,000/1,000/0" internally) and both axes now use
   explicit `Text`. Kept — it is the right thing — but no effect on this issue.
3. **Hidden visible text.** Two `Text` views carrying visible copy were marked
   `.accessibilityHidden(true)`, which is a real VoiceOver defect: sighted
   users read the share-privacy explanation and "Total spent", VoiceOver users
   did not. **Fixed** while investigating. No effect on this issue.

The exclusion is scoped to `.elementDetection` on this one screen.
Every other audit category — contrast, clipping, Dynamic Type, hit region —
still fails loudly on Year in Review.

## What to try next

- Dump `app.debugDescription` at audit time on a 17 Pro Max and diff the
  accessibility tree against 17 Pro to find what differs on the wider screen.
- Suspect the share-sheet toolbar item or the `VCard` background, both of
  which render differently at that width.
- Retest on a newer Xcode: if this is an Apple bug in the audit's element
  attribution, it may simply disappear, and the exclusion should then be
  removed rather than left to rot.

## Acceptance

- [ ] Root cause identified and fixed in the UI.
- [ ] The `.elementDetection` case removed from
      `YearInReviewAccessibilityUITests.performAudit()`.
- [ ] Both YIR audits pass on iPhone 17 Pro Max **and** 17 Pro **and** 16.
