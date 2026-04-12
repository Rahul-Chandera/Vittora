import Foundation

@Observable
@MainActor
final class CategoryFormViewModel {
    var name: String = ""
    var selectedIcon: String = "tag.fill"
    var selectedColorHex: String = "#007AFF"
    var selectedType: CategoryType = .expense
    var selectedParentID: UUID?
    var isEditing = false
    var editingID: UUID?
    var validationErrors: [String] = []

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedIcon.isEmpty
    }

    private let createUseCase: CreateCategoryUseCase
    private let updateUseCase: UpdateCategoryUseCase

    init(createUseCase: CreateCategoryUseCase, updateUseCase: UpdateCategoryUseCase) {
        self.createUseCase = createUseCase
        self.updateUseCase = updateUseCase
    }

    func loadCategory(_ entity: CategoryEntity) {
        isEditing = true
        editingID = entity.id
        name = entity.name
        selectedIcon = entity.icon
        selectedColorHex = entity.colorHex
        selectedType = entity.type
        selectedParentID = entity.parentID
    }

    func save() async throws {
        validationErrors = []
        if isEditing, let id = editingID {
            let entity = CategoryEntity(
                id: id,
                name: name,
                icon: selectedIcon,
                colorHex: selectedColorHex,
                type: selectedType,
                isDefault: false,
                sortOrder: 0,
                parentID: selectedParentID
            )
            try await updateUseCase.execute(entity)
        } else {
            try await createUseCase.execute(
                name: name,
                icon: selectedIcon,
                colorHex: selectedColorHex,
                type: selectedType,
                parentID: selectedParentID
            )
        }
    }
}
