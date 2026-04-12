import Foundation

@Observable
@MainActor
final class PayeeFormViewModel {
    var name: String = ""
    var selectedType: PayeeType = .business
    var phone: String = ""
    var email: String = ""
    var notes: String = ""
    var isEditing = false
    var editingID: UUID?
    var validationErrors: [String] = []

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let createUseCase: CreatePayeeUseCase
    private let updateUseCase: UpdatePayeeUseCase

    init(createUseCase: CreatePayeeUseCase, updateUseCase: UpdatePayeeUseCase) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
    }

    func loadPayee(_ entity: PayeeEntity) {
        isEditing = true
        editingID = entity.id
        name = entity.name
        selectedType = entity.type
        phone = entity.phone ?? ""
        email = entity.email ?? ""
        notes = entity.notes ?? ""
    }

    func save() async throws {
        validationErrors = []
        if isEditing, let id = editingID {
            let entity = PayeeEntity(
                id: id,
                name: name,
                type: selectedType,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                notes: notes.isEmpty ? nil : notes
            )
            try await updateUseCase.execute(entity)
        } else {
            try await createUseCase.execute(
                name: name,
                type: selectedType,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                notes: notes.isEmpty ? nil : notes
            )
        }
    }
}
