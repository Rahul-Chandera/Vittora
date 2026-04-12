import Foundation

@Observable
@MainActor
final class CategoryListViewModel {
    var expenseCategories: [CategoryEntity] = []
    var incomeCategories: [CategoryEntity] = []
    var searchQuery: String = ""
    var isLoading = false
    var error: String?

    var filteredExpenseCategories: [CategoryEntity] {
        guard !searchQuery.isEmpty else { return expenseCategories }
        return expenseCategories.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var filteredIncomeCategories: [CategoryEntity] {
        guard !searchQuery.isEmpty else { return incomeCategories }
        return incomeCategories.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private let fetchUseCase: FetchCategoriesUseCase
    private let deleteUseCase: DeleteCategoryUseCase
    private let reorderUseCase: ReorderCategoriesUseCase

    init(
        fetchUseCase: FetchCategoriesUseCase,
        deleteUseCase: DeleteCategoryUseCase,
        reorderUseCase: ReorderCategoriesUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
        self.reorderUseCase = reorderUseCase
    }

    func loadCategories() async {
        isLoading = true
        error = nil
        do {
            let grouped = try await fetchUseCase.executeGrouped()
            expenseCategories = grouped.expense
            incomeCategories = grouped.income
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteCategory(id: UUID) async {
        do {
            try await deleteUseCase.execute(id: id)
            await loadCategories()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reorder(type: CategoryType, orderedIDs: [UUID]) async {
        do {
            try await reorderUseCase.execute(orderedIDs: orderedIDs)
            await loadCategories()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
