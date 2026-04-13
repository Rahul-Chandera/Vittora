import Foundation

struct DebtBalance: Sendable {
    let totalOwedToMe: Decimal    // sum of outstanding lent amounts
    let totalIOwe: Decimal        // sum of outstanding borrowed amounts
    var netBalance: Decimal { totalOwedToMe - totalIOwe }
}

struct CalculateDebtBalanceUseCase: Sendable {
    let debtRepository: any DebtRepository

    func execute() async throws -> DebtBalance {
        let all = try await debtRepository.fetchAll()
        let outstanding = all.filter { !$0.isSettled }

        let totalOwedToMe = outstanding
            .filter { $0.direction == .lent }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }

        let totalIOwe = outstanding
            .filter { $0.direction == .borrowed }
            .reduce(Decimal(0)) { $0 + $1.remainingAmount }

        return DebtBalance(totalOwedToMe: totalOwedToMe, totalIOwe: totalIOwe)
    }
}
