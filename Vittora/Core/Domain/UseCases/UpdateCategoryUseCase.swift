import Foundation

struct UpdateCategoryUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func execute(_ entity: CategoryEntity) async throws {
        let trimmed = entity.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw VittoraError.validationFailed("Category name cannot be empty")
        }

        let existing = try await repository.fetchByType(entity.type)
        let isDuplicate = existing.contains {
            $0.id != entity.id && $0.name.lowercased() == trimmed.lowercased()
        }
        guard !isDuplicate else {
            throw VittoraError.duplicateEntry("A category named '\(trimmed)' already exists")
        }

        var updated = entity
        updated.name = trimmed
        try await repository.update(updated)
    }
}
