import Foundation

@Observable
@MainActor
final class AccountDetailViewModel {
    var account: AccountEntity?
    var recentTransactions: [TransactionEntity] = []
    var isLoading = false
    var error: String?

    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository

    init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }

    func loadAccount(id: UUID) async {
        isLoading = true
        error = nil
        do {
            account = try await accountRepository.fetchByID(id)
            let filter = TransactionFilter(accountIDs: [id])
            let all = try await transactionRepository.fetchAll(filter: filter)
            recentTransactions = Array(all.prefix(10))
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
