import Foundation
import Testing
@testable import Vittora

/// The Pro report set is the single place a report becomes paid. A typo here either
/// gives a Pro report away or locks a free one, and neither shows up in a build.
@Suite("Report Type Pro Gating Tests")
struct ReportTypeProGatingTests {
    /// Catches a regression where a report is added to or dropped from the paid set.
    @Test("exactly the five F3 reports require Pro")
    func exactlyFiveReportsRequirePro() {
        let pro = Set(ReportType.allCases.filter(\.requiresPro))
        #expect(pro == [.cashFlowForecast, .subscriptionAudit, .fiftyThirtyTwenty, .emergencyFund, .custom])
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
        #expect(ReportType.allCases.count == 12)
    }
}
