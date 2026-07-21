# G1 — 50/30/20 needs / wants / savings analysis

**Branch:** `feature/g1-fifty-thirty-twenty` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (money math)

## Context

Plan M3.6.1. Compares the user's actual spending against the 50/30/20
guideline (50% needs, 30% wants, 20% savings/debt repayment) for a chosen
month. Works from a single month of data, which is the point: it gives a
brand-new user something useful immediately.

Categories are user-editable, so the classification cannot be hardcoded to
category names. Design it as: a **`SpendingBucket` enum (needs / wants /
savings)** stored per category, with sensible defaults applied to the
seeded default categories and a user override in the category edit screen.

## Scope

1. **`SpendingBucket`** (`needs`, `wants`, `savings`) added to
   `CategoryEntity` + schema migration. Defaults for the seeded categories:
   - **needs** — Rent, Groceries, Utilities, Transport, Health, Insurance
   - **wants** — Dining, Entertainment, Shopping, Subscriptions, Travel
   - **savings** — treated separately (see 3); no expense category defaults here.
   Uncategorized expenses count as **wants** (documented, not silent).
2. **Picker in the category form** to change a category's bucket, so the
   user owns the classification. Changing it must recompute the report.
3. **Savings side** = contributions to savings goals + debt *repayments*
   in the period, NOT an expense category. Income is the denominator.
4. **Pure math in VittoraCore** (`FiftyThirtyTwentyMath`), injected
   "today"/period. Percentages of **income**, per the guideline.
5. **Report screen** "50/30/20" on the Reports home: three rows
   (actual % vs target %, amount, over/under), a stacked bar, and a plain
   verdict line ("Needs are 8 points over the guideline").
6. **Disclaimer on screen**: this is a general guideline, not advice —
   consistent with the Terms and the existing tax-estimator disclaimer.

## Non-goals

Automatic re-classification suggestions, ML, per-category drilldown,
changing how budgets work, historical trend of the ratio.

## Money-math requirements (Tier A)

- Percentages computed from `Decimal` sums; **no float-literal Decimals**
  (`Decimal(string:)` or integers only).
- **Do not derive one bucket by subtraction** from the others — sum each
  bucket from its own transactions, then assert in a test that the three
  sums equal total spending. (R2 shipped a wrong annual total by deriving
  it with inverse arithmetic; do not repeat it.)
- Zero income in the period → show "Add income to see this comparison",
  not a divide-by-zero or a 0%/∞ result.

## Acceptance criteria

- [ ] Report renders on iPhone/iPad/Mac with the demo dataset.
- [ ] PR description contains a **hand-computed** needs/wants/savings split
      for the US demo month that matches the screen. The reviewer will
      recompute it independently.
- [ ] Category bucket override persists and changes the report.
- [ ] Unit tests: default classification; user override wins; the three
      buckets sum to total spending exactly; zero-income case; a period
      with savings-goal contributions and a debt repayment.
- [ ] Migration test: existing categories get their default bucket, no
      data loss.
- [ ] Disclaimer visible on screen.
- [ ] `make test` green.
- [ ] **Reviewer sign-off posted before merge.**
