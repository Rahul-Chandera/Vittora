import Foundation
import Observation

@Observable
@MainActor
final class DebtFormViewModel {
    var amountString: String = ""
    var direction: DebtDirection = .lent
    var selectedPayeeID: UUID?
    var hasDueDate: Bool = false
    var dueDate: Date = .now
    var note: String = ""
    var isLoading = false
    var error: String?

    var amount: Decimal? { Decimal(string: amountString) }
    var canSave: Bool {
        selectedPayeeID != nil && (amount ?? 0) > 0
    }

    private let createUseCase: CreateDebtEntryUseCase

    init(createUseCase: CreateDebtEntryUseCase) {
        self.createUseCase = createUseCase
    }

    func save() async throws {
        guard let payeeID = selectedPayeeID,
              let amount = amount else {
            throw VittoraError.validationFailed(String(localized: "Please fill all required fields"))
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        try await createUseCase.execute(
            payeeID: payeeID,
            amount: amount,
            direction: direction,
            dueDate: hasDueDate ? dueDate : nil,
            note: note.isEmpty ? nil : note
        )
    }
}
