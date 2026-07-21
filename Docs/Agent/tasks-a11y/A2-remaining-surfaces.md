# A2 — Accessibility sweep: remaining app surfaces

**Branch:** `feature/a2-accessibility-remaining-surfaces` ·
**PR into:** `develop` · **Review tier: B**

## Context

P1 (release 1.2) fixed VoiceOver, Dynamic Type and WCAG AA contrast on
**five core flows** — dashboard, add-transaction, transaction
list/detail, budgets, reports home + monthly overview — and locked them
with `AccessibilityAuditUITests` running `performAccessibilityAudit()`.

It explicitly deferred everything else. This task closes that gap for the
remaining **iOS/iPadOS** surfaces. The audit infrastructure already
exists — extend it, don't rebuild it.

## Scope — surfaces to bring up to the P1 standard

Every one gets the same treatment P1 applied: VoiceOver labels/hints,
decorative icons hidden, amounts read correctly, Dynamic Type to
`.accessibility3` without clipping, and AA contrast.

1. **Tax** — dashboard, profile form, breakdown, comparison (India +
   US). High priority: it is a launch-market feature.
2. **Savings** — goal list, goal detail, contribution flow.
3. **Splits** — group list, group detail, add-expense, settle-up.
4. **Debt** — ledger, entry form, settlement.
5. **Settings** — all sections, including the 1.3 additions (appearance/
   themes, notification scheduling, Spotlight privacy toggle).
6. **Onboarding** — first-run flow. First impression, and currently
   unaudited.
7. **Payees, Categories, Accounts, Recurring, Documents** — list + form
   for each.
8. **New 1.3 reports** — 50/30/20 and Emergency Fund. These shipped
   after P1 and were never audited; their charts and status bands need
   `accessibilityValue` summaries like R1/R3 got.

## Also in scope — the two P1 follow-ups that apply here

- **44pt minimum hit targets** across compact chrome. P1's audit ignored
  `.hitRegion`; stop ignoring it and fix what it reports.
- **Reduce Motion**: honour `accessibilityReduceMotion` for the app's
  animations (progress rings, chart reveals, the budget-alert
  transition). Motion should degrade to a cross-fade or none, not be
  removed entirely.

## Non-goals

macOS/iPad **keyboard navigation** and Watch/widget accessibility — those
are task A3, running in parallel. Do not touch them; you will conflict.
Also out: redesigning any screen, or changing copy beyond accessibility
labels.

## How to work (important for reviewability)

- Extend `VittoraUITests/AccessibilityAuditUITests.swift` with an audit
  test per surface group, reusing the existing helper. Do **not** create
  a parallel test file.
- The audit must run with `--ui-test-seed-demo` so screens have real
  content — an empty screen passes trivially and proves nothing.
- If Apple's contrast sampler produces the known false positives on
  decorative chart marks (P1 documented this), keep P1's existing
  handling; do not silence whole audit categories to make tests pass.
  **Never** disable an audit type to get green — fix the issue or, if it
  is genuinely a false positive, narrow the exclusion to that element and
  say so in the PR.

## Acceptance criteria

- [ ] `performAccessibilityAudit()` passes on every surface listed above.
- [ ] `.accessibility3` screenshots for each surface group, no clipped or
      truncated text (gitignored `verification/`, attached to the PR).
- [ ] 44pt hit-target audit enabled and passing (or per-element
      exclusions justified individually in the PR).
- [ ] Reduce Motion honoured — demonstrate with a before/after on at
      least one animated surface.
- [ ] The 1.3 report charts expose `accessibilityValue` summaries.
- [ ] P1's original five-flow audits still pass — no regressions.
- [ ] `make test` green.

## Verification steps

1. Run the full `AccessibilityAuditUITests` suite on the assigned
   simulator; paste the pass list in the PR.
2. VoiceOver spot-check the Tax and Onboarding flows specifically (the
   two highest-stakes unaudited surfaces) and describe what is announced.
3. Screenshots at `.accessibility3` per surface group.
