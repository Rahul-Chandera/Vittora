import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Pins how a requested tax year resolves to a row of the rule table.
///
/// The golden snapshot cannot cover this on its own: today's years are
/// contiguous (2024/2025/2026), so floor and nearest-match agree everywhere.
/// They diverge the moment the table gains a gap, which is exactly what
/// happens when a future year is added, so the rule is pinned directly here.
@Suite("Tax Rule Table Year Lookup")
struct TaxRuleTableLookupTests {

    private let years = [2024, 2025, 2026]

    @Test("An exact year resolves to itself")
    func exactYearResolvesToItself() {
        for year in years {
            #expect(USTaxRuleTable.resolvedTaxYear(year, in: years) == year)
        }
    }

    @Test("A year before the table clamps up to the earliest row")
    func earlyYearClampsUp() {
        #expect(USTaxRuleTable.resolvedTaxYear(2023, in: years) == 2024)
        #expect(USTaxRuleTable.resolvedTaxYear(1999, in: years) == 2024)
    }

    @Test("A year after the table holds at the latest row")
    func lateYearHoldsAtLatest() {
        #expect(USTaxRuleTable.resolvedTaxYear(2027, in: years) == 2026)
        #expect(USTaxRuleTable.resolvedTaxYear(2099, in: years) == 2026)
    }

    /// The reason this suite exists. A later year's rules must never be applied
    /// to an earlier year, even when that later year is numerically closer.
    @Test("A gap resolves downward, never to a future year's rules")
    func gapResolvesDownward() {
        let sparse = [2024, 2030]
        #expect(USTaxRuleTable.resolvedTaxYear(2028, in: sparse) == 2024)
        #expect(USTaxRuleTable.resolvedTaxYear(2029, in: sparse) == 2024)
        #expect(USTaxRuleTable.resolvedTaxYear(2030, in: sparse) == 2030)
        #expect(USTaxRuleTable.resolvedTaxYear(2031, in: sparse) == 2030)
    }

    @Test("Resolution does not depend on the order rows are listed in")
    func orderIndependent() {
        #expect(USTaxRuleTable.resolvedTaxYear(2025, in: [2026, 2024, 2025]) == 2025)
        #expect(USTaxRuleTable.resolvedTaxYear(2023, in: [2026, 2024, 2025]) == 2024)
        #expect(USTaxRuleTable.resolvedTaxYear(2027, in: [2026, 2024, 2025]) == 2026)
    }

    @Test("A profile with an unparseable year falls back to the latest table row")
    func unparseableYearFallsBackToLatest() {
        let profile = TaxProfile(country: .unitedStates, financialYear: "not-a-year")
        #expect(USTaxCalculator.supportedTaxYear(for: profile) == USTaxRuleTable.latestTaxYear)
        #expect(USTaxRuleTable.latestTaxYear == 2026)
    }
}
