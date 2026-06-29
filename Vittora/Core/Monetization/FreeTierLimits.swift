import Foundation

/// Planned free-tier caps used for conversion instrumentation (F5).
/// Not enforced until StoreKit gating ships (F3 fast-follow).
enum FreeTierLimits {
    nonisolated static let maxAccounts = 5
    nonisolated static let maxBudgets = 3
    nonisolated static let maxOCRScansPerMonth = 5
    nonisolated static let transactionMilestoneCount = 10
}
