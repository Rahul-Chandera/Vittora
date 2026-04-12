import Foundation

struct PayeeAnalytics: Sendable, Equatable {
    let payeeID: UUID
    let totalSpent: Decimal
    let transactionCount: Int
    let averageAmount: Decimal
    let lastTransactionDate: Date?
}
