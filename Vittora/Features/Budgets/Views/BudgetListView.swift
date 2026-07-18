import SwiftUI
import VittoraCore

struct BudgetListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: BudgetListViewModel?
    @State private var showAddBudget = false

    var body: some View {
        ZStack {
            if let viewModel = viewModel, !viewModel.hasAnyBudgets && !viewModel.isLoading {
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
                            .contextMenu {
                                NavigationLink(value: NavigationDestination.budgetDetail(id: budget.id)) {
                                    Label(String(localized: "Edit"), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteBudget(id: budget.id)
                                        appState.notifyChanged(.budgets)
                                    }
                                } label: {
                                    Label(String(localized: "Delete"), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.deleteBudget(id: budget.id)
                                        appState.notifyChanged(.budgets)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    // No budgets for the selected period (others exist) — keep the
                    // selector visible so the user isn't stranded on an empty tab.
                    if let viewModel = viewModel, viewModel.budgets.isEmpty && !viewModel.isLoading {
                        Section {
                            Text(String(localized: "No budgets for this period"))
                                .font(VTypography.subheadline)
                                .foregroundColor(VColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, VSpacing.xl)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .accessibilityIdentifier("budget-period-empty-state")
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
        .task {
            if viewModel == nil {
                viewModel = dependencies.makeBudgetListViewModel()
            }

            if let viewModel = viewModel {
                await viewModel.loadBudgets()
            }
        }
        .task(id: appState.refreshVersion(for: .budgets)) {
            guard viewModel != nil, appState.refreshVersion(for: .budgets) > 0 else { return }
            await viewModel?.loadBudgets()
        }
        .accessibilityIdentifier("budget-list-root")
    }
}

#Preview {
    NavigationStack {
        BudgetListView()
            .withNavigationDestinations()
    }
    .environment(\.dependencies, DependencyContainer.preview())
}
