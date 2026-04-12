import Foundation

@Observable
@MainActor
final class BudgetFormViewModel {
    var amount: String = ""
    var selectedPeriod: BudgetPeriod = .monthly
    var selectedCategoryID: UUID? = nil
    var rollover: Bool = false
    var startDate: Date = .now
    var isEditing = false
    var editingID: UUID?
    var error: String?

    private let createUseCase: CreateBudgetUseCase
    private let updateUseCase: UpdateBudgetUseCase

    init(
        createUseCase: CreateBudgetUseCase,
        updateUseCase: UpdateBudgetUseCase
    ) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
    }

    var canSave: Bool {
        guard let decimalAmount = Decimal(string: amount) else { return false }
        return decimalAmount > 0
    }

    func loadBudget(_ entity: BudgetEntity) {
        isEditing = true
        editingID = entity.id
        amount = entity.amount.description
        selectedPeriod = entity.period
        selectedCategoryID = entity.categoryID
        rollover = entity.rollover
        startDate = entity.startDate
    }

    func save() async throws {
        guard let decimalAmount = Decimal(string: amount), decimalAmount > 0 else {
            throw VittoraError.validationFailed("Please enter a valid amount")
        }

        if isEditing, let id = editingID {
            // Update existing budget
            var updatedBudget = BudgetEntity(
                id: id,
                amount: decimalAmount,
                period: selectedPeriod,
                startDate: startDate,
                rollover: rollover,
                categoryID: selectedCategoryID
            )
            try await updateUseCase.execute(updatedBudget)
        } else {
            // Create new budget
            try await createUseCase.execute(
                amount: decimalAmount,
                period: selectedPeriod,
                categoryID: selectedCategoryID,
                rollover: rollover,
                startDate: startDate
            )
        }
    }

    func reset() {
        amount = ""
        selectedPeriod = .monthly
        selectedCategoryID = nil
        rollover = false
        startDate = .now
        isEditing = false
        editingID = nil
        error = nil
    }
}
