import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Savings Allocation Math Tests")
struct SavingsAllocationMathTests {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    @Test("monthly required divides remaining by calendar months until deadline")
    func monthlyRequiredUsesCalendarMonths() {
        let reference = date(2026, 1, 10)
        let targetDate = date(2026, 4, 10)
        let monthly = SavingsAllocationMath.monthlyRequired(
            targetAmount: 1200,
            currentAmount: 0,
            targetDate: targetDate,
            referenceDate: reference
        )
        #expect(monthly == 400)
    }

    @Test("snapshot includes projected completion date from deadline")
    func snapshotIncludesProjectedDate() {
        let reference = date(2026, 1, 1)
        let targetDate = date(2026, 7, 1)
        let snapshot = SavingsAllocationMath.snapshot(
            targetAmount: 6000,
            currentAmount: 0,
            targetDate: targetDate,
            referenceDate: reference
        )
        #expect(snapshot.monthlyRequired == 1000)
        #expect(snapshot.projectedCompletionDate == targetDate)
        #expect(snapshot.remainingMonths == 6)
    }

    @Test("planned monthly contribution yields projected completion date")
    func plannedMonthlyYieldsProjectedDate() {
        let reference = date(2026, 1, 1)
        let snapshot = SavingsAllocationMath.snapshot(
            targetAmount: 1200,
            currentAmount: 0,
            targetDate: nil,
            plannedMonthlyContribution: 200,
            referenceDate: reference
        )
        #expect(snapshot.monthlyRequired == 200)
        #expect(snapshot.remainingMonths == 6)
        #expect(snapshot.projectedCompletionDate == date(2026, 7, 1))
    }
}

@Suite("US Contribution Headroom Tests")
struct USContributionHeadroomTests {

    @Test("401k headroom subtracts contributed YTD from statutory limit")
    func headroom401k() {
        var profile = TaxProfile(country: .unitedStates, annualIncome: 100_000, financialYear: "2026")
        profile.advancedInputs.us401kYTDContributed = 10_000

        let items = USContributionHeadroomEngine.utilizations(profile: profile, taxYear: 2026)
        let plan401k = items.first { $0.id == "401k" }
        #expect(plan401k?.statutoryLimit == 24_500)
        #expect(plan401k?.headroom == 14_500)
    }

    @Test("HSA family limit applies when family coverage is enabled")
    func hsaFamilyLimit() {
        var profile = TaxProfile(country: .unitedStates, annualIncome: 80_000, financialYear: "2026")
        profile.advancedInputs.usHSAFamilyCoverage = true
        profile.advancedInputs.usHSAYTDContributed = 1_000

        let items = USContributionHeadroomEngine.utilizations(profile: profile, taxYear: 2026)
        let hsa = items.first { $0.id == "hsa" }
        #expect(hsa?.statutoryLimit == 8_750)
        #expect(hsa?.headroom == 7_750)
    }

    @Test("supplementary lines expose remaining headroom amounts")
    func supplementaryHeadroomLines() {
        var profile = TaxProfile(country: .unitedStates, annualIncome: 90_000, financialYear: "2026")
        profile.advancedInputs.usIRAYTDContributed = 2_000

        let lines = USContributionHeadroomEngine.supplementaryHeadroomLines(profile: profile, taxYear: 2026)
        let iraLine = lines.first { $0.title.contains("IRA") }
        #expect(iraLine?.amount == 5_500)
    }
}
