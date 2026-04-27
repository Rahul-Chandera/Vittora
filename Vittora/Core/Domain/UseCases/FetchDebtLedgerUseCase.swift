import Foundation

struct FetchDebtLedgerUseCase: Sendable {
    let debtRepository: any DebtRepository
    let payeeRepository: any PayeeRepository

    func execute() async throws -> [DebtLedgerEntry] {
        // Fetch only outstanding (non-settled) debts at the DB level
        async let outstandingDebtsTask = debtRepository.fetchOutstanding()
        async let allPayeesTask = payeeRepository.fetchAll()
        let (outstandingDebts, allPayees) = try await (outstandingDebtsTask, allPayeesTask)

        // O(1) payee lookup instead of O(n) linear scan per entry
        let payeeByID: [UUID: PayeeEntity] = Dictionary(uniqueKeysWithValues: allPayees.map { ($0.id, $0) })

        var payeeDebts: [UUID: [DebtEntry]] = [:]
        for debt in outstandingDebts {
            payeeDebts[debt.payeeID, default: []].append(debt)
        }

        return payeeDebts.compactMap { (payeeID, entries) -> DebtLedgerEntry? in
            guard let payee = payeeByID[payeeID] else { return nil }

            var totalLent = Decimal(0)
            var totalBorrowed = Decimal(0)
            for entry in entries {
                if entry.direction == .lent {
                    totalLent += entry.remainingAmount
                } else {
                    totalBorrowed += entry.remainingAmount
                }
            }

            guard totalLent > 0 || totalBorrowed > 0 else { return nil }

            return DebtLedgerEntry(
                payee: payee,
                entries: entries.sorted { $0.createdAt > $1.createdAt },
                totalLent: totalLent,
                totalBorrowed: totalBorrowed
            )
        }
        .sorted { abs($0.netBalance) > abs($1.netBalance) }
    }
}
