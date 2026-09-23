import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// `TaxEstimate.effectiveRate` is a FRACTION, and every calculator must agree.
///
/// Why this suite exists: the UK, Australian and Canadian calculators each
/// returned a percentage instead. Every display site multiplies by 100, so a
/// UK salary of £85,000 read "Effective Rate 2,958.0%" on the estimator, the
/// dashboard, the comparison view and the live preview in the profile form.
///
/// Nothing caught it. Each calculator had a thorough golden-fixture suite, but
/// the only `effectiveRate` assertion in any of them was the zero-income case
/// — which holds under either convention. A per-country suite cannot see a
/// disagreement *between* countries, so this one checks the shared contract
/// across all five.
///
/// `marginalRate` is deliberately the other way round (40 means 40%), which is
/// precisely why the fraction needs pinning rather than trusting.
@Suite("TaxEstimate.effectiveRate contract")
@MainActor
struct TaxEffectiveRateContractTests {

    /// Every country at one plainly-taxed salary. The values are not pinned
    /// here — the per-country golden suites own the arithmetic. This asserts
    /// only the unit, which is what crossed countries.
    private func estimates() -> [(name: String, estimate: TaxEstimate)] {
        var uk = TaxAdvancedInputs()
        uk.ukIsScottishTaxpayer = false

        var au = TaxAdvancedInputs()
        au.auHasPrivateHospitalCover = true

        var ca = TaxAdvancedInputs()
        ca.caProvince = .ontario

        return [
            ("India", IndiaTaxCalculator().calculate(profile: TaxProfile(
                country: .india, annualIncome: 1_500_000, financialYear: "2025-26"
            ))),
            ("United States", USTaxCalculator().calculate(profile: TaxProfile(
                country: .unitedStates, annualIncome: 85_000, financialYear: "2026"
            ))),
            ("United Kingdom", UKTaxCalculator().calculate(profile: TaxProfile(
                country: .unitedKingdom, annualIncome: 85_000,
                financialYear: "2025-26", advancedInputs: uk
            ))),
            ("Australia", AUTaxCalculator().calculate(profile: TaxProfile(
                country: .australia, annualIncome: 85_000,
                financialYear: "2025-26", advancedInputs: au
            ))),
            ("Canada", CATaxCalculator().calculate(profile: TaxProfile(
                country: .canada, annualIncome: 85_000,
                financialYear: "2025", advancedInputs: ca
            ))),
        ]
    }

    /// The regression itself: a percentage here is >= 1 for any real bill.
    @Test("effective rate is a fraction, never a percentage")
    func effectiveRateIsAFraction() {
        for (name, estimate) in estimates() {
            #expect(estimate.finalTax > 0, "\(name): fixture should owe tax, else the check is vacuous")
            #expect(
                estimate.effectiveRate > 0 && estimate.effectiveRate < 1,
                "\(name): effectiveRate \(estimate.effectiveRate) is not a fraction — a percentage renders 100x high"
            )
        }
    }

    /// Pins it to the figures beside it on screen, so the rate cannot drift
    /// away from the tax and income the same card shows.
    @Test("effective rate equals final tax over gross income")
    func effectiveRateMatchesTheCardItSitsOn() {
        for (name, estimate) in estimates() {
            let expected = (estimate.finalTax / estimate.grossIncome).rounded(scale: 4)
            #expect(
                estimate.effectiveRate == expected,
                "\(name): effectiveRate \(estimate.effectiveRate) != finalTax/grossIncome \(expected)"
            )
        }
    }

    /// The asymmetry that caused the bug, stated as a test so it is not guessed
    /// at again: this one IS a percentage.
    @Test("marginal rate is a percentage, unlike the effective rate")
    func marginalRateIsAPercentage() {
        for (name, estimate) in estimates() where estimate.marginalRate > 0 {
            #expect(
                estimate.marginalRate >= 1,
                "\(name): marginalRate \(estimate.marginalRate) looks like a fraction"
            )
        }
    }
}
