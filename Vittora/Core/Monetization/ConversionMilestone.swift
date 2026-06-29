import Foundation

enum ConversionMilestone: String, CaseIterable, Sendable, Codable {
    case tenthTransaction
    case firstOCRScan
    case firstReport
    case firstSplit
    case accountLimitReached
    case budgetLimitReached
    case ocrMonthlyLimitReached
}

struct ConversionEventResult: Sendable, Equatable {
    nonisolated let milestone: ConversionMilestone
    nonisolated let isFirstTime: Bool
    nonisolated let shouldPresentPaywall: Bool

    nonisolated init(
        milestone: ConversionMilestone,
        isFirstTime: Bool,
        shouldPresentPaywall: Bool
    ) {
        self.milestone = milestone
        self.isFirstTime = isFirstTime
        self.shouldPresentPaywall = shouldPresentPaywall
    }
}
