# Vittora Tax Rule Coverage

This document tracks what is modeled vs intentionally out of scope.

## Supported Countries

- India
- United States (federal-focused model)

## India Coverage (current)

- New vs Old regime comparisons
- Standard deduction handling by income source where applicable
- Rebate handling (including marginal-relief style behavior where modeled)
- Surcharge/cess pathways in current implementation
- Financial year-aware logic in calculator paths

## US Coverage (current)

- Filing statuses:
  - Single
  - Married Filing Jointly
  - Married Filing Separately
  - Head of Household
  - Qualifying Surviving Spouse
- Year-aware ordinary tax brackets (legacy/current modeled years)
- Standard vs itemized deduction mode behavior
- Preferential LTCG/qualified-dividend 0/15/20 stacking against ordinary taxable income
- NIIT simplified calculation path
- Payroll supplementary line estimates (separate from federal income tax total)

## Explicit Exclusions / Simplifications

- AMT not calculated
- State/local tax not included
- Some payroll/contribution lines are advisory, not full filing outputs
- NIIT and other special cases use simplified assumptions

## Required Test Expectations

- For any tax logic change:
  - Run `make test-tax`
  - Update regression vectors near threshold boundaries
  - Ensure assumptions/warnings/disclaimer strings remain accurate

## Change Protocol

When changing tax behavior:

1. Update calculator logic.
2. Update tests (use-case + regression vectors).
3. Update this document if coverage/exclusions changed.
