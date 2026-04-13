import Foundation

/// Implements the "minimize cash flow" algorithm to reduce the number of
/// settlement transactions in a group to the theoretical minimum.
struct SimplifyDebtsUseCase: Sendable {

    /// Computes the minimum set of transfers to settle all outstanding balances.
    static func simplify(expenses: [GroupExpense], memberIDs: [UUID]) -> [MemberBalance] {
        // Step 1: Compute net balance per member
        // Positive balance = person is owed money
        // Negative balance = person owes money
        var netBalances = memberIDs.reduce(into: [UUID: Decimal]()) { $0[$1] = 0 }

        for expense in expenses {
            let payerID = expense.paidByMemberID
            for share in expense.shares {
                if share.memberID == payerID { continue }
                // The share member owes the payer their portion
                netBalances[share.memberID, default: 0] -= share.amount
                netBalances[payerID, default: 0] += share.amount
            }
        }

        // Step 2: Greedy minimize-transfers algorithm
        // Sort: creditors (positive) descending, debtors (negative) ascending
        var creditors = netBalances
            .filter { $0.value > 0.005 }
            .map { (id: $0.key, balance: $0.value) }
            .sorted { $0.balance > $1.balance }

        var debtors = netBalances
            .filter { $0.value < -0.005 }
            .map { (id: $0.key, balance: $0.value) }
            .sorted { $0.balance < $1.balance }

        var result: [MemberBalance] = []

        while !creditors.isEmpty && !debtors.isEmpty {
            let creditorBalance = creditors[0].balance
            let debtorBalance   = -debtors[0].balance  // make positive for comparison
            let transfer = min(creditorBalance, debtorBalance)

            result.append(MemberBalance(
                fromMemberID: debtors[0].id,
                toMemberID: creditors[0].id,
                amount: transfer.rounded(scale: 2)
            ))

            creditors[0].balance -= transfer
            debtors[0].balance   += transfer

            if creditors[0].balance < 0.005 { creditors.removeFirst() }
            if debtors[0].balance   > -0.005 { debtors.removeFirst() }
        }

        return result
    }

    func execute(groupID: UUID, expenses: [GroupExpense], memberIDs: [UUID]) -> [MemberBalance] {
        SimplifyDebtsUseCase.simplify(
            expenses: expenses.filter { !$0.isSettled },
            memberIDs: memberIDs
        )
    }
}

private extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var result = Decimal()
        var copy = self
        NSDecimalRound(&result, &copy, scale, .bankers)
        return result
    }
}
