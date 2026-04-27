import Foundation

struct AddGroupExpenseUseCase: Sendable {
    let splitGroupRepository: any SplitGroupRepository

    enum ExpenseError: LocalizedError {
        case invalidAmount
        case missingPayer
        case splitGroupHasNoMembers
        case splitDoesNotBalance(Decimal, Decimal)

        var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return String(localized: "Amount must be greater than zero.")
            case .missingPayer:
                return String(localized: "Please select who paid.")
            case .splitGroupHasNoMembers:
                return String(localized: "Split group has no members.")
            case let .splitDoesNotBalance(total, splitSum):
                let code = CurrencyDefaults.code
                return String(localized: "Split amounts (\(splitSum.formatted(.currency(code: code)))) must equal the total (\(total.formatted(.currency(code: code)))).")
            }
        }
    }

    /// Creates an expense and auto-calculates shares based on the split method.
    func execute(
        groupID: UUID,
        paidByMemberID: UUID,
        amount: Decimal,
        title: String,
        date: Date,
        splitMethod: SplitMethod,
        memberIDs: [UUID],
        /// Custom input values: percentages, exact amounts, or share weights per member
        customValues: [UUID: Decimal] = [:],
        categoryID: UUID? = nil,
        note: String?
    ) async throws -> GroupExpense {
        guard amount > 0 else { throw ExpenseError.invalidAmount }

        let shares = try calculateShares(
            amount: amount,
            method: splitMethod,
            memberIDs: memberIDs,
            customValues: customValues
        )

        let expense = GroupExpense(
            groupID: groupID,
            paidByMemberID: paidByMemberID,
            amount: amount,
            title: title.trimmingCharacters(in: .whitespaces),
            date: date,
            splitMethod: splitMethod,
            shares: shares,
            categoryID: categoryID,
            note: note?.trimmingCharacters(in: .whitespaces)
        )
        try await splitGroupRepository.createExpense(expense)
        return expense
    }

    func executeUpdate(expense: GroupExpense) async throws {
        try await splitGroupRepository.updateExpense(expense)
    }

    // MARK: - Share Calculation

    func calculateShares(
        amount: Decimal,
        method: SplitMethod,
        memberIDs: [UUID],
        customValues: [UUID: Decimal]
    ) throws -> [SplitShare] {
        guard !memberIDs.isEmpty else { return [] }

        switch method {
        case .equal:
            guard let lastID = memberIDs.last else {
                throw ExpenseError.splitGroupHasNoMembers
            }
            let share = (amount / Decimal(memberIDs.count)).rounded(scale: 2)
            // Last member absorbs rounding remainder
            var shares = memberIDs.dropLast().map { SplitShare(memberID: $0, amount: share) }
            let remainder = amount - share * Decimal(memberIDs.count - 1)
            shares.append(SplitShare(memberID: lastID, amount: remainder))
            return shares

        case .percentage:
            var shares: [SplitShare] = []
            for id in memberIDs {
                let pct = customValues[id] ?? (100 / Decimal(memberIDs.count))
                shares.append(SplitShare(memberID: id, amount: (amount * pct / 100).rounded(scale: 2)))
            }
            return shares

        case .exact:
            let shares = memberIDs.map { SplitShare(memberID: $0, amount: customValues[$0] ?? 0) }
            let sum = shares.reduce(Decimal(0)) { $0 + $1.amount }
            if abs(sum - amount) > 0.01 {
                throw ExpenseError.splitDoesNotBalance(amount, sum)
            }
            return shares

        case .shares:
            guard let lastID = memberIDs.last else {
                throw ExpenseError.splitGroupHasNoMembers
            }
            let totalShares = customValues.values.reduce(Decimal(0), +)
            guard totalShares > 0 else {
                return memberIDs.map { SplitShare(memberID: $0, amount: 0) }
            }
            var shares: [SplitShare] = []
            for id in memberIDs.dropLast() {
                let weight = customValues[id] ?? 1
                shares.append(SplitShare(memberID: id, amount: (amount * weight / totalShares).rounded(scale: 2)))
            }
            let allocated = shares.reduce(Decimal(0)) { $0 + $1.amount }
            shares.append(SplitShare(memberID: lastID, amount: amount - allocated))
            return shares
        }
    }
}
