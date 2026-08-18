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
    /// Staged by every delete path on this screen so they all ask first.
    /// The detail screen's trash was guarded in 91c44b3b; these three — the
    /// row menu, the swipe, and the multi-select bulk delete — were not.
    @State private var pendingDelete: PendingDelete?

    private enum PendingDelete: Equatable {
        case single(UUID)
        case selected(count: Int)
    }

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
                // Full-screen empty state only when there's genuinely no data and
                // no active search/filter. During a search/filter the list (with
                // its search bar) must stay mounted, otherwise a zero-result query
                // removes the search field and strands the user.
                if vm.groupedTransactions.isEmpty && !hasQueryOrFilter(vm) {
                    emptyState
                } else {
                    listView(vm)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "Transactions"))
        .confirmationDialog(
            {
                // Multi-select can hold exactly one row, and "Delete 1
                // transactions?" is not a sentence.
                if case .selected(let count) = pendingDelete, count > 1 {
                    return String(localized: "Delete \(count) transactions?")
                }
                return String(localized: "Delete this transaction?")
            }(),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                guard let pending = pendingDelete, let vm else { return }
                pendingDelete = nil
                dependencies.hapticService.warning()
                Task {
                    switch pending {
                    case .single(let id):
                        await vm.deleteTransaction(id: id)
                    case .selected:
                        await vm.deleteSelected()
                    }
                    appState.notifyChanged([.transactions, .accounts, .budgets])
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            switch pendingDelete {
            case .selected(let count) where count > 1:
                Text(String(localized: "\(count) transactions will be removed permanently and the account balances updated. This cannot be undone."))
            default:
                Text(String(localized: "The transaction will be removed permanently and the account balance updated. This cannot be undone."))
            }
        }
        .accessibilityIdentifier("transaction-list-root")
        .advertisesHandoff(transactionListHandoffRoute)
        .task {
            if vm == nil {
                vm = createViewModel()
                await vm?.loadTransactions()
            }
            selectFirstTransactionForCaptureIfNeeded()
        }
        // Seeding is async: the first load usually returns an empty list and
        // the rows arrive afterwards, so selecting only in the initial task
        // left the detail pane on its "Select a Transaction" placeholder.
        .onChange(of: vm?.groupedTransactions.count ?? 0) { _, _ in
            selectFirstTransactionForCaptureIfNeeded()
        }
        .task(id: appState.refreshVersion(for: .transactions)) {
            guard vm != nil, appState.refreshVersion(for: .transactions) > 0 else { return }
            await vm?.loadTransactions()
        }
        .task(id: appState.pendingTransactionListFilter) {
            guard let filter = appState.pendingTransactionListFilter else { return }
            appState.clearPendingTransactionListFilter()
            if vm == nil {
                vm = createViewModel()
            }
            guard let listVM = vm else { return }
            await listVM.applyFilter(Self.transactionFilter(from: filter))
        }
        .task(id: appState.pendingTransactionDetailID) {
            guard let id = appState.pendingTransactionDetailID else { return }
            appState.clearPendingTransactionDetailID()
            // Deleted / missing IDs fall back to the list — do not push detail.
            let fetch = FetchTransactionsUseCase(transactionRepository: dependencies.transactionRepository)
            guard let found = try? await fetch.execute(id: id), found != nil else { return }
            navigateDestination = .transactionDetail(id: id)
            selectedTransactionID = id
        }
        .navigationDestination(item: $navigateDestination) { dest in
            NavigationDestinationView(destination: dest)
        }
        .errorAlert(message: transactionListErrorBinding)
    }

    private var transactionListHandoffRoute: HandoffDeepLink.Route? {
        guard let vm else { return .transactionList(HandoffDeepLink.ListFilter()) }
        return .transactionList(Self.listFilter(from: vm.activeFilter))
    }

    private static func listFilter(from filter: TransactionFilter) -> HandoffDeepLink.ListFilter {
        HandoffDeepLink.ListFilter(
            start: filter.dateRange?.lowerBound,
            end: filter.dateRange?.upperBound,
            types: filter.types?.map(\.rawValue).sorted(),
            categoryIDs: filter.categoryIDs.map(Array.init),
            accountIDs: filter.accountIDs.map(Array.init)
        )
    }

    private static func transactionFilter(from filter: HandoffDeepLink.ListFilter) -> TransactionFilter {
        TransactionFilter(
            dateRange: filter.dateRange,
            types: filter.types.flatMap { raw in
                let parsed = Set(raw.compactMap(TransactionType.init(rawValue:)))
                return parsed.isEmpty ? nil : parsed
            },
            categoryIDs: filter.categoryIDs.map(Set.init),
            accountIDs: filter.accountIDs.map(Set.init)
        )
    }

    private func hasQueryOrFilter(_ vm: TransactionListViewModel) -> Bool {
        !vm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.hasActiveFilter
    }

    @ViewBuilder
    private func listView(_ vm: TransactionListViewModel) -> some View {
        if prefersSplitDetail && !vm.isMultiSelectMode {
            splitDetailView(vm)
        } else {
            compactListView(vm)
        }
    }

    /// Screenshot support: preselect the first row so the split detail pane has
    /// something in it.
    ///
    /// On iPad and Mac this screen is a list plus a detail pane, and with no
    /// selection the pane is an empty placeholder — which is half of a wide
    /// screenshot showing nothing. `--ui-test-open-transaction` cannot help
    /// here because it needs a UUID from the seeded data, which the capture
    /// script has no way to know. Guarded by the launch argument, so normal
    /// launches still open with no selection.
    private func selectFirstTransactionForCaptureIfNeeded() {
        guard selectedTransactionID == nil,
              ProcessInfo.processInfo.arguments.contains("--ui-test-select-first-transaction"),
              let first = vm?.groupedTransactions.first?.transactions.first
        else { return }
        selectedTransactionID = first.id
    }

    @ViewBuilder
    private func splitDetailView(_ vm: TransactionListViewModel) -> some View {
        #if os(macOS)
        // HSplitView, not a nested NavigationSplitView: this view already
        // lives inside the app-wide NavigationSplitView's detail column, and
        // macOS renders a split view nested there with a phantom leading
        // offset in its detail pane (content shifted right by ~a column).
        HSplitView {
            // maxHeight fill: List reports a small ideal height, and HSplitView
            // vertically centers a non-expanding child — the short list floated
            // mid-pane with blank bands above and below.
            transactionList(vm, selection: $selectedTransactionID)
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
            splitDetailPane
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        NavigationSplitView {
            transactionList(vm, selection: $selectedTransactionID)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            splitDetailPane
        }
        #endif
    }

    @ViewBuilder
    private var splitDetailPane: some View {
        // The detail pane needs its own NavigationStack so pushes from
        // within it (e.g. the detail's edit button) have a stack to land on.
        NavigationStack {
            if let selectedTransactionID {
                TransactionDetailView(transactionID: selectedTransactionID)
                    .id(selectedTransactionID)
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
                // The selected row's OUTLINE is drawn from the tint, which
                // listRowBackground does not cover — so a neutral fill still
                // came with a brand-green ring around it. Scoped to this list so
                // the rest of the app keeps its accent.
                .tint(VColors.textTertiary)
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
        .overlay {
            if vm.groupedTransactions.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "No Results"), systemImage: "magnifyingglass")
                } description: {
                    Text(String(localized: "No transactions match your search or filters."))
                }
            }
        }
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
                // Button + navigateDestination instead of a value-based
                // NavigationLink: inside the iPad split view's sidebar column the
                // shared navigationDestination(for:) isn't in scope, so the value
                // link did nothing there (same family as #51/#60).
                Button {
                    navigateDestination = .addTransaction
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .accessibilityIdentifier("transaction-add-button")
                .accessibilityLabel(String(localized: "Add transaction"))
                .accessibilityHint(String(localized: "Opens the new transaction form"))

                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: vm.hasActiveFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .opacity(vm.hasActiveFilter ? 1.0 : 0.5)
                }
                .accessibilityIdentifier("transaction-filter-button")
                .accessibilityLabel(String(localized: "Filter transactions"))
                .accessibilityHint(String(localized: "Opens transaction filters"))
                .accessibilityValue(vm.hasActiveFilter ? String(localized: "Filter active") : String(localized: "No filters applied"))
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showCSVImport = true
                    } label: {
                        Label(String(localized: "Import CSV"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                }
                .accessibilityIdentifier("transaction-overflow-menu")
                .accessibilityLabel(String(localized: "More transaction actions"))
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
                            pendingDelete = .selected(count: vm.selectedTransactionIDs.count)
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
                            pendingDelete = .selected(count: vm.selectedTransactionIDs.count)
                        } label: {
                            Label("Delete \(vm.selectedTransactionIDs.count) selected", systemImage: "trash")
                        }
                    }
                }
                #endif
            }
        }
        // Only show the full-screen spinner on the very first load. On refreshes
        // (e.g. returning from a detail page, which re-runs .task), we already
        // have rows to show, so flashing the overlay just makes it blink.
        .if(vm.isLoading && vm.groupedTransactions.isEmpty) { view in
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
            category: vm.category(for: transaction),
            currencyCode: currencyCode,
            showSelection: vm.isMultiSelectMode,
            isSelected: vm.selectedTransactionIDs.contains(transaction.id)
        )

        if let selection {
            // Drive the split-view selection explicitly. Tag-based List selection
            // doesn't respond to taps in this nested context (split view inside
            // the tab's NavigationStack), so a plain row was un-tappable on iPad.
            Button {
                if vm.isMultiSelectMode {
                    vm.toggleSelection(transaction.id)
                } else {
                    selection.wrappedValue = transaction.id
                }
            } label: {
                row
            }
            .buttonStyle(.plain)
            .tag(Optional(transaction.id))
            // Neutral selection fill rather than the inherited accent. nil
            // restores the platform default for unselected rows.
            .listRowBackground(
                selection.wrappedValue == transaction.id ? VColors.rowSelection : nil
            )
            .transactionRowModifiers(
                vm: vm,
                transaction: transaction,
                onEdit: { navigateDestination = .editTransaction(id: transaction.id) },
                onRequestDelete: { pendingDelete = .single($0) }
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
                onEdit: { navigateDestination = .editTransaction(id: transaction.id) },
                onRequestDelete: { pendingDelete = .single($0) }
            )
        }
    }

    private var emptyState: some View {
        VEmptyState(
            icon: "list.bullet.rectangle",
            title: String(localized: "No transactions"),
            subtitle: String(localized: "Add your first transaction to get started"),
            actionLabel: String(localized: "Add Transaction"),
            action: { navigateDestination = .addTransaction }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VColors.groupedBackground)
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
    /// The row asks; the screen owns the confirmation and does the deleting.
    let onRequestDelete: (UUID) -> Void

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
                onDelete: { onRequestDelete(transaction.id) }
            ))
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    onRequestDelete(transaction.id)
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
        onEdit: @escaping () -> Void,
        onRequestDelete: @escaping (UUID) -> Void
    ) -> some View {
        modifier(TransactionRowModifier(
            vm: vm,
            transaction: transaction,
            onEdit: onEdit,
            onRequestDelete: onRequestDelete
        ))
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
    }
}
