import Foundation

/// Planned free-tier caps used for conversion instrumentation (F5).
/// Not enforced until StoreKit gating ships (F3 fast-follow).
enum FreeTierLimits {
    static let maxAccounts = 5
    static let maxBudgets = 3
    static let maxOCRScansPerMonth = 5
    static let transactionMilestoneCount = 10
}
