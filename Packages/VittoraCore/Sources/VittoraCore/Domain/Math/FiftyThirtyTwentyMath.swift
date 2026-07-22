import Foundation

public struct FiftyThirtyTwentyAmounts: Equatable, Sendable {
    public let needs: Decimal
    public let wants: Decimal
    public let savings: Decimal

    public var totalSpending: Decimal { needs + wants + savings }

    public init(needs: Decimal, wants: Decimal, savings: Decimal) {
        self.needs = needs
        self.wants = wants
        self.savings = savings
    }

    public subscript(bucket: SpendingBucket) -> Decimal {
        switch bucket {
        case .needs: needs
        case .wants: wants
        case .savings: savings
        }
    }
}

public struct FiftyThirtyTwentyRow: Equatable, Sendable, Identifiable {
    public var id: SpendingBucket { bucket }
    public let bucket: SpendingBucket
    public let amount: Decimal
    public let targetPercent: Decimal
    public let actualPercent: Decimal
    public var variancePoints: Decimal { actualPercent - targetPercent }
}

public struct FiftyThirtyTwentyResult: Equatable, Sendable {
    public let income: Decimal
    public let amounts: FiftyThirtyTwentyAmounts
    public let rows: [FiftyThirtyTwentyRow]
}

public enum FiftyThirtyTwentyMath {
    public static func calculate(
        income: Decimal,
        amounts: FiftyThirtyTwentyAmounts
    ) -> FiftyThirtyTwentyResult? {
        guard income > 0 else { return nil }

        let rows = SpendingBucket.allCases.map { bucket in
            let target: Decimal
            switch bucket {
            case .needs: target = 50
            case .wants: target = 30
            case .savings: target = 20
            }
            return FiftyThirtyTwentyRow(
                bucket: bucket,
                amount: amounts[bucket],
                targetPercent: target,
                actualPercent: amounts[bucket] / income * 100
            )
        }
        return FiftyThirtyTwentyResult(income: income, amounts: amounts, rows: rows)
    }
}

public enum FiftyThirtyTwentyPeriod {
    public static func month(
        containing date: Date,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let start = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? date
        return start...nextMonth.addingTimeInterval(-1)
    }
}
