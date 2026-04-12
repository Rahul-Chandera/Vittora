import Foundation

struct CreateRecurringRuleUseCase: Sendable {
    let repository: any RecurringRuleRepository

    init(repository: any RecurringRuleRepository) {
        self.repository = repository
    }

    func execute(
        amount: Decimal,
        frequency: RecurrenceFrequency,
        startDate: Date,
        categoryID: UUID?,
        accountID: UUID?,
        payeeID: UUID?,
        note: String?,
        endDate: Date?
    ) async throws {
        // Validate amount is positive
        guard amount > 0 else {
            throw VittoraError.validationFailed("Amount must be greater than zero")
        }

        // Create recurring rule entity
        let rule = RecurringRuleEntity(
            frequency: frequency,
            nextDate: startDate,
            isActive: true,
            endDate: endDate,
            templateAmount: amount,
            templateNote: note,
            templateCategoryID: categoryID,
            templateAccountID: accountID,
            templatePayeeID: payeeID
        )

        try await repository.create(rule)
    }
}
