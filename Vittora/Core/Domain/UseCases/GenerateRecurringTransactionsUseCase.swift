import Foundation

struct GenerateRecurringTransactionsUseCase: Sendable {
    let ruleRepository: any RecurringRuleRepository
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        ruleRepository: any RecurringRuleRepository,
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.ruleRepository = ruleRepository
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    /// Generate transactions for all due recurring rules
    /// Returns the count of generated transactions
    func execute() async throws -> Int {
        let dueRules = try await ruleRepository.fetchDueRules(before: .now)
        var generatedCount = 0

        for rule in dueRules {
            // Skip inactive rules or rules past their end date
            guard rule.isActive else { continue }
            if let endDate = rule.endDate, rule.nextDate > endDate {
                continue
            }

            // Create transaction from template
            guard let accountID = rule.templateAccountID else { continue }
            guard var account = try await accountRepository.fetchByID(accountID) else { continue }

            let transaction = TransactionEntity(
                amount: rule.templateAmount,
                date: rule.nextDate,
                note: rule.templateNote,
                type: .expense,
                paymentMethod: .other,
                currencyCode: "USD",
                tags: [],
                categoryID: rule.templateCategoryID,
                accountID: accountID,
                payeeID: rule.templatePayeeID,
                recurringRuleID: rule.id
            )

            try await transactionRepository.create(transaction)

            // Update account balance
            account.balance -= rule.templateAmount
            account.updatedAt = .now
            try await accountRepository.update(account)

            // Advance rule to next date
            var updatedRule = rule
            updatedRule.nextDate = advanceDate(from: rule.nextDate, frequency: rule.frequency)
            updatedRule.updatedAt = .now
            try await ruleRepository.update(updatedRule)

            generatedCount += 1
        }

        return generatedCount
    }

    /// Calculate next occurrence date based on frequency
    private func advanceDate(from date: Date, frequency: RecurrenceFrequency) -> Date {
        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date.addingTimeInterval(604800)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date.addingTimeInterval(1209600)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date.addingTimeInterval(2592000)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date.addingTimeInterval(7776000)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date.addingTimeInterval(31536000)
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days * 86400))
        }
    }
}
