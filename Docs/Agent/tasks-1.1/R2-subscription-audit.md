# R2 — Subscription audit report

**Branch:** `feature/r2-subscription-audit` · **PR into:** `develop` ·
**Review tier: B** (post-merge review) · **No dependencies**

## Context

Recurring rules already exist (`RecurringRuleEntity`, recurring
generation). This report answers "what am I actually paying for every
month?" — a high-love, low-effort feature (plan M2.8.7).

## Scope

1. New report **"Subscription Audit"** on the Reports home list (icon:
   `arrow.triangle.2.circlepath`; follow the existing report-row
   pattern).
2. Content: all active recurring **expense** rules, sorted by monthly
   cost descending. Each row: name, category, cadence, amount,
   **normalized monthly cost** (weekly ×52/12, yearly ÷12, etc.) and the
   date it last ran. Header totals: monthly total + annual total.
3. A gentle insight line, factual not judgmental: "12 recurring charges ·
   $86.40/month · $1,036.80/year". No cancellation advice claims —
   surface the numbers only.
4. Normalization math lives in VittoraCore with unit tests for every
   cadence the app supports (use existing cadence enum — don't invent
   one).
5. Empty state: no recurring expenses → prompt to create one.

## Non-goals

Cancellation deep links, price-change detection, notifications,
subscription categorization heuristics.

## Acceptance criteria

- [ ] Report renders on iPhone/iPad/Mac with the demo dataset (Netflix
      rule appears with correct monthly/annual normalization).
- [ ] Normalization unit tests cover every cadence; totals =
      sum of rows (test).
- [ ] Paused/ended rules excluded.
- [ ] Empty state renders.
- [ ] `make test` green.

## Verification steps

1. Screenshots on iPhone + Mac with demo data.
2. One hand-checked normalization in the PR description (e.g. weekly
   $10 → $43.33/month).
3. `make test` summary.
