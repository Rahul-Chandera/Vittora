import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Reported from device: Dashboard "Overall Progress" stays at its launch
/// snapshot (e.g. 0%) while the Budgets page already shows the updated figure.
///
/// This pins down WHERE the staleness is. If a second load picks up data added
/// after the first, the view model and the data layer are innocent and the
/// staleness is in SwiftUI refresh — which is why DashboardView now uses
/// onChange rather than .task(id:).
@Suite("Dashboard ViewModel refresh")
@MainActor
struct DashboardViewModelRefreshTests {

    private func makeViewModel(
        budgetRepository: MockBudgetRepository,
        transactionRepository: MockTransactionRepository,
        categoryRepository: MockCategoryRepository
    ) -> DashboardViewModel {
        DashboardViewModel(
            dashboardDataUseCase: DashboardDataUseCase(
                transactionRepository: transactionRepository,
                accountRepository: MockAccountRepository(),
                categoryRepository: categoryRepository,
                budgetRepository: budgetRepository,
                recurringRuleRepository: MockRecurringRuleRepository()
            ),
            monthComparisonUseCase: MonthComparisonUseCase(
                transactionRepository: transactionRepository
            )
        )
    }

    @Test("a refresh picks up a budget that arrived after the first load")
    func refreshReflectsNewBudget() async throws {
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

        let monthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: .now)
        ) ?? .now

        let vm = makeViewModel(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository
        )

        await vm.load()
        #expect(vm.dashboardData?.monthBudgetProgress == 0)

        try await budgetRepository.create(
            BudgetEntity(
                amount: Decimal(string: "1000")!,
                period: .monthly,
                startDate: monthStart,
                categoryID: category.id
            )
        )
        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "500")!,
                date: monthStart,
                type: .expense,
                categoryID: category.id
            )
        )

        await vm.refresh()

        let progress = try #require(vm.dashboardData?.monthBudgetProgress)
        #expect(progress > 0)
        #expect(abs(progress - 0.5) < 0.001)
    }

    @Test("a refresh picks up an expense that arrived after the first load")
    func refreshReflectsNewExpense() async throws {
        let budgetRepository = MockBudgetRepository()
        let transactionRepository = MockTransactionRepository()
        let categoryRepository = MockCategoryRepository()

        let category = CategoryEntity(
            name: "Dining",
            icon: "fork.knife",
            colorHex: "#FF6B35",
            type: .expense
        )
        try await categoryRepository.create(category)

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

        await vm.load()
        // Exact shape of the reported 0%: budget exists, spend has not arrived.
        #expect(vm.dashboardData?.monthBudgetProgress == 0)

        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "500")!,
                date: monthStart,
                type: .expense,
                categoryID: category.id
            )
        )

        await vm.refresh()

        let progress = try #require(vm.dashboardData?.monthBudgetProgress)
        #expect(abs(progress - 0.5) < 0.001)
    }
}
