import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Reported from device: a budget row's progress bar and spent figure do not
/// move after adding an expense in that category — only after relaunching.
///
/// This pins down WHERE the staleness is. `BudgetEntity.spent` is a stored
/// property, and `FetchBudgetsUseCase` recomputes it from transactions on every
/// fetch, so the question is whether a second `loadBudgets()` picks up a
/// transaction added after the first one. If these pass, the view model and the
/// data layer are innocent and the bug is in SwiftUI refresh.
@Suite("Budget List ViewModel refresh")
@MainActor
struct BudgetListViewModelRefreshTests {

    private func makeViewModel(
        budgetRepository: MockBudgetRepository,
        transactionRepository: MockTransactionRepository,
        categoryRepository: MockCategoryRepository
    ) -> BudgetListViewModel {
        BudgetListViewModel(
            fetchUseCase: FetchBudgetsUseCase(
                budgetRepository: budgetRepository,
                transactionRepository: transactionRepository
            ),
            deleteUseCase: DeleteBudgetUseCase(budgetRepository: budgetRepository),
            calculateProgressUseCase: CalculateBudgetProgressUseCase(),
            categoryRepository: categoryRepository
        )
    }

    @Test("a reload picks up an expense added after the first load")
    func reloadReflectsNewExpense() async throws {
        let budgetRepository = MockBudgetRepository()
        let transactionRepository = MockTransactionRepository()
        let categoryRepository = MockCategoryRepository()

        let category = CategoryEntity(
            name: "Entertainment",
            icon: "film",
            colorHex: "#FF6B35",
            type: .expense
        )
        try await categoryRepository.create(category)

        // Start the period comfortably inside the current month so "now" falls
        // in the budget's date range regardless of when this runs.
        let monthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        ) ?? .now
        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "1000")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: category.id
            )
        )

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository
        )

        await vm.loadBudgets()
        #expect(vm.budgets.count == 1)
        #expect(vm.budgets[0].spent == 0)
        #expect(vm.overallSpent == 0)

        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "37")!,
                date: .now,
                type: .expense,
                categoryID: category.id
            )
        )

        await vm.loadBudgets()

        #expect(vm.budgets[0].spent == Decimal(string: "37")!)
        #expect(vm.overallSpent == Decimal(string: "37")!)
        // The row reads budgetProgress, the header reads overallSpent — they
        // must not be able to drift apart.
        #expect(vm.budgetProgress[vm.budgets[0].id]?.spent == vm.overallSpent)
    }
}
