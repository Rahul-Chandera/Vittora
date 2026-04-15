import Foundation
@testable import Vittora

actor MockSavingsGoalRepository: SavingsGoalRepository {
    private(set) var goals: [SavingsGoalEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [SavingsGoalEntity] {
        if shouldThrowError { throw throwError }
        return goals
    }

    func fetchByID(_ id: UUID) async throws -> SavingsGoalEntity? {
        if shouldThrowError { throw throwError }
        return goals.first { $0.id == id }
    }

    func fetchActive() async throws -> [SavingsGoalEntity] {
        if shouldThrowError { throw throwError }
        return goals.filter { $0.status == .active }
    }

    func create(_ goal: SavingsGoalEntity) async throws {
        if shouldThrowError { throw throwError }
        goals.append(goal)
    }

    func update(_ goal: SavingsGoalEntity) async throws {
        if shouldThrowError { throw throwError }
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        } else {
            throw VittoraError.notFound(String(localized: "Savings goal not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        if let index = goals.firstIndex(where: { $0.id == id }) {
            goals.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Savings goal not found"))
        }
    }

    // MARK: - Test Helpers

    func seed(_ goal: SavingsGoalEntity) {
        goals.append(goal)
    }

    func configureShouldThrow(_ value: Bool) {
        shouldThrowError = value
    }
}
