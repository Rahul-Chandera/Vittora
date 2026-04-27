import Foundation
import Testing
@testable import Vittora

@Suite("Reports Use Case Tests")
struct ReportsUseCaseTests {
    @Test("spending trends aggregate long ranges monthly")
    func spendingTrendsAggregateLongRangesMonthly() async throws {
        let repository = MockTransactionRepository()
        let calendar = Calendar(identifier: .gregorian)
        let start = makeDate(year: 2025, month: 1, day: 1)
        let end = calendar.date(byAdding: .day, value: 399, to: start) ?? start

        for dayOffset in 0..<400 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
            try await repository.create(TransactionEntity(amount: 1, date: date, type: .expense))
        }

        let useCase = SpendingTrendsUseCase(transactionRepository: repository)
        let points = try await useCase.execute(dateRange: start...end, grouping: .daily)
        let totalAmount = await MainActor.run {
            points.reduce(Decimal(0)) { $0 + $1.amount }
        }
        let firstDate = await MainActor.run {
            points.first?.date
        }

        #expect(points.count <= 14)
        #expect(totalAmount == 400)
        #expect(firstDate == calendar.date(from: DateComponents(year: 2025, month: 1)))
    }

    @Test("category breakdown returns top buckets only")
    func categoryBreakdownReturnsTopBucketsOnly() async throws {
        let transactionRepository = MockTransactionRepository()
        let categoryRepository = MockCategoryRepository()
        let date = makeDate(year: 2026, month: 1, day: 15)

        for index in 1...30 {
            let category = CategoryEntity(
                name: "Category \(index)",
                icon: "tag.fill",
                type: .expense,
                sortOrder: index
            )
            await categoryRepository.seed(category)
            try await transactionRepository.create(
                TransactionEntity(
                    amount: Decimal(index),
                    date: date,
                    type: .expense,
                    categoryID: category.id
                )
            )
        }

        let useCase = CategoryBreakdownUseCase(
            transactionRepository: transactionRepository,
            categoryRepository: categoryRepository
        )
        let breakdowns = try await useCase.execute(dateRange: date...date)
        let firstAmount = await MainActor.run {
            breakdowns.first?.amount
        }
        let lastAmount = await MainActor.run {
            breakdowns.last?.amount
        }

        #expect(breakdowns.count == 25)
        #expect(firstAmount == 30)
        #expect(lastAmount == 6)
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
