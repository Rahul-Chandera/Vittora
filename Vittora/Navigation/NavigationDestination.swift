import Foundation

enum NavigationDestination: Hashable {
    // Accounts
    case accountDetail(id: UUID)
    case addAccount

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

    // Reports
    case reportDetail(type: ReportType)

    // Settings
    case settingsDetail(section: SettingsSection)
}

enum ReportType: String, Hashable, Sendable {
    case monthly, annual, category, cashFlow, netWorth
}

enum SettingsSection: String, Hashable, Sendable {
    case profile, security, sync, notifications, appearance, data, about
}
