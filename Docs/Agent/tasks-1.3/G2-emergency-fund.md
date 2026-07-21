# G2 — Emergency fund tracker

**Branch:** `feature/g2-emergency-fund` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (money math)

## Context

Plan M3.6.2. Answers "how many months could I cover if income stopped?"
Target is 3–6 months of **essential** monthly expenses. Like G1, this is
useful on day one because the essentials baseline can come from recurring
rules even before much history exists.

## Scope

1. **Essential monthly expenses baseline**, computed in this priority order
   (fall through when the earlier source is unavailable):
   a. Active recurring **expense** rules classified `needs` (reuse G1's
      `SpendingBucket` if merged; if G1 has not merged yet, define the
      minimal shared piece and note the coupling in the PR), normalized to
      monthly with `SubscriptionCostNormalization` — do **not** re-implement
      cadence math.
   b. If no recurring rules: average monthly `needs` spending over the
      available history (use the **available** window; never divide by a
      fixed 3 or 6 when the user has less history — this is the R3 lesson).
   c. Neither available → empty state prompting the user to add recurring
      items, not a zero or a fabricated number.
2. **Current fund** = sum of balances of accounts the user marks as
   emergency-fund sources + savings goals flagged as emergency funds. Add
   an `isEmergencyFund` flag to savings goals (schema migration) and let
   the user pick contributing accounts.
3. **Coverage** = currentFund ÷ essentialMonthly, shown in months to one
   decimal, with status: under 3 months (build up), 3–6 (on track), over 6
   (comfortable).
4. **Pure math in VittoraCore** (`EmergencyFundMath`), injected "today".
5. **Report screen** on Reports home: coverage in months, a progress arc
   to the 3-month and 6-month marks, current fund and monthly-essentials
   figures, and the shortfall to 3 months if under.
6. **Disclaimer on screen** — general guideline, not advice.

## Non-goals

Recommending how much to save per month, auto-allocating to the fund,
investment advice of any kind, projecting the fund forward.

## Money-math requirements (Tier A)

- `Decimal` throughout, no float literals; guard division by zero when
  essentials are zero.
- Coverage months must be derived from the two displayed figures — a test
  must assert `currentFund == coverageMonths * essentialMonthly` within
  the displayed rounding, so the screen cannot show three numbers that
  disagree.
- Reuse `SubscriptionCostNormalization` for cadence → monthly. Do not
  write a second cadence table.

## Acceptance criteria

- [ ] Report renders on iPhone/iPad/Mac with the demo dataset.
- [ ] PR description contains a **hand-computed** coverage figure for the
      US demo data matching the screen; the reviewer recomputes it.
- [ ] Unit tests for each baseline source (recurring rules; history
      fallback; neither), a short-history user (uses available window, not
      a fixed divisor), zero-essentials, and the three status bands.
- [ ] Migration test for the savings-goal `isEmergencyFund` flag.
- [ ] Disclaimer visible on screen.
- [ ] `make test` green.
- [ ] **Reviewer sign-off posted before merge.**
