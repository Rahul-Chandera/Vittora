import Foundation

/// Implements the "minimize cash flow" algorithm to reduce the number of
/// settlement transactions in a group to the theoretical minimum.
struct SimplifyDebtsUseCase: Sendable {
    nonisolated init() {}

    /// Computes the minimum set of transfers to settle all outstanding balances.
    nonisolated static func simplify(expenses: [GroupExpense], memberIDs: [UUID]) -> [MemberBalance] {
        var netBalances = memberIDs.reduce(into: [UUID: Decimal]()) { $0[$1] = 0 }

        for expense in expenses {
            let payerID = expense.paidByMemberID
            for share in expense.shares {
                if share.memberID == payerID { continue }
                netBalances[share.memberID, default: 0] -= share.amount
                netBalances[payerID, default: 0] += share.amount
            }
        }

        // Work in rounded cents so transfer rounding nets to zero.
        for id in netBalances.keys {
            netBalances[id] = netBalances[id]?.rounded(scale: SplitRounding.moneyScale) ?? 0
        }

        var creditors = netBalances
            .filter { $0.value > SplitRounding.moneyEpsilon }
            .map { (id: $0.key, balance: $0.value) }
            .sorted { $0.balance > $1.balance }

        var debtors = netBalances
            .filter { $0.value < -SplitRounding.moneyEpsilon }
            .map { (id: $0.key, balance: $0.value) }
            .sorted { $0.balance < $1.balance }

        var result: [MemberBalance] = []

        while !creditors.isEmpty && !debtors.isEmpty {
            let creditorOwed = creditors[0].balance
            let debtorOwes = -debtors[0].balance
            var transfer = min(creditorOwed, debtorOwes).rounded(scale: SplitRounding.moneyScale)

            // Avoid stalling on sub-cent dust when a side still has material balance.
            if transfer == 0,
               creditorOwed > SplitRounding.moneyTolerance || debtorOwes > SplitRounding.moneyTolerance {
                transfer = min(creditorOwed, debtorOwes)
            }

            guard transfer > 0 else { break }

            result.append(MemberBalance(
                fromMemberID: debtors[0].id,
                toMemberID: creditors[0].id,
                amount: transfer
            ))

            creditors[0].balance = (creditors[0].balance - transfer)
                .rounded(scale: SplitRounding.moneyScale)
            debtors[0].balance = (debtors[0].balance + transfer)
                .rounded(scale: SplitRounding.moneyScale)

            if creditors[0].balance <= SplitRounding.moneyEpsilon { creditors.removeFirst() }
            if debtors[0].balance >= -SplitRounding.moneyEpsilon { debtors.removeFirst() }
        }

        return result
    }

    /// Net balance per member after applying the suggested transfers (for tests).
    nonisolated static func netAfterTransfers(
        initialNet: [UUID: Decimal],
        transfers: [MemberBalance]
    ) -> [UUID: Decimal] {
        var net = initialNet
        for transfer in transfers {
            net[transfer.fromMemberID, default: 0] += transfer.amount
            net[transfer.toMemberID, default: 0] -= transfer.amount
        }
        return net
    }

    nonisolated func execute(groupID: UUID, expenses: [GroupExpense], memberIDs: [UUID]) -> [MemberBalance] {
        SimplifyDebtsUseCase.simplify(
            expenses: expenses.filter { !$0.isSettled },
            memberIDs: memberIDs
        )
    }
}
