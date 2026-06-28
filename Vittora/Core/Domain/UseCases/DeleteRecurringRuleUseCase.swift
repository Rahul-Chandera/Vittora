import Foundation

struct DeleteRecurringRuleUseCase: Sendable {
    let repository: any RecurringRuleRepository
    /// REQUIRED: nullifying `recurringRuleID` on generated transactions and
    /// deleting the rule must persist atomically (A10, DATAINTEGRITY-6).
    let ledgerWriting: any LedgerWriting

    init(
        repository: any RecurringRuleRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.repository = repository
        self.ledgerWriting = ledgerWriting
    }

    func execute(id: UUID) async throws {
        guard try await repository.fetchByID(id) != nil else {
            throw VittoraError.notFound(String(localized: "Recurring rule not found"))
        }
        try await ledgerWriting.performDeleteRecurringRule(ruleID: id)
    }
}
