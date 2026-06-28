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
    let milestone: ConversionMilestone
    let isFirstTime: Bool
    let shouldPresentPaywall: Bool
}
