import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("Cash Flow Projection Tests")
struct CashFlowProjectionUseCaseTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let anchor = makeDate(year: 2026, month: 6, day: 15)

    @Test("projects recurring expenses into future months")
    func projectsRecurringExpenses() async throws {
        let transactionRepository = MockTransactionRepository()
        let recurringRepository = MockRecurringRuleRepository()

        let monthStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? anchor
        try await transactionRepository.create(
            TransactionEntity(
                amount: 2_000,
                date: monthStart,
                type: .income
            )
        )
        try await transactionRepository.create(
            TransactionEntity(
                amount: 400,
                date: monthStart,
                type: .expense
            )
        )

        let accountID = UUID()
        await recurringRepository.seed(
            RecurringRuleEntity(
                frequency: .monthly,
                nextDate: calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart,
                templateAmount: 100,
                templateAccountID: accountID
            )
        )

        let useCase = CashFlowProjectionUseCase(
            transactionRepository: transactionRepository,
            recurringRuleRepository: recurringRepository,
            calendar: calendar,
            nowProvider: { anchor }
        )

        let result = try await useCase.execute(historyMonthCount: 3, projectionMonthCount: 2)
        let projected = result.months.filter(\.isProjected)

        #expect(projected.count == 2)
        #expect(projected.allSatisfy { $0.recurringExpense == 100 })
        #expect(projected.allSatisfy { $0.projectedExpense == 100 + result.averageDiscretionaryExpense })
        #expect(result.averageIncome == 2_000)
    }

    @Test("RecurrenceDateMath totals monthly rule occurrences in interval")
    func recurrenceDateMathTotalsMonthlyRule() {
        let monthStart = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)) ?? anchor
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: monthStart,
            templateAmount: 50,
            templateAccountID: UUID()
        )

        let total = RecurrenceDateMath.totalAmount(
            for: [rule],
            in: monthStart..<monthEnd,
            calendar: calendar
        )

        #expect(total == 50)
    }

    @Test("historical discretionary excludes linked recurring transactions")
    func historicalDiscretionaryExcludesRecurring() async throws {
        let transactionRepository = MockTransactionRepository()
        let recurringRepository = MockRecurringRuleRepository()
        let monthStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10)) ?? anchor
        let ruleID = UUID()

        try await transactionRepository.create(
            TransactionEntity(
                amount: 1_000,
                date: monthStart,
                type: .income
            )
        )
        try await transactionRepository.create(
            TransactionEntity(
                amount: 300,
                date: monthStart,
                type: .expense,
                recurringRuleID: ruleID
            )
        )
        try await transactionRepository.create(
            TransactionEntity(
                amount: 200,
                date: monthStart,
                type: .expense
            )
        )

        let useCase = CashFlowProjectionUseCase(
            transactionRepository: transactionRepository,
            recurringRuleRepository: recurringRepository,
            calendar: calendar,
            nowProvider: { anchor }
        )

        let result = try await useCase.execute(historyMonthCount: 1, projectionMonthCount: 1)

        #expect(result.averageDiscretionaryExpense == 200)
        #expect(result.averageIncome == 1_000)
    }
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        Issue.record("Failed to create test date")
        return Date(timeIntervalSince1970: 0)
    }
    return date
}
