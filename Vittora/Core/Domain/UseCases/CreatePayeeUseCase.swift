import Foundation

struct CreatePayeeUseCase: Sendable {
    private let repository: any PayeeRepository

    init(repository: any PayeeRepository) {
        self.repository = repository
    }

    func execute(
        name: String,
        type: PayeeType,
        phone: String? = nil,
        email: String? = nil,
        notes: String? = nil
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw VittoraError.validationFailed("Payee name cannot be empty")
        }

        let existing = try await repository.fetchAll()
        let isDuplicate = existing.contains { $0.name.lowercased() == trimmed.lowercased() }
        guard !isDuplicate else {
            throw VittoraError.duplicateEntry("A payee named '\(trimmed)' already exists")
        }

        let entity = PayeeEntity(
            id: UUID(),
            name: trimmed,
            type: type,
            phone: phone?.isEmpty == true ? nil : phone,
            email: email?.isEmpty == true ? nil : email,
            notes: notes?.isEmpty == true ? nil : notes
        )
        try await repository.create(entity)
    }
}
