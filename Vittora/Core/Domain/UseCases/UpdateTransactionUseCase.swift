import Foundation

struct UpdateTransactionUseCase: Sendable {
    let transactionRepository: any TransactionRepository
    let accountRepository: any AccountRepository

    init(
        transactionRepository: any TransactionRepository,
        accountRepository: any AccountRepository
    ) {
        self.transactionRepository = transactionRepository
        self.accountRepository = accountRepository
    }

    func execute(_ entity: TransactionEntity) async throws {
        // Fetch the existing transaction so we can reverse its *original* effect
        // against its *original* account (DATAINTEGRITY-3).
        guard let existingTransaction = try await transactionRepository.fetchByID(entity.id) else {
            throw VittoraError.notFound(String(localized: "Transaction not found"))
        }

        let oldDelta = Self.balanceEffect(type: existingTransaction.type, amount: existingTransaction.amount)
        let newDelta = Self.balanceEffect(type: entity.type, amount: entity.amount)
        let oldAccountID = existingTransaction.accountID
        let newAccountID = entity.accountID

        var updatedTransaction = entity
        updatedTransaction.updatedAt = .now
        try await transactionRepository.update(updatedTransaction)

        if oldAccountID == newAccountID {
            // Same account: net the two effects in a single update.
            guard let accountID = newAccountID else { return }
            try await adjustBalance(accountID: accountID, by: newDelta - oldDelta)
        } else {
            // Account changed: reverse the old effect on the OLD account and
            // apply the new effect on the NEW account.
            if let oldAccountID {
                try await adjustBalance(accountID: oldAccountID, by: -oldDelta)
            }
            if let newAccountID {
                try await adjustBalance(accountID: newAccountID, by: newDelta)
            }
        }
    }

    private func adjustBalance(accountID: UUID, by delta: Decimal) async throws {
        guard var account = try await accountRepository.fetchByID(accountID) else {
            throw VittoraError.notFound(String(localized: "Account not found"))
        }
        account.balance += delta
        account.updatedAt = .now
        try await accountRepository.update(account)
    }

    /// Signed balance change a transaction applies to its account when present.
    /// Reversing an effect is the negation of this value. Transfers are netted
    /// via their paired leg, so they contribute nothing here.
    private static func balanceEffect(type: TransactionType, amount: Decimal) -> Decimal {
        switch type {
        case .expense: -amount
        case .income: amount
        case .adjustment: amount
        case .transfer: 0
        }
    }
}
