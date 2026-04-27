import SwiftUI

struct BudgetListView: View {
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: BudgetListViewModel?
    @State private var showAddBudget = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if let viewModel = viewModel, viewModel.budgets.isEmpty && !viewModel.isLoading {
                    VEmptyState(
                        icon: "target",
                        title: String(localized: "No Budgets Yet"),
                        subtitle: String(localized: "Create your first budget to track spending")
                    )
                    .accessibilityIdentifier("budget-empty-state")
                } else {
                    List {
                        // Overview card
                        if let viewModel = viewModel {
                            Section {
                                BudgetOverviewCard(
                                    spent: viewModel.overallSpent,
                                    budget: viewModel.overallBudget,
                                    progress: viewModel.overallProgress,
                                    currencyCode: currencyCode
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }

                        // Period selector
                        if let viewModel = viewModel {
                            Section {
                                PeriodSelectorView(selectedPeriod: Bindable(viewModel).selectedPeriod)
                                    .onChange(of: viewModel.selectedPeriod) { _, _ in
                                        Task {
                                            await viewModel.loadBudgets()
                                        }
                                    }
                            }
                        }

                        // Budget list
                        if let viewModel = viewModel {
                            ForEach(viewModel.budgets) { budget in
                                NavigationLink(
                                    value: NavigationDestination.budgetDetail(id: budget.id)
                                ) {
                                    BudgetCardView(
                                        budget: budget,
                                        progress: viewModel.budgetProgress[budget.id],
                                        category: nil  // Categories loaded in list
                                    )
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteBudget(id: budget.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle(String(localized: "Budgets"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddBudget = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("budget-add-button")
                    .accessibilityLabel(String(localized: "Add budget"))
                    .accessibilityHint(String(localized: "Opens the budget form"))
                }
            }
            .sheet(isPresented: $showAddBudget, onDismiss: {
                guard let viewModel else { return }
                Task {
                    await viewModel.loadBudgets()
                }
            }) {
                BudgetFormView(isPresented: $showAddBudget)
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .budgetDetail(let id):
                    BudgetDetailView(budgetID: id)
                default:
                    EmptyView()
                }
            }
            .task {
                if viewModel == nil {
                    let fetchUseCase = FetchBudgetsUseCase(
                        budgetRepository: dependencies.budgetRepository ?? MockBudgetRepository(),
                        transactionRepository: dependencies.transactionRepository ?? MockTransactionRepository()
                    )
                    let deleteUseCase = DeleteBudgetUseCase(
                        budgetRepository: dependencies.budgetRepository ?? MockBudgetRepository()
                    )
                    let calculateProgressUseCase = CalculateBudgetProgressUseCase()

                    viewModel = BudgetListViewModel(
                        fetchUseCase: fetchUseCase,
                        deleteUseCase: deleteUseCase,
                        calculateProgressUseCase: calculateProgressUseCase
                    )
                }

                if let viewModel = viewModel {
                    await viewModel.loadBudgets()
                }
            }
            .accessibilityIdentifier("budget-list-root")
        }
    }
}

#Preview {
    BudgetListView()
        .environment(\.dependencies, DependencyContainer())
}
