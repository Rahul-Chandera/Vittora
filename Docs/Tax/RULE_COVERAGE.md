# Vittora Tax Rule Coverage

This document tracks what is modeled vs intentionally out of scope.

## Supported Countries

- India (resident individuals)
- United States (federal only)
- United Kingdom (England/Wales/NI and Scotland)
- Australia (residents, single person)
- Canada (federal + all 13 provinces and territories)

Reviewed against official sources on 3 October 2026 —
`Docs/Tax/TAX_LOGIC_REVIEW_2026-10-03.md`. Its reproduction vectors are pinned
in `VittoraTests/Features/Tax/TaxReviewRegressionTests.swift`.

## India Coverage (current)

- New vs Old regime comparisons; FY 2024-25, FY 2025-26, tax year 2026-27
  (Income-tax Act 2025 — same ordinary figures, its own rule-set ID)
- Order: ordinary taxable income → resident basic-exemption shortfall set
  against equity gains (STCG first) → **total income** (ordinary + full gains)
  → §87A rebate → surcharge with marginal relief → 4% cess
- §87A: eligibility on total income. New regime: offsets slab tax only, with
  marginal relief above the threshold. Old regime: a ₹5 lakh cliff (no marginal
  relief); may offset §111A STCG tax, never §112A LTCG tax
- Salary standard deduction capped at the salary itself
- Senior/super-senior status: age attained at any time in the **requested**
  year (born 1 April = attains the age on 31 March), shared with 80D
- Old-regime section caps: 80C/80CCC/80CCD(1) (₹1.5L combined), 80CCD(1B)
  (₹50k), 80D age tiers, HRA minimum-of-three (salaried only). Exact section
  identifiers — 80DD/80DDB are unsupported, not 80D
- §80CCD(2) employer NPS in **both** regimes: 14% (new) / 10% (old) of basic
  salary + DA; not applied without basic salary
- Surcharge rate and marginal relief on **total income** at ₹50L / ₹1Cr / ₹2Cr /
  ₹5Cr: caps tax + surcharge (pre-cess) at tax on income equal to the threshold
  (gains held fixed, ordinary income reduced) plus the excess; cess after
- Surcharge on equity STCG/LTCG capped at **15%**
- FY 2024-25: gains before 23 July 2024 (15%/10%) are not modelled separately —
  a warning says so
- Shown to the paisa; statutory ₹10 rounding of the return is disclosed, not applied
- **Compliance tips (FY 2025-26 / AY 2026-27)** — on-device, dismissible per rule per FY; informational only (existing `TaxDisclaimerView`):
  - **§269ST** cash receipt limit: ₹2,00,000 **or more** from one person in a day (`>=`). Source: Income-tax Act 1961, Section 269ST.
  - **§40A(3)** cash business expense disallowance: cash expense **exceeding** ₹10,000 in a day (`>`). Source: Income-tax Act 1961, Section 40A(3). Business/self-employed profiles only.
  - **SFT cash deposits (Rule 114E)**: savings accounts ₹10,00,000 **or more** in a FY (`>=`); current accounts ₹50,00,000 **or more** (`>=`). Source: Income-tax Rules 1962, Rule 114E. Bank accounts whose name contains “current” use the current-account threshold; other bank accounts use savings.
  - **GST registration**: services general ₹20,00,000 **exceeding** (`>`); goods general ₹40,00,000; special-category states services ₹10,00,000 / goods ₹20,00,000 (stated in tip text; evaluation uses the general services trigger). Source: CGST Act 2017, Section 22. Self-employed / business income only.
  - **§194-IB** TDS on rent: rent **exceeding** ₹50,000 in a month (`>`). Source: Income-tax Act 1961, Section 194-IB.

## US Coverage (current)

- All five filing statuses; tax years 2024–2026
- Income: wages or net self-employment profit, other investment income
  (ordinary, in addition to wages), short/long-term gains netted Schedule-D
  style (net loss limited to $3,000 / $1,500 MFS, excess carried forward),
  qualified dividends
- Above the line: traditional 401(k) (50+ catch-up; ages 60–63 SECURE 2.0
  catch-up from 2025) and HSA (55+ catch-up), capped at statutory limits; half
  of SE tax
- Standard (+ aged increment by marital status) or itemized; the OBBBA
  enhanced senior deduction (2025–2028, up to $6,000, 6% phase-out over
  $75k/$150k MAGI, not MFS) applies with either. Taxpayer only — a spouse's
  age is not known. Age by the IRS day-before-birthday convention
- Deduction allocated across total income: preferential income fills what the
  deduction leaves; 0/15/20 stacking; never more than regular tax on all of it
  (Schedule D worksheet)
- NIIT (simplified MAGI); employee FICA or SE tax (15.3% on 92.35%, wage-base
  cap, Additional Medicare) as supplementary lines

## UK Coverage (current)

- Tax years 2025-26 and 2026-27 (2026-27: dividend rates 10.75/35.75/39.35%,
  Scottish starter/basic bands to £16,537/£29,526)
- Additional/top rate from £125,140 of taxable income (rUK and Scotland)
- Personal allowance taper on adjusted net income (reliefs treated as net-pay
  deductions, across earnings, savings and dividends; negatives ignored)
- Savings starting rate and PSA; dividends stacked monotonically above other income
- Class 1 / Class 4 NI on annual income; none past State Pension age (Pensions
  Acts transition modelled; Class 1 pro-rated within the year)
- CGT 18/24% with £3,000 exemption

## Australia Coverage (current)

- Tax years 2025-26 and 2026-27 (15% rate from 1 July 2026)
- Medicare levy: lesser of 2% and 10% above $28,011 (2025-26 on)
- Medicare levy surcharge tiers by year; tier chosen on income for MLS
  purposes (taxable income + reportable super), charged on taxable income
- LITO; 50% CGT discount; concessional super = salary sacrifice + personal
  deductible (not employer SG), capped at the general cap ($30,000 / $32,500),
  with a warning when estimated SG would push past it
- Single person only: family/dependant thresholds are excluded

## Canada Coverage (current)

- Tax years 2025 and 2026; federal and all 13 provinces/territories
- CPP or QPP (Quebec rates) and EI first: enhanced part deducted, base part
  and EI as credits; self-employed pay both shares, deduct the employer half,
  no EI
- Federal BPA tapered on net income; Manitoba ($200k–$400k to nil) and Yukon
  (federal taper) provincial reductions
- Ontario surtax; Quebec 16.5% abatement; marginal rate includes both
- RRSP deducted as entered (room unknown — warned)

## Explicit Exclusions / Simplifications

- AMT, state/local tax (US); tax credits, QBI, tips/overtime/car-loan deductions (US)
- Student loans, Child Benefit charge, Marriage Allowance (UK)
- HELP, SAPTO, non-resident rates, Division 293, family Medicare thresholds (AU)
- Health premiums, QPIP, Canada Employment Amount, provincial low-income
  reductions, dividend credits, refundable credits (CA)
- Non-resident rules (India)
- Each estimate lists its own exclusions; these are summaries

## Versioned Rule Tables (1.7.0)

Rates are **in-binary data, keyed by year**, not literals inside the calculators:

- `Vittora/Core/Infrastructure/Tax/USTaxRuleTable.swift` — tax years 2024, 2025, 2026
- `Vittora/Core/Infrastructure/Tax/IndiaTaxRuleTable.swift` — FY 2024-25, FY 2025-26, tax year 2026-27
- `Vittora/Core/Infrastructure/Tax/UKTaxRuleTable.swift` — 2025-26, 2026-27
- `Vittora/Core/Infrastructure/Tax/AUTaxRuleTable.swift` — 2025-26, 2026-27
- `Vittora/Core/Infrastructure/Tax/CATaxRuleTable.swift` — 2025, 2026

The calculators contain logic only. Adding a future year is a data edit: one
`YearRules` literal plus golden rows.

**In-binary only, deliberately.** There is no remote config and no network call
for tax rules. The plan's M2.3.15 proposed remote config; it was not taken,
because the zero-server architecture is load-bearing for the pricing story and
the privacy label. Shipping new rates means shipping a build.

**Values are restated per year, never shared across years** — including
thresholds that do not currently differ (US NIIT and additional-Medicare, the
India old-regime slabs). Each year is self-contained so nothing silently
inherits a stale value when a year is added.

**Year resolution is a floor, not a nearest match.** A requested year resolves
to the most recent row *not later than* it, clamping up to the earliest row for
years before the table. Rules enacted for a later year must never be applied to
an earlier one: with rows for 2024 and 2030, 2028 resolves to 2024. All five
countries use this rule, and a year that is not held adds a warning. The
rule-set ID always names the year actually applied. Pinned by
`VittoraTests/Features/Tax/TaxRuleTableLookupTests.swift`.

## Required Test Expectations

- For any tax logic change:
  - Run `make test-tax` (all tax suites, including the review regressions)
  - Update regression vectors near threshold boundaries
  - Ensure assumptions/warnings/disclaimer strings remain accurate

### Golden snapshot

`VittoraTests/Features/Tax/TaxGoldenFixtures.swift` pins rows of computed
output for India and the US, every modeled year, every filing status/regime,
and every slab edge — plus an exact dump of the US bracket table.

These fixtures are a record of what users are charged. **Do not regenerate them
to make a change pass.** A diff means computed tax changed; if that is
intended, it belongs in a reviewed commit of its own that says so. Adding a
tax year appends rows, it never edits existing ones.

## Change Protocol

When changing tax behavior:

1. Update the rule table (data) or the calculator (logic).
2. Update tests (use-case + regression vectors).
3. If the golden snapshot moves, confirm the change is intended and say so in
   the commit message.
4. Update this document if coverage/exclusions changed.
