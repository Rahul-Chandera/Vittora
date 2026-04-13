import Foundation
import Observation

@Observable
@MainActor
final class ReportsHomeViewModel {
    var monthSpending: Decimal = 0
    var monthIncome: Decimal = 0
    var isLoading = false
    var error: String?

    private let transactionRepository: any TransactionRepository

    init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let calendar = Calendar.current
            let now = Date.now
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now

            let filter = TransactionFilter(dateRange: monthStart...now)
            let transactions = try await transactionRepository.fetchAll(filter: filter)

            monthSpending = transactions
                .filter { $0.type == .expense }
                .reduce(Decimal(0)) { $0 + $1.amount }

            monthIncome = transactions
                .filter { $0.type == .income }
                .reduce(Decimal(0)) { $0 + $1.amount }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}
