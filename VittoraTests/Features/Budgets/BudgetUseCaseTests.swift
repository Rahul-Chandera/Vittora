import Foundation
import Testing

@testable import Vittora

@Suite("Budget Use Case Tests")
struct BudgetUseCaseTests {

    // MARK: - CreateBudgetUseCase

    @Suite("CreateBudgetUseCase")
    struct CreateBudgetUseCaseTests {

        @Test("Creates a budget with valid amount")
        func testCreatesValidBudget() async throws {
            let repo = MockBudgetRepository()
            let useCase = CreateBudgetUseCase(budgetRepository: repo)

            try await useCase.execute(amount: Decimal(500), period: .monthly)

            let all = await repo.budgets
            #expect(all.count == 1)
            #expect(all[0].amount == 500)
            #expect(all[0].period == .monthly)
            #expect(all[0].spent == 0)
        }

        @Test("Throws for zero amount")
        func testThrowsForZeroAmount() async throws {
            let useCase = CreateBudgetUseCase(budgetRepository: MockBudgetRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.execute(amount: 0, period: .monthly)
            }
        }

        @Test("Throws for negative amount")
        func testThrowsForNegativeAmount() async throws {
            let useCase = CreateBudgetUseCase(budgetRepository: MockBudgetRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.execute(amount: -100, period: .monthly)
            }
        }

        @Test("Throws when duplicate active budget exists for same category and period")
        func testThrowsForDuplicateCategoryBudget() async throws {
            let repo = MockBudgetRepository()
            let categoryID = UUID()

            // Seed an existing budget for the category
            let existing = BudgetEntity(amount: 200, period: .monthly, categoryID: categoryID)
            await repo.seed(existing)

            let useCase = CreateBudgetUseCase(budgetRepository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
                    amount: 300,
                    period: .monthly,
                    categoryID: categoryID
                )
            }
        }

        @Test("Allows budget without category even if same period exists")
        func testAllowsNoCategoryBudget() async throws {
            let repo = MockBudgetRepository()

            // Existing budget with no category
            await repo.seed(BudgetEntity(amount: 200, period: .monthly))

            let useCase = CreateBudgetUseCase(budgetRepository: repo)

            // Should not throw — no category means no duplicate check
            try await useCase.execute(amount: 300, period: .monthly)

            let all = await repo.budgets
            #expect(all.count == 2)
        }

        @Test("Creates budget with rollover enabled")
        func testCreatesWithRollover() async throws {
            let repo = MockBudgetRepository()
            let useCase = CreateBudgetUseCase(budgetRepository: repo)

            try await useCase.execute(amount: 400, period: .monthly, rollover: true)

            let all = await repo.budgets
            #expect(all[0].rollover == true)
        }
    }

    // MARK: - UpdateBudgetUseCase

    @Suite("UpdateBudgetUseCase")
    struct UpdateBudgetUseCaseTests {

        @Test("Updates an existing budget")
        func testUpdatesExistingBudget() async throws {
            let repo = MockBudgetRepository()
            var budget = BudgetEntity(amount: 100, period: .monthly)
            await repo.seed(budget)

            budget.amount = 250

            let useCase = UpdateBudgetUseCase(budgetRepository: repo)
            try await useCase.execute(budget)

            let all = await repo.budgets
            #expect(all[0].amount == 250)
        }

        @Test("Throws for zero amount on update")
        func testThrowsForZeroAmount() async throws {
            let repo = MockBudgetRepository()
            let budget = BudgetEntity(amount: 0, period: .monthly)
            await repo.seed(budget)

            let useCase = UpdateBudgetUseCase(budgetRepository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(budget)
            }
        }
    }

    // MARK: - DeleteBudgetUseCase

    @Suite("DeleteBudgetUseCase")
    struct DeleteBudgetUseCaseTests {

        @Test("Deletes an existing budget")
        func testDeletesBudget() async throws {
            let repo = MockBudgetRepository()
            let budget = BudgetEntity(amount: 300, period: .weekly)
            await repo.seed(budget)

            let useCase = DeleteBudgetUseCase(budgetRepository: repo)
            try await useCase.execute(id: budget.id)

            let all = await repo.budgets
            #expect(all.isEmpty)
        }

        @Test("Throws when budget not found")
        func testThrowsWhenMissing() async throws {
            let useCase = DeleteBudgetUseCase(budgetRepository: MockBudgetRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.execute(id: UUID())
            }
        }
    }

    // MARK: - FetchBudgetsUseCase

    @Suite("FetchBudgetsUseCase")
    struct FetchBudgetsUseCaseTests {

        @Test("Returns active budgets with calculated spent")
        func testFetchActiveWithSpent() async throws {
            let budgetRepo = MockBudgetRepository()
            let transactionRepo = MockTransactionRepository()

            let categoryID = UUID()
            let budget = BudgetEntity(
                amount: 500,
                period: .monthly,
                startDate: Calendar.current.date(
                    from: Calendar.current.dateComponents([.year, .month], from: .now)
                ) ?? .now,
                categoryID: categoryID
            )
            await budgetRepo.seed(budget)

            // Add expense transaction in this month for the same category
            let transaction = TransactionEntity(
                amount: 120,
                date: .now,
                type: .expense,
                categoryID: categoryID
            )
            await transactionRepo.seed(transaction)

            let useCase = FetchBudgetsUseCase(
                budgetRepository: budgetRepo,
                transactionRepository: transactionRepo
            )
            let result = try await useCase.execute()

            #expect(result.count == 1)
            #expect(result[0].spent == 120)
        }

        @Test("Returns all budgets including inactive with executeAll")
        func testExecuteAll() async throws {
            let budgetRepo = MockBudgetRepository()
            let transactionRepo = MockTransactionRepository()

            await budgetRepo.seed(BudgetEntity(amount: 100, period: .monthly))
            await budgetRepo.seed(BudgetEntity(amount: 200, period: .yearly))

            let useCase = FetchBudgetsUseCase(
                budgetRepository: budgetRepo,
                transactionRepository: transactionRepo
            )
            let result = try await useCase.executeAll()

            #expect(result.count == 2)
        }

        @Test("Spent is zero when no matching transactions")
        func testSpentIsZeroWithNoTransactions() async throws {
            let budgetRepo = MockBudgetRepository()
            await budgetRepo.seed(BudgetEntity(amount: 300, period: .monthly))

            let useCase = FetchBudgetsUseCase(
                budgetRepository: budgetRepo,
                transactionRepository: MockTransactionRepository()
            )
            let result = try await useCase.execute()

            #expect(result[0].spent == 0)
        }
    }

    // MARK: - CalculateBudgetProgressUseCase

    @Suite("CalculateBudgetProgressUseCase")
    struct CalculateBudgetProgressUseCaseTests {

        @Test("Returns safe status when under 75% spent")
        func testSafeStatus() {
            let budget = BudgetEntity(amount: 1000, spent: 500, period: .monthly)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.statusColor == "safe")
            #expect(progress.spent == 500)
            #expect(progress.remaining == 500)
        }

        @Test("Returns warning status when between 75% and 90% spent")
        func testWarningStatus() {
            let budget = BudgetEntity(amount: 1000, spent: 800, period: .monthly)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.statusColor == "warning")
        }

        @Test("Returns danger status when at or above 90% spent")
        func testDangerStatus() {
            let budget = BudgetEntity(amount: 1000, spent: 950, period: .monthly)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.statusColor == "danger")
        }

        @Test("Returns danger status when over budget")
        func testDangerStatusOverBudget() {
            let budget = BudgetEntity(amount: 1000, spent: 1200, period: .monthly)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.statusColor == "danger")
            #expect(progress.remaining < 0)
        }

        @Test("Percentage matches budget.progress")
        func testPercentageValue() {
            let budget = BudgetEntity(amount: 200, spent: 100, period: .monthly)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.percentage == budget.progress)
        }

        @Test("Days remaining is non-negative for current period")
        func testDaysRemainingNonNegative() {
            let budget = BudgetEntity(amount: 500, period: .monthly, startDate: .now)
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.daysRemaining >= 0)
        }
    }
}
