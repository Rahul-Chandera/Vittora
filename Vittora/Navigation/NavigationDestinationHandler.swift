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
                    Text(String(localized: "Report: \(type.rawValue)"))
                case .settingsDetail(let section):
                    Text(String(localized: "Settings: \(section.rawValue)"))
                }
            }
    }
}

extension View {
    func withNavigationDestinations() -> some View {
        modifier(NavigationDestinationHandler())
    }
}
