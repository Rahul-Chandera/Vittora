import Foundation

@Observable
@MainActor
final class PayeeDetailViewModel {
    var payee: PayeeEntity?
    var analytics: PayeeAnalytics?
    var recentTransactions: [TransactionEntity] = []
    var isLoading = false
    var error: String?

    private let payeeRepository: any PayeeRepository
    private let analyticsUseCase: PayeeAnalyticsUseCase
    private let transactionRepository: any TransactionRepository

    init(
        payeeRepository: any PayeeRepository,
        analyticsUseCase: PayeeAnalyticsUseCase,
        transactionRepository: any TransactionRepository
    ) {
        self.payeeRepository = payeeRepository
        self.analyticsUseCase = analyticsUseCase
        self.transactionRepository = transactionRepository
    }

    func loadPayee(id: UUID) async {
        isLoading = true
        error = nil
        do {
            payee = try await payeeRepository.fetchByID(id)
            analytics = try await analyticsUseCase.execute(payeeID: id)
            let filter = TransactionFilter(payeeIDs: [id])
            let all = try await transactionRepository.fetchAll(filter: filter)
            recentTransactions = Array(all.prefix(10))
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
