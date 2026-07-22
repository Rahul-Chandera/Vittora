import SwiftUI
import VittoraCore

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.currencyCode) private var currencyCode
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var vm: DashboardViewModel?
    @State private var navigateDestination: NavigationDestination?
    @State private var activeQuickActionModal: QuickActionModal?
    @State private var isQuickEntryButtonVisible: Bool = true
    @State private var lastScrollOffsetY: CGFloat = 0

    var body: some View {
        ZStack {
            if let vm = vm {
                if vm.isLoading && vm.dashboardData == nil {
                    ProgressView()
                        .tint(VColors.primary)
                } else {
                    dashboardContent(vm)
                }
            } else {
                ProgressView()
                    .tint(VColors.primary)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            quickEntryFloatingButton
        }
        .navigationTitle(String(localized: "Dashboard"))
        .task {
            if vm == nil {
                vm = createViewModel()
                await vm?.load()
            }
        }
        .task(id: appState.dashboardRefreshToken) {
            guard vm != nil, appState.hasAnyRefresh(in: [.transactions, .accounts, .budgets, .recurring]) else { return }
            await vm?.refresh()
        }
        .navigationDestination(item: $navigateDestination) { dest in
            NavigationDestinationView(destination: dest)
        }
        .task(id: appState.pendingAccountDetailID) {
            guard let id = appState.pendingAccountDetailID else { return }
            appState.clearPendingAccountDetailID()
            let exists = (try? await dependencies.accountRepository.fetchByID(id)) != nil
            guard exists else { return }
            navigateDestination = .accountDetail(id: id)
        }
        #if os(iOS)
        .if(shouldPresentQuickActionsAsSheet) { view in
            view
                .sheet(item: $activeQuickActionModal) { modal in
                    quickActionModalView(for: modal)
                }
        }
        .if(!shouldPresentQuickActionsAsSheet) { view in
            view
                .fullScreenCover(item: $activeQuickActionModal) { modal in
                    quickActionModalView(for: modal)
                }
        }
        #else
        .sheet(item: $activeQuickActionModal) { modal in
            quickActionModalView(for: modal)
        }
        #endif
    }

    #if os(iOS)
    private var shouldPresentQuickActionsAsSheet: Bool {
        horizontalSizeClass == .regular
    }
    #endif

    @ViewBuilder
    private func dashboardContent(_ vm: DashboardViewModel) -> some View {
        ScrollView {
            #if os(iOS)
            iOSLayout(vm)
            #else
            macLayout(vm)
            #endif
        }
        .safeAreaInset(edge: .bottom) {
            VColors.background
                .frame(height: 72)
                .allowsHitTesting(false)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { oldValue, newValue in
            updateQuickEntryButtonVisibility(oldOffset: oldValue, newOffset: newValue)
        }
        .refreshable {
            await vm.refresh()
        }
        .overlay(alignment: .top) {
            if let errorMessage = vm.error {
                errorBanner(errorMessage)
            }
        }
    }

    private var quickEntryFloatingButton: some View {
        QuickEntryButton {
            appState.request(.presentNewTransaction)
        }
        .padding(.trailing, VSpacing.lg)
        .padding(.bottom, VSpacing.lg)
        .opacity(isQuickEntryButtonVisible ? 1 : 0)
        .scaleEffect(isQuickEntryButtonVisible ? 1 : 0.85)
        .offset(y: isQuickEntryButtonVisible ? 0 : 16)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: isQuickEntryButtonVisible)
        .allowsHitTesting(isQuickEntryButtonVisible)
        .accessibilityHidden(!isQuickEntryButtonVisible)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func updateQuickEntryButtonVisibility(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset
        let scrollThreshold: CGFloat = 6
        let topProximity: CGFloat = 16

        if newOffset <= topProximity {
            if !isQuickEntryButtonVisible { isQuickEntryButtonVisible = true }
            return
        }

        if delta > scrollThreshold, isQuickEntryButtonVisible {
            isQuickEntryButtonVisible = false
        } else if delta < -scrollThreshold, !isQuickEntryButtonVisible {
            isQuickEntryButtonVisible = true
        }
    }

    // MARK: - iOS single-column layout

    @ViewBuilder
    private func iOSLayout(_ vm: DashboardViewModel) -> some View {
        VStack(spacing: VSpacing.sectionSpacing) {
            if let data = vm.dashboardData {
                HeroSpendingCard(
                    monthSpending: data.monthSpending,
                    monthIncome: data.monthIncome,
                    comparison: vm.comparison,
                    currencyCode: currencyCode
                )

                budgetProgressSection(progress: data.monthBudgetProgress)

                QuickActionGrid { destination, transactionType in
                    handleQuickAction(destination, transactionType: transactionType)
                }

                RecentTransactionsList(
                    transactions: data.recentTransactions,
                    onSeeAll: { appState.selectedTab = .transactions },
                    onSelect: { id in navigateDestination = .transactionDetail(id: id) }
                )

                TopCategoriesChart(categories: data.topCategories, currencyCode: currencyCode)

                AccountsSummaryScroll(
                    accounts: data.accountSummary,
                    onSelect: { id in navigateDestination = .accountDetail(id: id) },
                    onManage: { navigateDestination = .accountList },
                    onAdd: { navigateDestination = .addAccount }
                )

                netWorthSection(netWorth: data.netWorth)

                UpcomingRecurringList(rules: data.upcomingRecurring)
            }
        }
        .padding(VSpacing.screenPadding)
    }

    // MARK: - iPad/Mac two-column layout

    @ViewBuilder
    private func macLayout(_ vm: DashboardViewModel) -> some View {
        if let data = vm.dashboardData {
            VStack(spacing: VSpacing.sectionSpacing) {
                HeroSpendingCard(
                    monthSpending: data.monthSpending,
                    monthIncome: data.monthIncome,
                    comparison: vm.comparison,
                    currencyCode: currencyCode
                )

                // HStack, not LazyVGrid: a grid vertically centers its two
                // column-VStacks in the shared row, so the shorter column
                // floated mid-air next to the taller one.
                HStack(alignment: .top, spacing: VSpacing.sectionSpacing) {
                    VStack(spacing: VSpacing.sectionSpacing) {
                        budgetProgressSection(progress: data.monthBudgetProgress)
                        QuickActionGrid { destination, transactionType in
                            handleQuickAction(destination, transactionType: transactionType)
                        }
                        TopCategoriesChart(categories: data.topCategories, currencyCode: currencyCode)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: VSpacing.sectionSpacing) {
                        RecentTransactionsList(
                            transactions: data.recentTransactions,
                            onSeeAll: { appState.selectedTab = .transactions },
                            onSelect: { id in navigateDestination = .transactionDetail(id: id) }
                        )
                        UpcomingRecurringList(rules: data.upcomingRecurring)
                        netWorthSection(netWorth: data.netWorth)
                    }
                    .frame(maxWidth: .infinity)
                }

                AccountsSummaryScroll(
                    accounts: data.accountSummary,
                    onSelect: { id in navigateDestination = .accountDetail(id: id) },
                    onManage: { navigateDestination = .accountList },
                    onAdd: { navigateDestination = .addAccount }
                )
            }
            .padding(VSpacing.screenPadding)
        }
    }

    // MARK: - Shared sub-sections

    private func budgetProgressSection(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: VSpacing.md) {
            HStack {
                Text(String(localized: "Budget"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                Spacer()
                Button {
                    appState.selectedTab = .budgets
                } label: {
                    HStack(spacing: VSpacing.xxs) {
                        Text(String(localized: "Manage"))
                            .font(VTypography.caption1)
                            .foregroundColor(VColors.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(VColors.primary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Manage budgets"))
                .accessibilityHint(String(localized: "Opens the Budgets tab"))
            }

            VStack(spacing: VSpacing.sm) {
                HStack {
                    Text(String(localized: "Overall Progress"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textPrimary)
                    Spacer()
                    if progress >= 0.75 {
                        Image(systemName: progress > 1.0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(progressColor(progress))
                            .accessibilityHidden(true)
                    }
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(VTypography.caption1Bold)
                        .foregroundColor(progressColor(progress))
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                            .fill(VColors.tertiaryBackground)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: VSpacing.cornerRadiusPill)
                            .fill(progressColor(progress))
                            .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 8)
                            .animation(reduceMotion ? .none : .easeOut(duration: VSpacing.animationStandard), value: progress)
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
            .padding(VSpacing.md)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Budget overall progress"))
            .accessibilityValue(String(localized: "\(Int(min(progress * 100, 999))) percent"))
        }
    }

    private func netWorthSection(netWorth: Decimal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(String(localized: "Net Worth"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                Text(CurrencyFormatter.format(netWorth, currencyCode: currencyCode))
                    .font(VTypography.amountMedium)
                    .amountScaling()
                    .foregroundColor(netWorth >= 0 ? VColors.income : VColors.expense)
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Net worth"))
        .accessibilityValue(CurrencyFormatter.format(netWorth, currencyCode: currencyCode))
    }

    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.9 { return VColors.budgetDanger }
        if progress >= 0.75 { return VColors.budgetWarning }
        return VColors.budgetSafe
    }

    private func errorBanner(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .padding(VSpacing.md)
                .background(VColors.expense)
                .cornerRadius(VSpacing.cornerRadiusSM)
                .padding(VSpacing.md)
            Spacer()
        }
    }

    private func handleQuickAction(
        _ destination: NavigationDestination,
        transactionType: TransactionType?
    ) {
        switch destination {
        case .addTransaction:
            activeQuickActionModal = .addTransaction(type: transactionType ?? .expense)
        case .addTransfer:
            activeQuickActionModal = .addTransfer
        case .addBudget:
            activeQuickActionModal = .addBudget
        default:
            navigateDestination = destination
        }
    }

    @ViewBuilder
    private func quickActionModalView(for modal: QuickActionModal) -> some View {
        switch modal {
        case .addTransaction(let type):
            NavigationStack {
                TransactionFormView(initialType: type, showsCancelButton: true)
            }
        case .addTransfer:
            NavigationStack {
                TransferFormView(showsCancelButton: true)
            }
        case .addBudget:
            BudgetFormView(isPresented: budgetPresentationBinding)
        }
    }

    private var budgetPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                if case .addBudget = activeQuickActionModal {
                    return true
                }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    activeQuickActionModal = nil
                }
            }
        )
    }

    private func createViewModel() -> DashboardViewModel {
        dependencies.makeDashboardViewModel()
    }
}

private enum QuickActionModal: Identifiable {
    case addTransaction(type: TransactionType)
    case addTransfer
    case addBudget

    var id: String {
        switch self {
        case .addTransaction(let type):
            return "addTransaction-\(type.rawValue)"
        case .addTransfer:
            return "addTransfer"
        case .addBudget:
            return "addBudget"
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
