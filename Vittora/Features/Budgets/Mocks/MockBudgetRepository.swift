import Foundation

struct MockBudgetRepository: BudgetRepository {
    func fetchAll() async throws -> [BudgetEntity] {
        return [
            BudgetEntity(
                id: UUID(uuidString: "1234-5678-1234-5678")!,
                amount: 1000,
                spent: 650,
                period: .monthly,
                startDate: Date()
            ),
            BudgetEntity(
                id: UUID(uuidString: "2345-6789-2345-6789")!,
                amount: 500,
                spent: 480,
                period: .weekly,
                startDate: Date()
            ),
        ]
    }

    func fetchByID(_ id: UUID) async throws -> BudgetEntity? {
        return BudgetEntity(
            id: id,
            amount: 1000,
            spent: 650,
            period: .monthly,
            startDate: Date()
        )
    }

    func create(_ entity: BudgetEntity) async throws {}

    func update(_ entity: BudgetEntity) async throws {}

    func delete(_ id: UUID) async throws {}

    func fetchActive() async throws -> [BudgetEntity] {
        return try await fetchAll()
    }

    func fetchForCategory(_ categoryID: UUID, period: BudgetPeriod) async throws -> BudgetEntity? {
        return nil
    }
}
