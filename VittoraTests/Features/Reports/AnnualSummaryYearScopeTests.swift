import Foundation
import Testing
import VittoraCore

@testable import Vittora

/// Annual Summary showed identical figures for every year in its picker.
///
/// It called `MonthlyOverviewUseCase.execute(monthCount:)`, which is anchored to
/// `Date.now` and always returns the trailing 12 months, so switching year
/// reloaded the same window. These tests pin the year-scoped path: a calendar
/// year must contain only its own transactions, and must be January-first.
@Suite("Annual Summary year scoping")
@MainActor
struct AnnualSummaryYearScopeTests {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    private func seededRepository() async throws -> MockTransactionRepository {
        let repo = MockTransactionRepository()
        // One income and one expense in each of two different years, with
        // deliberately different amounts so a leak between them is visible.
        try await repo.create(TransactionEntity(
            amount: Decimal(string: "1000")!, date: date(2024, 3, 15), type: .income))
        try await repo.create(TransactionEntity(
            amount: Decimal(string: "400")!, date: date(2024, 7, 2), type: .expense))
        try await repo.create(TransactionEntity(
            amount: Decimal(string: "5000")!, date: date(2025, 6, 10), type: .income))
        try await repo.create(TransactionEntity(
            amount: Decimal(string: "2200")!, date: date(2025, 11, 20), type: .expense))
        return repo
    }

    @Test("each year reports only its own transactions")
    func yearsDoNotLeakIntoEachOther() async throws {
        let useCase = MonthlyOverviewUseCase(transactionRepository: try await seededRepository())

        let y2024 = try await useCase.execute(year: 2024)
        #expect(y2024.reduce(Decimal(0)) { $0 + $1.income } == Decimal(string: "1000")!)
        #expect(y2024.reduce(Decimal(0)) { $0 + $1.expense } == Decimal(string: "400")!)

        let y2025 = try await useCase.execute(year: 2025)
        #expect(y2025.reduce(Decimal(0)) { $0 + $1.income } == Decimal(string: "5000")!)
        #expect(y2025.reduce(Decimal(0)) { $0 + $1.expense } == Decimal(string: "2200")!)

        // The actual reported symptom: two different years, identical totals.
        #expect(y2024.reduce(Decimal(0)) { $0 + $1.income }
                != y2025.reduce(Decimal(0)) { $0 + $1.income })
    }

    @Test("a year is twelve months starting in January")
    func yearIsJanuaryThroughDecember() async throws {
        let useCase = MonthlyOverviewUseCase(transactionRepository: try await seededRepository())
        let months = try await useCase.execute(year: 2025)
        let calendar = Calendar.current

        #expect(months.count == 12)
        #expect(calendar.component(.month, from: months[0].month) == 1)
        #expect(calendar.component(.month, from: months[11].month) == 12)
        #expect(months.allSatisfy { calendar.component(.year, from: $0.month) == 2025 })
    }

    @Test("an empty year reports zero rather than borrowing another year")
    func emptyYearIsZero() async throws {
        let useCase = MonthlyOverviewUseCase(transactionRepository: try await seededRepository())
        let months = try await useCase.execute(year: 2023)
        #expect(months.count == 12)
        #expect(months.allSatisfy { $0.income == 0 && $0.expense == 0 })
    }
}
