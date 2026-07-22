# C1 — India compliance tips

**Branch:** `feature/c1-india-compliance-tips` · **PR into:** `develop` ·
**Review tier: A — pre-merge sign-off required** (tax/legal surface) ·
**Parallel-safe:** yes

## Context

Plan M3.6.3. India is a Wave 1 storefront. 1.3 gave it Hindi (L1) and we
already ship a regime comparison; this adds the compliance rules an Indian
user is most likely to trip over without knowing. It is **rules-based**, so
unlike spending-pattern features it is useful on a brand-new install.

## Reuse, do not reinvent

- `Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift`
- `Vittora/Core/Infrastructure/Tax/IndiaSectionDeductionEngine.swift`
- `Vittora/Core/Domain/UseCases/CompareTaxRegimesUseCase.swift`
- `Vittora/Features/Tax/Components/TaxDisclaimerView.swift` — the disclaimer
  component already exists; use it, do not write a second one.

Thresholds go in the existing rule/config layer alongside the tax tables,
**never inline in a view**, and each carries the assessment year it applies
to. See `Docs/Tax/RULE_COVERAGE.md` and add these rules to it.

## Scope

Surface a tip when the user's own recorded data crosses a threshold. Only
these rules in this task:

1. **Cash transaction limit** — §269ST: receiving ₹2,00,000 or more in cash
   in aggregate from one person in a day / for one event.
2. **Cash expense disallowance** — §40A(3): cash business expense above
   ₹10,000 in a day.
3. **Large deposit reporting** — SFT thresholds: cash deposits aggregating
   ₹10,00,000+ in a financial year in savings accounts; ₹50,00,000+ in
   current accounts.
4. **GST registration threshold** — ₹40,00,000 goods / ₹20,00,000 services
   annual turnover (₹20,00,000 / ₹10,00,000 in special-category states).
   Only evaluate this when the user has marked income as business income.
5. **TDS on rent** — §194-IB: individual paying rent above ₹50,000/month.

Each tip states the threshold, what the user's own figure is, and what the
rule requires. Tips appear in the Tax section and are **dismissible**;
dismissal persists per rule per financial year.

## Non-goals

Filing anything, computing penalties, GST return preparation, advising on
structuring, and any rule not in the list above. **No US rules in this task.**

## Legal/compliance requirements (Tier A)

- **Every tip carries the existing disclaimer**: general information, not tax
  advice, consult a qualified professional. A tip must never use imperative
  advice phrasing ("you should", "reduce your"). State the rule and the
  user's figure; let them draw the conclusion.
- **Thresholds are `Decimal`, from integer or `Decimal(string:)` literals.**
  Never a float literal (AGENTS.md money rule).
- **Comparisons at the boundary must be exact.** ₹2,00,000 exactly is *at*
  the §269ST limit — the code and its test must agree on whether the rule
  triggers at `>=` or `>`, and the test must assert the exact boundary value,
  one paisa below, and one paisa above.
- Each rule records its **assessment year and statutory source** in the rule
  definition, so a future year's change is a data edit, not a code hunt.
- Tips are computed **on device from the user's own records only**. No
  network call, no lookup service.

## Acceptance criteria

- [ ] Each of the five rules has unit tests at the exact boundary, just
      below, and just above.
- [ ] A test asserts tips are suppressed entirely when the user's country is
      not India.
- [ ] GST tip does not appear for a user with no business income.
- [ ] Dismissal persists across launches and resets on a new financial year.
- [ ] Disclaimer visible on every tip; a test asserts no tip string contains
      imperative advice phrasing.
- [ ] `Docs/Tax/RULE_COVERAGE.md` updated with all five rules and sources.
- [ ] PR body cites the statutory section for each threshold; the reviewer
      independently verifies each figure before sign-off.
- [ ] Hindi strings for every new user-facing string (L1 shipped `hi`).
- [ ] `make test-tax` and `make test` green.
- [ ] **Reviewer sign-off posted before merge.**
