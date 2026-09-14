import Foundation
import VittoraCore

/// Free-tier caps.
///
/// Accounts and budgets are deliberately uncapped (DEC-014): capping how many
/// records a user may keep is a cap on record-keeping, which stays free. OCR is
/// the one real cap, because unlimited receipt OCR is a named Pro feature.
enum FreeTierLimits {
    nonisolated static let maxOCRScansPerMonth = 5
    nonisolated static let transactionMilestoneCount = 10
}
