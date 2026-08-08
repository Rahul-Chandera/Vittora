import SwiftUI
import VittoraCore

struct BudgetListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) var dependencies
    @Environment(\.currencyCode) private var currencyCode
    @State private var viewModel: BudgetListViewModel?
    @State private var showAddBudget = false
    @State private var navigateDestination: NavigationDestination?

    var body: some View {
        ZStack {
            if let viewModel = viewModel, !viewModel.hasAnyBudgets && !viewModel.isLoading {
                VEmptyState(
                    icon: "target",
                    title: String(localized: "No Budgets Yet"),
                    subtitle: String(localized: "Create your first budget to track spending"),
                    // Centred action, matching Transactions, Debt, Splits and
                    // Recurring. Without it this screen's only way in was the
                    // small "+" in the corner.
                    actionLabel: String(localized: "Create Budget"),
                    action: { showAddBudget = true }
                )
                .accessibilityIdentifier("budget-empty-state")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // The empty branch renders outside the List, so it does not
                // inherit the grouped page colour the populated state has.
                .background(VColors.groupedBackground)
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
                                // No `progress:` parameter. BudgetProgress is
                                // not Equatable and the view never read it —
                                // every figure comes from `budget` — so it only
                                // served to muddy SwiftUI's view comparison
                                // while this row went stale after a new expense.
                                BudgetCardView(
                                    budget: budget,
                                    category: budget.categoryID.flatMap { viewModel.categoriesByID[$0] }
                                )
                            }
                            // listRow* belongs on the ROW, not inside the
                            // NavigationLink's label. Applied to the label it
                            // styles the wrong node and muddles List's row
                            // diffing — this row kept rendering a stale
                            // `spent` after a new expense while the header,
                            // assigned in the same loadBudgets() call, moved.
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
        // onChange, not .task(id:). A .task(id:) attached to a tab that is not
        // frontmost did not restart when the version changed: adding an expense
        // from the Transactions tab left this screen's rows stale until the app
        // was relaunched — not even a tab switch corrected it.
        .onChange(of: appState.refreshVersion(for: .budgets)) { _, _ in
            Task { await viewModel?.loadBudgets() }
        }
        .task(id: appState.pendingBudgetDetailID) {
            guard let id = appState.pendingBudgetDetailID else { return }
            appState.clearPendingBudgetDetailID()
            if viewModel?.budgets.contains(where: { $0.id == id }) == true {
                navigateDestination = .budgetDetail(id: id)
                return
            }
            guard let found = try? await dependencies.budgetRepository.fetchByID(id), found != nil else {
                return
            }
            navigateDestination = .budgetDetail(id: id)
        }
        .navigationDestination(item: $navigateDestination) { dest in
            NavigationDestinationView(destination: dest)
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
