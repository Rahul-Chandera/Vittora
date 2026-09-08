import Foundation

public enum EmergencyFundBaselineSource: Equatable, Sendable {
    case recurringRules
    case spendingHistory(monthCount: Int)
}

public enum EmergencyFundStatus: Equatable, Sendable {
    case buildUp
    case onTrack
    case comfortable
}

public struct EmergencyFundBaseline: Equatable, Sendable {
    public let monthlyAmount: Decimal
    public let source: EmergencyFundBaselineSource

    public nonisolated init(monthlyAmount: Decimal, source: EmergencyFundBaselineSource) {
        self.monthlyAmount = monthlyAmount
        self.source = source
    }
}

public struct EmergencyFundSnapshot: Equatable, Sendable {
    public let currentFund: Decimal
    public let essentialMonthly: Decimal
    public let coverageMonths: Decimal
    public let shortfallToThreeMonths: Decimal
    public let status: EmergencyFundStatus
    public let baselineSource: EmergencyFundBaselineSource

    public nonisolated init(
        currentFund: Decimal,
        essentialMonthly: Decimal,
        coverageMonths: Decimal,
        shortfallToThreeMonths: Decimal,
        status: EmergencyFundStatus,
        baselineSource: EmergencyFundBaselineSource
    ) {
        self.currentFund = currentFund
        self.essentialMonthly = essentialMonthly
        self.coverageMonths = coverageMonths
        self.shortfallToThreeMonths = shortfallToThreeMonths
        self.status = status
        self.baselineSource = baselineSource
    }
}

public enum EmergencyFundMath {
    public nonisolated static func recurringBaseline(
        rules: [RecurringRuleEntity],
        needsCategoryIDs: Set<UUID>,
        today: Date
    ) -> EmergencyFundBaseline? {
        let total = rules.reduce(Decimal(0)) { partial, rule in
            guard rule.isActive,
                  rule.endDate.map({ $0 >= today }) ?? true,
                  rule.templateCategoryID.map(needsCategoryIDs.contains) == true,
                  rule.templateAmount > 0 else {
                return partial
            }
            return partial + SubscriptionCostNormalization.monthlyEquivalent(
                amount: rule.templateAmount,
                frequency: rule.frequency
            )
        }
        guard total > 0 else { return nil }
        return EmergencyFundBaseline(monthlyAmount: total, source: .recurringRules)
    }

    public nonisolated static func historyBaseline(
        transactions: [TransactionEntity],
        needsCategoryIDs: Set<UUID>,
        today: Date,
        calendar: Calendar
    ) -> EmergencyFundBaseline? {
        let eligible = transactions.filter {
            $0.type == .expense
                && $0.date <= today
                && $0.amount > 0
                && $0.categoryID.map(needsCategoryIDs.contains) == true
        }
        let months = Set(eligible.map {
            calendar.dateComponents([.era, .year, .month], from: $0.date)
        })
        guard !months.isEmpty else { return nil }

        let total = eligible.reduce(Decimal(0)) { $0 + $1.amount }
        return EmergencyFundBaseline(
            monthlyAmount: total / Decimal(months.count),
            source: .spendingHistory(monthCount: months.count)
        )
    }

    /// The fund total, counted in a single currency.
    ///
    /// Accounts carry their own `currencyCode` and there are no exchange rates,
    /// so adding balances across currencies produced a total that was wrong by
    /// the FX factor — the same defect fixed in CalculateNetWorthUseCase and
    /// CashFlowForecastUseCase, here in a third place.
    ///
    /// Owner decision (2026-08-17): savings goals are treated as being in the
    /// display currency — SavingsGoalEntity has no currencyCode of its own — and
    /// contributing accounts are scoped to match, so only accounts held in that
    /// currency count. The picker is constrained to the same set, so a user
    /// cannot select an account whose balance would then be silently ignored.
    public nonisolated static func currentFund(
        accounts: [AccountEntity],
        selectedAccountIDs: Set<UUID>,
        goals: [SavingsGoalEntity],
        currencyCode: String
    ) -> Decimal {
        let accountTotal = accounts
            .filter { selectedAccountIDs.contains($0.id) && $0.currencyCode == currencyCode }
            .reduce(Decimal(0)) { $0 + $1.balance }
        let goalTotal = goals
            .filter(\.isEmergencyFund)
            .reduce(Decimal(0)) { $0 + $1.currentAmount }
        return accountTotal + goalTotal
    }

    public nonisolated static func coverageMonths(
        currentFund: Decimal,
        essentialMonthly: Decimal
    ) -> Decimal? {
        guard essentialMonthly > 0 else { return nil }
        return rounded(currentFund / essentialMonthly, scale: 1)
    }

    public nonisolated static func snapshot(
        currentFund: Decimal,
        baseline: EmergencyFundBaseline
    ) -> EmergencyFundSnapshot? {
        guard let coverage = coverageMonths(
            currentFund: currentFund,
            essentialMonthly: baseline.monthlyAmount
        ) else {
            return nil
        }
        let shortfall = max(0, baseline.monthlyAmount * 3 - currentFund)
        return EmergencyFundSnapshot(
            currentFund: currentFund,
            essentialMonthly: baseline.monthlyAmount,
            coverageMonths: coverage,
            shortfallToThreeMonths: shortfall,
            status: status(for: coverage),
            baselineSource: baseline.source
        )
    }

    public nonisolated static func status(for coverageMonths: Decimal) -> EmergencyFundStatus {
        if coverageMonths < 3 { return .buildUp }
        if coverageMonths <= 6 { return .onTrack }
        return .comfortable
    }

    public nonisolated static func displayedFiguresReconcile(
        currentFund: Decimal,
        essentialMonthly: Decimal,
        coverageMonths: Decimal
    ) -> Bool {
        guard essentialMonthly > 0 else { return false }
        let displayedFund = rounded(currentFund, scale: 2)
        let displayedMonthly = rounded(essentialMonthly, scale: 2)
        let difference = abs(displayedFund - coverageMonths * displayedMonthly)
        return difference <= displayedMonthly / 20
    }

    private nonisolated static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }
}
