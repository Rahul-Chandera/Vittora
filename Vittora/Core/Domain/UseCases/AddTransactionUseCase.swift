import Foundation

struct AddTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository
    let categoryRepository: any CategoryRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
    }

    func execute(
        amount: Decimal,
        type: TransactionType,
        date: Date,
        categoryID: UUID?,
        accountID: UUID,
        payeeID: UUID?,
        note: String?,
        tags: [String],
        paymentMethod: PaymentMethod,
        currencyCode: String
    ) async throws -> TransactionEntity {
        // Validate amount is positive
        guard amount > 0 else {
            throw VittoraError.validationFailed("Amount must be greater than zero")
        }

        // Validate account exists and is not archived
        guard let account = try await accountRepository.fetchByID(accountID) else {
            throw VittoraError.notFound("Account not found")
        }

        guard !account.isArchived else {
            throw VittoraError.validationFailed("Cannot add transaction to archived account")
        }

        // Validate category exists if provided
        if let categoryID = categoryID {
            guard let _ = try await categoryRepository.fetchByID(categoryID) else {
                throw VittoraError.notFound("Category not found")
            }
        }

        // Create transaction entity
        let transaction = TransactionEntity(
            amount: amount,
            date: date,
            note: note,
            type: type,
            paymentMethod: paymentMethod,
            currencyCode: currencyCode,
            tags: tags,
            categoryID: categoryID,
            accountID: accountID,
            payeeID: payeeID
        )

        // Save transaction
        try await transactionRepository.create(transaction)

        // Adjust account balance
        var updatedAccount = account
        updatedAccount.updatedAt = .now

        switch type {
        case .expense:
            updatedAccount.balance -= amount
        case .income:
            updatedAccount.balance += amount
        case .transfer:
            // Transfer balance effects handled by destinationAccountID
            break
        case .adjustment:
            updatedAccount.balance += amount
        }

        try await accountRepository.update(updatedAccount)

        return transaction
    }
}
