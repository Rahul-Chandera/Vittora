import Foundation

struct AddGroupExpenseUseCase: Sendable {
    let splitGroupRepository: any SplitGroupRepository

    enum ExpenseError: LocalizedError {
        case invalidAmount
        case missingPayer
        case splitGroupHasNoMembers
        case splitDoesNotBalance(Decimal, Decimal)
        case percentagesDoNotSum(Decimal)
        case shareWeightsInvalid

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
            case let .percentagesDoNotSum(sum):
                return String(localized: "Percentages must sum to 100% (currently \(sum.formatted(.number.precision(.fractionLength(0...2))))%).")
            case .shareWeightsInvalid:
                return String(localized: "Share weights must sum to more than zero.")
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
            let ideal = memberIDs.map { _ in amount / Decimal(memberIDs.count) }
            return SplitRounding.allocate(amount: amount, memberIDs: memberIDs, idealParts: ideal)

        case .percentage:
            let percentages = memberIDs.map { id in
                customValues[id] ?? (100 / Decimal(memberIDs.count))
            }
            let pctSum = percentages.reduce(Decimal(0), +)
            if abs(pctSum - 100) > SplitRounding.percentageTolerance {
                throw ExpenseError.percentagesDoNotSum(pctSum)
            }
            let ideal = zip(memberIDs, percentages).map { _, pct in amount * pct / 100 }
            return SplitRounding.allocate(amount: amount, memberIDs: memberIDs, idealParts: ideal)

        case .exact:
            let shares = memberIDs.map { SplitShare(memberID: $0, amount: customValues[$0] ?? 0) }
            let sum = SplitRounding.shareTotal(shares)
            if abs(sum - amount) > SplitRounding.moneyTolerance {
                throw ExpenseError.splitDoesNotBalance(amount, sum)
            }
            return shares

        case .shares:
            let weights = memberIDs.map { customValues[$0] ?? 1 }
            let totalShares = weights.reduce(Decimal(0), +)
            guard totalShares > 0 else {
                throw ExpenseError.shareWeightsInvalid
            }
            let ideal = weights.map { amount * $0 / totalShares }
            return SplitRounding.allocate(amount: amount, memberIDs: memberIDs, idealParts: ideal)
        }
    }
}
