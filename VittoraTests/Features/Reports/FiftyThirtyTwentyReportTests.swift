import Foundation
import Testing
import VittoraCore
@testable import Vittora

@Suite("50/30/20 report")
@MainActor
struct FiftyThirtyTwentyReportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private var today: Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 21
        ).date ?? .now
    }

    @Test("seeded category names receive the specified defaults")
    func defaultClassification() {
        for name in [
            "Groceries", "Transport", "Health", "Education", "Utilities", "Rent",
            "EMI", "Insurance", "Personal Care", "Phone", "Internet", "Clothing", "Pets",
        ] {
            #expect(SpendingBucket.defaultBucket(categoryName: name, type: .expense) == .needs)
        }
        for name in ["Dining", "Entertainment", "Shopping", "Subscriptions", "Travel"] {
            #expect(SpendingBucket.defaultBucket(categoryName: name, type: .expense) == .wants)
        }
        #expect(SpendingBucket.defaultBucket(categoryName: "Custom", type: .expense) == .wants)
    }

    @Test("pure math returns no comparison for zero income")
    func zeroIncomeMath() {
        let amounts = FiftyThirtyTwentyAmounts(needs: 100, wants: 50, savings: 25)
        #expect(FiftyThirtyTwentyMath.calculate(income: 0, amounts: amounts) == nil)
    }

    @Test("each displayed bucket contributes to the exact total independently")
    func bucketsSumExactly() {
        let amounts = FiftyThirtyTwentyAmounts(
            needs: Decimal(string: "2403.55") ?? 0,
            wants: Decimal(string: "346.68") ?? 0,
            savings: 800
        )
        #expect(amounts.needs + amounts.wants + amounts.savings == amounts.totalSpending)
        #expect(amounts.totalSpending == Decimal(string: "3550.23"))
    }

    @Test("production wiring applies category overrides and uncategorized wants")
    func categoryOverrideWiring() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let debts = MockDebtRepository()
        let rent = CategoryEntity(
            name: "Rent",
            icon: "house.fill",
            spendingBucket: .wants
        )
        await categories.seed(rent)
        await transactions.seed(TransactionEntity(
            amount: 1_000,
            date: today,
            type: .income
        ))
        await transactions.seed(TransactionEntity(
            amount: 300,
            date: today,
            type: .expense,
            categoryID: rent.id
        ))
        await transactions.seed(TransactionEntity(
            amount: 25,
            date: today,
            type: .expense,
            categoryID: nil
        ))

        let snapshot = try await makeUseCase(
            transactions: transactions,
            categories: categories,
            debts: debts
        ).execute()

        #expect(snapshot.amounts.needs == 0)
        #expect(snapshot.amounts.wants == 325)
        #expect(
            snapshot.comparison?.rows.first { $0.bucket == .wants }?.actualPercent
                == Decimal(string: "32.5")
        )
    }

    @Test("production wiring sums goal contributions and borrowed-debt repayments")
    func savingsAndDebtWiring() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let debts = MockDebtRepository()
        let repaymentID = UUID()

        await transactions.seed(TransactionEntity(
            amount: 2_000,
            date: today,
            type: .income
        ))
        await transactions.seed(TransactionEntity(
            id: repaymentID,
            amount: 200,
            date: today,
            type: .expense
        ))
        await transactions.seed(TransactionEntity(
            amount: 400,
            date: today,
            type: .adjustment,
            tags: [FiftyThirtyTwentyReportUseCase.savingsContributionTag]
        ))
        debts.seed(DebtEntry(
            payeeID: UUID(),
            amount: 500,
            settledAmount: 200,
            direction: .borrowed,
            linkedTransactionIDs: [repaymentID]
        ))

        let snapshot = try await makeUseCase(
            transactions: transactions,
            categories: categories,
            debts: debts
        ).execute()

        #expect(snapshot.amounts.wants == 0)
        #expect(snapshot.amounts.savings == 600)
        #expect(snapshot.comparison?.rows.first { $0.bucket == .savings }?.actualPercent == 30)
    }

    @Test("production wiring preserves the zero-income prompt state")
    func zeroIncomeWiring() async throws {
        let transactions = MockTransactionRepository()
        await transactions.seed(TransactionEntity(amount: 50, date: today, type: .expense))

        let snapshot = try await makeUseCase(
            transactions: transactions,
            categories: MockCategoryRepository(),
            debts: MockDebtRepository()
        ).execute()

        #expect(snapshot.income == 0)
        #expect(snapshot.comparison == nil)
    }

    private func makeUseCase(
        transactions: MockTransactionRepository,
        categories: MockCategoryRepository,
        debts: MockDebtRepository
    ) -> FiftyThirtyTwentyReportUseCase {
        let reportDate = today
        return FiftyThirtyTwentyReportUseCase(
            transactionRepository: transactions,
            categoryRepository: categories,
            debtRepository: debts,
            calendar: calendar,
            today: { reportDate }
        )
    }
}
