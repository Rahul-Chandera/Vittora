# Vittora tax calculation review — 3 October 2026

**Purpose:** actionable findings and repair instructions for Claude Code. This is a review, not an implementation. No application code, tests, fixtures, or configuration were changed.

**Repository reviewed:** `/Volumes/Data/Projects/Vittora/Vittora`, revision `68793bb9d5e8b4d6e1d398e6d7fc733a7238a015`.

**Rules cut-off:** 3 October 2026, Asia/Kolkata. A tax-year label means the year of the income, not the year in which a return is submitted. Future enacted changes are identified separately from currently applicable rules. Amounts use the country's local currency.

## 1. Assessment

**The calculators cannot currently be considered validated. Material calculation errors exist in all five countries.** Updating tables alone will not fix deductions, income classification, rebate eligibility, surcharge relief, or payroll treatment.

| Country | Assessment | Highest-impact issues |
| --- | --- | --- |
| United States | Current ordinary federal brackets broadly match; other components fail | Senior deductions conflated; preferential-gain thresholds wrong for 2026; deductions cannot shelter gains-only income; contribution eligibility incomplete |
| United Kingdom | Errors in the held 2025–26 rules, plus missing 2026–27 rules | Additional rate starts too early; dividend stacking can move backwards; allowance taper ignores adjusted net income; current dividend/Scottish rates absent |
| India | Ordinary 2025–26 slabs broadly match and remain numerically relevant in 2026–27; surrounding logic fails | Old-regime rebate overgranted above ₹5 lakh; gain income omitted from rebate eligibility; surcharge uses gross income; mixed-income marginal relief wrong; resident gain exemption/age handling missing |
| Australia | Held 2025–26 ordinary bands broadly match; levies and current year fail | 2026–27 15% rate absent; Medicare thresholds stale even for 2025–26; MLS uses wrong income definition; employer super treated as a personal deduction |
| Canada | Federal 2025 baseline broadly matches; current year and common components fail | 2026 absent; QPP calculated as CPP; CPP/EI tax deductions/credits absent; self-employment ignored; several provincial amounts wrong |

Severity below: **P1** = repair before describing the affected calculation as accurate; **P2** = material coverage, disclosure, historical-rule, or presentation gap. “Confirmed” means the implementation demonstrably disagrees with the cited rule. “Coverage gap” means required inputs or a statutory scenario are absent; it is not a claim that every simple estimate is wrong.

## 2. Scope and validation method

Reviewed all five `*TaxCalculator.swift` and `*TaxRuleTable.swift` files under `Vittora/Core/Infrastructure/Tax/`, the progressive-band helper, India section deductions, US contribution headroom, shared tax entities, estimate/regime-comparison/saving use cases, relevant form/breakdown views, tax tests, `Makefile`, and tax coverage documentation.

Official sources were preferred: IRS/SSA, HMRC/GOV.UK/Scottish Government, Indian Income Tax Department/enacted legislation, Australian legislation/ATO/government health insurance guidance, and CRA/provincial authorities/Revenu Québec. Links beside findings are the evidence to use during implementation. Important source conflicts and inaccessible sources are called out rather than silently resolved by a third-party calculator.

The **unchanged production calculators were compiled and executed** in an isolated Swift harness under `/private/tmp/vittora-tax-review-20261003`. The harness used the real rule tables, helpers, `TaxProfile`/`TaxEstimate` definitions and `TaxDisclaimer`; a minimal `CategoryEntity` declaration only satisfied an unrelated tax-summary type dependency. No tax arithmetic was substituted. The executable exercised 27 calculation scenarios, plus table/headroom checks. Selected reproducible results are in section 9. Expected values were independently derived from the cited rules, not copied from existing tests.

This was not a full Xcode/UI/unit-test run or a certification of every possible return. Xcode builds were avoided because they can rewrite tracked plist/project/localization files. Residency, filing eligibility, losses, annual-versus-pay-period payroll differences, and complex deductions require additional inputs and tests.

### Year coverage as of the cut-off

| Country | Current income year | Tables actually held | Behavior for the current year |
| --- | --- | --- | --- |
| US | 2026 | 2024, 2025, 2026 | Uses 2026, with defects below |
| UK | 2026–27, starting 6 April | 2025–26 only | Uses 2025–26 and emits a fallback warning |
| India | Tax year 2026–27, starting 1 April | FY 2024–25, FY 2025–26 | Silently uses 2025–26; also resolves age against that old year |
| AU | 2026–27, starting 1 July | 2025–26 only | Uses 2025–26 and emits a fallback warning |
| Canada | 2026 | 2025 only | Uses 2025 and emits a fallback warning |

India's new Income-tax Act applies from 1 April 2026; FY 2025–26 returns remain under the earlier Act. This is a legal/year-identity transition, not evidence of a new 2026 slab change. [Income Tax Department transition FAQ](https://www.incometax.gov.in/iec/foportal/help/all-topics/e-filing-services/objective-and-scope-new-act-faq), [2025 Act as amended by Finance Act 2026](https://www.incometaxindia.gov.in/documents/d/guest/income_tax_act_2025_as_amended_by_fa_act_2026-pdf).

## 3. United States

### US-01 — P1, confirmed: senior deductions are conflated

**Location:** `USTaxCalculator.calculate`, `USTaxRuleTable.age65AdditionalStandardDeduction` in all three years, `ageAtEndOfTaxYear`.

The code adds $6,000 to the standard deduction for one taxpayer aged 65+, including in 2024. It omits the existing aged/blind standard-deduction increment and discards the $6,000 when itemized deductions win. It does not phase out the enhanced deduction or model an eligible spouse.

These are two distinct mechanisms:

| Year | Existing additional standard deduction per qualifying age/blindness condition: unmarried, not surviving spouse / married or surviving spouse |
| --- | --- |
| 2024 | $1,950 / $1,550 |
| 2025 | $2,000 / $1,600 |
| 2026 | $2,050 / $1,650 |

The separate enhanced senior deduction is up to $6,000 **per eligible person**, for 2025–2028, available with standard or itemized deductions. Its reduction is 6% of excess MAGI over $75,000, or $150,000 for a joint return; married taxpayers must meet the joint-filing requirement. Eligibility is not merely a DOB test. [IRS senior deduction guidance](https://www.irs.gov/pub/irs-pdf/p6142.pdf), [26 USC 151](https://uscode.house.gov/view.xhtml?req=%28title%3A26+section%3A151%28d%29+edition%3Aprelim%29), [2024 adjustments, §3.15](https://www.irs.gov/pub/irs-drop/rp-23-34.pdf), [2025 adjustments, §3.15](https://www.irs.gov/pub/irs-drop/rp-24-40.pdf), [2026 adjustments, §4.14](https://www.irs.gov/pub/irs-drop/rp-25-32.pdf).

**Reproduction:** single, DOB 1955-01-01, 2026 wages $50,000, no other inputs. App income tax $3,100. Correct formula income tax $2,854: $16,100 + $2,050 standard deduction, then $6,000 enhanced deduction, leaving $25,850 taxable.

**Repair:** separate standard, aged/blind increment and enhanced senior deduction; calculate MAGI and spouse eligibility explicitly. Keep enhanced deduction outside the standard-versus-itemized choice. Verify the US statutory age-attainment convention, including January 1 birthdays.

**Tests:** 2024 has no enhanced deduction; 2025/2026 amounts; itemizers; both eligible spouses; filing separately; MAGI just below/at/above phase-out boundaries; age 64/65 and January 1 DOB; blindness as a separate condition or an explicit exclusion.

### US-02 — P1, confirmed: 2026 preferential-rate thresholds are wrong

**Location:** `USTaxRuleTable.rules2026.byStatus`, `preferentialCapitalGainsTax`.

| Filing status | App 0% upper limit → correct | App 15% upper limit → correct |
| --- | --- | --- |
| Single | $50,000 → $49,450 | $545,000 → $545,500 |
| Married filing jointly / qualifying surviving spouse | $100,000 → $98,900 | $612,000 → $613,700 |
| Married filing separately | $50,000 → $49,450 | $306,000 → $306,850 |
| Head of household | $67,000 → $66,200 | $578,000 → $579,600 |

These are taxable-income stacking thresholds. [IRS Revenue Procedure 2025-32, §4.03](https://www.irs.gov/pub/irs-drop/rp-25-32.pdf).

**Reproduction:** single, 2026 wages $65,550 and LTCG $550. Ordinary taxable income is $49,450. App preferential tax $0; correct $82.50. App total federal income tax $5,686; corrected formula total $5,768.50, excluding payroll.

**Repair/tests:** replace every 2026 status value; test both ends of each preferential band with ordinary-income stacking. The held 2025 MFS $300,000 limit and 2024 MFS $291,850 limit match the respective IRS publications; do not “correct” them to values inferred by halving another status.

### US-03 — P1, confirmed: deductions cannot reduce preferential-only income

**Location:** `USTaxCalculator.calculate`, construction of `ordinaryGross`, `taxableOrdinary`, `preferentialIncome`.

The standard/itemized deduction is subtracted only from ordinary income. Any unused portion vanishes, and the full gain/dividend amount remains taxable.

**Reproduction:** single, 2026 ordinary income $0, LTCG $60,000, no other inputs. App federal tax $1,500. Correct $0: taxable income $43,900 after the $16,100 standard deduction, entirely below the $49,450 preferential threshold. [IRS Schedule D instructions and tax worksheet](https://www.irs.gov/instructions/i1040sd).

**Repair:** determine aggregate taxable income first. For the supported positive-income case, allocate `taxablePreferential = min(netPreferentialIncome, totalTaxableIncome)` and ordinary taxable income as the remainder. Apply the official worksheet's ordinary-tax comparison/limit; do not assume the preferential computation must always produce a lower bill. Implement loss netting separately rather than treating negative gains as ordinary positive amounts.

**Tests:** gains-only, dividends-only, unused deduction partially sheltering gains, itemized deductions exceeding ordinary income, low ordinary bands, qualified/non-qualified dividends, capital-loss interactions. Update saving scenarios to use total taxable income consistently.

### US-04 — P1 input-contract gap: other investment income and payroll bases are ambiguous

**Location:** `USTaxCalculator.calculate`; `TaxAdvancedInputs.usOtherInvestmentIncome`; form labels.

`usOtherInvestmentIncome` is included in NIIT MAGI and net investment income, but never ordinary taxable income. If it represents interest/non-qualified dividends in addition to wages, ordinary income tax is understated. If it is already inside `annualIncome`, it is double-counted in MAGI and treated as payroll wages. The field's NIIT-oriented comment does not resolve the user's underlying income contract. [IRS taxable dividends guidance](https://www.irs.gov/taxtopics/tc404).

**Observed conditional example:** wages $50,000 plus separately entered taxable investment income $10,000, single 2026. App $3,820; correct ordinary formula tax $5,020 if that $10,000 is incremental taxable interest/non-qualified dividends.

**Repair:** represent wages, ordinary investment income, qualified dividends and gains separately; define whether entered salary is before deferrals or W-2 Box 1. Include each receipt once in income/MAGI and only eligible wages in payroll. `.selfEmployed` currently still receives employee wage payroll assumptions: either support self-employment tax or reject/disclose that profile explicitly.

Joint-return payroll also needs wages **per worker**: the Social Security wage base is not one household cap. If a 2026 joint profile's $200,000 represents two workers earning $100,000 each, the current single-cap computation gives $11,439 Social Security instead of $12,400. This is a static component derivation, not an additional executed harness vector. [SSA wage-base calculation](https://www.ssa.gov/OACT/COLA/cbbdet.html).

**Tests:** additive investment income, already-included investment income prevented, wages versus pension/business income, pre-deferral salary versus Box 1, NIIT threshold cases. Use Form 8960 definitions rather than treating a simplified MAGI sum as universally valid.

### US-05 — P2, confirmed: historical payroll/contribution values and catch-ups

**Location:** 2024 `USTaxRuleTable` contribution/payroll values; `USContributionHeadroomEngine`; `preTaxContributions`.

| Item | App | Correct |
| --- | --- | --- |
| 2024 Social Security wage base | $176,100 | $168,600 |
| 2024 401(k) elective-deferral base | $23,500 | $23,000 |
| 2024 HSA individual / family | $4,300 / $8,550 | $4,150 / $8,300 |
| 2026 IRA age-50 catch-up | $1,000 | $1,100; total $8,600 |

The 2024 Social Security error can overstate employee Social Security by $465. [SSA annual adjusted amounts](https://www.ssa.gov/oact/cola/autoAdj.html), [IRS 2024 Publication 525](https://www.irs.gov/pub/irs-prior/p525--2024.pdf), [IRS 2024 Publication 969](https://www.irs.gov/pub/irs-prior/p969--2024.pdf), [IRS 2026 retirement limits](https://www.irs.gov/newsroom/401k-limit-increases-to-24500-for-2026-ira-limit-increases-to-7500).

**Repair/tests:** use independently sourced year values; test cap minus/at/plus one, payroll maximums, and IRA headroom even though IRA deductions are deliberately excluded.

### US-06 — P2 coverage gap: contribution limits are not sufficient eligibility rules

The age-50 boolean cannot implement the higher $11,250 401(k) catch-up for ages 60–63 in 2025/2026. For 2026, affected participants with prior-year employer wages above $150,000 must make catch-up contributions as Roth; a single “entire account is Roth” boolean cannot represent the mixed treatment. [IRS contribution limits](https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-topics-401k-and-profit-sharing-plan-contribution-limits), [IRS Roth catch-up regulations](https://www.irs.gov/irb/2025-40_IRB).

HSA age-55 catch-up of $1,000, employer contributions consuming headroom, qualifying coverage/months and Medicare enrollment are absent. Direct personal HSA deductions and cafeteria-plan payroll contributions have different payroll treatment; the current statement that all HSA contributions leave payroll tax unchanged is too broad. [IRS Publication 969](https://www.irs.gov/publications/p969).

**Repair/tests:** structured contribution sources, age ranges and eligibility; distinguish contribution headroom from deductible headroom; test employer contributions, partial-year coverage, Medicare, direct versus payroll HSA, mixed Roth catch-up.

**Scope:** AMT, state/local tax and traditional IRA deductibility are expressly excluded; that is a scope choice, not a newly discovered calculation defect. Credits, QBI and new tips/overtime/car-loan deductions are also not generally represented. Add precise scope notices or implement them with eligibility inputs; do not imply the output is a complete Form 1040 liability.

## 4. United Kingdom

### UK-01 — P1, confirmed: additional/top rate begins too early

**Location:** `UKTaxRuleTable` rest-of-UK 40%/45% and Scottish 45%/48% edges (`112_570`), and dividend/savings band consumers.

The code subtracts the full £12,570 allowance from the £125,140 top-rate threshold, despite the allowance taper removing it at that income. The cumulative taxable upper edge is **£125,140**, not £112,570. The basic taxable band remains £37,700; relief can extend bands. [HMRC income-tax rates and allowances](https://www.gov.uk/government/publications/rates-and-allowances-income-tax/income-tax-rates-and-allowances-current-and-past).

**Reproduction:** England/Wales/NI, 2025–26 wages £120,000, no relief. App income tax £39,675; correct £39,432. NI £4,410.60 is unchanged. App combined total £44,085.60; correct £43,842.60. App marginal income-tax rate 67.5%; correct 60% within this tapered-allowance slice.

**Repair/tests:** correct cumulative band edges in both regions and dependent savings/dividend calculations. Test £100,000, allowance taper, £125,140 ± £1, Scotland and rUK, and relief-extended bands. Do not merely change `topRateThreshold` metadata while leaving slab edges unchanged.

### UK-02 — P1, confirmed: dividend stacking moves backwards

**Location:** `UKTaxCalculator.dividendTax`, the `else { position = limit }` branch around line 345.

When prior income is already beyond a band's limit, this branch resets the stacking position down to that limit. A taxpayer in the additional-rate band can then have dividends taxed in the higher-rate band.

**Reproduction:** 2025–26 rUK earnings £200,000, dividends £10,000. App dividend component £3,206.25; correct £3,738.25: (£10,000 − £500) × 39.35%. This comparison isolates dividend tax; the earnings portion has the separate UK-01 error. [HMRC dividend tax](https://www.gov.uk/tax-on-dividends).

**Repair/tests:** make band position monotonic; skip exhausted bands without decreasing position. Preserve the £500 allowance's occupation of tax bands. Test income already in each dividend band, allowance crossing a boundary, and gains/savings/dividend mixtures.

### UK-03 — P1, confirmed/coverage: gross income substitutes for adjusted net income

**Location:** `calculate`, allowance computed before `reliefApplied`; generic `customDeductions` subtraction; `personalAllowance` and `marginalRate`.

The allowance taper must use adjusted net income (ANI). Net-pay pension deductions reduce relevant income; relief-at-source pensions and Gift Aid require gross-up and the appropriate band extensions. Treating every relief as an ordinary subtraction after computing the allowance cannot implement these rules. [HMRC adjusted net income](https://www.gov.uk/guidance/adjusted-net-income), [pension tax relief](https://www.gov.uk/tax-on-your-private-pension/pension-tax-relief), [HMRC pension relief band extensions](https://www.gov.uk/hmrc-internal-manuals/pensions-tax-manual/ptm056130).

**Reproduction:** £110,000 salary before a £10,000 net-pay pension deduction, 2025–26 rUK. App allowance £7,570, taxable income £92,430, income tax £29,432. Correct ANI £100,000, allowance £12,570, taxable income £87,430, tax £27,432. Employee NI remains based on £110,000 for a normal net-pay pension, unlike salary sacrifice.

A second static defect: `reliefApplied` can cover all income, but is subtracted only from earnings. With no earnings, the reported relief does not reduce savings/dividends at all. Negative custom deductions can increase tax.

**Repair/tests:** typed reliefs and separate ANI/band-extension/NI effects; validate negatives. Test net pay, salary sacrifice, relief at source and Gift Aid independently; savings-only inputs; allowance restored by relief; Scottish income with UK savings bands.

### UK-04 — P1, confirmed: current-year dividend and Scottish rules absent

Only 2025–26 exists. For 2026–27 dividends, rates are **10.75%, 35.75%, 39.35%**; the £500 allowance remains. The held first two rates are 8.75%/33.75%. [HMRC dividend rates](https://www.gov.uk/tax-on-dividends), [Finance Act 2026](https://www.legislation.gov.uk/ukpga/2026/11/part/1/crossheading/income-tax-charge-rates-and-allowances/made?view=plain).

Scottish non-savings/non-dividend rates remain 19/20/21/42/45/48%; the 2026–27 cumulative taxable edges, assuming the standard allowance in the lower bands, are **£3,967, £16,956, £31,092, £62,430, £125,140**. Use the correct allowance calculation at high incomes rather than permanently subtracting £12,570 from the top edge. [Scottish Government rate tables](https://www.gov.scot/publications/scottish-income-tax-rates-and-bands/), [GOV.UK Scottish income tax](https://www.gov.uk/scottish-income-tax).

**Reproduction:** £30,000 wages + £3,000 dividends, 2026–27 rUK. App dividend tax £218.75; correct £268.75. Correct combined income tax and NI £5,149.15 versus app £5,099.15.

**Repair/tests:** introduce an explicit 2026–27 rule set, preserve 2025–26, and test new Scottish lower bands and both changed dividend bands. Do not apply Scottish employment rates to savings/dividends.

### UK-05 — P1/P2 coverage: National Insurance treats pensions and exempt people as workers

**Location:** NI call in `calculate`; `.salaried` label “Salaried / Pensioner”; DOB unused for NI.

A £30,000 pension-only profile entering the shared salaried/pensioner route receives £1,394.40 employee NI. Pension income is not Class 1 earnings. Employees stop paying NI at State Pension age; Class 4 cessation uses its tax-year rule. State Pension age is transitioning and must not be hardcoded to 65 or 66. [GOV.UK NI eligibility](https://www.gov.uk/national-insurance), [HMRC NI rates/earnings categories](https://www.gov.uk/government/publications/rates-and-allowances-national-insurance-contributions/rates-and-allowances-national-insurance-contributions).

**Repair:** separate employment earnings, pension income and self-employment profit. Use pay-period inputs if estimating actual employee deductions; otherwise label the annualized Class 1 assumption. Determine Class 4 from taxable business profits rather than salary-style gross income or unrelated personal reliefs. Model age/exemption categories or disclose unsupported eligibility.

**Tests:** pension-only NI zero; post-State-Pension-age employment; transition DOB boundaries; self-employed business expenses versus pension relief; uneven pay periods. The simplified 8%/2% employee and 6%/2% Class 4 rates and £12,570/£50,270 thresholds are otherwise consistent with the reviewed standard category. Mandatory Class 2 is correctly absent for ordinary cases.

**Other coverage:** standard UK-wide CGT rates 18%/24% and £3,000 annual exemption are consistent for the held year. BADR/Investors' Relief needs separate handling if offered: the rate is 18% from 6 April 2026, following 14% in 2025–26. [HMRC CGT rates](https://www.gov.uk/capital-gains-tax/rates). Savings starting-rate/PSA mechanisms are present, but taxpayer-band determination must be retested after ANI/relief fixes. Optimal allowance allocation across income types is not comprehensively validated.

## 5. India

### IN-01 — P1, confirmed: old-regime rebate receives unauthorized marginal relief

**Location:** `IndiaTaxCalculator.calculateRebate`, shared branch for income exceeding the rebate threshold.

The old-regime ₹12,500 rebate ends when total income exceeds ₹500,000. The marginal-relief provision belongs to the new-regime rebate; it cannot be applied to old-regime income just over ₹5 lakh. [Income-tax Act 1961, §87A](https://www.incometaxindia.gov.in/w/section-87a-24), [Income Tax Department AY 2026–27 individual rules](https://www.incometax.gov.in/iec/foportal/help/individual/return-applicable-1).

**Reproduction:** old regime, salaried, FY 2025–26 gross ₹550,100. After ₹50,000 standard deduction: ₹500,100 taxable, ₹12,520 basic tax. App rebate ₹12,420 and final ₹104. Correct rebate zero and tax including cess **₹13,020.80 before final statutory rounding**.

**Repair/tests:** separate old/new eligibility and relief functions. Test total income ₹500,000 and ₹500,100 old regime; corresponding new-regime boundary cases; do not smooth away the old-regime cliff. Use inputs unaffected by statutory total-income rounding when testing this defect.

### IN-02 — P1, confirmed: rebate eligibility and eligible tax exclude the wrong components

**Location:** `computeCoreAmounts`, rebate receives ordinary `taxableIncome`/`basicTax` only; warning says all special-rate equity gains are excluded.

The eligibility threshold concerns total income, including relevant gains; it is not merely the ordinary slab income. The 2025–26 new-regime rebate cannot offset special-rate gain tax. However, the old-regime rebate can offset eligible §111A STCG tax, while §112A(6) specifically restricts LTCG rebate. A blanket identical rule for both regimes/years is wrong. [§112A, especially subsection 6](https://www.incometaxindia.gov.in/w/section-112a-60), [§87A old-regime provision](https://www.incometaxindia.gov.in/w/section-87a-24), [2025 Act as amended, §156](https://www.incometaxindia.gov.in/documents/d/guest/income_tax_act_2025_as_amended_by_fa_act_2026-pdf).

**Reproductions, FY 2025–26:**

- New regime: ₹1,275,000 salary + ₹200,000 equity STCG. Ordinary taxable income ₹1,200,000; total income ₹1,400,000. App rebate ₹60,000 and final ₹41,600. Correct rebate zero, including no marginal relief in this example, and final **₹104,000**.
- Old regime: ₹300,000 ordinary business income + ₹100,000 qualifying STCG. App final ₹20,800. Eligible tax is ₹2,500 ordinary + ₹20,000 STCG; rebate ₹12,500 leaves ₹10,000 plus cess, **₹10,400**.

**Repair/tests:** carry separate total-income, ordinary-tax and eligible-special-tax values; encode rebate law by regime/year/income type. Test LTCG rate thresholds without treating the ₹125,000 rate threshold as a universal total-income deduction. Historical new-regime special-income rebate treatment needs a deliberate year-specific legal check rather than backporting the 2025 rule indiscriminately.

### IN-03 — P1, confirmed: surcharge threshold uses gross income

**Location:** `calculate`, `totalGrossForSurcharge`, `nominalSurchargeRate`/`rawSurcharge`.

Surcharge thresholds are based on statutory total income after allowable income deductions. The code uses salary before standard/custom deductions plus gains. [Income Tax Department surcharge rules](https://www.incometax.gov.in/iec/foportal/help/individual/return-applicable-1).

**Reproduction:** new-regime FY 2025–26 salary ₹5,050,000. Taxable ordinary income ₹4,975,000, below the ₹5 million threshold. App surcharge ₹35,000 and total ₹1,151,800. Correct surcharge zero and total **₹1,115,400**.

**Repair/tests:** compute total income once and use it throughout surcharge eligibility and relief; retain the appropriate separate special-income surcharge cap. Test deductions moving income below each threshold; mixed ordinary/gain income; old/new maximum rates. Above ₹2 crore, also implement the statutory distinction involving specified gains/dividend income instead of assuming all income drives one ordinary surcharge rate.

### IN-04 — P1, confirmed: mixed-income surcharge marginal-relief comparator is not at the threshold

**Location:** `applySurchargeMarginalRelief` → `preCessTotal(forGrossIncome:)`.

The comparator replaces `annualIncome` with the threshold, then adds unchanged capital gains again. Even after IN-03 is fixed, this does not calculate tax on total income at the threshold.

**Reproduction:** new-regime FY 2025–26 business income ₹4,980,000 + STCG ₹50,000. App tax before surcharge ₹1,084,000, surcharge ₹108,400, final ₹1,240,096. With the gain component held fixed, threshold ordinary income is ₹4,950,000: threshold tax ₹1,075,000; excess total income ₹30,000; pre-cess ceiling ₹1,105,000. Correct surcharge ₹21,000 and final **₹1,149,200**.

**Repair:** construct a comparator at the relevant **total-income** threshold and recompute its valid income composition/deductions without double-adding gains. Use the lower-threshold surcharge entitlement when appropriate; do not recursively reuse the actual high-income surcharge. Apply cess after the relief calculation. [Official surcharge and marginal-relief summary](https://www.incometax.gov.in/iec/foportal/help/individual/return-applicable-1).

**Tests:** each surcharge threshold, gains-only/mixed income, deductions, 15% special-income cap, previous-threshold surcharge, and cess ordering. The example's fixed gain composition is explicit; obtain a legally grounded allocation policy for complex threshold counterfactuals.

### IN-05 — P1, confirmed: senior status uses the start of the financial year

**Location:** `ageCategory` uses April 1; `IndiaSectionDeductionEngine` already uses an FY-end age basis.

Old-regime senior/super-senior slabs apply if the resident individual attains the relevant age at any time during the year. The current calculation understates eligibility for birthdays during the year. Fallback to FY 2025 additionally misclassifies current-year birthdays. [Official age-category rules](https://www.incometax.gov.in/iec/foportal/help/individual/return-applicable-1).

**Reproduction:** DOB 1965-10-01, FY 2025–26, old-regime business income ₹700,000. App final ₹54,600; correct senior final **₹52,000**.

**Repair/tests:** one shared tax-year age function using the requested income year, independent of rule-table fallback. Test age 60/80 attained on first/last day and inside the FY; ordinary deduction-engine consistency; no senior slab preference under the new regime.

### IN-06 — P1, confirmed: unused resident basic exemption is not applied to equity gains

**Location:** `computeCoreAmounts` flat STCG/LTCG tax calculations.

Qualifying resident individuals can use the shortfall in ordinary income below the basic exemption against these gains, subject to the statutory ordering. The code simply taxes STCG at 20% and LTCG above its rate threshold. [§111A resident shortfall provision](https://www.incometaxindia.gov.in/hi/w/section-111a-21), [§112A resident shortfall provision](https://www.incometaxindia.gov.in/w/section-112a-60).

**Reproduction:** new-regime FY 2025–26 business income zero + qualifying STCG ₹100,000. App final ₹20,800; correct **zero**, because the available basic exemption covers the gain. This is an exemption adjustment, not a rebate against special-rate tax.

**Repair/tests:** explicit remaining basic exemption and gain ordering; resident/non-resident eligibility; mixtures of ordinary income, STCG and LTCG. Do not grant the same shortfall exemption to every unsupported residency category.

### IN-07 — P2, confirmed historical gap: FY 2024–25 needs gain transaction dates

**Location:** `IndiaTaxRuleTable` FY 2024 values; aggregate `indiaEquitySTCG`/`indiaEquityLTCG` inputs.

The held entire-year rates 20% STCG and 12.5% LTCG cannot handle qualifying transfers before 23 July 2024, which use 15%/10%. For §112A the amended ₹125,000 threshold applies to aggregate pre/post-date gains; do not mistakenly give each date bucket a separate exemption or replace it with ₹100,000 for the entire mixed year. [Income Tax Department capital-gain summary](https://www.incometaxindia.gov.in/w/capital-gain), [amended §112A](https://www.incometaxindia.gov.in/w/section-112a-60).

**Repair/tests:** dated gain buckets or an explicit unsupported historical-gains restriction. Test 22/23 July, mixed disposals, one annual exemption and special-income rebate treatment for that year.

### IN-08 — P1/P2 coverage: deduction classification, employer NPS and pension type

**Location:** `computeCoreAmounts` zeroes all new-regime custom deductions; `IndiaSectionDeductionEngine.bucket`, HRA handling; shared salary/pension classification.

Employer NPS deduction is allowed in the new regime, unlike most personal Chapter VI-A deductions. It is currently always denied. The section classifier also uses `hasPrefix("80D")` and `hasPrefix("80C")`: 80DD/80DDB and employer 80CCD(2) can be placed into unrelated caps. Free-text prefixes are unsafe statutory identifiers. [Income Tax Department new-regime deductions](https://www.incometax.gov.in/iec/foportal/help/individual/return-applicable-1), [2025 Act §132](https://www.incometaxindia.gov.in/documents/d/guest/income_tax_act_2025_as_amended_by_fa_act_2026-pdf).

Additional coverage risks: HRA can be claimed through the deduction engine without a salary-eligibility gate; fallback accepts a user amount when components are unavailable; 80D self/family senior eligibility does not capture a senior spouse; several old-regime sections are explicitly unsupported. Ordinary pension and family pension require different deduction rules. The salary deduction should not exceed the eligible salary amount even if taxable income is clamped to zero.

**Repair/tests:** typed deduction identifiers and regime eligibility; employer versus personal NPS and salary-percentage bases; exact cap families, unsupported-section warnings, business-only HRA rejection, senior spouse, ordinary versus family pension, low salary. Obtain current statutory rules for any newly implemented section rather than allowing an arbitrary custom amount.

### IN-09 — P2: legal-year identity and statutory rounding

There is no explicit 2026–27 rule set or fallback warning. The underlying ordinary new-regime thresholds ₹400k/800k/1.2m/1.6m/2m/2.4m at 0/5/10/15/20/25/30%, ₹75k salary deduction and ₹1.2m/₹60k rebate baseline are consistent with the reviewed current ordinary-income law; do not invent a changed slab just because the Act changed. Add the correct law/year provenance and section-name mapping. [Enacted 2025 Act as amended by Finance Act 2026, §§19,156,202](https://www.incometaxindia.gov.in/documents/d/guest/income_tax_act_2025_as_amended_by_fa_act_2026-pdf).

The calculator returns paise-scale tax rather than statutory nearest-₹10 total-income/final-payable rounding (earlier Act §§288A/288B; 2025 Act §516). Implement a country-specific rounding policy if the result is intended as payable tax. Do not use epsilon comparisons to hide Decimal construction errors. Keep pre-rounding and final-payable values distinct in tests; section 9's India decimal expectations are explicitly pre-final-rounding. [Official §288A](https://www.incometaxindia.gov.in/w/section-288a-61), [official §288B](https://www.incometaxindia.gov.in/w/section-288b-43), [2025 Act §516](https://www.incometaxindia.gov.in/documents/d/guest/income_tax_act_2025_as_amended_by_fa_act_2026-pdf).

## 6. Australia

### AU-01 — P1, confirmed: 2026–27 resident rate cut absent

**Location:** `AUTaxRuleTable` only holds 2025–26, `AUTaxCalculator.supportedTaxYear`.

The $18,200–$45,000 slice is **15% from 1 July 2026**, replacing 16%. The 30%/37%/45% higher rates and $135,000/$190,000 higher edges remain. The enacted 14% rate starts in **2027–28**, not the current year. [Income Tax Rates Act, current compilation](https://www.legislation.gov.au/C2004A03348/2026-07-01/2026-07-01/text/original/epub/OEBPS/document_1/document_1.html), [2025 amending Act](https://www.ato.gov.au/law/view/pdf/acts/20250028.pdf).

**Reproduction:** resident single, age below senior eligibility, income $50,000, full-year qualifying private hospital cover, 2026–27. App income tax after LITO plus Medicare $6,538; correct **$6,270**. The ordinary rate difference is $268.

**Repair/tests:** explicit 2026–27 rules; retain 2025–26 and separately version 2027–28 if future years are supported. Test $18,200/$45,000 edges and whole-year labels.

### AU-02 — P1, confirmed: held Medicare low-income thresholds are stale

**Location:** `AUTaxRuleTable.rules2025.medicareLevy`, `medicareLevy`.

The $27,222 lower threshold is from 2024–25. Legislation enacted on 30 June 2026 replaces it with **$28,011 for 2025–26 and later years**. The ordinary single phase-in reaches the full levy around $35,013; use the exact lesser-of formula rather than introducing a rounding discontinuity at an integer upper threshold. [Treasury Laws Amendment (2026 Measures No. 2) Act 2026, Schedule 5](https://www.legislation.gov.au/C2026A00058/asmade/2026-06-30/text/original/pdf), [ATO software-developer Medicare thresholds](https://softwaredevelopers.ato.gov.au/Medicarelevythresholds).

**Reproduction:** standard resident single, 2025–26 taxable income $28,000. App levy $77.80 and total $945.80. Correct levy zero and total **$868** after LITO.

**Repair:** for ordinary single eligibility, levy `min(2% × income, 10% × max(0, income − threshold))`, then apply applicable exemptions/days. Add family/senior/SAPTO threshold and exemption eligibility before claiming universal Medicare coverage. Do not forecast an unannounced 2026–27 inflation adjustment; use enacted applicable thresholds and version any subsequent law.

**Tests:** lower threshold ± $1; shade-in crossover; families, dependent children, senior eligibility, Medicare-ineligible periods and partial-year exemption. Current inputs cannot cover all of these.

### AU-03 — P1, confirmed: current Medicare levy surcharge tiers absent

**Location:** `AUTaxRuleTable.surchargeTiers`, `medicareLevySurcharge`.

| Income year | Single no-MLS / 1% / 1.25% upper boundaries | Family equivalents |
| --- | --- | --- |
| 2025–26 | $101,000 / $118,000 / $158,000 | $202,000 / $236,000 / $316,000 |
| 2026–27 | $105,000 / $123,000 / $164,000 | $210,000 / $246,000 / $328,000 |

The highest tier is 1.5%. Family thresholds increase by $1,500 for each dependent child after the first. Qualifying hospital cover and days matter. [Australian Government MLS guidance](https://privatehealth.gov.au/health_insurance/surcharges_incentives/medicare_levy.htm).

**Reproduction:** standard single, 2026–27 income $103,000, no cover. App MLS $1,030; correct zero. After also fixing AU-01, app combined total $24,778 becomes **$23,480** under these assumptions.

**Repair/tests:** per-year tiers, family status/dependants and qualifying cover periods; exact tier boundaries. A generic private-cover boolean must not grant a full exemption for extras-only cover or only part-year coverage.

### AU-04 — P1, confirmed: MLS income test is confused with its charge base

**Location:** `medicareLevySurcharge(taxableIncome:)`, after super/custom deductions.

MLS tier selection uses an adjusted income definition, including reportable super contributions and other add-backs. The income tested for eligibility is not necessarily the taxable amount charged. [ATO income for MLS purposes](https://www.ato.gov.au/individuals-and-families/medicare-and-private-health-insurance/medicare-levy-surcharge/income-for-medicare-levy-surcharge-purposes).

**Reproduction:** single, 2025–26 income $120,000 before $20,000 valid personal deductible super, no cover, no other items. App taxable income $100,000 and MLS zero. MLS income remains $120,000; rate 1.25% applied to the $100,000 taxable base gives **$1,250 MLS**. This is a component expectation, not a complete return computation.

**Repair/tests:** separate assessable income, taxable income, MLS-tested income and MLS charge base; model reportable employer contributions, personal deductible super, relevant fringe benefits/investment-loss add-backs, family income and days. Test tier crossing caused by add-backs, not just taxable salary.

### AU-05 — P1/P2: super contribution type and cap handling are wrong/incomplete

**Location:** `calculate`: `min(auConcessionalSuper, cap)` is deducted in full from entered salary.

The bucket combines employer SG, salary sacrifice and personal deductible contributions. Employer SG is part of the concessional cap but is not a fresh personal salary deduction. Salary already entered after sacrifice must not be reduced twice. Personal contributions require deduction eligibility/notice requirements; available cap can include carry-forward room, so blindly clipping to the annual general cap does not establish the valid deduction.

The held general cap is $30,000. **The Commonwealth Superannuation Corporation's current contribution guidance states $32,500 for 2026–27.** Its budget announcement page alone would not prove enactment; the operational contribution page corroborates the current figure. [CSC current contribution guidance](https://www.csc.gov.au/Defined-benefit-members/Manage/Contributions?scheme=pss). Direct ATO cap pages could not be retrieved during this review; confirm the year/carry-forward/eligibility details against the ATO table before merging a cap update. [ATO cap reference](https://www.ato.gov.au/tax-rates-and-codes/key-superannuation-rates-and-thresholds/contributions-caps).

**Repair/tests:** explicit employer/personal/sacrifice fields and salary basis; cap consumption separate from deductions; carry-forward eligibility; notice of intent; excess contribution treatment. Test employer SG only gives no personal deduction, combined cap use, already-reduced salary and valid carry-forward claims. If showing a total tax saving, account for or disclose fund contribution tax rather than presenting the personal-income-tax reduction as a complete net benefit.

**Reviewed baseline:** 2025–26 resident ordinary bands and the standard LITO $700/5%/1.5% taper are consistent with the simple scenarios checked. The 50% individual CGT discount requires qualifying holding/residency conditions and loss ordering; the single gross-gain field does not implement current/carried losses. HELP, SAPTO, non-resident/working-holiday rates and Division 293 are outside the simple model; retain precise exclusions or implement them deliberately.

## 7. Canada

### CA-01 — P1, confirmed: 2026 federal, provincial and payroll rules absent

**Location:** `CATaxRuleTable` has only 2025; current profiles resolve to it.

Federal 2026 cumulative bracket edges are **$58,523 / $117,045 / $181,440 / $258,482**, rates **14 / 20.5 / 26 / 29 / 33%**. The 2025 first annual rate of 14.5% is correct for that year; do not replace it with the second-half payroll catch-up rate. [CRA annual 2026 rates](https://www.canada.ca/en/revenue-agency/services/tax/individuals/tax-rates-brackets/current-year.html).

2026 federal BPA maximum/minimum are **$16,452 / $14,829**. [CRA 2026 federal personal amounts](https://www.canada.ca/en/revenue-agency/services/forms-publications/payroll/t4032-payroll-deductions-tables/t4032bc-july/t4032bc-july-general-information.html).

2026 CPP uses YMPE $74,600, YAMPE $85,000, $3,500 exemption, employee 5.95% plus CPP2 4%; maximums $4,230.45 + $416. EI is 1.63% up to $68,900, or 1.30% in Quebec. [CRA CPP annual limits](https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/payroll/payroll-deductions-contributions/canada-pension-plan-cpp/cpp-contribution-rates-maximums-exemptions.html), [Canada Employment Insurance Commission 2026 rates](https://www.canada.ca/en/employment-social-development/news/2025/09/canada-employment-insurance-commission-sets-the-2026-employment-insurance-premium-rate.html).

**Repair/tests:** explicit 2026 tables for every supported jurisdiction, BPA taper, contributions and credits. British Columbia's 2026 lowest **annual** rate is 5.60%, not the old 5.06% nor a second-half catch-up payroll rate. PEI introduces a 20% bracket above $200,000 in 2026. [BC provincial rates](https://www2.gov.bc.ca/gov/content?id=E90F9F1717DB451BB7E4A6CC0BDC6F9F&title=Tax+Rates), [PEI 2026 budget](https://www.princeedwardisland.ca/en/information/finance-and-affordability/budget-address-2026).

Do not copy annual tables from an early-January withholding publication without checking later legislation. The CRA's January payroll page and current annual page disagree on BC; annual provincial law/rates and updated guidance control annual liability.

### CA-02 — P1, confirmed: Quebec QPP is only a label over CPP arithmetic

**Location:** `cppContribution` has no province argument; only the supplementary-line title changes to QPP.

For 2025 Quebec's first-tier employee QPP rate is 6.40%, versus CPP 5.95%. For 2026 QPP changes to 6.30%; CPP remains 5.95%. [Revenu Québec RL-1 guide](https://www-prd.revenuquebec.ca/en/online-services/forms-and-publications/rl-1-g-v/guide-to-filing-the-rl-1-slip-employment-and-other-income/), [Revenu Québec 2026 changes](https://www.revenuquebec.ca/en/businesses/source-deductions-and-employer-contributions/employers-principal-changes-for-2026/).

**Reproduction:** Quebec employee, 2025 wages $60,000. App QPP line $3,361.75; correct **$3,616**. The $254.25 difference is before correcting the related income-tax deductions/credits. QPIP is explicitly excluded, not secretly included by the lower Quebec EI rate.

**Repair/tests:** separate CPP/QPP rules, base/enhanced components and exemptions; test both years, first/second ceiling, age/exemption status and provincial credit treatment. Refer to Quebec-specific pension rules instead of treating it as a rate-label variation only.

### CA-03 — P1, confirmed: mandatory contribution deductions and credits absent

**Location:** `calculate` computes federal/provincial tax before payroll, with only BPA credits.

Enhanced CPP/QPP employee contributions are deductible; base contributions and EI support non-refundable credits. The code subtracts none of these and then adds the contributions to the total. [CRA line 22215 enhanced-contribution deduction](https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses/line-22215-deduction-for-cpp-or-qpp-enhanced-contributions-on-employment-income.html), [CRA line 30800 base contribution credit](https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses/line-30800-cpp-qpp-contributions-through-employment.html).

**Component illustration:** Ontario employee, 2025 wages $60,000. Enhanced CPP deduction $565; base CPP credit amount $2,796.75; EI credit amount $984. App federal tax $6,518.80. Incorporating these three items, still excluding the separately disclosed Canada Employment Amount, gives approximately **$5,854.76** under cent rounding. CEA and provincial credits/reductions further affect a complete return; this number is not the final combined liability.

**Repair/tests:** compute contributions first; split base/enhanced; determine net income then taxable income; apply capped federal and jurisdiction-specific credits before surtax/abatement. Add the related EI and Quebec credit rules. Test contribution maximums, mixed employment/self-employment, low income and non-refundable floor. General “other credits excluded” wording should not conceal absent standard contribution effects in a take-home estimate.

### CA-04 — P1, confirmed: self-employment is ignored

**Location:** `calculate` never branches on `profile.incomeSourceType`; all `annualIncome` is `employmentIncome`.

Self-employed people pay both CPP shares; EI special-benefit participation is voluntary. [CRA employee/self-employed responsibilities](https://www.canada.ca/en/revenue-agency/services/tax/canada-pension-plan-cpp-employment-insurance-ei-rulings/cpp-ei-explained/employees-self-employed-workers-responsibilities-benefits-entitlements.html).

**Reproduction:** Ontario 2025 net business profit $60,000, self-employed, not opted into EI. App CPP $3,361.75 and EI $984. Correct CPP **$6,723.50**, EI **zero**, with corresponding deduction/credit treatment also changing. The app returns exactly the employee estimate for this profile.

**Repair/tests:** separate net business profit and employment wages, opt-in EI status, combined contribution ceiling, employer-share deductions and enhanced components. Quebec requires QPP/QPIP-specific handling. Also prevent pension-only income in the shared salaried/pensioner route from receiving ordinary employee CPP/EI by default.

### CA-05 — P1/P2, confirmed: several held 2025 provincial amounts are wrong

**Location:** `CATaxRuleTable.rules2025.provinces`; constant provincial BPA multiplication.

All 13 supported provinces/territories were compared at the ordinary-bracket/BPA level. “Matches” below is limited to those values, not a validation of all provincial credits/levies or of 2026.

| Jurisdiction | Held 2025 ordinary brackets | Held 2025 BPA finding |
| --- | --- | --- |
| Alberta | Match, including new annual 8% lowest band | Match |
| British Columbia | Match | Match |
| Manitoba | **Wrong:** $47,564/$101,200; should $47,000/$100,000 | **Wrong:** $15,969; should $15,780, reducing above net income $200,000 to zero at $400,000 |
| New Brunswick | Match | Match |
| Newfoundland and Labrador | Match | Match |
| Northwest Territories | Match | Match |
| Nova Scotia | Match | Match for the reviewed 2025 amount |
| Nunavut | Match | Match |
| Ontario | Match; surtax thresholds $5,710/$7,307 also match | Match |
| Prince Edward Island | Match | **Wrong:** $14,250 should be $14,650 |
| Quebec | Match | Match, $18,571 |
| Saskatchewan | Match | **Wrong:** $18,991 should be $19,491 |
| Yukon | Match | **Incomplete:** maximum matches; must also follow federal BPA taper |

Evidence for ordinary tables: [CRA 2025 annual rates](https://www.canada.ca/en/revenue-agency/services/tax/individuals/tax-rates-brackets/last-year.html), [Revenu Québec rates](https://www.revenuquebec.ca/en/citizens/income-tax-return/completing-your-income-tax-return/income-tax-rates/). Evidence for personal amounts/tapers: [CRA line 30000 provincial amounts](https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses/line-30000-basic-personal-amount.html), [CRA updated July 2025 formula publication](https://www.canada.ca/en/revenue-agency/services/forms-publications/payroll/payroll-deductions-t4127-payroll-deductions-formulas/t4127-jul-121st-edition-effective-july-1-2025/t4127-jul-payroll-deductions-formulas.html).

**Source conflict requiring care:** the general CRA 2025/2026 rate webpages retain indexed Manitoba figures inconsistent with Manitoba's freeze. Manitoba's own page and CRA's updated payroll guidance explicitly retain annual $47,000/$100,000 and $15,780. The July payroll adjustment figures are catch-up values, not the annual return values. Use Manitoba law/annual return form when settling this discrepancy, not an unqualified copy of the general CRA rate webpage. [Manitoba personal taxes](https://www.gov.mb.ca/finance/personal/ptaxes.html), [Manitoba budget tax bulletin](https://www.gov.mb.ca/finance/taxation/pubs/bulletins/2025budget.pdf), [CRA Manitoba return/form package](https://www.canada.ca/en/revenue-agency/services/forms-publications/tax-packages-years/general-income-tax-benefit-package/manitoba/5007-pc.html).

**Repair/tests:** correct those 2025 values; typed province-specific BPA formulas; test Manitoba $200k/$400k taper and frozen boundaries, Yukon federal taper, PEI/Saskatchewan corrected credits. Add one independent per-jurisdiction fixture and boundary cases for both 2025 and 2026. Do not validate all provinces solely against the same potentially stale CRA summary table.

### CA-06 — P2, confirmed/coverage: marginal rates and income definitions

**Location:** `marginalRate`, `federalBasicPersonalAmount(taxableIncome:)`, `grossIncome`.

The displayed marginal rate is merely federal + provincial slab rates. It ignores Ontario surtax and Quebec federal abatement, even though both are applied to liability. At $120,000 Ontario 2025, the app displays 37.16%; the income-tax marginal rate in both surtax rungs is **26% + 11.16% × 1.56 = 43.4096%** before unrelated marginal adjustments. Quebec $60,000 displays 39.5%; corresponding income-tax marginal rate is **20.5% × 0.835 + 19% = 36.1175%**. [CRA Ontario surtax rules](https://www.canada.ca/en/revenue-agency/services/forms-publications/payroll/t4032-payroll-deductions-tables-previous-years/t4032on-july-2025/t4032on-july-general-information.html).

Federal BPA taper is based on **net income, line 23600**, not taxable income in every circumstance. RRSP may reduce net income, but not every later taxable-income adjustment does. [CRA federal BPA definition](https://www.canada.ca/en/revenue-agency/services/tax/individuals/topics/about-your-tax-return/tax-return/completing-a-tax-return/deductions-credits-expenses/line-30000-basic-personal-amount.html).

**Repair/tests:** separate net/taxable/gross economic income. Define marginal income-tax rate versus total tax-and-contribution rate; include surtax, abatement and taper effects appropriate to the stated definition. Compare finite differences away from boundaries and define the next-dollar convention at boundaries. Half of a gain is taxable income, not half of the economic gain received.

### CA-07 — P2 coverage: RRSP and incomplete liability scope

`caRRSPContributions` is deducted in full without the individual's available deduction limit. This is not safely fixed by capping at 18% of current-year income: prior-year earned income, pension adjustment and unused room matter. Contribution amount and chosen deductible amount can differ. [CRA RRSP guide](https://www.canada.ca/en/revenue-agency/services/forms-publications/publications/t4040/rrsps-other-registered-plans-retirement.html).

**Repair/tests:** available deduction room/claimed deduction as explicit inputs; duplicate generic RRSP entry prevention; negative deductions; carry-forward and overcontribution scenarios. The 50% capital-gain inclusion baseline is not itself identified as wrong here; losses and exemptions still need scope treatment.

Provincial health premiums, QPIP, CEA, dividends and refundable credits are explicitly excluded. Preserve these disclosures or implement the components intentionally. Provincial low-income reductions also matter: the model can charge tax where a standard provincial reduction should remove it. Do not describe a total including CPP/EI but excluding ordinary income-tax credits/health premiums as fully comprehensive take-home tax.

## 8. Shared architecture, provenance and test coverage

### SH-01 — P1/P2: unsupported-year resolution is inconsistent and can mislabel rules

US `supportedTaxYear` returns the requested parsed year, while the table resolves another year. Thus an unsupported year can produce a `US_FEDERAL_TY<requested>` ID despite using different rules, with no fallback warning. India silently floors to a held year. UK/AU/CA warn, but their resolver falls to the highest available year when a prior year is not found, which can apply future rules to historical income. `Docs/Tax/RULE_COVERAGE.md` promises a different floor/earliest fallback policy and still describes only US/India.

**Repair:** return one structured resolution containing requested year, applied year, rule ID, effective date, verified-on date and fallback status. Decide whether unsupported years are refused or clearly approximate. Keep age/year-specific eligibility based on the actual income year, not table lookup. Never imply unsupported 2027 rules are verified because 2026 was reused. Dates marked `rulesLastUpdated` are hand-set and do not establish freshness.

**Tests:** current/default year at all country boundary dates; malformed year; earlier than oldest; between held years; later than newest; rule ID and warnings match the applied table. Validate offline behavior: bundled tables and provenance should remain available without a network call.

### SH-02 — P1 presentation: shared breakdown fields do not reconcile

**Locations:** `TaxEstimate` in `Packages/VittoraCore/Sources/VittoraCore/Domain/Entities/TaxEntity.swift`; `TaxBreakdownView`; `TaxEstimateLabels`; all calculators.

Canada correctly uses BPA as a tax credit internally, but returns it as `standardDeduction`. The view displays a subtraction from gross even though `taxableIncome` was not reduced by BPA. Canada also returns already-net federal `basicTax` while populating `rebate` with both federal/provincial BPA credits; the adjustments display subtracts those credits again. Australia similarly returns tax after LITO as `basicTax` and also reports LITO as `rebate`. The final totals do not repeat the deduction, but the visible explanation does.

US ordinary-only taxable income does not explain preferential income or above-the-line exclusions; India gross/taxable fields exclude separately added gains; AU/Canada “gross income” uses discounted/included gain rather than full economic gain. UK effective-rate denominator excludes capital gains while the numerator includes CGT. US effective-rate denominator uses income after pre-tax contributions. These are materially different concepts under one label.

**Repair:** typed income adjustments, taxable income categories, gross tax, non-refundable credits, special taxes and mandatory contributions. Either adopt one reconciling contract or render country-specific reconciliations with explicit labels. Distinguish subtotal lines from additive lines so supplementary breakdowns cannot be summed twice. Choose and document an effective-rate denominator, and disclose whether payroll/CGT are included.

**Tests:** displayed income bridge sums to taxable income; displayed tax bridge sums to final total; no double-counted BPA/LITO/abatement/surtax; full gain versus taxable inclusion; denominator contracts and zero income; localized country-specific labels. These tests verify a user-visible financial invariant, not just implementation shape.

### SH-03 — P2: scenario savings inherit errors and use an incomplete denominator

`EstimateTaxSavingUseCase` runs the calculator twice, which is the correct architectural direction, but `deductibleAmount` uses the difference in the shared `taxableIncome` field. US gains-only deduction changes can be invisible under the current ordinary-only contract. Its generic notes assume India/US deduction semantics even if other countries reach the API. `CompareTaxRegimesUseCase` inherits the India rebate/surcharge errors and can recommend the wrong regime.

**Repair/tests:** fix calculators and taxable-income semantics first; restrict scenario types to supported country reliefs and give precise reasons for zero effect. Test regime comparison near rebate/surcharge thresholds and saving scenarios with gain income, allowance taper, cap exhaustion and contribution-source rules.

### SH-04 — P2: `make test-tax` misses most country suites

**Location:** `Makefile` lines 153–164. It selects TaxUseCase/US calculator, regression, India deduction and compliance-tip tests. It does not select the dedicated UK/AU/CA suites, US pre-tax contribution suite, effective-rate contract, rule-table lookup/golden suites or saving-use-case suite. Existing passing “tax” checks would not establish coverage of this review.

**Repair:** expand the focused test target deliberately; update `Docs/Tax/RULE_COVERAGE.md` and add source-backed golden cases. The repository rule against changing assertions/fixtures to chase green applies. If an existing expected value conflicts with the law, record the conflict explicitly and obtain owner direction for that assertion instead of silently changing it. Preserve the offending input. Add independent regressions before repairing production behavior.

## 9. Reproduction vectors and expected assertions

All unspecified advanced inputs are zero/default. All taxpayers are full-year residents of the supported standard category unless specified. US examples are single; UK examples are England/Wales/NI; AU examples are single, non-senior. Use integer Decimal inputs or `Decimal(string:)`, never floating-point money literals. DOBs must be constructed with an explicit Gregorian calendar/time zone.

“App” values below were executed against the unchanged code. “Expected” is the stated **component or scoped total**, not a claim to include every excluded return item. Formula examples use cents/paise to isolate arithmetic; statutory final return rounding is a separate test layer.

| ID | Inputs | App result | Expected assertion |
| --- | --- | --- | --- |
| US-01 | 2026, wages 50,000, DOB 1955-01-01 | Federal income tax 3,100 | 2,854 under bracket formula; senior deductions separate |
| US-02 | 2026, wages 65,550, LTCG 550 | Preferential tax 0; total 5,686 | Preferential 82.50; total 5,768.50, payroll excluded |
| US-03 | 2026, wages 0, LTCG 60,000 | Federal income tax 1,500 | 0; total taxable income 43,900 |
| US-04 | 2026, wages 50,000 plus incremental taxable ordinary investment income 10,000 | Federal income tax 3,820 | 5,020, conditional on additive ordinary-income contract |
| US-05 | 2026, age 50+, IRA headroom helper | Limit 8,500 | 8,600 |
| UK-01 | 2025–26, wages 120,000 | Income tax 39,675; combined 44,085.60 | Income tax 39,432; combined 43,842.60; marginal income tax 60% |
| UK-02 | 2025–26, wages 200,000, dividends 10,000 | Dividend tax 3,206.25 | 3,738.25; assert component separately |
| UK-03 | 2025–26, wages before net-pay pension 110,000, deduction 10,000 | Allowance 7,570; tax 29,432 | Allowance 12,570; tax 27,432; NI base unchanged |
| UK-04 | 2026–27, wages 30,000, dividends 3,000 | Dividend tax 218.75 | 268.75; combined income tax/NI 5,149.15 |
| IN-01 | FY 2025–26, old, salary 550,100 | Rebate 12,420; total 104 | Rebate 0; pre-final-round total 13,020.80 |
| IN-02a | FY 2025–26, new, salary 1,275,000, STCG 200,000 | Rebate 60,000; total 41,600 | Rebate 0; total 104,000 |
| IN-02b | FY 2025–26, old, business 300,000, STCG 100,000 | Rebate 2,500; total 20,800 | Rebate 12,500; total 10,400 |
| IN-03 | FY 2025–26, new, salary 5,050,000 | Surcharge 35,000; total 1,151,800 | Surcharge 0; total 1,115,400 |
| IN-04 | FY 2025–26, new, business 4,980,000, STCG 50,000 | Surcharge 108,400; total 1,240,096 | Surcharge 21,000; total 1,149,200 for fixed gain comparator |
| IN-05 | FY 2025–26, old, business 700,000, DOB 1965-10-01 | Total 54,600 | 52,000 |
| IN-06 | FY 2025–26, new, business 0, STCG 100,000 | Total 20,800 | 0 from basic-exemption shortfall |
| AU-01 | 2026–27, income 50,000, qualifying cover full year | Combined tax/levy 6,538 | 6,270 |
| AU-02 | 2025–26, income 28,000, qualifying cover full year | Levy 77.80; combined 945.80 | Levy 0; combined 868 |
| AU-03 | 2026–27, income 103,000, no cover | MLS 1,030; combined 24,778 | MLS 0; combined 23,480 after rate update |
| AU-04 | 2025–26, income 120,000, valid personal deductible super 20,000, no cover | MLS 0 | MLS income 120,000; taxable charge base 100,000; MLS 1,250 |
| CA-02 | 2025, Quebec employee wages 60,000 | QPP line 3,361.75 | QPP 3,616, before tax-credit corrections |
| CA-03 | 2025, Ontario employee wages 60,000 | Federal tax 6,518.80 | Enhanced CPP deduction 565; base CPP credit amount 2,796.75; EI credit amount 984; federal tax about 5,854.76 excluding CEA |
| CA-04 | 2025, Ontario self-employed net profit 60,000, no EI opt-in | CPP 3,361.75; EI 984 | CPP 6,723.50; EI 0; income-tax effects tested separately |
| CA-06 | 2025, Ontario taxable band at income 120,000 | Marginal 37.16% | Income-tax marginal 43.4096% before other adjustments |

For US taxpayers with taxable income below $100,000, official return instructions can require the IRS Tax Table rather than exact bracket-formula arithmetic. The US examples above validate the app's advertised continuous bracket model; a return-filing implementation must separately implement the applicable table/worksheet rounding. This is an additional P2 precision/scope gap, not a reason to dismiss the much larger deduction errors. [IRS Form 1040 instructions, line 16 and qualified-dividend worksheet](https://www.irs.gov/instructions/i1040gi). Likewise, statutory Indian rounding must not be mixed into the rebate/surcharge component tests.

Example regression setup using the existing domain API:

```swift
var profile = TaxProfile(
    country: .india,
    annualIncome: 550_100,
    financialYear: "2025-26",
    incomeSourceType: .salaried
)
profile.indiaRegime = .oldRegime
let estimate = IndiaTaxCalculator().calculate(profile: profile)
#expect(estimate.rebate == 0)
// Assert the pre-final-rounding component or the new explicit payable-tax field.
// Decimal(string: "13020.80") is exact; Decimal(13020.80) is not.
```

Preserve all these inputs when repairing the calculations. Add independent expected-value derivations beside fixtures, with source/year/assumptions. Do not regenerate expected results from the production calculator being tested.

## 10. Suggested implementation sequence for Claude Code

1. **Establish country income/result contracts and year resolution.** Document wages/business/pension/gain semantics, requested/applied year, net versus taxable income, payroll inclusion, rounding and denominator. Add failing source-backed regressions for the confirmed bugs.
2. **Repair India core calculation ordering.** Total income → rebate eligibility/eligible tax → surcharge/marginal relief → cess → payable rounding. Share age eligibility; then typed deductions and gain exemptions. Retest both regimes and comparisons.
3. **Repair US deduction allocation and senior rules.** Correct current preferential thresholds and historical limits; add contribution eligibility and source distinctions. Keep excluded IRA deductions explicit until implemented.
4. **Repair UK band traversal and ANI.** Fix held-year edges and monotonic dividend stacking; add current-year rules; then typed relief/NI categories.
5. **Repair AU years, Medicare and MLS definitions.** Split super sources before claiming a correct deduction or savings figure; implement family/cover-period eligibility or constrain scope.
6. **Repair Canada contributions before income tax.** CPP/QPP/source categories, deductible versus creditable portions, BPA/provincial corrections and current-year tables; then rates/credits/levies and rendering.
7. **Make the visible breakdown reconcile and expand the tax test target.** Update localization, provenance and coverage docs together. Preserve bundled/offline calculation.

Use focused commits per independent risk area. Follow `AGENTS.md`: exact Decimal money, no production force unwraps, localized strings, Sendable-safe patterns, no unapproved SDKs, and tests for finance logic. Do not change assertions or move fixture inputs out of the failing scenario to make a check pass. Escalate a demonstrably wrong existing oracle as an explicit, source-backed conflict rather than silently editing it.

Validation after implementation should include the dedicated suites in `VittoraTests/Core/Domain/{UKTax,AUTax,CATax}CalculatorTests.swift`, `USPreTaxContributionTests`, `TaxEffectiveRateContractTests`, `VittoraTests/Features/Tax/{TaxCalculatorRegression,TaxRuleTableGolden,TaxRuleTableLookup,IndiaSectionDeductionEngine}Tests.swift`, saving-use-case tests, and profile/view-model tests. Start with `make test-tax` only after correcting its selections; use `make test` for integration coverage. Inspect tracked plist/project/watch-string churn before committing a build. This review executed none of those Xcode targets.

## 11. Remaining evidence/coverage limits

- Most ATO ordinary website pages returned access errors in the review tool. Enacted Australian income-rate and Medicare legislation and government MLS guidance were accessible. The super cap has current CSC government corroboration; retrieve the ATO cap/eligibility reference before implementing its full rules. No guessed cap was used as an executed expected-tax result.
- Canada has real official-source conflicts for Manitoba annual bands and BC early payroll versus current annual rates. These must be resolved against current provincial law/annual forms, not by preferring whichever webpage is easiest to parse.
- Complex Indian historical rebate litigation/return treatment, mixed-gain threshold counterfactual allocation, capital-loss ordering, specialized deductions and non-resident rules were not exhaustively certified. The simple counterexamples above remain valid without resolving all those cases.
- Review of a small set of resident scenarios cannot establish coverage of every credit, household condition, special income, cross-border rule or payroll schedule. Unsupported scenarios should produce specific, actionable exclusions, not only a generic “consult an adviser” disclaimer.

**Completion criterion for fixes:** each confirmed counterexample passes an independent statutory assertion; current-year tables have per-jurisdiction source provenance; supported input contracts are unambiguous; displayed bridges reconcile; unsupported conditions are explicit; and appropriate finance tests pass without weakening their inputs or checks.
