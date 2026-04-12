import Foundation

struct MockCategoryRepository: CategoryRepository {
    func fetchAll() async throws -> [CategoryEntity] {
        return [
            CategoryEntity(
                id: UUID(),
                name: "Groceries",
                icon: "cart.fill",
                colorHex: "#34C759",
                type: .expense
            ),
            CategoryEntity(
                id: UUID(),
                name: "Dining",
                icon: "fork.knife",
                colorHex: "#FF6B35",
                type: .expense
            ),
            CategoryEntity(
                id: UUID(),
                name: "Transportation",
                icon: "car.fill",
                colorHex: "#007AFF",
                type: .expense
            ),
            CategoryEntity(
                id: UUID(),
                name: "Salary",
                icon: "dollarsign.circle.fill",
                colorHex: "#34C759",
                type: .income
            ),
        ]
    }

    func fetchByID(_ id: UUID) async throws -> CategoryEntity? {
        return CategoryEntity(
            id: id,
            name: "Groceries",
            icon: "cart.fill",
            colorHex: "#34C759",
            type: .expense
        )
    }

    func create(_ entity: CategoryEntity) async throws {}

    func update(_ entity: CategoryEntity) async throws {}

    func delete(_ id: UUID) async throws {}

    func fetchDefaults() async throws -> [CategoryEntity] {
        return try await fetchAll()
    }

    func fetchByType(_ type: CategoryType) async throws -> [CategoryEntity] {
        return try await fetchAll().filter { $0.type == type }
    }
}
