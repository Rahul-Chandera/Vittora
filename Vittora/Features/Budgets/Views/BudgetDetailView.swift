import SwiftUI

struct BudgetDetailView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.dismiss) var dismiss
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: BudgetDetailViewModel?
    @State private var showEdit = false
    @State private var editRefreshTask: Task<Void, Never>?
    let budgetID: UUID

    var body: some View {
        ZStack {
            if let viewModel = viewModel, let budget = viewModel.budget {
                ScrollView {
                    VStack(spacing: VSpacing.lg) {
                        // Progress ring
                        VStack(spacing: VSpacing.md) {
                            if let progress = viewModel.progress {
                                BudgetProgressRing(progress: progress.percentage, size: 160)
                            }

                            VStack(spacing: VSpacing.xs) {
                                Text(viewModel.category?.name ?? "Budget")
                                    .font(VTypography.bodyBold)
                                    .foregroundColor(VColors.textPrimary)

                                Text(budget.period.rawValue.capitalized)
                                    .font(VTypography.caption1)
                                    .foregroundColor(VColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(VSpacing.xl)

                        VStack(spacing: VSpacing.lg) {
                            // Amount details
                            VCard {
                                VStack(spacing: VSpacing.lg) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                                            Text("Budget Amount")
                                                .font(VTypography.caption2)
                                                .foregroundColor(VColors.textSecondary)
                                            VAmountText(budget.amount, size: .title3)
                                        }
                                        Spacer()
                                    }

                                    Divider()

                                    HStack {
                                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                                            Text("Spent")
                                                .font(VTypography.caption2)
                                                .foregroundColor(VColors.textSecondary)
                                            VAmountText(budget.spent, size: .title3)
                                        }
                                        Spacer()
                                    }

                                    Divider()

                                    HStack {
                                        VStack(alignment: .leading, spacing: VSpacing.xs) {
                                            Text("Remaining")
                                                .font(VTypography.caption2)
                                                .foregroundColor(VColors.textSecondary)
                                            VAmountText(budget.remaining, size: .title3)
                                                .foregroundColor(budget.isOverBudget ? VColors.budgetDanger : VColors.budgetSafe)
                                        }
                                        Spacer()
                                    }
                                }
                            }

                            // Period info
                            VCard {
                                VStack(spacing: VSpacing.md) {
                                    HStack {
                                        Text("Period")
                                            .font(VTypography.caption1)
                                            .foregroundColor(VColors.textSecondary)
                                        Spacer()
                                        Text(budget.period.rawValue.capitalized)
                                            .font(VTypography.body)
                                            .foregroundColor(VColors.textPrimary)
                                    }

                                    Divider()

                                    HStack {
                                        Text("Start Date")
                                            .font(VTypography.caption1)
                                            .foregroundColor(VColors.textSecondary)
                                        Spacer()
                                        Text(budget.startDate.formatted(as: .medium))
                                            .font(VTypography.body)
                                            .foregroundColor(VColors.textPrimary)
                                    }

                                    if budget.rollover {
                                        Divider()
                                        HStack {
                                            Text("Rollover Enabled")
                                                .font(VTypography.caption1)
                                                .foregroundColor(VColors.textSecondary)
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(VColors.budgetSafe)
                                        }
                                    }
                                }
                            }

                            // Daily spend chart
                            if !viewModel.recentTransactions.isEmpty {
                                let dailyAverage = budget.amount / Decimal(calculateDaysInPeriod(for: budget))
                                DailySpendChart(
                                    transactions: viewModel.recentTransactions,
                                    dailyBudgetAverage: dailyAverage,
                                    currencyCode: currencyCode
                                )
                            }

                            // Recent transactions
                            if !viewModel.recentTransactions.isEmpty {
                                VCard {
                                    VStack(alignment: .leading, spacing: VSpacing.md) {
                                        Text("Recent Transactions")
                                            .font(VTypography.bodyBold)
                                            .foregroundColor(VColors.textPrimary)

                                        ForEach(viewModel.recentTransactions) { transaction in
                                            HStack(spacing: VSpacing.md) {
                                                Image(systemName: "arrow.down.circle.fill")
                                                    .foregroundColor(VColors.budgetDanger)
                                                    .font(.system(size: 18))

                                                VStack(alignment: .leading, spacing: VSpacing.xs) {
                                                    Text(transaction.note ?? "Transaction")
                                                        .font(VTypography.body)
                                                        .foregroundColor(VColors.textPrimary)
                                                    Text(transaction.date.formatted(as: .short))
                                                        .font(VTypography.caption2)
                                                        .foregroundColor(VColors.textSecondary)
                                                }

                                                Spacer()

                                                VAmountText(transaction.amount, size: .body)
                                                    .foregroundColor(VColors.budgetDanger)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(VSpacing.screenPadding)
                    }
                    .padding(.bottom, VSpacing.xl)
                }
            } else if let viewModel = viewModel, viewModel.isLoading {
                ProgressView()
            } else {
                VEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Budget Not Found",
                    subtitle: "This budget could not be loaded"
                )
            }
        }
        .navigationTitle("Budget Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showEdit = true }) {
                    Image(systemName: "pencil")
                }
                .accessibilityIdentifier("budget-edit-button")
                .accessibilityLabel(String(localized: "Edit budget"))
                .accessibilityHint(String(localized: "Opens the budget form"))
            }
        }
        .sheet(isPresented: $showEdit) {
            if let viewModel = viewModel, let budget = viewModel.budget {
                BudgetFormView(isPresented: $showEdit, editingBudget: budget)
                    .onDisappear {
                        editRefreshTask?.cancel()
                        editRefreshTask = Task {
                            await viewModel.loadBudget(id: budgetID)
                        }
                    }
            }
        }
        .task {
            if viewModel == nil {
                let calculateProgressUseCase = CalculateBudgetProgressUseCase()
                viewModel = BudgetDetailViewModel(
                    budgetRepository: dependencies.budgetRepository ?? MockBudgetRepository(),
                    categoryRepository: dependencies.categoryRepository ?? MockCategoryRepository(),
                    transactionRepository: dependencies.transactionRepository ?? MockTransactionRepository(),
                    calculateProgressUseCase: calculateProgressUseCase
                )
            }

            if let viewModel = viewModel {
                await viewModel.loadBudget(id: budgetID)
            }
        }
    }

    private func calculateDaysInPeriod(for budget: BudgetEntity) -> Int {
        switch budget.period {
        case .weekly: return 7
        case .monthly: return 30
        case .quarterly: return 90
        case .yearly: return 365
        }
    }
}

#Preview {
    BudgetDetailView(budgetID: UUID())
        .environment(\.dependencies, DependencyContainer())
}
