import SwiftUI

struct NavigationDestinationHandler: ViewModifier {
    @Environment(SettingsViewModel.self) private var settingsVM

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .accountDetail(let id):
                    AccountDetailView(accountID: id)
                case .addAccount:
                    AccountFormView()
                case .addTransfer:
                    TransferFormView()
                case .transactionDetail(let id):
                    TransactionDetailView(transactionID: id)
                case .addTransaction:
                    TransactionFormView()
                case .editTransaction(let id):
                    TransactionFormView(transactionID: id)
                case .categoryDetail(let id):
                    CategoryDetailView(categoryID: id)
                case .addCategory:
                    CategoryFormView()
                case .budgetDetail(let id):
                    BudgetDetailView(budgetID: id)
                case .addBudget:
                    BudgetFormView(isPresented: .constant(false))
                case .payeeDetail(let id):
                    PayeeDetailView(payeeID: id)
                case .reportDetail(let type):
                    reportView(for: type)
                case .settingsDetail(let section):
                    settingsView(for: section)
                }
            }
    }

    // MARK: - Report routing

    @ViewBuilder
    private func reportView(for type: ReportType) -> some View {
        switch type {
        case .monthly:   MonthlyOverviewView()
        case .category:  CategoryBreakdownView()
        case .trends:    SpendingTrendsView()
        case .custom:    CustomReportView()
        case .annual:    AnnualReportView()
        case .cashFlow:  CashFlowReportView()
        case .netWorth:  NetWorthReportView()
        }
    }

    // MARK: - Settings routing

    @ViewBuilder
    private func settingsView(for section: SettingsSection) -> some View {
        switch section {
        case .profile:       ProfileSettingsView(vm: settingsVM)
        case .security:      SecuritySettingsView(vm: settingsVM)
        case .sync:          SyncSettingsView(vm: settingsVM)
        case .notifications: NotificationsSettingsView(vm: settingsVM)
        case .appearance:    AppearanceSettingsView(vm: settingsVM)
        case .data:          DataSettingsView()
        case .about:         AboutView(vm: settingsVM)
        }
    }
}

extension View {
    func withNavigationDestinations() -> some View {
        modifier(NavigationDestinationHandler())
    }
}
