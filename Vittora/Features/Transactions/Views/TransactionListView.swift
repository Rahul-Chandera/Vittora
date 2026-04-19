import SwiftUI

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @State private var vm: TransactionListViewModel?
    @State private var showFilterSheet = false
    @State private var filterVM: TransactionFilterViewModel?
    @State private var navigateDestination: NavigationDestination?

    var body: some View {
        ZStack {
            if let vm = vm {
                if vm.groupedTransactions.isEmpty {
                    emptyState
                } else {
                    listView(vm)
                }
            }
        }
        .navigationTitle(String(localized: "Transactions"))
        .accessibilityIdentifier("transaction-list-root")
        .task {
            if vm == nil {
                vm = await createViewModel()
                await vm?.loadTransactions()
            }
        }
        .task(id: appState.transactionRefreshVersion) {
            guard vm != nil else { return }
            await vm?.loadTransactions()
        }
        .navigationDestination(item: $navigateDestination) { dest in
            navigationView(for: dest)
        }
        .errorAlert(message: transactionListErrorBinding)
    }

    @ViewBuilder
    private func listView(_ vm: TransactionListViewModel) -> some View {
        List {
            ForEach(vm.groupedTransactions, id: \.date) { dateGroup in
                Section(header: sectionHeader(for: dateGroup.date)) {
                    ForEach(dateGroup.transactions) { transaction in
                        TransactionRowView(transaction: transaction, showSelection: vm.isMultiSelectMode)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if vm.isMultiSelectMode {
                                    vm.toggleSelection(transaction.id)
                                } else {
                                    navigateDestination = .transactionDetail(id: transaction.id)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        HapticService.warning()
                                        await vm.deleteTransaction(id: transaction.id)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                NavigationLink(value: NavigationDestination.editTransaction(id: transaction.id)) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onLongPressGesture {
                                if !vm.isMultiSelectMode {
                                    vm.isMultiSelectMode = true
                                }
                                vm.toggleSelection(transaction.id)
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
        .searchable(text: Bindable(vm).searchQuery, prompt: String(localized: "Search transactions"))
        .onChange(of: vm.searchQuery) { oldValue, newValue in
            Task {
                await vm.search(newValue)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    NavigationLink(value: NavigationDestination.addTransaction) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityIdentifier("transaction-add-button")
                    .accessibilityLabel(String(localized: "Add transaction"))
                    .accessibilityHint(String(localized: "Opens the new transaction form"))

                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "funnel.fill")
                            .font(.title2)
                            .opacity(vm.hasActiveFilter ? 1.0 : 0.5)
                    }
                    .accessibilityIdentifier("transaction-filter-button")
                    .accessibilityLabel(String(localized: "Filter transactions"))
                    .accessibilityHint(String(localized: "Opens transaction filters"))
                    .accessibilityValue(vm.hasActiveFilter ? String(localized: "Filter active") : String(localized: "No filters applied"))
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            TransactionFilterSheet(
                viewModel: filterVM ?? TransactionFilterViewModel(),
                onApply: { filter in
                    Task {
                        await vm.applyFilter(filter)
                    }
                    showFilterSheet = false
                }
            )
        }
        .refreshable {
            await vm.loadTransactions()
        }
        .if(!vm.selectedTransactionIDs.isEmpty) { view in
            view.toolbar {
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(role: .destructive) {
                            Task {
                                await vm.deleteSelected()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Spacer()

                        Text("\(vm.selectedTransactionIDs.count) selected")
                            .font(.caption)
                            .foregroundColor(VColors.textSecondary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Button(role: .destructive) {
                            Task {
                                await vm.deleteSelected()
                            }
                        } label: {
                            Label("Delete \(vm.selectedTransactionIDs.count) selected", systemImage: "trash")
                        }
                    }
                }
                #endif
            }
        }
        .if(vm.isLoading) { view in
            view.overlay {
                ProgressView()
                    .tint(VColors.primary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "list.dash")
                .font(.system(size: 48))
                .foregroundColor(VColors.textTertiary)

            Text("No transactions")
                .font(VTypography.bodyBold)
                .foregroundColor(VColors.textPrimary)

            Text("Add your first transaction to get started")
                .font(VTypography.caption1)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink(value: NavigationDestination.addTransaction) {
                Text("Add Transaction")
                    .font(VTypography.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(VSpacing.md)
                    .background(VColors.primary)
                    .cornerRadius(VSpacing.cornerRadiusSM)
            }
            .padding(.top, VSpacing.lg)

            Spacer()
        }
        .padding(VSpacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.background)
        .accessibilityIdentifier("transaction-empty-state")
    }

    @ViewBuilder
    private func sectionHeader(for date: Date) -> some View {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            Text("Today")
                .foregroundColor(VColors.textSecondary)
        } else if calendar.isDateInYesterday(date) {
            Text("Yesterday")
                .foregroundColor(VColors.textSecondary)
        } else {
            Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .foregroundColor(VColors.textSecondary)
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

        default:
            EmptyView()
        }
    }

    private func createViewModel() async -> TransactionListViewModel? {
        guard let transactionRepo = dependencies.transactionRepository,
              let accountRepo = dependencies.accountRepository else {
            return nil
        }

        let fetchUseCase = FetchTransactionsUseCase(transactionRepository: transactionRepo)
        let searchUseCase = SearchTransactionsUseCase(transactionRepository: transactionRepo)
        let deleteUseCase = DeleteTransactionUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo
        )
        let bulkOpsUseCase = BulkOperationsUseCase(
            transactionRepository: transactionRepo,
            accountRepository: accountRepo
        )

        return TransactionListViewModel(
            fetchUseCase: fetchUseCase,
            searchUseCase: searchUseCase,
            deleteUseCase: deleteUseCase,
            bulkOpsUseCase: bulkOpsUseCase
        )
    }

    private var transactionListErrorBinding: Binding<String?> {
        Binding(
            get: { vm?.error },
            set: { newValue in
                vm?.error = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
    }
}
