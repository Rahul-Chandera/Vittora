import Foundation
import Testing
import SwiftData
import VittoraCore
@testable import Vittora

@MainActor
@Suite("FetchBudgets rolling spend")
struct FetchBudgetsRollingSpendTests {

    private func makeUseCase() throws -> (
        useCase: FetchBudgetsUseCase,
        budgets: SwiftDataBudgetRepository,
        transactions: SwiftDataTransactionRepository
    ) {
        let container = try ModelContainerConfig.makePreviewContainer()
        let budgets = SwiftDataBudgetRepository(modelContainer: container)
        let transactions = SwiftDataTransactionRepository(modelContainer: container)
        let useCase = FetchBudgetsUseCase(
            budgetRepository: budgets,
            transactionRepository: transactions
        )
        return (useCase, budgets, transactions)
    }

    @Test("spent resets each period - only the current window counts")
    func spentResetsEachPeriodOnlyCurrentWindowCounts() async throws {
        let env = try makeUseCase()
        let calendar = Calendar.current
        let now = Date()
        let categoryID = UUID()
        // `.month, -3` from now lands exactly on a window boundary (lowerBound == now),
        // which would exclude a 2-day-old txn. Shift 14 days earlier so now is mid-window.
        let threeMonthsAgo = try #require(calendar.date(byAdding: .month, value: -3, to: now))
        let startDate = try #require(calendar.date(byAdding: .day, value: -14, to: threeMonthsAgo))
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: now))
        let seventyDaysAgo = try #require(calendar.date(byAdding: .day, value: -70, to: now))

        try await env.budgets.create(
            BudgetEntity(
                amount: 3400,
                period: .monthly,
                startDate: startDate,
                categoryID: categoryID,
                createdAt: startDate,
                updatedAt: startDate
            )
        )
        try await env.transactions.create(
            TransactionEntity(
                amount: 1200,
                date: twoDaysAgo,
                type: .expense,
                categoryID: categoryID
            )
        )
        try await env.transactions.create(
            TransactionEntity(
                amount: 900,
                date: seventyDaysAgo,
                type: .expense,
                categoryID: categoryID
            )
        )

        let budgets = try await env.useCase.execute()

        #expect(budgets.count == 1)
        #expect(budgets.first?.spent == 1200)
    }

    @Test("a budget whose start period ended long ago is still returned by execute()")
    func budgetWhoseStartPeriodEndedLongAgoIsStillReturned() async throws {
        let env = try makeUseCase()
        let calendar = Calendar.current
        let now = Date()
        let startDate = try #require(calendar.date(byAdding: .month, value: -3, to: now))

        try await env.budgets.create(
            BudgetEntity(
                amount: 3400,
                period: .monthly,
                startDate: startDate,
                createdAt: startDate,
                updatedAt: startDate
            )
        )

        let budgets = try await env.useCase.execute()

        #expect(budgets.count == 1)
        #expect(budgets.first?.spent == 0)
    }
}
