import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// Predictive entry (M3.2.7) on the transaction form: offered only on a new,
/// still-empty expense, and applying it never overwrites what the user chose.
@Suite("TransactionFormViewModel entry suggestion")
@MainActor
struct TransactionFormEntrySuggestionTests {

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private let coffee = UUID()
    private let dining = UUID()

    /// Monday 2026-10-05 at 08:00 UTC, `weeksBack` weeks before `now`'s Monday.
    private func monday8am(weeksBack: Int) -> Date {
        let base = Self.utc.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 8)) ?? .distantPast
        return Self.utc.date(byAdding: .day, value: -7 * weeksBack, to: base) ?? .distantPast
    }

    /// Four Monday-morning coffees at the same price, the last one a week before `now`.
    private func makeViewModel() async throws -> TransactionFormViewModel {
        let txRepo = MockTransactionRepository()
        for week in 1...4 {
            try await txRepo.create(TransactionEntity(
                amount: Decimal(string: "4.50") ?? 0, date: monday8am(weeksBack: week),
                categoryID: dining, payeeID: coffee
            ))
        }
        let accountRepo = MockAccountRepository()
        let categoryRepo = MockCategoryRepository()
        let ledger = MockLedgerWriting(transactionRepository: txRepo, accountRepository: accountRepo)
        return TransactionFormViewModel(
            addUseCase: AddTransactionUseCase(
                accountRepository: accountRepo, categoryRepository: categoryRepo, ledgerWriting: ledger
            ),
            updateUseCase: UpdateTransactionUseCase(transactionRepository: txRepo, ledgerWriting: ledger),
            smartCategorizeUseCase: SmartCategorizeUseCase(
                transactionRepository: txRepo,
                ruleStore: InMemoryCategorizationRuleStore(),
                categoryRepository: categoryRepo
            ),
            duplicateDetectionUseCase: DuplicateDetectionUseCase(transactionRepository: txRepo),
            transactionRepository: txRepo
        )
    }

    @Test("a new empty expense is offered the habit for this weekday and hour")
    func offersHabit() async throws {
        let vm = try await makeViewModel()
        await vm.loadEntrySuggestion(now: monday8am(weeksBack: 0), calendar: Self.utc)

        let suggestion = try #require(vm.entrySuggestion)
        #expect(suggestion.payeeID == coffee)
        #expect(suggestion.categoryID == dining)
        #expect(suggestion.amount == Decimal(string: "4.50"))
    }

    @Test("nothing is offered once the user has started filling the form")
    func respectsInput() async throws {
        let vm = try await makeViewModel()
        vm.amountString = "12"
        await vm.loadEntrySuggestion(now: monday8am(weeksBack: 0), calendar: Self.utc)
        #expect(vm.entrySuggestion == nil)
    }

    @Test("nothing is offered when editing an existing transaction")
    func notWhenEditing() async throws {
        let vm = try await makeViewModel()
        vm.isEditing = true
        await vm.loadEntrySuggestion(now: monday8am(weeksBack: 0), calendar: Self.utc)
        #expect(vm.entrySuggestion == nil)
    }

    @Test("applying fills only empty fields and withdraws the offer")
    func applyKeepsUserChoices() async throws {
        let vm = try await makeViewModel()
        await vm.loadEntrySuggestion(now: monday8am(weeksBack: 0), calendar: Self.utc)
        let chosenCategory = UUID()
        vm.selectedCategoryID = chosenCategory

        vm.applyEntrySuggestion()

        #expect(vm.selectedPayeeID == coffee)
        #expect(vm.selectedCategoryID == chosenCategory)
        #expect(Decimal(localizedAmount: vm.amountString) == Decimal(string: "4.50"))
        #expect(vm.entrySuggestion == nil)
    }
}
