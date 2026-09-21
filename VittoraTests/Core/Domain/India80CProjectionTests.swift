import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M2.4.1/M2.4.2. The projection is the only arithmetic Vittora adds here — the instrument
/// table is statutory facts and the tax side reuses the real calculator.
@Suite("India 80C Projection Tests")
struct India80CProjectionTests {

    @Test("compounds annually at the rate the user supplied")
    func compoundsAnnually() {
        // 100000 at 10% for 3 years = 133100 exactly.
        let value = India80CProjection.futureValue(
            amount: 100_000,
            annualRatePercent: 10,
            years: 3
        )
        #expect(value == Decimal(string: "133100.00"))
    }

    @Test("a zero rate returns the amount untouched rather than shrinking it")
    func zeroRateIsIdentity() {
        #expect(India80CProjection.futureValue(amount: 150_000, annualRatePercent: 0, years: 15) == 150_000)
    }

    @Test("zero years returns the amount, so a same-year view is not a loss")
    func zeroYearsIsIdentity() {
        #expect(India80CProjection.futureValue(amount: 150_000, annualRatePercent: 12, years: 0) == 150_000)
    }

    @Test("a longer lock-in compounds further at the same rate")
    func longerLockInCompoundsFurther() {
        let threeYears = India80CProjection.futureValue(amount: 150_000, annualRatePercent: 8, years: 3)
        let fifteenYears = India80CProjection.futureValue(amount: 150_000, annualRatePercent: 8, years: 15)
        #expect(fifteenYears > threeYears)
    }

    @Test("a non-positive amount cannot produce a projection")
    func nonPositiveAmountIsClamped() {
        #expect(India80CProjection.futureValue(amount: 0, annualRatePercent: 12, years: 3) == 0)
        #expect(India80CProjection.futureValue(amount: -100, annualRatePercent: 12, years: 3) == 0)
    }

    /// Guards the reason the table exists: the moment a return figure appears in it,
    /// Vittora is publishing a forecast rather than describing an instrument.
    @Test("the instrument table states no return figures")
    func tableCarriesNoReturnFigures() {
        for instrument in India80CInstrumentTable.all {
            let text = instrument.returnBasis + " " + instrument.maturityTaxation
            #expect(text.contains("%") == false, "\(instrument.id) states a rate")
        }
    }

    @Test("every instrument declares the sections it counts against")
    func everyInstrumentDeclaresItsSections() {
        for instrument in India80CInstrumentTable.all {
            #expect(instrument.sections.isEmpty == false)
        }
        let nps = India80CInstrumentTable.all.first { $0.id == "nps-tier-1" }
        // NPS is the only one that can also use the separate 80CCD(1B) limit.
        #expect(nps?.sections.contains("80CCD(1B)") == true)
    }
}

/// The headroom inversion, pinned. `resolve` emits a `Utilization` only for sections that
/// were claimed against, so reading a missing entry as "nothing remaining" tells a user
/// with an empty 80C that they have no room — which is what the comparison screen showed
/// on its first run in the simulator.
@Suite("India Section Headroom Tests")
struct IndiaSectionHeadroomTests {

    private func resolve(_ deductions: [TaxDeduction]) -> IndiaSectionDeductionEngine.Result {
        IndiaSectionDeductionEngine.resolve(
            deductions: deductions,
            advancedInputs: TaxAdvancedInputs(),
            dateOfBirth: nil,
            financialYearLabel: "2025-26"
        )
    }

    @Test("an untouched 80C has the whole limit remaining, not zero")
    func untouchedSectionHasFullHeadroom() {
        let result = resolve([])
        #expect(result.utilizations.isEmpty)
        #expect(IndiaSectionDeductionEngine.remaining80C(in: result) == IndiaSectionDeductionEngine.cap80C)
        #expect(IndiaSectionDeductionEngine.remaining80CCD1B(in: result) == IndiaSectionDeductionEngine.cap80CCD1B)
    }

    @Test("a partly used 80C reports the difference")
    func partlyUsedSectionReportsDifference() {
        let result = resolve([TaxDeduction(name: "EPF", amount: 100_000, section: "80C")])
        #expect(IndiaSectionDeductionEngine.remaining80C(in: result) == 50_000)
    }

    @Test("a full 80C reports nothing remaining")
    func fullSectionReportsNothing() {
        let result = resolve([TaxDeduction(name: "PPF", amount: 150_000, section: "80C")])
        #expect(IndiaSectionDeductionEngine.remaining80C(in: result) == 0)
    }

    @Test("an over-claimed 80C never reports negative headroom")
    func overClaimedSectionIsClamped() {
        let result = resolve([TaxDeduction(name: "PPF", amount: 500_000, section: "80C")])
        #expect(IndiaSectionDeductionEngine.remaining80C(in: result) == 0)
    }

    @Test("80CCD(1B) headroom is independent of a full 80C")
    func eightyCCD1BIsIndependent() {
        let result = resolve([TaxDeduction(name: "PPF", amount: 150_000, section: "80C")])
        #expect(IndiaSectionDeductionEngine.remaining80CCD1B(in: result) == IndiaSectionDeductionEngine.cap80CCD1B)
    }
}

/// The shared-cap trap, pinned. ELSS, PPF and NPS all draw on one ₹1.5L 80C limit, so a
/// screen that shows a saving per instrument tells a user splitting ₹1.5L three ways that
/// they save three times over. The saving has to be computed on the aggregate.
@MainActor
@Suite("80C Allocation Aggregation Tests")
struct India80CAllocationTests {

    private let useCase = EstimateTaxSavingUseCase()

    private var profile: TaxProfile {
        TaxProfile(
            country: .india,
            annualIncome: 1_500_000,
            indiaRegime: .oldRegime,
            financialYear: "2025-26",
            incomeSourceType: .salaried
        )
    }

    @Test("splitting the limit saves the same as putting it all in one place")
    func splitMatchesLumpSum() {
        let lumpSum = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)
        let aggregated = useCase.execute(profile: profile, section: "80C", additionalAmount: 50_000 + 50_000 + 50_000)
        #expect(aggregated.taxSaved == lumpSum.taxSaved)
    }

    /// Under the cap and inside one bracket, a split and a lump sum agree — three x 50,000
    /// at a flat 30% is the same 46,800 either way, which is why the first version of this
    /// test asserted the wrong thing and failed. The overstatement appears once the
    /// allocations together exceed the limit, which is the realistic case: the cap binds on
    /// the aggregate, but a per-instrument figure would never show it binding.
    @Test("summing per-instrument savings overstates once the allocations exceed the limit")
    func perInstrumentSumOverstatesAboveTheCap() {
        let perInstrument: Decimal = 100_000
        let aggregated = useCase.execute(
            profile: profile,
            section: "80C",
            additionalAmount: perInstrument * 3
        )
        let naiveSum = (0..<3).reduce(Decimal(0)) { running, _ in
            running + useCase.execute(profile: profile, section: "80C", additionalAmount: perInstrument).taxSaved
        }

        // Only 150,000 of the 300,000 is deductible.
        #expect(aggregated.deductibleAmount == 150_000)
        #expect(naiveSum > aggregated.taxSaved)
    }

    /// The honest half of the same story: under the cap and inside one bracket the two
    /// agree, so aggregating is not a pessimisation.
    @Test("under the cap and inside one bracket, aggregating changes nothing")
    func underTheCapAggregationMatches() {
        let aggregated = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)
        let naiveSum = (0..<3).reduce(Decimal(0)) { running, _ in
            running + useCase.execute(profile: profile, section: "80C", additionalAmount: 50_000).taxSaved
        }
        #expect(naiveSum == aggregated.taxSaved)
    }

    @Test("80C and 80CCD(1B) allocations do add up, because the limits are separate")
    func separateSectionsAreAdditive() {
        let eightyC = useCase.execute(profile: profile, section: "80C", additionalAmount: 150_000)
        let nps = useCase.execute(profile: profile, section: "80CCD(1B)", additionalAmount: 50_000)
        let combined = eightyC.taxSaved + nps.taxSaved

        #expect(eightyC.taxSaved > 0)
        #expect(nps.taxSaved > 0)
        #expect(combined > eightyC.taxSaved)
    }
}
