import Foundation

struct GenerateRecurringTransactionsUseCase: Sendable {
    let ruleRepository: any RecurringRuleRepository
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    /// Required atomic write surface — the generated transaction and its balance
    /// effect must land in a single save (DATAINTEGRITY-2). No repository
    /// fallback: a non-atomic create+update reintroduces the corruption path.
    let ledgerWriting: any LedgerWriting
    /// Calendar used for occurrence math. Fixed to gregorian by default so
    /// month-end anchoring and catch-up are deterministic regardless of locale.
    let calendar: Calendar
    /// Injectable clock so catch-up generation is testable.
    let nowProvider: @Sendable () -> Date

    init(
        ruleRepository: any RecurringRuleRepository,
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        ledgerWriting: any LedgerWriting,
        calendar: Calendar = Calendar(identifier: .gregorian),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.ruleRepository = ruleRepository
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.ledgerWriting = ledgerWriting
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    /// Generate transactions for all due recurring rules, catching up every
    /// occurrence missed since each rule's `nextDate`.
    ///
    /// Idempotency: each occurrence is keyed by `(recurringRuleID, calendar day)`.
    /// Before creating, we skip any occurrence whose day already has a
    /// transaction for the rule, so re-running (or an interrupted run) never
    /// duplicates. The create+balance write is atomic via `performAdd`; the
    /// rule's `nextDate` is advanced in a separate save, and because a stale
    /// pointer is self-healed by the idempotency skip on the next run, a failure
    /// between the two never double-charges.
    ///
    /// Concurrency: callers MUST funnel through `RecurringGenerationCoordinator`
    /// so an app-launch run and a background-task run can't interleave their
    /// check-then-create windows (DATAINTEGRITY-4).
    ///
    /// Returns the count of generated transactions.
    func execute() async throws -> Int {
        let now = nowProvider()
        let dueRules = try await ruleRepository.fetchDueRules(before: now)
        var generatedCount = 0

        for rule in dueRules {
            guard rule.isActive else { continue }
            guard let accountID = rule.templateAccountID else { continue }
            guard let account = try await accountRepository.fetchByID(accountID) else { continue }

            // Existing occurrences for this rule, keyed by calendar day.
            let existing = try await transactionRepository.fetchForRecurringRule(rule.id)
            var occurrenceDays = Set(existing.map { calendar.startOfDay(for: $0.date) })

            var occurrence = rule.nextDate
            var advanced = false

            while occurrence <= now, withinEndDate(occurrence, endDate: rule.endDate) {
                let dayKey = calendar.startOfDay(for: occurrence)
                if !occurrenceDays.contains(dayKey) {
                    let transaction = TransactionEntity(
                        amount: rule.templateAmount,
                        date: occurrence,
                        note: rule.templateNote,
                        type: .expense,
                        paymentMethod: .other,
                        currencyCode: account.currencyCode,
                        tags: [],
                        categoryID: rule.templateCategoryID,
                        accountID: accountID,
                        payeeID: rule.templatePayeeID,
                        recurringRuleID: rule.id
                    )

                    // Atomic insert + balance adjustment in one save.
                    try await ledgerWriting.performAdd(transaction)
                    occurrenceDays.insert(dayKey)
                    generatedCount += 1
                }

                let next = nextOccurrence(after: occurrence, frequency: rule.frequency)
                // Safety: a non-advancing frequency (e.g. custom(days: 0)) would
                // otherwise loop forever.
                guard next > occurrence else { break }
                occurrence = next
                advanced = true
            }

            if advanced {
                var updatedRule = rule
                updatedRule.nextDate = occurrence
                updatedRule.updatedAt = .now
                try await ruleRepository.update(updatedRule)
            }
        }

        return generatedCount
    }

    private func withinEndDate(_ occurrence: Date, endDate: Date?) -> Bool {
        guard let endDate else { return true }
        return occurrence <= endDate
    }

    /// Calculate the next occurrence date based on frequency.
    private func nextOccurrence(after date: Date, frequency: RecurrenceFrequency) -> Date {
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date.addingTimeInterval(604800)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date.addingTimeInterval(1209600)
        case .monthly:
            return addMonths(1, to: date)
        case .quarterly:
            return addMonths(3, to: date)
        case .yearly:
            return addMonths(12, to: date)
        case .custom(let days):
            return calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days * 86400))
        }
    }

    /// Advance by whole months while anchoring to the original day-of-month.
    ///
    /// A naive `byAdding: .month` clamps Jan-31 → Feb-28 and then permanently
    /// drifts to the 28th. We instead preserve an end-of-month anchor: a date
    /// that is the last day of its month maps to the last day of the target
    /// month (Jan-31 → Feb-28 → Mar-31), and other days clamp only when the
    /// target month is shorter.
    private func addMonths(_ months: Int, to date: Date) -> Date {
        let fallback = calendar.date(byAdding: .month, value: months, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard let day = components.day,
              let monthRange = calendar.range(of: .day, in: .month, for: date) else {
            return fallback
        }
        let isLastDayOfMonth = day == monthRange.count

        var firstOfMonth = DateComponents()
        firstOfMonth.year = components.year
        firstOfMonth.month = components.month
        firstOfMonth.day = 1
        firstOfMonth.hour = components.hour
        firstOfMonth.minute = components.minute
        firstOfMonth.second = components.second

        guard let baseDate = calendar.date(from: firstOfMonth),
              let targetMonthDate = calendar.date(byAdding: .month, value: months, to: baseDate),
              let targetRange = calendar.range(of: .day, in: .month, for: targetMonthDate) else {
            return fallback
        }

        let targetDay = isLastDayOfMonth ? targetRange.count : min(day, targetRange.count)
        var result = calendar.dateComponents([.year, .month, .hour, .minute, .second], from: targetMonthDate)
        result.day = targetDay
        return calendar.date(from: result) ?? fallback
    }
}
