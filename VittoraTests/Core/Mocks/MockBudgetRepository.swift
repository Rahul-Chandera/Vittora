import Foundation
import VittoraCore
@testable import Vittora

actor MockBudgetRepository: BudgetRepository {
    private(set) var budgets: [BudgetEntity] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))
    var writeFailureControls = MockWriteFailureControls()

    private func checkWriteFailure(for entityID: UUID? = nil) throws {
        try writeFailureControls.checkWrite(entityID: entityID)
    }

    func fetchAll() async throws -> [BudgetEntity] {
        if shouldThrowError { throw throwError }
        return budgets
    }

    func fetchByID(_ id: UUID) async throws -> BudgetEntity? {
        if shouldThrowError { throw throwError }
        return budgets.first { $0.id == id }
    }

    func create(_ entity: BudgetEntity) async throws {
        try checkWriteFailure(for: entity.id)
        if shouldThrowError { throw throwError }
        budgets.append(entity)
    }

    func update(_ entity: BudgetEntity) async throws {
        try checkWriteFailure(for: entity.id)
        if shouldThrowError { throw throwError }
        if let index = budgets.firstIndex(where: { $0.id == entity.id }) {
            budgets[index] = entity
        } else {
            throw VittoraError.notFound(String(localized: "Budget not found"))
        }
    }

    func delete(_ id: UUID) async throws {
        try checkWriteFailure(for: id)
        if shouldThrowError { throw throwError }
        if let index = budgets.firstIndex(where: { $0.id == id }) {
            budgets.remove(at: index)
        } else {
            throw VittoraError.notFound(String(localized: "Budget not found"))
        }
    }

    func fetchActive() async throws -> [BudgetEntity] {
        if shouldThrowError { throw throwError }
        return budgets
    }

    func fetchForCategory(_ categoryID: UUID, period: BudgetPeriod) async throws -> BudgetEntity? {
        if shouldThrowError { throw throwError }
        return budgets.first { $0.categoryID == categoryID && $0.period == period }
    }

    // MARK: - Test Helpers

    func seed(_ entity: BudgetEntity) {
        budgets.append(entity)
    }
}
