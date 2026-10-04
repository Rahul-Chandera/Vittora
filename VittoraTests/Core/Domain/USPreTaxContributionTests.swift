import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M2.4.3. A tax-engine change, so it gets targeted tests per AGENTS.md rather than riding
/// on the presentation layer above it.
///
/// Until now 401(k)/IRA/HSA amounts only drove the headroom display and never touched
/// taxable income, so "what would contributing more save?" would have answered $0 for every
/// US profile.
@MainActor
@Suite("US Pre-Tax Contribution Tests")
struct USPreTaxContributionTests {

    private let estimate = EstimateTaxUseCase()

    private func profile(
        income: Decimal = 120_000,
        contributed401k: Decimal = 0,
        isRoth401k: Bool = false,
        contributedIRA: Decimal = 0,
        contributedHSA: Decimal = 0,
        familyHSA: Bool = false
    ) -> TaxProfile {
        var advanced = TaxAdvancedInputs()
        advanced.us401kYTDContributed = contributed401k
        advanced.us401kIsRoth = isRoth401k
        advanced.usIRAYTDContributed = contributedIRA
        advanced.usHSAYTDContributed = contributedHSA
        advanced.usHSAFamilyCoverage = familyHSA
        return TaxProfile(
            country: .unitedStates,
            annualIncome: income,
            filingStatus: .single,
            financialYear: "2026",
            advancedInputs: advanced
        )
    }

    @Test("a traditional 401(k) deferral reduces taxable income")
    func traditional401kReducesTaxableIncome() {
        let without = estimate.execute(profile: profile())
        let with = estimate.execute(profile: profile(contributed401k: 10_000))

        #expect(with.taxableIncome == without.taxableIncome - 10_000)
        #expect(with.finalTax < without.finalTax)
    }

    /// The direction that would have been wrong if the flag were assumed rather than asked:
    /// a Roth saver's tax must not drop.
    @Test("a Roth 401(k) deferral changes nothing")
    func roth401kChangesNothing() {
        let without = estimate.execute(profile: profile())
        let roth = estimate.execute(profile: profile(contributed401k: 10_000, isRoth401k: true))

        #expect(roth.taxableIncome == without.taxableIncome)
        #expect(roth.finalTax == without.finalTax)
        #expect(roth.assumptions.contains { $0.contains("after tax") })
    }

    @Test("an HSA contribution reduces taxable income regardless of the 401(k) choice")
    func hsaReducesTaxableIncome() {
        let without = estimate.execute(profile: profile())
        let with = estimate.execute(profile: profile(contributedHSA: 3_000))

        #expect(with.taxableIncome == without.taxableIncome - 3_000)
    }

    /// Typing a number larger than the law allows must not buy tax relief.
    @Test("contributions above the statutory limit are capped")
    func contributionsAreCappedAtTheStatutoryLimit() {
        let limit = USContributionHeadroomEngine.statutory401kLimit(taxYear: 2026, age50Plus: false)
        let atLimit = estimate.execute(profile: profile(contributed401k: limit))
        let wayOver = estimate.execute(profile: profile(contributed401k: limit * 10))

        #expect(wayOver.taxableIncome == atLimit.taxableIncome)
        #expect(wayOver.finalTax == atLimit.finalTax)
    }

    /// A deferral is exempt from federal income tax but not from FICA. If payroll moved
    /// with taxable income, the estimate would understate what is actually withheld.
    @Test("payroll estimates stay on gross wages, not the reduced figure")
    func payrollStaysOnGrossWages() {
        let without = estimate.execute(profile: profile())
        let with = estimate.execute(profile: profile(contributed401k: 10_000))

        let payrollLines: (TaxEstimate) -> [Decimal] = { estimate in
            estimate.supplementaryLines
                .filter { !$0.title.localizedCaseInsensitiveContains("headroom") }
                .map(\.amount)
        }
        #expect(payrollLines(with) == payrollLines(without))
    }

    /// Withheld on purpose: deductibility phases out with income when a workplace plan
    /// covers the saver, and Vittora does not know about coverage. Better no figure than a
    /// flattering one.
    @Test("a traditional IRA contribution does not reduce tax, and the estimate says why")
    func iraIsExcludedAndExplained() {
        let without = estimate.execute(profile: profile())
        let with = estimate.execute(profile: profile(contributedIRA: 7_000))

        #expect(with.taxableIncome == without.taxableIncome)
        #expect(with.exclusions.contains { $0.contains("IRA") })
    }

    @Test("profiles with no contributions are completely unaffected")
    func noContributionsNoChange() {
        let estimateResult = estimate.execute(profile: profile())
        #expect(estimateResult.taxableIncome > 0)
        #expect(estimateResult.assumptions.contains { $0.contains("Pre-tax") } == false)
    }

    /// Saved profiles predate this field, so their JSON has no key for it. A synthesised
    /// Codable would throw on the missing key even with a default on the property.
    @Test("a profile saved before the Roth flag existed still decodes")
    func legacyAdvancedInputsStillDecode() throws {
        let json = Data(#"{"us401kYTDContributed":5000}"#.utf8)
        let decoded = try JSONDecoder().decode(TaxAdvancedInputs.self, from: json)

        #expect(decoded.us401kYTDContributed == 5_000)
        #expect(decoded.us401kIsRoth == false)
    }
}

/// M2.4.3's user-facing half: what contributing more would save.
@MainActor
@Suite("US Contribution Scenario Tests")
struct USContributionScenarioTests {

    private let useCase = EstimateTaxSavingUseCase()

    private func profile(contributed401k: Decimal = 0, isRoth: Bool = false) -> TaxProfile {
        var advanced = TaxAdvancedInputs()
        advanced.us401kYTDContributed = contributed401k
        advanced.us401kIsRoth = isRoth
        return TaxProfile(
            country: .unitedStates,
            annualIncome: 150_000,
            filingStatus: .single,
            financialYear: "2026",
            advancedInputs: advanced
        )
    }

    @Test("contributing more to a traditional 401(k) saves tax")
    func moreTraditional401kSaves() {
        let scenario = useCase.execute(profile: profile(), contribution: .traditional401k, additionalAmount: 10_000)

        #expect(scenario.deductibleAmount == 10_000)
        #expect(scenario.taxSaved > 0)
        #expect(scenario.notes.contains { $0.contains("Social Security") })
    }

    @Test("a Roth 401(k) saves nothing, and the note names the reason")
    func rothSavesNothing() {
        let scenario = useCase.execute(profile: profile(isRoth: true), contribution: .traditional401k, additionalAmount: 10_000)

        #expect(scenario.taxSaved == 0)
        #expect(scenario.isIneffective)
        #expect(scenario.notes.contains { $0.contains("Roth") })
    }

    /// Already at the limit: the honest answer is zero, same as a full 80C.
    @Test("contributing past the statutory limit saves nothing more")
    func pastTheLimitSavesNothing() {
        let limit = USContributionHeadroomEngine.statutory401kLimit(taxYear: 2026, age50Plus: false)
        let scenario = useCase.execute(
            profile: profile(contributed401k: limit),
            contribution: .traditional401k,
            additionalAmount: 5_000
        )

        #expect(scenario.deductibleAmount == 0)
        #expect(scenario.taxSaved == 0)
        #expect(scenario.notes.contains { $0.contains("statutory limit") })
    }

    @Test("only the part under the limit counts")
    func partialHeadroomIsRespected() {
        let limit = USContributionHeadroomEngine.statutory401kLimit(taxYear: 2026, age50Plus: false)
        let scenario = useCase.execute(
            profile: profile(contributed401k: limit - 2_000),
            contribution: .traditional401k,
            additionalAmount: 10_000
        )

        #expect(scenario.deductibleAmount == 2_000)
        #expect(scenario.taxSaved > 0)
    }

    @Test("an HSA contribution saves tax on its own limit")
    func hsaSaves() {
        let scenario = useCase.execute(profile: profile(), contribution: .hsa, additionalAmount: 2_000)
        #expect(scenario.deductibleAmount == 2_000)
        #expect(scenario.taxSaved > 0)
    }

    @Test("zero is a no-op")
    func zeroIsANoOp() {
        let scenario = useCase.execute(profile: profile(), contribution: .hsa, additionalAmount: 0)
        #expect(scenario.taxSaved == 0)
        #expect(scenario.baselineTax == scenario.scenarioTax)
    }
}
