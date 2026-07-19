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
    case monthly, category, trends, custom, annual, cashFlow, cashFlowForecast, netWorth, subscriptionAudit
}

enum SettingsSection: String, Hashable, Sendable {
    case profile, security, sync, notifications, appearance, data, about
}
