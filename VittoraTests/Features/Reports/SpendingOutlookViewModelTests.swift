import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// The view model's side of the 1.8.1 projection fix: it must hand the engine
/// what each earlier month cost after today's day of the month, so rent paid on
/// the 1st is counted once rather than multiplied across the month.
@Suite("SpendingOutlookViewModel")
@MainActor
struct SpendingOutlookViewModelTests {

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private func date(_ month: Int, _ day: Int) -> Date {
        Self.utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .distantPast
    }

    /// July–September: rent 1,850 on the 1st and 300 on the 20th. October so far:
    /// rent on the 1st and 150 on the 3rd; today is the 5th. The rest of each
    /// earlier month cost 300, so the estimate is 2,000 + 300 = 2,300. The 1.8.0
    /// straight line said 2,000 / 5 × 31 = 12,400.
    @Test("projects spent-so-far plus the typical rest of the month")
    func projectsFromThePattern() async throws {
        let transactions = MockTransactionRepository()
        for month in 7...9 {
            try await transactions.create(TransactionEntity(amount: 1_850, date: date(month, 1)))
            try await transactions.create(TransactionEntity(amount: 300, date: date(month, 20)))
        }
        try await transactions.create(TransactionEntity(amount: 1_850, date: date(10, 1)))
        try await transactions.create(TransactionEntity(amount: 150, date: date(10, 3)))
        let today = date(10, 5)

        let vm = SpendingOutlookViewModel(
            transactionRepository: transactions,
            categoryRepository: MockCategoryRepository(),
            calendar: Self.utc,
            nowProvider: { today }
        )
        await vm.load()

        let projection = try #require(vm.projection)
        #expect(projection.method == .pattern)
        #expect(projection.spentSoFar == 2_000)
        #expect(projection.elapsedDays == 5)
        #expect(projection.projectedTotal == 2_300)
        #expect(projection.typicalMonth == 2_150)
        #expect(projection.isAboveTypical)
    }
}
