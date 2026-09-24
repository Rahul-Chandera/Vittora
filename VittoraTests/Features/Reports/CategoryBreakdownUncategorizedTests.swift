import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Category Breakdown must account for every expense it is given.
///
/// It used to skip transactions with no `categoryID`, so spending simply
/// vanished from the report: the seeded $200 "Settlement: Moving costs" was
/// absent, and the percentages were of CATEGORISED spending while the
/// Dashboard's "Spent" covered everything. Rent read 67.3% here and 62.7% on
/// the Custom Report for the same $1,850, with nothing on screen to explain
/// the gap.
///
/// The deleted-category case was worse than absent: the amount still counted
/// toward the total but had no row, so the listed percentages did not even sum
/// to 100%.
@Suite("Category breakdown accounts for uncategorised spending")
struct CategoryBreakdownUncategorizedTests {

    private func makeDate() -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 15)) ?? .now
    }

    private func useCase(
        _ transactions: MockTransactionRepository,
        _ categories: MockCategoryRepository
    ) -> CategoryBreakdownUseCase {
        CategoryBreakdownUseCase(
            transactionRepository: transactions,
            categoryRepository: categories
        )
    }

    /// The regression, with the seeded figures.
    @Test("a transaction with no category appears as its own row")
    func uncategorisedGetsARow() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let date = makeDate()

        let rent = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        await categories.seed(rent)
        try await transactions.create(
            TransactionEntity(amount: 1_850, date: date, type: .expense, categoryID: rent.id)
        )
        try await transactions.create(
            TransactionEntity(amount: 200, date: date, type: .expense, categoryID: nil)
        )

        let breakdowns = try await useCase(transactions, categories)
            .execute(dateRange: date...date)

        let names = await MainActor.run { breakdowns.map(\.category.displayName) }
        let amounts = await MainActor.run { breakdowns.map(\.amount) }

        #expect(names.contains("Uncategorized"))
        #expect(amounts.reduce(0, +) == 2_050)
    }

    /// Percentages must be of everything spent, not of the categorised part.
    @Test("percentages use the full total, including uncategorised")
    func percentagesUseFullTotal() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let date = makeDate()

        let rent = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        await categories.seed(rent)
        try await transactions.create(
            TransactionEntity(amount: 750, date: date, type: .expense, categoryID: rent.id)
        )
        try await transactions.create(
            TransactionEntity(amount: 250, date: date, type: .expense, categoryID: nil)
        )

        let breakdowns = try await useCase(transactions, categories)
            .execute(dateRange: date...date)
        let rentPercent = await MainActor.run {
            breakdowns.first { $0.category.displayName == "Rent" }?.percentage ?? 0
        }

        // 750 of 1,000, not 750 of 750.
        #expect(abs(rentPercent - 75.0) < 0.01)
    }

    /// A category deleted after the fact must not make the report's own
    /// percentages fail to add up.
    @Test("spending on a deleted category folds into uncategorised")
    func deletedCategoryFoldsIn() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let date = makeDate()

        let kept = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        await categories.seed(kept)
        try await transactions.create(
            TransactionEntity(amount: 600, date: date, type: .expense, categoryID: kept.id)
        )
        // Points at a category the repository does not have.
        try await transactions.create(
            TransactionEntity(amount: 400, date: date, type: .expense, categoryID: UUID())
        )

        let breakdowns = try await useCase(transactions, categories)
            .execute(dateRange: date...date)
        let total = await MainActor.run { breakdowns.map(\.percentage).reduce(0, +) }
        let amounts = await MainActor.run { breakdowns.map(\.amount).reduce(0, +) }

        #expect(abs(total - 100.0) < 0.01)
        #expect(amounts == 1_000)
    }

    /// No phantom row when everything is categorised.
    @Test("a fully categorised ledger gets no uncategorised row")
    func noRowWhenNothingIsUncategorised() async throws {
        let transactions = MockTransactionRepository()
        let categories = MockCategoryRepository()
        let date = makeDate()

        let rent = CategoryEntity(name: "Rent", icon: "house", type: .expense)
        await categories.seed(rent)
        try await transactions.create(
            TransactionEntity(amount: 500, date: date, type: .expense, categoryID: rent.id)
        )

        let breakdowns = try await useCase(transactions, categories)
            .execute(dateRange: date...date)
        let names = await MainActor.run { breakdowns.map(\.category.displayName) }

        #expect(names == ["Rent"])
    }
}
