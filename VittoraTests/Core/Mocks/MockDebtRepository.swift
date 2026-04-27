import Foundation
@testable import Vittora

@MainActor
final class MockDebtRepository: DebtRepository {
    private(set) var debts: [DebtEntry] = []
    var shouldThrowError: Bool = false
    var throwError: VittoraError = .unknown(String(localized: "Mock error"))

    func fetchAll() async throws -> [DebtEntry] {
        if shouldThrowError { throw throwError }
        return debts
    }

    func fetchOutstanding() async throws -> [DebtEntry] {
        if shouldThrowError { throw throwError }
        return debts.filter { !$0.isSettled }
    }

    func fetchByID(_ id: UUID) async throws -> DebtEntry? {
        if shouldThrowError { throw throwError }
        return debts.first { $0.id == id }
    }

    func create(_ entity: DebtEntry) async throws {
        if shouldThrowError { throw throwError }
        debts.append(entity)
    }

    func update(_ entity: DebtEntry) async throws {
        if shouldThrowError { throw throwError }
        guard let index = debts.firstIndex(where: { $0.id == entity.id }) else {
            throw VittoraError.notFound(String(localized: "Debt not found"))
        }
        debts[index] = entity
    }

    func delete(_ id: UUID) async throws {
        if shouldThrowError { throw throwError }
        guard let index = debts.firstIndex(where: { $0.id == id }) else {
            throw VittoraError.notFound(String(localized: "Debt not found"))
        }
        debts.remove(at: index)
    }

    func fetchForPayee(_ payeeID: UUID) async throws -> [DebtEntry] {
        if shouldThrowError { throw throwError }
        return debts.filter { $0.payeeID == payeeID }
    }

    func fetchOverdue(before date: Date) async throws -> [DebtEntry] {
        if shouldThrowError { throw throwError }
        return debts.filter {
            guard let due = $0.dueDate else { return false }
            return !$0.isSettled && due < date
        }
    }

    func seed(_ entity: DebtEntry) {
        debts.append(entity)
    }
}
