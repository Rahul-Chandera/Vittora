import Foundation

struct CreateDebtEntryUseCase: Sendable {
    let debtRepository: any DebtRepository

    func execute(
        payeeID: UUID,
        amount: Decimal,
        direction: DebtDirection,
        dueDate: Date? = nil,
        note: String? = nil
    ) async throws -> DebtEntry {
        guard amount > 0 else {
            throw VittoraError.validationFailed(String(localized: "Amount must be greater than zero"))
        }
        let entry = DebtEntry(
            payeeID: payeeID,
            amount: amount,
            direction: direction,
            dueDate: dueDate,
            note: note
        )
        try await debtRepository.create(entry)
        return entry
    }
}
