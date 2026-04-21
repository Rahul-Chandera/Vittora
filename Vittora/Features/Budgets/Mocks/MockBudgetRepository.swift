import Foundation

struct MockBudgetRepository: BudgetRepository {
    private static let monthlyBudgetID = UUID(uuidString: "12345678-1234-5678-1234-567812345678") ?? UUID()
    private static let weeklyBudgetID = UUID(uuidString: "23456789-2345-6789-2345-678923456789") ?? UUID()

    func fetchAll() async throws -> [BudgetEntity] {
        return [
            BudgetEntity(
                id: Self.monthlyBudgetID,
                amount: 1000,
                spent: 650,
                period: .monthly,
                startDate: Date()
            ),
            BudgetEntity(
                id: Self.weeklyBudgetID,
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
