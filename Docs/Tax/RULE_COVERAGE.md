# Vittora Tax Rule Coverage

This document tracks what is modeled vs intentionally out of scope.

## Supported Countries

- India
- United States (federal-focused model)

## India Coverage (current)

- New vs Old regime comparisons
- Standard deduction handling by income source where applicable
- Rebate handling (including marginal-relief style behavior where modeled)
- Old-regime section caps: 80C (₹1.5L combined), 80CCD(1B) (₹50k additional), 80D age tiers, HRA minimum-of-three exemption
- Surcharge marginal relief at ₹50L / ₹1Cr / ₹2Cr / ₹5Cr gross-income thresholds: caps **income tax + surcharge (pre-cess)** at `[pre-cess at threshold] + gross excess`, then 4% health & education cess is applied on that subtotal (statutory ordering)
- Surcharge on equity STCG/LTCG (Sections 111A/112A-style simplified model) capped at **15%** even when the nominal surcharge rate is higher (25%/37%)
- Health and education cess (4%) on tax plus surcharge
- Financial year-aware logic in calculator paths
- **Compliance tips (FY 2025-26 / AY 2026-27)** — on-device, dismissible per rule per FY; informational only (existing `TaxDisclaimerView`):
  - **§269ST** cash receipt limit: ₹2,00,000 **or more** from one person in a day (`>=`). Source: Income-tax Act 1961, Section 269ST.
  - **§40A(3)** cash business expense disallowance: cash expense **exceeding** ₹10,000 in a day (`>`). Source: Income-tax Act 1961, Section 40A(3). Business/self-employed profiles only.
  - **SFT cash deposits (Rule 114E)**: savings accounts ₹10,00,000 **or more** in a FY (`>=`); current accounts ₹50,00,000 **or more** (`>=`). Source: Income-tax Rules 1962, Rule 114E. Bank accounts whose name contains “current” use the current-account threshold; other bank accounts use savings.
  - **GST registration**: services general ₹20,00,000 **exceeding** (`>`); goods general ₹40,00,000; special-category states services ₹10,00,000 / goods ₹20,00,000 (stated in tip text; evaluation uses the general services trigger). Source: CGST Act 2017, Section 22. Self-employed / business income only.
  - **§194-IB** TDS on rent: rent **exceeding** ₹50,000 in a month (`>`). Source: Income-tax Act 1961, Section 194-IB.

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
