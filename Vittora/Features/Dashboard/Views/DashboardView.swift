import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var vm: DashboardViewModel?
    @State private var navigateDestination: NavigationDestination?
    @State private var showAddBudget = false

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
        .sheet(isPresented: $showAddBudget) {
            BudgetFormView(isPresented: $showAddBudget)
        }
    }

    @ViewBuilder
    private func dashboardContent(_ vm: DashboardViewModel) -> some View {
        ScrollView {
            #if os(iOS)
            iOSLayout(vm)
            #else
            macLayout(vm)
            #endif
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

    // MARK: - iOS single-column layout

    @ViewBuilder
    private func iOSLayout(_ vm: DashboardViewModel) -> some View {
        VStack(spacing: VSpacing.sectionSpacing) {
            if let data = vm.dashboardData {
                HeroSpendingCard(
                    monthSpending: data.monthSpending,
                    monthIncome: data.monthIncome,
                    comparison: vm.comparison
                )

                budgetProgressSection(progress: data.monthBudgetProgress)

                QuickActionGrid { destination in
                    navigateDestination = destination
                }

                RecentTransactionsList(
                    transactions: data.recentTransactions,
                    onSeeAll: { navigateDestination = .addTransaction },
                    onSelect: { id in navigateDestination = .transactionDetail(id: id) }
                )

                TopCategoriesChart(categories: data.topCategories)

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
                    comparison: vm.comparison
                )

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: VSpacing.sectionSpacing
                ) {
                    VStack(spacing: VSpacing.sectionSpacing) {
                        budgetProgressSection(progress: data.monthBudgetProgress)
                        QuickActionGrid { destination in
                            navigateDestination = destination
                        }
                        TopCategoriesChart(categories: data.topCategories)
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
                    showAddBudget = true
                } label: {
                    Text(String(localized: "Manage"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: VSpacing.sm) {
                HStack {
                    Text(String(localized: "Overall Progress"))
                        .font(VTypography.caption1)
                        .foregroundColor(VColors.textPrimary)
                    Spacer()
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
                            .animation(.easeOut(duration: VSpacing.animationStandard), value: progress)
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
            monthComparisonUseCase: comparisonUseCase
        )
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
