# R3 — Cash-flow forecast report (STRETCH — do not start until W-track and R1/R2 are merged)

**Branch:** `feature/r3-cashflow-forecast` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (money math)

## Context

Plan M2.8.5. Projects account balance forward using recurring rules +
average discretionary spend. This is estimation math shown next to real
balances — the reason it's Tier A: a wrong projection displayed
confidently damages trust in the whole ledger.

## Scope

1. New report **"Cash Flow Forecast"**: 90-day projection line chart of
   total balance across accounts. Inputs:
   - scheduled recurring incomes/expenses (actual dates from the rules);
   - average daily discretionary spend over the trailing 90 days
     (total non-recurring expenses ÷ days), applied per future day.
2. Clearly labeled as an estimate: subtitle "Projection based on your
   recurring items and recent spending — not a guarantee."
3. Forecast math in VittoraCore, pure and deterministic (inject "today");
   exhaustive unit tests: no recurring rules, only income, only expenses,
   rule ending mid-window, new user with <90 days history (use available
   window), zero-history user (flat line from recurring only).
4. Chart uses the existing Reports charting components/styling.

## Non-goals

Scenario planning ("what if I cancel X"), per-account forecasts, alerts,
ML anything.

## Acceptance criteria

- [ ] Forecast for the demo dataset is hand-verifiable: PR description
      includes the manual computation for day 30 matching the chart.
- [ ] All listed edge-case unit tests pass.
- [ ] Estimate disclaimer visible on the screen.
- [ ] `make test` green.
- [ ] **Pre-merge reviewer sign-off posted on the PR before merging.**

## Verification steps

1. Screenshots iPhone + Mac with demo data.
2. Manual day-30 computation vs chart value in the PR description.
3. `make test` summary.
