import Foundation

struct DeleteCategoryUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func execute(id: UUID) async throws {
        guard (try await repository.fetchByID(id)) != nil else {
            throw VittoraError.notFound("Category not found")
        }
        try await repository.delete(id)
    }
}
