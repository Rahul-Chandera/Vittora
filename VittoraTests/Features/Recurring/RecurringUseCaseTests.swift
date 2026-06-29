import Foundation
import Testing
import VittoraCore

@testable import Vittora

@MainActor
@Suite("Recurring Use Case Tests")
struct RecurringUseCaseTests {

    @Test("Generate recurring transactions creates a transaction, updates the account, and advances the rule")
    func generateRecurringTransactionsAdvancesRuleAndAccount() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 500)
        try await accountRepository.create(account)

        let originalNextDate = makeRecurringDate(year: 2026, month: 1, day: 15)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: originalNextDate,
            templateAmount: 75,
            templateNote: "Subscription",
            templateCategoryID: UUID(),
            templateAccountID: account.id,
            templatePayeeID: UUID()
        )
        await ruleRepository.seed(rule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: originalNextDate
        )

        let generatedCount = try await useCase.execute()

        #expect(generatedCount == 1)

        let transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(transactions[0].amount == 75)
        #expect(transactions[0].recurringRuleID == rule.id)
        #expect(transactions[0].accountID == account.id)

        let accounts = accountRepository.accounts
        #expect(accounts.first?.balance == 425)

        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        let expectedNextDate = makeRecurringDate(year: 2026, month: 2, day: 15)
        #expect(updatedRule?.nextDate == expectedNextDate)
    }

    @Test("Generate recurring transactions skips ended rules and rules without accounts")
    func generateRecurringTransactionsSkipsInvalidRules() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()

        let endedRule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: makeRecurringDate(year: 2026, month: 2, day: 1),
            endDate: makeRecurringDate(year: 2026, month: 1, day: 31),
            templateAmount: 40,
            templateAccountID: UUID()
        )
        let missingAccountRule = RecurringRuleEntity(
            frequency: .weekly,
            nextDate: makeRecurringDate(year: 2026, month: 2, day: 1),
            templateAmount: 20,
            templateAccountID: UUID()
        )
        await ruleRepository.seed(endedRule)
        await ruleRepository.seed(missingAccountRule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: makeRecurringDate(year: 2026, month: 3, day: 1)
        )

        let generatedCount = try await useCase.execute()

        #expect(generatedCount == 0)
        let transactions = await transactionRepository.transactions
        #expect(transactions.isEmpty)
    }

    @Test("Generate recurring transactions advances custom rules by their configured number of days")
    func generateRecurringTransactionsAdvancesCustomFrequency() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Wallet", type: .cash, balance: 120)
        try await accountRepository.create(account)

        let originalNextDate = makeRecurringDate(year: 2026, month: 3, day: 10)
        let rule = RecurringRuleEntity(
            frequency: .custom(days: 10),
            nextDate: originalNextDate,
            templateAmount: 15,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: originalNextDate
        )

        _ = try await useCase.execute()

        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        let expectedNextDate = makeRecurringDate(year: 2026, month: 3, day: 20)
        #expect(updatedRule?.nextDate == expectedNextDate)
    }

    @Test("Generate recurring transactions is idempotent when scheduled transaction already exists")
    func generateRecurringTransactionsSkipsDuplicateSchedule() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 1_000)
        try await accountRepository.create(account)

        let originalNextDate = makeRecurringDate(year: 2026, month: 2, day: 1)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: originalNextDate,
            templateAmount: 120,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        try await transactionRepository.create(
            TransactionEntity(
                amount: 120,
                date: originalNextDate,
                type: .expense,
                paymentMethod: .other,
                currencyCode: account.currencyCode,
                accountID: account.id,
                recurringRuleID: rule.id
            )
        )

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: originalNextDate
        )

        let generatedCount = try await useCase.execute()

        #expect(generatedCount == 0)
        let transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(accountRepository.accounts.first?.balance == 1_000)
        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        let expectedNextDate = makeRecurringDate(year: 2026, month: 3, day: 1)
        #expect(updatedRule?.nextDate == expectedNextDate)
    }

    @Test("Idempotency keys on calendar day, not the exact timestamp")
    func generateRecurringTransactionsMatchesExistingByCalendarDay() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 1_000)
        try await accountRepository.create(account)

        let occurrenceDay = makeRecurringDate(year: 2026, month: 2, day: 1)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: occurrenceDay,
            templateAmount: 120,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        // Existing transaction on the same calendar day but a different time.
        let laterSameDay = occurrenceDay.addingTimeInterval(13 * 3600)
        try await transactionRepository.create(
            TransactionEntity(
                amount: 120,
                date: laterSameDay,
                type: .expense,
                paymentMethod: .other,
                currencyCode: account.currencyCode,
                accountID: account.id,
                recurringRuleID: rule.id
            )
        )

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: occurrenceDay
        )

        let generatedCount = try await useCase.execute()

        #expect(generatedCount == 0)
        let transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(accountRepository.accounts.first?.balance == 1_000)
    }

    @Test("A stale rule catches up every missed occurrence in one run")
    func generateRecurringTransactionsCatchesUpStaleRule() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 1_000)
        try await accountRepository.create(account)

        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: makeRecurringDate(year: 2026, month: 1, day: 15),
            templateAmount: 100,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: makeRecurringDate(year: 2026, month: 4, day: 20)
        )

        let generatedCount = try await useCase.execute()

        // Jan 15, Feb 15, Mar 15, Apr 15 — all on or before Apr 20.
        #expect(generatedCount == 4)
        let transactions = await transactionRepository.transactions
        #expect(transactions.count == 4)
        #expect(accountRepository.accounts.first?.balance == 600)

        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        #expect(updatedRule?.nextDate == makeRecurringDate(year: 2026, month: 5, day: 15))
    }

    @Test("Month-end rules stay anchored to month-end across catch-up (no Jan-31 drift)")
    func generateRecurringTransactionsKeepsMonthEndAnchor() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 10_000)
        try await accountRepository.create(account)

        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: makeRecurringDate(year: 2026, month: 1, day: 31),
            templateAmount: 50,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: makeRecurringDate(year: 2026, month: 4, day: 15)
        )

        let generatedCount = try await useCase.execute()

        // Jan 31, Feb 28, Mar 31 — crucially Mar is the 31st, not the 28th.
        #expect(generatedCount == 3)
        let calendar = Calendar(identifier: .gregorian)
        let transactions = await transactionRepository.transactions
        let days = Set(transactions.map { calendar.startOfDay(for: $0.date) })
        #expect(days == Set([
            makeRecurringDate(year: 2026, month: 1, day: 31),
            makeRecurringDate(year: 2026, month: 2, day: 28),
            makeRecurringDate(year: 2026, month: 3, day: 31)
        ]))

        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        #expect(updatedRule?.nextDate == makeRecurringDate(year: 2026, month: 4, day: 30))
    }

    @Test("A rule-pointer update failure is self-healed on the next run without double-charging")
    func generateRecurringTransactionsSelfHealsRuleUpdateFailure() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 500)
        try await accountRepository.create(account)

        let occurrenceDay = makeRecurringDate(year: 2026, month: 3, day: 1)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: occurrenceDay,
            templateAmount: 50,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)
        await ruleRepository.configureUpdateFailure(true)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: occurrenceDay
        )

        // First run: the transaction+balance commit atomically, but advancing
        // the rule pointer fails — so it surfaces an error and leaves the rule
        // at its original nextDate. The committed transaction is NOT rolled back.
        await #expect(throws: (any Error).self) {
            try await useCase.execute()
        }
        var transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(accountRepository.accounts.first?.balance == 450)

        // Second run (pointer update now works): idempotency skips the existing
        // occurrence, so no duplicate transaction and the balance is untouched,
        // while the rule pointer finally advances.
        await ruleRepository.configureUpdateFailure(false)
        let generatedCount = try await useCase.execute()
        #expect(generatedCount == 0)
        transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(accountRepository.accounts.first?.balance == 450)
        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        #expect(updatedRule?.nextDate == makeRecurringDate(year: 2026, month: 4, day: 1))
    }

    @Test("Concurrent launch + background runs never duplicate an occurrence")
    func recurringCoordinatorCoalescesConcurrentRuns() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        let account = AccountEntity(name: "Main Account", type: .bank, balance: 1_000)
        try await accountRepository.create(account)

        let occurrenceDay = makeRecurringDate(year: 2026, month: 2, day: 1)
        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: occurrenceDay,
            templateAmount: 120,
            templateAccountID: account.id
        )
        await ruleRepository.seed(rule)

        let useCase = makeUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository,
            now: occurrenceDay
        )
        let coordinator = RecurringGenerationCoordinator(useCase: useCase)

        async let first = coordinator.generate()
        async let second = coordinator.generate()
        _ = try await (first, second)

        // Exactly one occurrence regardless of how the two runs interleave.
        let transactions = await transactionRepository.transactions
        #expect(transactions.count == 1)
        #expect(accountRepository.accounts.first?.balance == 880)
        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        #expect(updatedRule?.nextDate == makeRecurringDate(year: 2026, month: 3, day: 1))
    }

    @Test("Subscription cost uses actual days in a 30 day month")
    func subscriptionCostUsesThirtyDayMonth() {
        let useCase = CalculateSubscriptionCostUseCase(
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { makeRecurringDate(year: 2026, month: 4, day: 15) }
        )
        let rule = RecurringRuleEntity(
            frequency: .weekly,
            nextDate: makeRecurringDate(year: 2026, month: 4, day: 1),
            templateAmount: 70
        )

        let summary = useCase.execute(rules: [rule])

        #expect(summary.monthlyCost == 300)
        #expect(summary.annualCost == 3_600)
    }

    @Test("Subscription cost uses actual days in February")
    func subscriptionCostUsesFebruaryDays() {
        let useCase = CalculateSubscriptionCostUseCase(
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { makeRecurringDate(year: 2026, month: 2, day: 15) }
        )
        let rule = RecurringRuleEntity(
            frequency: .biweekly,
            nextDate: makeRecurringDate(year: 2026, month: 2, day: 1),
            templateAmount: 50
        )

        let summary = useCase.execute(rules: [rule])

        #expect(summary.monthlyCost == 100)
        #expect(summary.annualCost == 1_200)
    }

    @Test("Delete recurring rule nullifies recurringRuleID on generated transactions")
    func deleteRecurringRuleNullifiesLinkedTransactions() async throws {
        let ruleRepository = MockRecurringRuleRepository()
        let transactionRepository = MockTransactionRepository()
        let accountRepository = MockAccountRepository()

        let rule = RecurringRuleEntity(
            frequency: .monthly,
            nextDate: makeRecurringDate(year: 2026, month: 1, day: 1),
            templateAmount: 100
        )
        await ruleRepository.seed(rule)
        try await transactionRepository.create(
            TransactionEntity(amount: 100, type: .expense, recurringRuleID: rule.id)
        )

        let useCase = DeleteRecurringRuleUseCase(
            repository: ruleRepository,
            ledgerWriting: MockLedgerWriting(
                transactionRepository: transactionRepository,
                accountRepository: accountRepository,
                recurringRuleRepository: ruleRepository
            )
        )
        try await useCase.execute(id: rule.id)

        let txs = await transactionRepository.transactions
        #expect(txs.first?.recurringRuleID == nil)
        let rules = await ruleRepository.rules
        #expect(rules.isEmpty)
    }
}

@MainActor
private func makeUseCase(
    ruleRepository: MockRecurringRuleRepository,
    transactionRepository: MockTransactionRepository,
    accountRepository: MockAccountRepository,
    now: Date
) -> GenerateRecurringTransactionsUseCase {
    GenerateRecurringTransactionsUseCase(
        ruleRepository: ruleRepository,
        transactionRepository: transactionRepository,
        accountRepository: accountRepository,
        ledgerWriting: MockLedgerWriting(
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
        ),
        calendar: Calendar(identifier: .gregorian),
        nowProvider: { now }
    )
}

private func makeRecurringDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
        Issue.record("makeRecurringDate failed for \(year)-\(month)-\(day)")
        return Date(timeIntervalSince1970: 0)
    }
    return date
}
