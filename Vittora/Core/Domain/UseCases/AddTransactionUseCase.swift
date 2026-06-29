import Foundation
import VittoraCore

struct AddTransactionUseCase: Sendable {
    let accountRepository: any AccountRepository
    let categoryRepository: any CategoryRepository
    /// Required atomic write surface — no repository fallback. The insert and
    /// the balance adjustment must land in one save (DATAINTEGRITY-2).
    let ledgerWriting: any LedgerWriting

    nonisolated init(
        accountRepository: any AccountRepository,
        categoryRepository: any CategoryRepository,
        ledgerWriting: any LedgerWriting
    ) {
        self.accountRepository = accountRepository
        self.categoryRepository = categoryRepository
        self.ledgerWriting = ledgerWriting
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

        // Insert the transaction and adjust the account balance atomically.
        // The store applies the type-specific balance effect in one save.
        try await ledgerWriting.performAdd(transaction)

        return transaction
    }
}
