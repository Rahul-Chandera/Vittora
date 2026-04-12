import Foundation

struct ReorderCategoriesUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    /// Update sort orders for a list of categories.
    /// - Parameter orderedIDs: Category IDs in desired order.
    func execute(orderedIDs: [UUID]) async throws {
        for (index, id) in orderedIDs.enumerated() {
            guard var entity = try await repository.fetchByID(id) else { continue }
            entity.sortOrder = index
            try await repository.update(entity)
        }
    }
}
