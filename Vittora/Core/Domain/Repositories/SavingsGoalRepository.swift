import Foundation

protocol SavingsGoalRepository: Sendable {
    func fetchAll() async throws -> [SavingsGoalEntity]
    func fetchByID(_ id: UUID) async throws -> SavingsGoalEntity?
    func fetchActive() async throws -> [SavingsGoalEntity]
    func create(_ goal: SavingsGoalEntity) async throws
    func update(_ goal: SavingsGoalEntity) async throws
    func delete(_ id: UUID) async throws
}
