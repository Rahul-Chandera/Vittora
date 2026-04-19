import Foundation

protocol DebtRepository: Sendable {
    func fetchAll() async throws -> [DebtEntry]
    func fetchOutstanding() async throws -> [DebtEntry]
    func fetchByID(_ id: UUID) async throws -> DebtEntry?
    func create(_ entity: DebtEntry) async throws
    func update(_ entity: DebtEntry) async throws
    func delete(_ id: UUID) async throws
    func fetchForPayee(_ payeeID: UUID) async throws -> [DebtEntry]
    func fetchOverdue(before date: Date) async throws -> [DebtEntry]
}
