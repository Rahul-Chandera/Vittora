import Foundation

struct TransferFundsUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    func execute(
        sourceAccountID: UUID,
        destinationAccountID: UUID,
        amount: Decimal,
        date: Date = .now,
        note: String = "",
        currencyCode: String = "USD"
    ) async throws {
        // Validate accounts exist
        guard let sourceAccount = try await accountRepository.fetchByID(sourceAccountID) else {
            throw VittoraError.notFound("Source account not found")
        }

        guard let destinationAccount = try await accountRepository.fetchByID(destinationAccountID) else {
            throw VittoraError.notFound("Destination account not found")
        }

        // Validate amount is positive
        guard amount > 0 else {
            throw VittoraError.validationFailed("Transfer amount must be positive")
        }

        // Create debit transaction from source account
        let sourceTransaction = TransactionEntity(
            amount: amount,
            date: date,
            note: note,
            type: .transfer,
            paymentMethod: .bankTransfer,
            currencyCode: currencyCode,
            accountID: sourceAccountID,
            destinationAccountID: destinationAccountID
        )

        try await transactionRepository.create(sourceTransaction)

        // Create credit transaction to destination account
        let destinationTransaction = TransactionEntity(
            amount: amount,
            date: date,
            note: note,
            type: .transfer,
            paymentMethod: .bankTransfer,
            currencyCode: currencyCode,
            accountID: destinationAccountID,
            destinationAccountID: sourceAccountID
        )

        try await transactionRepository.create(destinationTransaction)
    }
}
