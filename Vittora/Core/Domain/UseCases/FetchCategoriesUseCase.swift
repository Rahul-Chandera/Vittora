import Foundation

struct FetchCategoriesUseCase: Sendable {
    private let repository: any CategoryRepository

    init(repository: any CategoryRepository) {
        self.repository = repository
    }

    func execute() async throws -> [CategoryEntity] {
        let all = try await repository.fetchAll()
        return all.sorted { $0.sortOrder < $1.sortOrder }
    }

    func executeByType(_ type: CategoryType) async throws -> [CategoryEntity] {
        return try await repository.fetchByType(type)
    }

    func executeGrouped() async throws -> (expense: [CategoryEntity], income: [CategoryEntity]) {
        let all = try await execute()
        let expense = all.filter { $0.type == .expense }
        let income = all.filter { $0.type == .income }
        return (expense, income)
    }
}
