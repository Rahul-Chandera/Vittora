import SwiftUI

struct NavigationDestinationHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .accountDetail(let id):
                    AccountDetailView(accountID: id)
                case .addAccount:
                    AccountFormView()
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
        case .monthly:   MonthlyReportView()
        case .category:  CategoryReportView()
        case .trends:    TrendsReportView()
        case .custom:    CustomReportView()
        case .annual:    MonthlyReportView()   // reuse monthly view for annual — refine in F4/F5
        case .cashFlow:  TrendsReportView()
        case .netWorth:  MonthlyReportView()
        }
    }

    // MARK: - Settings routing

    @ViewBuilder
    private func settingsView(for section: SettingsSection) -> some View {
        let vm = SettingsViewModel()
        switch section {
        case .profile:       ProfileSettingsView(vm: vm)
        case .security:      SecuritySettingsView(vm: vm)
        case .sync:          SyncSettingsView(vm: vm)
        case .notifications: NotificationsSettingsView(vm: vm)
        case .appearance:    AppearanceSettingsView(vm: vm)
        case .data:          DataSettingsView()
        case .about:         AboutView(vm: vm)
        }
    }
}

extension View {
    func withNavigationDestinations() -> some View {
        modifier(NavigationDestinationHandler())
    }
}
