# W1 — Year in Review ("Vittora Wrapped")

**Branch:** `feature/w1-year-in-review` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (money display) ·
**Parallel-safe:** yes (with L2)

## Context

Plan M3.7.5, identified in the plan's own §Viral Growth Loops as the
strongest sharing mechanic available to us: a Spotify-Wrapped-style annual
spending summary the user actually wants to show people.

**It is built now specifically because it is deadline-bound.** To be useful
it must ship before December; building it in November means one bad CI week
costs a full year of value. Building it in July removes that risk entirely.
It is also independent of launch data — it renders whatever history the user
has, and the demo seed exercises it for verification.

## Scope

An annual summary screen, reachable from Reports, that presents the user's
year as a short sequence of cards:

1. **Total spent** for the year, with the month-by-month shape.
2. **Top categories** — the three or four they spent most on, with amounts
   and share of total.
3. **Biggest single month** and what drove it.
4. **Top payees / merchants** by total spend.
5. **Savings** — total contributed to savings goals, and goals completed.
6. **A milestone or two**: longest streak of days with a logged transaction,
   number of transactions recorded, first-ever transaction date.
7. **A closing card** suitable for sharing.

### Sharing

- Render the summary to a **shareable image** (portrait, story-shaped) via
  `ImageRenderer`, offered through the standard share sheet.
- **The shared image must contain no amounts by default.** Ship a privacy
  toggle — *"Include amounts"*, default **off** — so the default share is
  shapes, categories and counts, not the user's finances. Someone sharing
  their Wrapped to social media must not leak their income by accident.
  This is the single most important design decision in this task.
- Include a tasteful "Made with Vittora" mark on the shared image only.

## Money-math requirements (Tier A)

- `Decimal` throughout; no float literals (AGENTS.md rule 8).
- **Never derive a displayed total by inverse arithmetic** (rule 2). Each
  displayed figure is summed from its own column. A test must assert that
  the category amounts shown sum to the displayed year total.
- Percentages are computed from the displayed amounts, and a test must
  assert the displayed shares sum to 100% within the displayed rounding —
  the screen must not show parts that disagree with their whole.
- Pure math lives in `VittoraCore` (`YearInReviewMath`) with an injected
  "today" — no `Date()` inside the calculation.
- **Multi-currency**: if the user has transactions in more than one
  currency, do **not** silently sum them. Either scope the summary to the
  primary currency and say so, or present per-currency — but never add
  different currencies into one number.

## Empty and thin states

- **Fewer than ~20 transactions or less than 2 months of history**: show an
  encouraging "your Wrapped will be ready once you've tracked more" state.
  Do not render a summary that makes a new user's sparse data look sad —
  that is the opposite of shareable.
- Zero transactions in the selected year → offer the previous year if it has
  data, otherwise the empty state.
- The year selector must let the user view any year they have data for, not
  only the current one.

## Non-goals

Comparisons against other users or any benchmark, predictions for next year,
advice about spending, server-side rendering or a web share link, and
animation-heavy transitions (keep it calm and accessible).

## Accessibility (non-negotiable — audits are enforced)

- Every card passes `performAccessibilityAudit` at standard **and**
  accessibility Dynamic Type sizes.
- Charts carry real accessibility labels conveying the same information as
  the visual; decorative marks are hidden from VoiceOver.
- Respect Reduce Motion for any card transition.
- Works in light, dark, and OLED black.

## Acceptance criteria

- [ ] Renders on iPhone, iPad and Mac with the demo dataset.
- [ ] PR body contains a **hand-computed** year total and top-category
      breakdown for the US demo data matching the screen; the reviewer
      recomputes it independently.
- [ ] Unit tests: year total, top categories, biggest month, streak
      calculation, savings totals, multi-currency handling, a
      single-transaction year, and an empty year.
- [ ] Test asserting displayed category amounts sum to the displayed total.
- [ ] Test asserting the shared image contains **no amounts** when the
      include-amounts toggle is off.
- [ ] Accessibility audits pass at standard and XL sizes.
- [ ] `make test` green.
- [ ] **Reviewer sign-off posted before merge.**
