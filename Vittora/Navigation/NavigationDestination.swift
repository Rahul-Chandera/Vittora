import Foundation
import VittoraCore

enum NavigationDestination: Hashable {
    // Accounts
    case accountList
    case accountDetail(id: UUID)
    case addAccount
    case addTransfer

    // Transactions
    case transactionDetail(id: UUID)
    case addTransaction
    case editTransaction(id: UUID)

    // Categories
    case categoryDetail(id: UUID)
    case addCategory

    // Budgets
    case budgetDetail(id: UUID)
    case addBudget

    // Payees
    case payeeDetail(id: UUID)

    // Recurring
    case recurringDetail(id: UUID)

    // Reports
    case reportDetail(type: ReportType)

    // Settings
    case settingsDetail(section: SettingsSection)
}

enum ReportType: String, Hashable, Sendable, CaseIterable {
    case fiftyThirtyTwenty, monthly, category, trends, custom, annual, cashFlow, cashFlowForecast, netWorth, subscriptionAudit, emergencyFund, yearInReview
}

extension ReportType {
    /// The five Pro reports (F3). Listed exhaustively with no `default` so adding a
    /// report forces an explicit free-or-Pro decision instead of defaulting to free.
    nonisolated var requiresPro: Bool {
        switch self {
        case .cashFlowForecast, .subscriptionAudit, .fiftyThirtyTwenty, .emergencyFund, .custom:
            true
        case .monthly, .category, .trends, .annual, .cashFlow, .netWorth, .yearInReview:
            false
        }
    }
}

enum SettingsSection: String, Hashable, Sendable {
    case profile, security, sync, notifications, appearance, data, about, support
}
