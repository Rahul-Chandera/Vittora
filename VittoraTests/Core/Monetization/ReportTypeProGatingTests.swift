import Foundation
import Testing
@testable import Vittora

/// The Pro report set is the single place a report becomes paid. A typo here either
/// gives a Pro report away or locks a free one, and neither shows up in a build.
@Suite("Report Type Pro Gating Tests")
struct ReportTypeProGatingTests {
    /// Catches a regression where a report is added to or dropped from the paid set.
    ///
    /// Updated 2026-09-23 for M3.2.4 and M3.2.2/M3.2.5: `.healthScore` and
    /// `.spendingOutlook` join the paid set, making seven.
    /// This assertion exists to force that decision to be stated rather than
    /// defaulted, so changing it IS the intended response to adding a report —
    /// the alternative would be letting a test decide the pricing.
    @Test("exactly the seven paid reports require Pro")
    func exactlySevenReportsRequirePro() {
        let pro = Set(ReportType.allCases.filter(\.requiresPro))
        #expect(pro == [.cashFlowForecast, .subscriptionAudit, .fiftyThirtyTwenty, .emergencyFund, .custom, .healthScore, .spendingOutlook])
    }

    /// Catches a regression where a never-gated report starts demanding Pro.
    @Test("monthly, annual, split-adjacent and year in review stay free")
    func coreReportsStayFree() {
        for type in [ReportType.monthly, .category, .trends, .annual, .cashFlow, .netWorth, .yearInReview] {
            #expect(type.requiresPro == false, "\(type.rawValue) must stay free")
        }
    }

    /// Catches a regression where a newly added ReportType is silently free because
    /// nobody classified it.
    @Test("every report type is classified")
    func everyReportTypeIsClassified() {
        #expect(ReportType.allCases.count == 14)
    }
}
