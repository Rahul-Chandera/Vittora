import Foundation

@Observable
@MainActor
final class TransferViewModel {
    var sourceAccount: AccountEntity?
    var destinationAccount: AccountEntity?
    var amount: String = ""
    var note: String = ""
    var date: Date = .now
    var accounts: [AccountEntity] = []
    var isLoading = false
    var error: String?

    var canTransfer: Bool {
        sourceAccount != nil &&
        destinationAccount != nil &&
        sourceAccount?.id != destinationAccount?.id &&
        (Decimal(string: amount) ?? 0) > 0
    }

    private let transferUseCase: TransferFundsUseCase
    private let fetchUseCase: FetchAccountsUseCase

    init(transferUseCase: TransferFundsUseCase, fetchUseCase: FetchAccountsUseCase) {
        self.transferUseCase = transferUseCase
        self.fetchUseCase = fetchUseCase
    }

    func loadAccounts() async {
        do {
            accounts = try await fetchUseCase.execute()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func transfer() async throws {
        guard let source = sourceAccount, let destination = destinationAccount else {
            throw VittoraError.validationFailed("Please select source and destination accounts")
        }
        let transferAmount = Decimal(string: amount) ?? 0
        try await transferUseCase.execute(
            sourceAccountID: source.id,
            destinationAccountID: destination.id,
            amount: transferAmount,
            date: date,
            note: note
        )
    }
}
