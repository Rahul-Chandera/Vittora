import Foundation

struct FetchDebtLedgerUseCase: Sendable {
    let debtRepository: any DebtRepository
    let payeeRepository: any PayeeRepository

    func execute() async throws -> [DebtLedgerEntry] {
        // Fetch only outstanding (non-settled) debts at the DB level
        async let outstandingDebtsTask = debtRepository.fetchOutstanding()
        async let allPayeesTask = payeeRepository.fetchAll()
        let (outstandingDebts, allPayees) = try await (outstandingDebtsTask, allPayeesTask)

        var payeeDebts: [UUID: [DebtEntry]] = [:]
        for debt in outstandingDebts {
            var list = payeeDebts[debt.payeeID] ?? []
            list.append(debt)
            payeeDebts[debt.payeeID] = list
        }

        return payeeDebts.compactMap { (payeeID, entries) -> DebtLedgerEntry? in
            guard let payee = allPayees.first(where: { $0.id == payeeID }) else { return nil }

            let totalLent = entries
                .filter { $0.direction == .lent }
                .reduce(Decimal(0)) { $0 + $1.remainingAmount }
            let totalBorrowed = entries
                .filter { $0.direction == .borrowed }
                .reduce(Decimal(0)) { $0 + $1.remainingAmount }

            return DebtLedgerEntry(
                payee: payee,
                entries: entries.sorted { $0.createdAt > $1.createdAt },
                totalLent: totalLent,
                totalBorrowed: totalBorrowed
            )
        }
        .filter { $0.totalLent > 0 || $0.totalBorrowed > 0 }
        .sorted { abs($0.netBalance) > abs($1.netBalance) }
    }
}
