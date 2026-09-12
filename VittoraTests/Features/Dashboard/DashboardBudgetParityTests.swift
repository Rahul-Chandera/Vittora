import Foundation
import Testing
import SwiftData
import VittoraCore
@testable import Vittora

/// Diagnostic: Dashboard "Overall Progress" vs Budgets-page overall progress
/// for the same SwiftData-backed seed. Expects shared compute path parity.
@MainActor
@Suite("Dashboard Budget Parity Diagnostics")
struct DashboardBudgetParityTests {

    @Test("Dashboard monthBudgetProgress matches Budgets overall progress for overlapping Dining budgets")
    func testDashboardBudgetProgressParity() async throws {
        let container = try ModelContainerConfig.makePreviewContainer()
        let budgetRepository = SwiftDataBudgetRepository(modelContainer: container)
        let transactionRepository = SwiftDataTransactionRepository(modelContainer: container)
        let accountRepository = SwiftDataAccountRepository(modelContainer: container)
        let categoryRepository = SwiftDataCategoryRepository(modelContainer: container)
        let recurringRuleRepository = SwiftDataRecurringRuleRepository(modelContainer: container)

        let calendar = Calendar.current
        let now = Date.now
        guard
            let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: now),
            let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now),
            let twentyThreeDaysAgo = calendar.date(byAdding: .day, value: -23, to: now)
        else {
            Issue.record("Failed to compute relative dates")
            return
        }

        let dining = CategoryEntity(
            name: "Dining",
            icon: "fork.knife",
            type: .expense
        )
        try await categoryRepository.create(dining)

        let budgetA = BudgetEntity(
            amount: Decimal(string: "5000")!,
            period: .monthly,
            startDate: oneDayAgo,
            categoryID: dining.id
        )
        let budgetB = BudgetEntity(
            amount: Decimal(string: "3400")!,
            period: .monthly,
            startDate: twentyThreeDaysAgo,
            categoryID: dining.id
        )
        try await budgetRepository.create(budgetA)
        try await budgetRepository.create(budgetB)

        // Expenses totalling 6238 in Dining, dated 10 days ago.
        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "3000")!,
                date: tenDaysAgo,
                type: .expense,
                categoryID: dining.id
            )
        )
        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "3238")!,
                date: tenDaysAgo,
                type: .expense,
                categoryID: dining.id
            )
        )
        // Income in the same category/date — type filter should exclude it from spent.
        try await transactionRepository.create(
            TransactionEntity(
                amount: Decimal(string: "1000")!,
                date: tenDaysAgo,
                type: .income,
                categoryID: dining.id
            )
        )

        let budgets = try await FetchBudgetsUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        ).execute()

        let overallBudget = budgets.reduce(Decimal(0)) { $0 + $1.amount }
        let overallSpent = budgets.reduce(Decimal(0)) { $0 + $1.spent }

        #expect(budgets.count == 2)
        #expect(overallBudget == Decimal(string: "8400")!)
        #expect(overallSpent == Decimal(string: "6238")!)

        let data = try await DashboardDataUseCase(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            budgetRepository: budgetRepository,
            recurringRuleRepository: recurringRuleRepository
        ).execute()

        let overallProgress = overallBudget > 0
            ? Double(truncating: (overallSpent / overallBudget) as NSDecimalNumber)
            : 0.0

        #expect(abs(data.monthBudgetProgress - overallProgress) < 0.001)
    }
}
