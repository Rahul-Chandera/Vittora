import Foundation

struct FetchOverdueDebtsUseCase: Sendable {
    let debtRepository: any DebtRepository

    func execute() async throws -> [DebtEntry] {
        try await debtRepository.fetchOverdue(before: .now)
    }
}
