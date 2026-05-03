import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.currencyCode) private var currencyCode
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
        .navigationDestination(item: $navigateDestination) { dest in
            navigationView(for: dest)
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
        UIDevice.current.userInterfaceIdiom == .pad
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
            NotificationCenter.default.post(name: .vittoraNewTransaction, object: nil)
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
                    onSeeAll: { navigateDestination = .addTransaction },
                    onSelect: { id in navigateDestination = .transactionDetail(id: id) }
                )

                TopCategoriesChart(categories: data.topCategories, currencyCode: currencyCode)

                AccountsSummaryScroll(
                    accounts: data.accountSummary,
                    onSelect: { id in navigateDestination = .accountDetail(id: id) }
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

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: VSpacing.sectionSpacing
                ) {
                    VStack(spacing: VSpacing.sectionSpacing) {
                        budgetProgressSection(progress: data.monthBudgetProgress)
                        QuickActionGrid { destination, transactionType in
                            handleQuickAction(destination, transactionType: transactionType)
                        }
                        TopCategoriesChart(categories: data.topCategories, currencyCode: currencyCode)
                    }

                    VStack(spacing: VSpacing.sectionSpacing) {
                        RecentTransactionsList(
                            transactions: data.recentTransactions,
                            onSeeAll: { navigateDestination = .addTransaction },
                            onSelect: { id in navigateDestination = .transactionDetail(id: id) }
                        )
                        UpcomingRecurringList(rules: data.upcomingRecurring)
                        netWorthSection(netWorth: data.netWorth)
                    }
                }

                AccountsSummaryScroll(
                    accounts: data.accountSummary,
                    onSelect: { id in navigateDestination = .accountDetail(id: id) }
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
                    activeQuickActionModal = .addBudget
                } label: {
                    Text(String(localized: "Manage"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.primary)
                }
                .buttonStyle(.plain)
                .accessibilityHint(String(localized: "Opens the budget form"))
            }

            VStack(spacing: VSpacing.sm) {
                HStack {
                    Text(String(localized: "Overall Progress"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textPrimary)
                    Spacer()
                    if progress >= 0.75 {
                        Image(systemName: progress > 1.0 ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2)
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
                            .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                            .animation(reduceMotion ? .none : .easeOut(duration: VSpacing.animationStandard), value: progress)
                    }
                }
                .frame(height: 8)
            }
            .padding(VSpacing.md)
            .background(VColors.secondaryBackground)
            .cornerRadius(VSpacing.cornerRadiusCard)
        }
    }

    private func netWorthSection(netWorth: Decimal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: VSpacing.xs) {
                Text(String(localized: "Net Worth"))
                    .font(VTypography.subheadline)
                    .foregroundColor(VColors.textSecondary)
                Text(vm?.formattedAmount(netWorth) ?? "$0.00")
                    .font(VTypography.amountMedium)
                    .foregroundColor(netWorth >= 0 ? VColors.income : VColors.expense)
            }
            Spacer()
        }
        .padding(VSpacing.cardPadding)
        .background(VColors.secondaryBackground)
        .cornerRadius(VSpacing.cornerRadiusCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Net worth"))
        .accessibilityValue(vm?.formattedAmount(netWorth) ?? netWorth.formatted(.currency(code: currencyCode)))
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
                TransactionFormView(initialType: type)
            }
        case .addTransfer:
            NavigationStack {
                TransferFormView()
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

    @ViewBuilder
    private func navigationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .transactionDetail(let id):
            TransactionDetailView(transactionID: id)
        case .addTransaction:
            TransactionFormView()
        case .editTransaction(let id):
            TransactionFormView(transactionID: id)
        case .addTransfer:
            TransferFormView()
        case .addBudget:
            BudgetFormView(isPresented: .constant(false))
        case .accountDetail(let id):
            AccountDetailView(accountID: id)
        default:
            EmptyView()
        }
    }

    private func createViewModel() -> DashboardViewModel? {
        guard let transactionRepo = dependencies.transactionRepository,
              let accountRepo = dependencies.accountRepository,
              let categoryRepo = dependencies.categoryRepository,
              let budgetRepo = dependencies.budgetRepository,
              let recurringRepo = dependencies.recurringRuleRepository else {
            return nil
        }

        let dataUseCase = DashboardDataUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            budgetRepository: budgetRepo,
            recurringRuleRepository: recurringRepo
        )
        let comparisonUseCase = MonthComparisonUseCase(transactionRepository: transactionRepo)

        return DashboardViewModel(
            dashboardDataUseCase: dataUseCase,
            monthComparisonUseCase: comparisonUseCase,
            currencyCode: currencyCode
        )
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
