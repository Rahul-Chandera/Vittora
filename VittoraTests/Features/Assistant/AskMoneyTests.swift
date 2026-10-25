import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// The assistant's numbers all come from `MoneyAnswerEngine`. These pin that the right
/// transactions are counted: the right type, period, category (with sub-categories),
/// payee and currency.
@MainActor
@Suite("Ask About Your Money Tests")
struct AskMoneyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }
    /// 25 October 2026, 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_792_929_600)
    private let dining = CategoryEntity(name: "Dining", icon: "fork.knife")
    private let groceries = CategoryEntity(name: "Groceries", icon: "cart")
    private let starbucks = PayeeEntity(name: "Starbucks")

    private func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(TimeInterval(-days * 86_400)) }

    private func makeEngine(_ transactions: [TransactionEntity], categories: [CategoryEntity]? = nil) async throws -> MoneyAnswerEngine {
        let repository = MockTransactionRepository()
        for transaction in transactions { try await repository.create(transaction) }
        let categoryRepository = MockCategoryRepository()
        await categoryRepository.seedMany(categories ?? [dining, groceries])
        let payeeRepository = MockPayeeRepository()
        await payeeRepository.seedMany([starbucks])
        return MoneyAnswerEngine(
            transactionRepository: repository,
            categoryRepository: categoryRepository,
            payeeRepository: payeeRepository
        )
    }

    private func expense(_ amount: Decimal, daysAgo days: Int, category: CategoryEntity? = nil,
                         payee: PayeeEntity? = nil, currency: String = "USD") -> TransactionEntity {
        TransactionEntity(amount: amount, date: daysAgo(days), type: .expense, currencyCode: currency,
                          categoryID: category?.id, payeeID: payee?.id)
    }

    // MARK: - Engine

    @Test("Spent this month counts only this month's expenses in the user's currency")
    func spentThisMonth() async throws {
        let engine = try await makeEngine([
            expense(40, daysAgo: 1, category: dining),
            expense(10, daysAgo: 3),
            expense(99, daysAgo: 40),                                   // last month
            TransactionEntity(amount: 2000, date: daysAgo(2), type: .income, currencyCode: "USD"),
        ])
        let answer = try await engine.answer(MoneyQuestion(measure: .spent, period: .thisMonth),
                                             currencyCode: "USD", now: now, calendar: calendar)
        #expect(answer.text.contains("50"))
        #expect(!answer.text.contains("99"))
        #expect(answer.transactions.count == 2)
    }

    @Test("A category includes its sub-categories")
    func categoryIncludesChildren() async throws {
        let coffee = CategoryEntity(name: "Coffee", icon: "cup.and.saucer", parentID: dining.id)
        let engine = try await makeEngine([
            expense(30, daysAgo: 1, category: dining),
            expense(5, daysAgo: 2, category: coffee),
            expense(70, daysAgo: 2, category: groceries),
        ], categories: [dining, groceries, coffee])
        let answer = try await engine.answer(MoneyQuestion(measure: .spent, period: .thisMonth, categoryName: "dining"),
                                             currencyCode: "USD", now: now, calendar: calendar)
        #expect(answer.transactions.count == 2)
        #expect(answer.text.contains("35"))
        #expect(answer.text.contains("Dining"))
    }

    @Test("Amounts in other currencies are left out, and the answer says so")
    func otherCurrenciesExcluded() async throws {
        let engine = try await makeEngine([
            expense(20, daysAgo: 1),
            expense(1500, daysAgo: 1, currency: "INR"),
        ])
        let answer = try await engine.answer(MoneyQuestion(measure: .spent, period: .thisMonth),
                                             currencyCode: "USD", now: now, calendar: calendar)
        #expect(answer.transactions.count == 1)
        #expect(!answer.text.contains("1,500"))
        #expect(answer.text.contains(String(localized: "Transactions in other currencies aren't included.")))
    }

    @Test("Biggest expense names the payee and lists only that transaction")
    func biggestExpense() async throws {
        let engine = try await makeEngine([
            expense(12, daysAgo: 1, payee: starbucks),
            expense(80, daysAgo: 2, payee: starbucks),
            expense(30, daysAgo: 3),
        ])
        let answer = try await engine.answer(MoneyQuestion(measure: .biggestExpense, period: .thisMonth),
                                             currencyCode: "USD", now: now, calendar: calendar)
        #expect(answer.transactions.map(\.amount) == [80])
        #expect(answer.text.contains("Starbucks"))
    }

    @Test("Top categories are ordered by total")
    func topCategories() async throws {
        let engine = try await makeEngine([
            expense(10, daysAgo: 1, category: dining),
            expense(60, daysAgo: 1, category: groceries),
            expense(15, daysAgo: 2, category: dining),
        ])
        let answer = try await engine.answer(MoneyQuestion(measure: .topCategories, period: .thisMonth),
                                             currencyCode: "USD", now: now, calendar: calendar)
        let groceriesAt = try #require(answer.text.range(of: "Groceries"))
        let diningAt = try #require(answer.text.range(of: "Dining"))
        #expect(groceriesAt.lowerBound < diningAt.lowerBound)
    }

    @Test("Nothing in the period says so instead of a zero total")
    func emptyPeriod() async throws {
        let engine = try await makeEngine([expense(10, daysAgo: 400)])
        let answer = try await engine.answer(MoneyQuestion(measure: .spent, period: .lastMonth),
                                             currencyCode: "USD", now: now, calendar: calendar)
        #expect(answer.transactions.isEmpty)
        #expect(!answer.text.contains("0.00"))
    }

    // MARK: - Periods

    @Test("Last month is the whole previous calendar month")
    func lastMonthRange() {
        let range = MoneyQuestion.Period.lastMonth.dateRange(now: now, calendar: calendar)
        let start = calendar.dateComponents([.year, .month, .day], from: range.lowerBound)
        let end = calendar.dateComponents([.year, .month, .day], from: range.upperBound)
        #expect(start.year == 2026 && start.month == 9 && start.day == 1)
        #expect(end.month == 9 && end.day == 30)
    }

    // MARK: - Interpreters

    @Test("Keywords pick the measure, the period and the longest matching name")
    func keywordInterpreter() {
        let question = MoneyQuestionKeywordInterpreter.interpret(
            "How much did I spend on dining out last month?",
            categoryNames: ["Dining", "Dining Out", "Groceries"],
            payeeNames: ["Starbucks"]
        )
        #expect(question.measure == .spent)
        #expect(question.period == .lastMonth)
        #expect(question.categoryName == "Dining Out")
        #expect(question.payeeName == nil)
    }

    @Test("Keywords recognise income, biggest and top-category questions", arguments: [
        ("How much did I earn this year?", MoneyQuestion.Measure.earned, MoneyQuestion.Period.thisYear),
        ("What was my biggest purchase this week?", .biggestExpense, .thisWeek),
        ("What are my top categories?", .topCategories, .thisMonth),
        ("How many coffees today?", .transactionCount, .today),
    ])
    func keywordMeasures(text: String, measure: MoneyQuestion.Measure, period: MoneyQuestion.Period) {
        let question = MoneyQuestionKeywordInterpreter.interpret(text, categoryNames: [], payeeNames: [])
        #expect(question.measure == measure)
        #expect(question.period == period)
    }

    @Test("A name from the model is kept only if it is one of the user's own")
    func modelNamesAreValidated() {
        #expect(MoneyQuestionModelInterpreter.matched(" dining ", in: ["Dining", "Groceries"]) == "Dining")
        #expect(MoneyQuestionModelInterpreter.matched("Restaurants", in: ["Dining"]) == nil)
        #expect(MoneyQuestionModelInterpreter.matched("", in: ["Dining"]) == nil)
    }
}
