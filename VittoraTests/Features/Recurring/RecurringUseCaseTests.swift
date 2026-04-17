import Foundation
import Testing

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

        let useCase = GenerateRecurringTransactionsUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
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
        let expectedNextDate = Calendar.current.date(byAdding: .month, value: 1, to: originalNextDate)
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

        let useCase = GenerateRecurringTransactionsUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
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

        let useCase = GenerateRecurringTransactionsUseCase(
            ruleRepository: ruleRepository,
            transactionRepository: transactionRepository,
            accountRepository: accountRepository
        )

        _ = try await useCase.execute()

        let updatedRule = try await ruleRepository.fetchByID(rule.id)
        let expectedNextDate = Calendar.current.date(byAdding: .day, value: 10, to: originalNextDate)
        #expect(updatedRule?.nextDate == expectedNextDate)
    }
}

private func makeRecurringDate(year: Int, month: Int, day: Int) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
}
