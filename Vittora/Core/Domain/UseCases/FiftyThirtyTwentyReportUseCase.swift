import Foundation
import VittoraCore

struct FiftyThirtyTwentyReportSnapshot: Sendable {
    let period: ClosedRange<Date>
    let income: Decimal
    let amounts: FiftyThirtyTwentyAmounts
    let comparison: FiftyThirtyTwentyResult?
}

struct FiftyThirtyTwentyReportUseCase: Sendable {
    nonisolated static let savingsContributionTag = "savings-goal-contribution"

    let transactionRepository: any TransactionRepository
    let categoryRepository: any CategoryRepository
    let debtRepository: any DebtRepository
    var calendar: Calendar = .current
    var today: @Sendable () -> Date = { .now }

    func execute(month: Date? = nil) async throws -> FiftyThirtyTwentyReportSnapshot {
        let period = FiftyThirtyTwentyPeriod.month(
            containing: month ?? today(),
            calendar: calendar
        )
        async let transactionFetch = transactionRepository.fetchAll(
            filter: TransactionFilter(dateRange: period)
        )
        async let categoryFetch = categoryRepository.fetchAll()
        async let debtFetch = debtRepository.fetchAll()

        let (transactions, categories, debts) = try await (
            transactionFetch,
            categoryFetch,
            debtFetch
        )
        let bucketsByCategory = Dictionary(
            categories.compactMap { category in
                category.spendingBucket.map { (category.id, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let borrowedRepaymentIDs = Set(
            debts
                .filter { $0.direction == .borrowed }
                .flatMap(\.linkedTransactionIDs)
        )
        let lentRepaymentIDs = Set(
            debts
                .filter { $0.direction == .lent }
                .flatMap(\.linkedTransactionIDs)
        )

        var income: Decimal = 0
        var needs: Decimal = 0
        var wants: Decimal = 0
        var savings: Decimal = 0

        for transaction in transactions {
            if transaction.type == .income, !lentRepaymentIDs.contains(transaction.id) {
                income += transaction.amount
                continue
            }
            if transaction.tags.contains(Self.savingsContributionTag) {
                savings += transaction.amount
                continue
            }
            guard transaction.type == .expense else { continue }
            if borrowedRepaymentIDs.contains(transaction.id) {
                savings += transaction.amount
                continue
            }

            // Uncategorized expenses intentionally count as wants.
            let bucket = transaction.categoryID.flatMap { bucketsByCategory[$0] } ?? .wants
            switch bucket {
            case .needs: needs += transaction.amount
            case .wants: wants += transaction.amount
            case .savings: savings += transaction.amount
            }
        }

        let amounts = FiftyThirtyTwentyAmounts(
            needs: needs,
            wants: wants,
            savings: savings
        )
        return FiftyThirtyTwentyReportSnapshot(
            period: period,
            income: income,
            amounts: amounts,
            comparison: FiftyThirtyTwentyMath.calculate(income: income, amounts: amounts)
        )
    }
}
