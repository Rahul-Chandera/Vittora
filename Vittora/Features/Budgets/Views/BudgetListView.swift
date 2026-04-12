import SwiftUI

struct BudgetListView: View {
    @Environment(\.dependencies) var dependencies
    @State private var viewModel: BudgetListViewModel?
    @State private var showAddBudget = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                if let viewModel = viewModel, viewModel.budgets.isEmpty && !viewModel.isLoading {
                    VEmptyState(
                        icon: "target",
                        title: "No Budgets Yet",
                        subtitle: "Create your first budget to track spending"
                    )
                } else {
                    List {
                        // Overview card
                        if let viewModel = viewModel {
                            Section {
                                BudgetOverviewCard(
                                    spent: viewModel.overallSpent,
                                    budget: viewModel.overallBudget,
                                    progress: viewModel.overallProgress
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
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddBudget = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
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
            .onDisappear {
                if showAddBudget {
                    Task {
                        if let viewModel = viewModel {
                            await viewModel.loadBudgets()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    BudgetListView()
        .environment(\.dependencies, DependencyContainer())
}
