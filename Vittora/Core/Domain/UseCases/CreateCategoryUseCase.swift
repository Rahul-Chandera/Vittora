import Foundation

struct CreateCategoryUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func execute(
        name: String,
        icon: String,
        colorHex: String,
        type: CategoryType,
        parentID: UUID? = nil
    ) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw VittoraError.validationFailed("Category name cannot be empty")
        }
        guard !icon.isEmpty else {
            throw VittoraError.validationFailed("Category icon cannot be empty")
        }

        let existing = try await repository.fetchByType(type)
        let isDuplicate = existing.contains { $0.name.lowercased() == trimmed.lowercased() }
        guard !isDuplicate else {
            throw VittoraError.duplicateEntry("A category named '\(trimmed)' already exists")
        }

        if let parentID {
            let parent = try await repository.fetchByID(parentID)
            guard parent != nil else {
                throw VittoraError.notFound("Parent category not found")
            }
            guard parent?.type == type else {
                throw VittoraError.validationFailed("Sub-category must have same type as parent")
            }
        }

        let sortOrder = existing.count
        let entity = CategoryEntity(
            id: UUID(),
            name: trimmed,
            icon: icon,
            colorHex: colorHex,
            type: type,
            isDefault: false,
            sortOrder: sortOrder,
            parentID: parentID
        )
        try await repository.create(entity)
    }
}
