import Foundation

/// One account whose stored balance disagrees with its reconstructed balance
/// (opening balance + Σ transaction effects). DATAINTEGRITY-12.
struct BalanceDrift: Identifiable, Hashable, Sendable {
    /// Account identifier.
    let id: UUID
    let accountName: String
    let storedBalance: Decimal
    let expectedBalance: Decimal

    /// Signed difference between the stored and reconstructed balance.
    var delta: Decimal { storedBalance - expectedBalance }
}

/// Detects and repairs account-balance drift by replaying transaction effects
/// over each account's opening balance (DATAINTEGRITY-12).
///
/// Scope (A7, post-A3): transfers are now reconciled when they are
/// balance-derivable. A3 gives each transfer leg an explicit `transferDirection`,
/// so a leg's effect on its own `accountID` is just its `signedBalanceEffect`
/// (`.debit` → −amount, `.credit` → +amount). Such legs are replayed like any
/// other row. Only LEGACY transfer legs with `transferDirection == nil` remain
/// non-derivable (two symmetric positive legs that would double-count or
/// false-flag); any account touched by such a leg is SKIPPED so repair can never
/// wipe a real transfer effect.
///
/// Legacy accounts with `openingBalance == nil` are treated as reconciled: their
/// implied opening (`balance − Σ effects`) is derived on read and never flagged
/// or persisted. CloudKit transactions may not be fully synced, so pinning a
/// baseline at this point could lock in a wrong opening value.
struct ReconcileAccountBalanceUseCase: Sendable {
    let accountRepository: any AccountRepository
    let transactionRepository: any TransactionRepository

    nonisolated init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }

    /// Accounts whose stored balance disagrees with the replayed balance.
    /// Legacy nil-direction-transfer-touched and legacy nil-opening accounts are
    /// excluded (see type docs).
    func detectDrift() async throws -> [BalanceDrift] {
        let accounts = try await accountRepository.fetchAll()
        // Uncapped: reconciliation must replay every row, not the first 500.
        let transactions = try await transactionRepository.fetchAllForReconciliation()

        var effects: [UUID: Decimal] = [:]
        var nonDerivableTransferAccounts: Set<UUID> = []

        for transaction in transactions {
            // Legacy transfer legs carry no direction → not balance-derivable.
            // Flag their accounts for skipping. Direction-carrying legs (A3) fall
            // through and are replayed via signedBalanceEffect like any other row.
            if transaction.type == .transfer, transaction.transferDirection == nil {
                if let source = transaction.accountID {
                    nonDerivableTransferAccounts.insert(source)
                }
                if let destination = transaction.destinationAccountID {
                    nonDerivableTransferAccounts.insert(destination)
                }
                continue
            }
            guard let accountID = transaction.accountID else { continue }
            effects[accountID, default: 0] += transaction.signedBalanceEffect
        }

        var drifts: [BalanceDrift] = []
        for account in accounts {
            // Accounts touched by a non-derivable legacy transfer leg — skip.
            if nonDerivableTransferAccounts.contains(account.id) { continue }
            // Legacy nil-opening accounts reconcile by construction — don't flag.
            guard let opening = account.openingBalance else { continue }

            let expected = opening + (effects[account.id] ?? 0)
            if account.balance != expected {
                drifts.append(
                    BalanceDrift(
                        id: account.id,
                        accountName: account.name,
                        storedBalance: account.balance,
                        expectedBalance: expected
                    )
                )
            }
        }
        return drifts
    }

    /// Repairs drifted accounts by writing back the replayed balance. The opening
    /// balance is left untouched, so a repaired account satisfies
    /// `opening + Σ effects == balance`. Idempotent: a second run finds nothing.
    /// Returns the drifts that were repaired.
    @discardableResult
    func repair() async throws -> [BalanceDrift] {
        let drifts = try await detectDrift()
        for drift in drifts {
            guard var account = try await accountRepository.fetchByID(drift.id) else { continue }
            account.balance = drift.expectedBalance
            account.updatedAt = .now
            try await accountRepository.update(account)
        }
        return drifts
    }
}
