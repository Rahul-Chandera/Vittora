import Foundation

@Observable @MainActor final class TransactionListViewModel {
    var groupedTransactions: [(date: Date, transactions: [TransactionEntity])] = []
    var activeFilter: TransactionFilter = TransactionFilter()
    var searchQuery: String = ""
    var isLoading = false
    var error: String?
    var selectedTransactionIDs: Set<UUID> = []
    var isMultiSelectMode = false

    private let fetchUseCase: FetchTransactionsUseCase
    private let searchUseCase: SearchTransactionsUseCase
    private let deleteUseCase: DeleteTransactionUseCase
    private let bulkOpsUseCase: BulkOperationsUseCase

    init(
        fetchUseCase: FetchTransactionsUseCase,
        searchUseCase: SearchTransactionsUseCase,
        deleteUseCase: DeleteTransactionUseCase,
        bulkOpsUseCase: BulkOperationsUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.searchUseCase = searchUseCase
        self.deleteUseCase = deleteUseCase
        self.bulkOpsUseCase = bulkOpsUseCase
    }

    var hasActiveFilter: Bool {
        activeFilter.dateRange != nil ||
        (activeFilter.types?.isEmpty == false) ||
        (activeFilter.categoryIDs?.isEmpty == false) ||
        (activeFilter.accountIDs?.isEmpty == false) ||
        (activeFilter.payeeIDs?.isEmpty == false) ||
        (activeFilter.tags?.isEmpty == false) ||
        activeFilter.amountRange != nil
    }

    func loadTransactions() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let filter = searchQuery.trimmingCharacters(in: .whitespaces).isEmpty ? activeFilter : nil
            groupedTransactions = try await fetchUseCase.executeGroupedByDate(filter: filter)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func search(_ query: String) async {
        searchQuery = query
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                await loadTransactions()
            } else {
                let results = try await searchUseCase.execute(query: query)
                let grouped = Dictionary(grouping: results) { transaction in
                    Calendar.current.startOfDay(for: transaction.date)
                }
                let sortedDates = grouped.keys.sorted(by: >)
                groupedTransactions = sortedDates.map { date in
                    (date: date, transactions: grouped[date] ?? [])
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func applyFilter(_ filter: TransactionFilter) async {
        activeFilter = filter
        searchQuery = ""
        await loadTransactions()
    }

    func deleteTransaction(id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await deleteUseCase.execute(id: id)
            selectedTransactionIDs.remove(id)
            await loadTransactions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteSelected() async {
        let ids = Array(selectedTransactionIDs)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await bulkOpsUseCase.bulkDelete(transactionIDs: ids)
            selectedTransactionIDs.removeAll()
            isMultiSelectMode = false
            await loadTransactions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func recategorizeSelected(to categoryID: UUID) async {
        let ids = Array(selectedTransactionIDs)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await bulkOpsUseCase.recategorize(transactionIDs: ids, newCategoryID: categoryID)
            selectedTransactionIDs.removeAll()
            isMultiSelectMode = false
            await loadTransactions()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleSelection(_ id: UUID) {
        if selectedTransactionIDs.contains(id) {
            selectedTransactionIDs.remove(id)
            if selectedTransactionIDs.isEmpty {
                isMultiSelectMode = false
            }
        } else {
            selectedTransactionIDs.insert(id)
            isMultiSelectMode = true
        }
    }
}
