import SwiftUI
import VittoraCore

struct NavigationDestinationHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Reset the inherited tint for screen content.
            //
            // `AppTabView` tints the TabView with `VColors.primary` so the
            // selected tab matches the accent swatch the user picked. `.tint`
            // inherits all the way down, though, so without this every Picker
            // and Menu label in the app — "Monthly", "Year 2026" — also renders
            // in the *fill* accent. That colour is chosen to carry white
            // content, not to be read against a surface: purple on the dark
            // card measures 3.35:1, under the 4.5:1 body-text minimum, which is
            // what CI's OLED audit caught. `primaryOnSurface` is the token
            // solved for exactly this and gives 5.54:1.
            //
            // Applied here because every tab routes its content through this
            // modifier, and the TabView's own tint still colours the tab items.
            .tint(VColors.primaryOnSurface)
            .navigationDestination(for: NavigationDestination.self) { destination in
                NavigationDestinationView(destination: destination)
            }
    }
}

/// Single source of truth mapping a `NavigationDestination` to its view. Used both
/// by the shared `.navigationDestination(for:)` handler and by screens that push
/// programmatically (e.g. `DashboardView`), so routing can't drift between them.
struct NavigationDestinationView: View {
    let destination: NavigationDestination
    @Environment(SettingsViewModel.self) private var settingsVM
    @Environment(SyncStatusService.self) private var syncService
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        switch destination {
        case .accountList:
            AccountListView()
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
        case .recurringDetail(let id):
            RecurringDetailView(ruleID: id)
        case .reportDetail(let type):
            reportView(for: type)
        case .settingsDetail(let section):
            settingsView(for: section)
        }
    }

    // MARK: - Report routing

    @ViewBuilder
    private func reportView(for type: ReportType) -> some View {
        switch type {
        case .fiftyThirtyTwenty: FiftyThirtyTwentyReportView()
        case .monthly:   MonthlyOverviewView()
        case .category:  CategoryBreakdownView()
        case .trends:    SpendingTrendsView()
        case .custom:    CustomReportView()
        case .annual:    AnnualReportView()
        case .cashFlow:  CashFlowReportView()
        case .cashFlowForecast: CashFlowForecastReportView()
        case .netWorth:  NetWorthReportView()
        case .subscriptionAudit: SubscriptionAuditReportView()
        case .emergencyFund: EmergencyFundReportView()
        case .yearInReview: YearInReviewView()
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
        case .support:
            ContactSupportView(
                settingsVM: settingsVM,
                dependencies: dependencies,
                syncService: syncService
            )
        }
    }
}

extension View {
    func withNavigationDestinations() -> some View {
        modifier(NavigationDestinationHandler())
    }
}
