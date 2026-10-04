import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M2.4.4. The scenario engine owns no tax arithmetic, so these assert the behaviours a
/// user would be misled by if they broke: a capped section must report zero rather than a
/// plausible number, and the new regime must not appear to grant old-regime deductions.
/// `@MainActor` because the app target defaults to MainActor isolation, so the calculator
/// chain `EstimateTaxUseCase` routes to is main-isolated too.
@MainActor
@Suite("Tax Saving Scenario Tests")
struct EstimateTaxSavingUseCaseTests {

    private let useCase = EstimateTaxSavingUseCase()

    private func indiaProfile(
        income: Decimal,
        regime: IndiaRegime = .oldRegime,
        deductions: [TaxDeduction] = []
    ) -> TaxProfile {
        TaxProfile(
            country: .india,
            annualIncome: income,
            indiaRegime: regime,
            customDeductions: deductions,
            financialYear: "2025-26",
            incomeSourceType: .salaried
        )
    }

    @Test("an empty 80C turns a contribution into a real tax saving")
    func emptyEightyCSaves() {
        let profile = indiaProfile(income: 1_200_000)
        let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)

        #expect(scenario.deductibleAmount == 150_000)
        #expect(scenario.taxSaved > 0)
        #expect(scenario.isIneffective == false)
        // Saving per unit deducted cannot exceed the top marginal rate plus cess.
        #expect(scenario.savingRate <= 0.35)
    }

    /// The case that makes the feature worth shipping: the honest answer is zero, and a
    /// calculator that reported a saving here would be teaching the user to waste money.
    @Test("a full 80C reports no saving and says why")
    func fullEightyCSavesNothing() {
        let profile = indiaProfile(
            income: 1_200_000,
            deductions: [TaxDeduction(name: "PPF", amount: 150_000, section: "80C")]
        )
        let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: 50_000)

        #expect(scenario.deductibleAmount == 0)
        #expect(scenario.taxSaved == 0)
        #expect(scenario.isIneffective)
        #expect(scenario.savingRate == 0)
        #expect(scenario.notes.isEmpty == false)
    }

    @Test("a partly used 80C deducts only the headroom")
    func partialEightyCDeductsHeadroomOnly() {
        let profile = indiaProfile(
            income: 1_200_000,
            deductions: [TaxDeduction(name: "EPF", amount: 100_000, section: "80C")]
        )
        let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: 100_000)

        #expect(scenario.deductibleAmount == 50_000)
        #expect(scenario.taxSaved > 0)
        #expect(scenario.notes.isEmpty == false)
    }

    @Test("80CCD(1B) is its own 50k limit on top of a full 80C")
    func eightyCCD1BIsSeparateFromEightyC() {
        let profile = indiaProfile(
            income: 1_200_000,
            deductions: [TaxDeduction(name: "PPF", amount: 150_000, section: "80C")]
        )
        let scenario = useCase.execute(profile: profile, section: "80CCD(1B)", additionalAmount: 50_000)

        #expect(scenario.deductibleAmount == 50_000)
        #expect(scenario.taxSaved > 0)
    }

    @Test("the new regime grants no 80C, and the note explains that rather than the cap")
    func newRegimeGrantsNoEightyC() {
        let profile = indiaProfile(income: 1_200_000, regime: .newRegime)
        let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)

        #expect(scenario.deductibleAmount == 0)
        #expect(scenario.taxSaved == 0)
        #expect(scenario.notes.contains { $0.contains("new regime") })
    }

    @Test("income below the taxable threshold saves nothing to save")
    func noTaxMeansNoSaving() {
        let profile = indiaProfile(income: 300_000)
        let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)

        #expect(scenario.taxSaved == 0)
    }

    @Test("a zero or negative amount is a no-op, not a crash")
    func zeroAmountIsANoOp() {
        let profile = indiaProfile(income: 1_200_000)
        for amount in [Decimal(0), Decimal(-1)] {
            let scenario = useCase.execute(profile: profile, section: "80C", additionalAmount: amount)
            #expect(scenario.taxSaved == 0)
            #expect(scenario.deductibleAmount == 0)
            #expect(scenario.baselineTax == scenario.scenarioTax)
        }
    }

    /// Higher income sits in a higher bracket, so the same contribution is worth more.
    /// This is the comparison the screen exists to make legible.
    @Test("the same contribution saves more at a higher marginal rate")
    func savingScalesWithMarginalRate() {
        let lower = useCase.execute(
            profile: indiaProfile(income: 800_000),
            section: "80C",
            additionalAmount: 50_000
        )
        let higher = useCase.execute(
            profile: indiaProfile(income: 2_500_000),
            section: "80C",
            additionalAmount: 50_000
        )

        #expect(higher.taxSaved > lower.taxSaved)
        #expect(higher.savingRate > lower.savingRate)
    }

    @Test("a US itemised deduction below the standard deduction changes nothing")
    func usItemisedBelowStandardChangesNothing() {
        let profile = TaxProfile(
            country: .unitedStates,
            annualIncome: 120_000,
            filingStatus: .single,
            financialYear: "2026"
        )
        let scenario = useCase.execute(profile: profile, section: "itemized", additionalAmount: 1_000)

        #expect(scenario.taxSaved == 0)
        #expect(scenario.isIneffective)
        #expect(scenario.notes.isEmpty == false)
    }

    /// The US partial case is not a statutory cap — itemising replaces the standard
    /// deduction rather than adding to it, and saying "above the statutory limit" there
    /// told the user the wrong story. Caught by running it in the simulator.
    @Test("a US itemised deduction above the standard deduction explains the replacement, not a cap")
    func usItemisedAboveStandardExplainsReplacement() {
        let profile = TaxProfile(
            country: .unitedStates,
            annualIncome: 85_000,
            filingStatus: .single,
            financialYear: "2026"
        )
        let scenario = useCase.execute(profile: profile, section: "itemized", additionalAmount: 25_000)

        #expect(scenario.taxSaved > 0)
        // Only the excess over the standard deduction does any work.
        #expect(scenario.deductibleAmount < 25_000)
        #expect(scenario.deductibleAmount > 0)
        #expect(scenario.notes.contains { $0.contains("standard deduction") })
        #expect(scenario.notes.contains { $0.contains("statutory limit") } == false)
    }
}
