import Foundation

public protocol InvestmentRepository: Sendable {
    /// Earliest maturity first; age-linked records (no date) sort last.
    func fetchAll() async throws -> [Investment]
    func save(_ investment: Investment) async throws
    func delete(id: UUID) async throws
}
