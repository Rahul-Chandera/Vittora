import SwiftUI

struct NavigationDestinationHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .accountDetail(let id):
                    Text(String(localized: "Account Detail: \(id)"))
                case .addAccount:
                    Text(String(localized: "Add Account"))
                case .transactionDetail(let id):
                    Text(String(localized: "Transaction Detail: \(id)"))
                case .addTransaction:
                    Text(String(localized: "Add Transaction"))
                case .editTransaction(let id):
                    Text(String(localized: "Edit Transaction: \(id)"))
                case .categoryDetail(let id):
                    Text(String(localized: "Category Detail: \(id)"))
                case .addCategory:
                    Text(String(localized: "Add Category"))
                case .budgetDetail(let id):
                    Text(String(localized: "Budget Detail: \(id)"))
                case .addBudget:
                    Text(String(localized: "Add Budget"))
                case .payeeDetail(let id):
                    Text(String(localized: "Payee Detail: \(id)"))
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
