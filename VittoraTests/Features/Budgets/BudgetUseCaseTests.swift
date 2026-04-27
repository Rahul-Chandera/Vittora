import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Budget Use Case Tests")
struct BudgetUseCaseTests {

    // MARK: - CreateBudgetUseCase

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
    @Suite("FetchBudgetsUseCase")
    struct FetchBudgetsUseCaseTests {

        @Test("Returns active budgets with calculated spent")
        func testFetchActiveWithSpent() async throws {
            let budgetRepo = MockBudgetRepository()
            let transactionRepo = MockTransactionRepository()

            // Fixed dates: budget starts April 1 2026, transaction mid-month — avoids month-boundary races
            let aprilStart = makeBudgetDate(year: 2026, month: 4, day: 1)
            let aprilMid = makeBudgetDate(year: 2026, month: 4, day: 15)
            let categoryID = UUID()
            let budget = BudgetEntity(
                amount: 500,
                period: .monthly,
                startDate: aprilStart,
                categoryID: categoryID
            )
            await budgetRepo.seed(budget)

            // Add expense transaction in the same fixed month for the same category
            let transaction = TransactionEntity(
                amount: 120,
                date: aprilMid,
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

    @MainActor
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

        @Test("Days remaining is non-negative for a period that has not ended")
        func testDaysRemainingNonNegative() {
            let budget = BudgetEntity(amount: 500, period: .monthly, startDate: makeBudgetDate(year: 2026, month: 4, day: 1))
            let useCase = CalculateBudgetProgressUseCase()
            let progress = useCase.execute(budget: budget)

            #expect(progress.daysRemaining >= 0)
        }
    }

    @MainActor
    @Suite("CheckBudgetThresholdUseCase")
    struct CheckBudgetThresholdUseCaseTests {

        @Test("Returns budgets at or above fifty percent spent")
        func testReturnsBudgetsAtThresholdOrAbove() {
            let useCase = CheckBudgetThresholdUseCase()
            let belowThreshold = BudgetEntity(amount: 200, spent: 99, period: .monthly)
            let atThreshold = BudgetEntity(amount: 200, spent: 100, period: .monthly)
            let overThreshold = BudgetEntity(amount: 200, spent: 175, period: .monthly)

            let result = useCase.execute(budgets: [belowThreshold, atThreshold, overThreshold])

            #expect(result.count == 2)
            #expect(result.contains(where: { $0.id == atThreshold.id }))
            #expect(result.contains(where: { $0.id == overThreshold.id }))
        }
    }

    @MainActor
    @Suite("RolloverBudgetUseCase")
    struct RolloverBudgetUseCaseTests {

        @Test("Rollover enabled carries unused amount into next budget")
        func testRolloverCarriesUnusedAmount() async throws {
            let repo = MockBudgetRepository()
            let sourceBudget = BudgetEntity(
                amount: 500,
                spent: 125,
                period: .monthly,
                startDate: makeBudgetDate(year: 2026, month: 1, day: 1),
                rollover: true,
                categoryID: UUID()
            )
            await repo.seed(sourceBudget)

            let useCase = RolloverBudgetUseCase(budgetRepository: repo)
            let nextStartDate = makeBudgetDate(year: 2026, month: 2, day: 1)

            try await useCase.execute(budgetID: sourceBudget.id, newStartDate: nextStartDate)

            let budgets = await repo.budgets
            #expect(budgets.count == 2)

            let rolledBudget = budgets.first(where: { $0.id != sourceBudget.id })
            #expect(rolledBudget?.amount == 875)
            #expect(rolledBudget?.spent == 0)
            #expect(rolledBudget?.startDate == nextStartDate)
            #expect(rolledBudget?.categoryID == sourceBudget.categoryID)
        }

        @Test("Rollover disabled keeps original amount")
        func testRolloverDisabledKeepsOriginalAmount() async throws {
            let repo = MockBudgetRepository()
            let sourceBudget = BudgetEntity(
                amount: 600,
                spent: 240,
                period: .monthly,
                startDate: makeBudgetDate(year: 2026, month: 3, day: 1),
                rollover: false
            )
            await repo.seed(sourceBudget)

            let useCase = RolloverBudgetUseCase(budgetRepository: repo)
            try await useCase.execute(
                budgetID: sourceBudget.id,
                newStartDate: makeBudgetDate(year: 2026, month: 4, day: 1)
            )

            let budgets = await repo.budgets
            let rolledBudget = budgets.first(where: { $0.id != sourceBudget.id })
            #expect(rolledBudget?.amount == 600)
            #expect(rolledBudget?.rollover == false)
        }

        @Test("Throws when source budget does not exist")
        func testThrowsWhenSourceBudgetMissing() async throws {
            let useCase = RolloverBudgetUseCase(budgetRepository: MockBudgetRepository())

            await #expect(throws: (any Error).self) {
                try await useCase.execute(
                    budgetID: UUID(),
                    newStartDate: makeBudgetDate(year: 2026, month: 5, day: 1)
                )
            }
        }
    }

    @MainActor
    @Suite("CopyBudgetTemplateUseCase")
    struct CopyBudgetTemplateUseCaseTests {

        @Test("Copies only matching period budgets from the source window")
        func testCopiesOnlyMatchingPeriodBudgets() async throws {
            let repo = MockBudgetRepository()
            let sourceStart = makeBudgetDate(year: 2026, month: 1, day: 1)
            let targetStart = makeBudgetDate(year: 2026, month: 2, day: 1)

            let matchingBudget = BudgetEntity(
                amount: 300,
                spent: 120,
                period: .monthly,
                startDate: sourceStart,
                rollover: true,
                categoryID: UUID()
            )
            let wrongPeriodBudget = BudgetEntity(
                amount: 900,
                spent: 100,
                period: .yearly,
                startDate: sourceStart,
                categoryID: UUID()
            )
            let outsideWindowBudget = BudgetEntity(
                amount: 450,
                spent: 90,
                period: .monthly,
                startDate: makeBudgetDate(year: 2026, month: 4, day: 1),
                categoryID: UUID()
            )

            await repo.seed(matchingBudget)
            await repo.seed(wrongPeriodBudget)
            await repo.seed(outsideWindowBudget)

            let useCase = CopyBudgetTemplateUseCase(budgetRepository: repo)
            try await useCase.execute(
                fromPeriodStart: sourceStart,
                toPeriodStart: targetStart,
                period: .monthly
            )

            let budgets = await repo.budgets
            #expect(budgets.count == 4)

            let copiedBudget = budgets.first(where: {
                $0.startDate == targetStart && $0.categoryID == matchingBudget.categoryID
            })
            #expect(copiedBudget?.amount == matchingBudget.amount)
            #expect(copiedBudget?.spent == 0)
            #expect(copiedBudget?.rollover == true)
            #expect(copiedBudget?.period == .monthly)
        }
    }
}

private func makeBudgetDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        Issue.record("makeBudgetDate failed for \(year)-\(month)-\(day)")
        return Date(timeIntervalSince1970: 0)
    }
    return date
}
