import Foundation
import VittoraCore

@Observable @MainActor final class TransactionListViewModel {
    var groupedTransactions: [(date: Date, transactions: [TransactionEntity])] = []
    var activeFilter: TransactionFilter = TransactionFilter()
    var searchQuery: String = ""
    var isLoading = false
    var isLoadingMore = false
    var hasMorePages = true
    var error: String?
    var selectedTransactionIDs: Set<UUID> = []
    var isMultiSelectMode = false

    private let fetchUseCase: FetchTransactionsUseCase
    private let searchUseCase: SearchTransactionsUseCase
    private let deleteUseCase: DeleteTransactionUseCase
    private let bulkOpsUseCase: BulkOperationsUseCase
    private let addUseCase: AddTransactionUseCase
    private var loadedOffset = 0

    init(
        fetchUseCase: FetchTransactionsUseCase,
        searchUseCase: SearchTransactionsUseCase,
        deleteUseCase: DeleteTransactionUseCase,
        bulkOpsUseCase: BulkOperationsUseCase,
        addUseCase: AddTransactionUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.searchUseCase = searchUseCase
        self.deleteUseCase = deleteUseCase
        self.bulkOpsUseCase = bulkOpsUseCase
        self.addUseCase = addUseCase
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

    var lastLoadedTransactionID: UUID? {
        groupedTransactions.last?.transactions.last?.id
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadTransactions() async {
        isLoading = true
        error = nil
        loadedOffset = 0
        hasMorePages = true
        defer { isLoading = false }

        do {
            let page = try await fetchUseCase.executePage(filter: activeFilter, offset: 0)
            groupedTransactions = FetchTransactionsUseCase.groupByDate(page)
            loadedOffset = page.count
            hasMorePages = page.count == FetchTransactionsUseCase.listPageSize
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load transactions right now.")
            )
        }
    }

    func loadNextPageIfNeeded(currentTransactionID: UUID) async {
        guard !isSearching,
              hasMorePages,
              !isLoading,
              !isLoadingMore,
              currentTransactionID == lastLoadedTransactionID else {
            return
        }
        await loadNextPage()
    }

    private func loadNextPage() async {
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchUseCase.executePage(
                filter: activeFilter,
                offset: loadedOffset
            )
            guard !page.isEmpty else {
                hasMorePages = false
                return
            }
            groupedTransactions = FetchTransactionsUseCase.mergeGrouped(
                groupedTransactions,
                with: page
            )
            loadedOffset += page.count
            hasMorePages = page.count == FetchTransactionsUseCase.listPageSize
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't load more transactions.")
            )
        }
    }

    func search(_ query: String) async {
        isLoading = true
        error = nil
        hasMorePages = false
        defer { isLoading = false }

        do {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                await loadTransactions()
            } else {
                let results = try await searchUseCase.execute(query: query)
                groupedTransactions = FetchTransactionsUseCase.groupByDate(results)
            }
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't search transactions right now.")
            )
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
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't delete this transaction.")
            )
        }
    }

    func duplicateTransaction(id: UUID) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            guard let original = try await fetchUseCase.execute(id: id) else {
                error = String(localized: "We couldn't find this transaction.")
                return
            }
            guard original.type != .transfer else {
                error = String(localized: "Transfers must be created through the transfer flow.")
                return
            }
            guard let accountID = original.accountID else {
                error = String(localized: "This transaction isn't linked to an account.")
                return
            }

            _ = try await addUseCase.execute(
                amount: original.amount,
                type: original.type,
                date: .now,
                categoryID: original.categoryID,
                accountID: accountID,
                payeeID: original.payeeID,
                note: original.note,
                tags: original.tags,
                paymentMethod: original.paymentMethod,
                currencyCode: original.currencyCode
            )
            await loadTransactions()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't duplicate this transaction.")
            )
        }
    }

    func deleteSelected() async {
        let ids = Array(selectedTransactionIDs)
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await deleteUseCase.executeBulk(ids: ids)
            selectedTransactionIDs.removeAll()
            isMultiSelectMode = false
            await loadTransactions()
        } catch {
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't delete the selected transactions.")
            )
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
            self.error = error.userFacingMessage(
                fallback: String(localized: "We couldn't update the selected transactions.")
            )
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
