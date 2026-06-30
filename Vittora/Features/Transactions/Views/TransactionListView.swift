import SwiftUI
import VittoraCore

struct TransactionListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dependencies) private var dependencies: DependencyContainer
    @Environment(\.currencyCode) private var currencyCode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var vm: TransactionListViewModel?
    @State private var showFilterSheet = false
    @State private var showCSVImport = false
    @State private var filterVM: TransactionFilterViewModel?
    @State private var navigateDestination: NavigationDestination?
    @State private var selectedTransactionID: UUID?

    private var prefersSplitDetail: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        ZStack {
            if let vm = vm {
                if vm.groupedTransactions.isEmpty {
                    emptyState
                } else {
                    listView(vm)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Transactions"))
        .accessibilityIdentifier("transaction-list-root")
        .task {
            if vm == nil {
                vm = createViewModel()
                await vm?.loadTransactions()
            }
        }
        .task(id: appState.refreshVersion(for: .transactions)) {
            guard vm != nil, appState.refreshVersion(for: .transactions) > 0 else { return }
            await vm?.loadTransactions()
        }
        .navigationDestination(item: $navigateDestination) { dest in
            navigationView(for: dest)
        }
        .errorAlert(message: transactionListErrorBinding)
    }

    @ViewBuilder
    private func listView(_ vm: TransactionListViewModel) -> some View {
        if prefersSplitDetail && !vm.isMultiSelectMode {
            splitDetailView(vm)
        } else {
            compactListView(vm)
        }
    }

    @ViewBuilder
    private func splitDetailView(_ vm: TransactionListViewModel) -> some View {
        NavigationSplitView {
            transactionList(vm, selection: $selectedTransactionID)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            if let selectedTransactionID {
                TransactionDetailView(transactionID: selectedTransactionID)
            } else {
                ContentUnavailableView(
                    String(localized: "Select a Transaction"),
                    systemImage: "list.bullet.rectangle",
                    description: Text(String(localized: "Choose a transaction from the list to view its details."))
                )
            }
        }
    }

    @ViewBuilder
    private func compactListView(_ vm: TransactionListViewModel) -> some View {
        transactionList(vm, selection: nil)
    }

    @ViewBuilder
    private func transactionList(_ vm: TransactionListViewModel, selection: Binding<UUID?>?) -> some View {
        @Bindable var vm = vm

        Group {
            if let selection {
                List(selection: selection) {
                    transactionSections(vm, selection: selection)
                }
            } else {
                List {
                    transactionSections(vm, selection: nil)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
        .searchable(text: Bindable(vm).searchQuery, prompt: String(localized: "Search transactions"))
        .task(id: vm.searchQuery) {
            let query = vm.searchQuery
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                await vm.loadTransactions()
            } else {
                await vm.search(trimmed)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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

                Button {
                    showCSVImport = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2)
                }
                .accessibilityLabel(String(localized: "Import CSV"))
                .accessibilityHint(String(localized: "Import transactions from a CSV file"))
            }
        }
        .sheet(isPresented: $showCSVImport) {
            TransactionCSVImportView {
                Task { await vm.loadTransactions() }
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

                        Text(String(localized: "\(vm.selectedTransactionIDs.count) selected"))
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
        .overlay(alignment: .bottom) {
            if vm.isLoadingMore {
                ProgressView()
                    .padding(VSpacing.md)
            }
        }
    }

    @ViewBuilder
    private func transactionSections(
        _ vm: TransactionListViewModel,
        selection: Binding<UUID?>?
    ) -> some View {
        ForEach(vm.groupedTransactions, id: \.date) { dateGroup in
            Section(header: sectionHeader(for: dateGroup.date)) {
                ForEach(dateGroup.transactions) { transaction in
                    transactionRow(vm, transaction: transaction, selection: selection)
                }
            }
        }
    }

    @ViewBuilder
    private func transactionRow(
        _ vm: TransactionListViewModel,
        transaction: TransactionEntity,
        selection: Binding<UUID?>?
    ) -> some View {
        let row = TransactionRowView(
            transaction: transaction,
            currencyCode: currencyCode,
            showSelection: vm.isMultiSelectMode,
            isSelected: vm.selectedTransactionIDs.contains(transaction.id)
        )

        if selection != nil {
            row
                .tag(Optional(transaction.id))
                .transactionRowModifiers(
                    vm: vm,
                    transaction: transaction,
                    onEdit: { navigateDestination = .editTransaction(id: transaction.id) }
                )
        } else {
            Button {
                if vm.isMultiSelectMode {
                    vm.toggleSelection(transaction.id)
                } else {
                    navigateDestination = .transactionDetail(id: transaction.id)
                }
            } label: {
                row
            }
            .buttonStyle(.plain)
            .transactionRowModifiers(
                vm: vm,
                transaction: transaction,
                onEdit: { navigateDestination = .editTransaction(id: transaction.id) }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "list.dash")
                .font(.system(size: 48))
                .foregroundColor(VColors.textTertiary)

            Text(String(localized: "No transactions"))
                .font(VTypography.bodyBold)
                .foregroundColor(VColors.textPrimary)

            Text(String(localized: "Add your first transaction to get started"))
                .font(VTypography.caption1)
                .foregroundColor(VColors.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink(value: NavigationDestination.addTransaction) {
                Text(String(localized: "Add Transaction"))
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
        let title: String = {
            if calendar.isDateInToday(date) {
                return String(localized: "Today")
            } else if calendar.isDateInYesterday(date) {
                return String(localized: "Yesterday")
            } else {
                return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            }
        }()

        Text(title)
            .foregroundColor(VColors.textSecondary)
            .accessibilityAddTraits(.isHeader)
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

    private func createViewModel() -> TransactionListViewModel {
        dependencies.makeTransactionListViewModel()
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

private struct TransactionRowModifier: ViewModifier {
    @Environment(\.dependencies) private var dependencies
    @Environment(AppState.self) private var appState
    let vm: TransactionListViewModel
    let transaction: TransactionEntity
    let onEdit: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    await vm.loadNextPageIfNeeded(currentTransactionID: transaction.id)
                }
            }
            .accessibilityAction(named: String(localized: "Select")) {
                if !vm.isMultiSelectMode {
                    vm.isMultiSelectMode = true
                }
                vm.toggleSelection(transaction.id)
            }
            .vittoraRowContextMenu(VittoraRowContextMenuActions(
                onEdit: onEdit,
                onDuplicate: transaction.type == .transfer ? nil : {
                    Task {
                        await vm.duplicateTransaction(id: transaction.id)
                        appState.notifyChanged([.transactions, .accounts, .budgets])
                    }
                },
                onDelete: {
                    Task {
                        dependencies.hapticService.warning()
                        await vm.deleteTransaction(id: transaction.id)
                        appState.notifyChanged([.transactions, .accounts, .budgets])
                    }
                }
            ))
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Task {
                        dependencies.hapticService.warning()
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

private extension View {
    func transactionRowModifiers(
        vm: TransactionListViewModel,
        transaction: TransactionEntity,
        onEdit: @escaping () -> Void
    ) -> some View {
        modifier(TransactionRowModifier(vm: vm, transaction: transaction, onEdit: onEdit))
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
    }
}
