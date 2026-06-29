import Foundation

public struct PayeeAnalytics: Sendable, Equatable {
    public let payeeID: UUID
    public let totalSpent: Decimal
    public let transactionCount: Int
    public let averageAmount: Decimal
    public let lastTransactionDate: Date?

    public init(
        payeeID: UUID,
        totalSpent: Decimal,
        transactionCount: Int,
        averageAmount: Decimal,
        lastTransactionDate: Date?
    ) {
        self.payeeID = payeeID
        self.totalSpent = totalSpent
        self.transactionCount = transactionCount
        self.averageAmount = averageAmount
        self.lastTransactionDate = lastTransactionDate
    }
}
