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
                    Text(String(localized: "Transaction Detail: \(id)"))
                case .addTransaction:
                    Text(String(localized: "Add Transaction"))
                case .editTransaction(let id):
                    Text(String(localized: "Edit Transaction: \(id)"))
                case .categoryDetail(let id):
                    CategoryDetailView(categoryID: id)
                case .addCategory:
                    CategoryFormView()
                case .budgetDetail(let id):
                    Text(String(localized: "Budget Detail: \(id)"))
                case .addBudget:
                    Text(String(localized: "Add Budget"))
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
