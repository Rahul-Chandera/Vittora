import Foundation
import Observation

@Observable
@MainActor
final class RecurringFormViewModel {
    var amount: String = ""
    var selectedFrequency: RecurrenceFrequency = .monthly
    var startDate: Date = .now
    var endDate: Date? = nil
    var hasEndDate: Bool = false
    var selectedCategoryID: UUID? = nil
    var selectedAccountID: UUID? = nil
    var selectedPayeeID: UUID? = nil
    var note: String = ""
    var isEditing = false
    var editingID: UUID?

    var canSave: Bool {
        !amount.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Decimal(string: amount) ?? 0) > 0 &&
        selectedAccountID != nil
    }

    private let createUseCase: CreateRecurringRuleUseCase
    private let updateUseCase: UpdateRecurringRuleUseCase
    private let repository: any RecurringRuleRepository

    init(
        createUseCase: CreateRecurringRuleUseCase,
        updateUseCase: UpdateRecurringRuleUseCase,
        repository: any RecurringRuleRepository
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
        self.repository = repository
    }

    func loadRule(_ entity: RecurringRuleEntity) {
        isEditing = true
        editingID = entity.id
        amount = "\(entity.templateAmount)"
        selectedFrequency = entity.frequency
        startDate = entity.nextDate
        endDate = entity.endDate
        hasEndDate = entity.endDate != nil
        selectedCategoryID = entity.templateCategoryID
        selectedAccountID = entity.templateAccountID
        selectedPayeeID = entity.templatePayeeID
        note = entity.templateNote ?? ""
    }

    func save() async throws {
        guard let amountDecimal = Decimal(string: amount) else {
            throw VittoraError.validationFailed("Invalid amount")
        }

        if isEditing, let id = editingID {
            guard var rule = try await repository.fetchByID(id) else {
                throw VittoraError.notFound("Recurring rule not found")
            }

            rule.templateAmount = amountDecimal
            rule.frequency = selectedFrequency
            rule.nextDate = startDate
            rule.endDate = hasEndDate ? endDate : nil
            rule.templateCategoryID = selectedCategoryID
            rule.templateAccountID = selectedAccountID
            rule.templatePayeeID = selectedPayeeID
            rule.templateNote = note.isEmpty ? nil : note
            rule.updatedAt = .now

            try await updateUseCase.execute(rule)
        } else {
            try await createUseCase.execute(
                amount: amountDecimal,
                frequency: selectedFrequency,
                startDate: startDate,
                categoryID: selectedCategoryID,
                accountID: selectedAccountID,
                payeeID: selectedPayeeID,
                note: note.isEmpty ? nil : note,
                endDate: hasEndDate ? endDate : nil
            )
        }
    }

    func reset() {
        amount = ""
        selectedFrequency = .monthly
        startDate = .now
        endDate = nil
        hasEndDate = false
        selectedCategoryID = nil
        selectedAccountID = nil
        selectedPayeeID = nil
        note = ""
        isEditing = false
        editingID = nil
    }
}
