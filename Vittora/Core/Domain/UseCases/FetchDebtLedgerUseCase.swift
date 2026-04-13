import Foundation

struct FetchDebtLedgerUseCase: Sendable {
    let debtRepository: any DebtRepository
    let payeeRepository: any PayeeRepository

    func execute() async throws -> [DebtLedgerEntry] {
        async let allDebtsTask = debtRepository.fetchAll()
        async let allPayeesTask = payeeRepository.fetchAll()
        let (allDebts, allPayees) = try await (allDebtsTask, allPayeesTask)

        // Group by payee, only non-settled entries count toward balance
        var payeeDebts: [UUID: [DebtEntry]] = [:]
        for debt in allDebts {
            var list = payeeDebts[debt.payeeID] ?? []
            list.append(debt)
            payeeDebts[debt.payeeID] = list
        }

        return payeeDebts.compactMap { (payeeID, entries) -> DebtLedgerEntry? in
            guard let payee = allPayees.first(where: { $0.id == payeeID }) else { return nil }

            let outstanding = entries.filter { !$0.isSettled }
            let totalLent = outstanding
                .filter { $0.direction == .lent }
                .reduce(Decimal(0)) { $0 + $1.remainingAmount }
            let totalBorrowed = outstanding
                .filter { $0.direction == .borrowed }
                .reduce(Decimal(0)) { $0 + $1.remainingAmount }

            return DebtLedgerEntry(
                payee: payee,
                entries: entries.sorted { $0.createdAt > $1.createdAt },
                totalLent: totalLent,
                totalBorrowed: totalBorrowed
            )
        }
        .filter { $0.totalLent > 0 || $0.totalBorrowed > 0 || !$0.entries.filter({ !$0.isSettled }).isEmpty }
        .sorted { abs($0.netBalance) > abs($1.netBalance) }
    }
}
