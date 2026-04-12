import Foundation

protocol BudgetRepository: Sendable {
    func fetchAll() async throws -> [BudgetEntity]
    func fetchByID(_ id: UUID) async throws -> BudgetEntity?
    func create(_ entity: BudgetEntity) async throws
    func update(_ entity: BudgetEntity) async throws
    func delete(_ id: UUID) async throws
    func fetchActive() async throws -> [BudgetEntity]
    func fetchForCategory(_ categoryID: UUID, period: BudgetPeriod) async throws -> BudgetEntity?
}
