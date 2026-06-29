
import Foundation
import Testing
import SwiftData
import VittoraCore
@testable import Vittora

/// DATAINTEGRITY-12 (A7): balance reconciliation + repair over a real in-memory
/// store. Repositories are intentionally "dumb" here (they persist what they are
/// given without adjusting balances), so a deliberately wrong stored balance
/// models real-world drift that the use case must detect and repair.
@MainActor
@Suite("ReconcileAccountBalanceUseCase Tests")
struct ReconcileAccountBalanceUseCaseTests {

    private struct Env {
        let accounts: SwiftDataAccountRepository
        let transactions: SwiftDataTransactionRepository
        let useCase: ReconcileAccountBalanceUseCase
    }

    private func makeEnv() throws -> Env {
        let container = try ModelContainerConfig.makePreviewContainer()
        let accounts = SwiftDataAccountRepository(modelContainer: container)
        let transactions = SwiftDataTransactionRepository(modelContainer: container)
        let useCase = ReconcileAccountBalanceUseCase(
            accountRepository: accounts,
            transactionRepository: transactions
        )
        return Env(accounts: accounts, transactions: transactions, useCase: useCase)
    }

    @Test("Detects drift on a transfer-free account and repairs it idempotently")
    func detectsAndRepairsDrift() async throws {
        let env = try makeEnv()
        let accountID = UUID()

        // opening 1000; effects: -100 (expense) + 50 (income) = -50 → expected 950.
        // Store a wrong balance of 900 to model drift.
        try await env.accounts.create(
            AccountEntity(id: accountID, name: "Checking", type: .bank, balance: 900, openingBalance: 1000)
        )
        try await env.transactions.create(
            TransactionEntity(amount: 100, type: .expense, accountID: accountID)
        )
        try await env.transactions.create(
            TransactionEntity(amount: 50, type: .income, accountID: accountID)
        )

        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.count == 1)
        let drift = try #require(drifts.first)
        #expect(drift.id == accountID)
        #expect(drift.storedBalance == 900)
        #expect(drift.expectedBalance == 950)
        #expect(drift.delta == -50)

        let repaired = try await env.useCase.repair()
        #expect(repaired.count == 1)

        let after = try #require(try await env.accounts.fetchByID(accountID))
        #expect(after.balance == 950)
        // Opening balance is left untouched by repair.
        #expect(after.openingBalance == 1000)

        // Idempotent: a second pass finds nothing.
        let second = try await env.useCase.detectDrift()
        #expect(second.isEmpty)
    }

    @Test("A reconciled account is not flagged")
    func reconciledAccountNotFlagged() async throws {
        let env = try makeEnv()
        let accountID = UUID()

        // opening 200; income 300 → expected 500; store exactly 500.
        try await env.accounts.create(
            AccountEntity(id: accountID, name: "Savings", type: .bank, balance: 500, openingBalance: 200)
        )
        try await env.transactions.create(
            TransactionEntity(amount: 300, type: .income, accountID: accountID)
        )

        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.isEmpty)
    }

    @Test("Legacy nil-opening accounts are treated as reconciled and skipped")
    func legacyNilOpeningAccountSkipped() async throws {
        let env = try makeEnv()
        let accountID = UUID()

        // No openingBalance and a balance that does NOT match Σ effects — must
        // still be skipped (implied opening derived on read, never flagged).
        try await env.accounts.create(
            AccountEntity(id: accountID, name: "Legacy", type: .bank, balance: 42, openingBalance: nil)
        )
        try await env.transactions.create(
            TransactionEntity(amount: 1000, type: .expense, accountID: accountID)
        )

        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.isEmpty)

        // Repair must not touch a skipped legacy account.
        let repaired = try await env.useCase.repair()
        #expect(repaired.isEmpty)
        let after = try #require(try await env.accounts.fetchByID(accountID))
        #expect(after.balance == 42)
        #expect(after.openingBalance == nil)
    }

    @Test("Accounts touched by a LEGACY nil-direction transfer leg are skipped")
    func legacyNilDirectionTransferAccountSkipped() async throws {
        let env = try makeEnv()
        let source = UUID()
        let destination = UUID()

        // Both accounts have explicit openings and clearly wrong stored balances,
        // but each is touched by a legacy transfer leg with no direction, so the
        // leg is not balance-derivable and neither account may be flagged.
        try await env.accounts.create(
            AccountEntity(id: source, name: "Source", type: .bank, balance: 0, openingBalance: 1000)
        )
        try await env.accounts.create(
            AccountEntity(id: destination, name: "Destination", type: .bank, balance: 0, openingBalance: 0)
        )
        try await env.transactions.create(
            TransactionEntity(
                amount: 250,
                type: .transfer,
                accountID: source,
                destinationAccountID: destination
                // transferDirection == nil → legacy, non-derivable.
            )
        )

        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.isEmpty)

        let repaired = try await env.useCase.repair()
        #expect(repaired.isEmpty)
        let sourceAfter = try #require(try await env.accounts.fetchByID(source))
        #expect(sourceAfter.balance == 0)
    }

    @Test("Direction-carrying transfer legs (A3) are reconciled, not skipped")
    func directionCarryingTransferReconciled() async throws {
        let env = try makeEnv()
        let source = UUID()
        let destination = UUID()
        let pairID = UUID()

        // A3-style paired legs: debit on source (−250), credit on destination (+250).
        // Source: opening 1000 + (−250) = 750 expected; store a wrong 700 (drift).
        // Destination: opening 0 + 250 = 250 expected; store the correct 250.
        try await env.accounts.create(
            AccountEntity(id: source, name: "Source", type: .bank, balance: 700, openingBalance: 1000)
        )
        try await env.accounts.create(
            AccountEntity(id: destination, name: "Destination", type: .bank, balance: 250, openingBalance: 0)
        )
        try await env.transactions.create(
            TransactionEntity(
                amount: 250,
                type: .transfer,
                accountID: source,
                destinationAccountID: destination,
                transferPairID: pairID,
                transferDirection: .debit
            )
        )
        try await env.transactions.create(
            TransactionEntity(
                amount: 250,
                type: .transfer,
                accountID: destination,
                destinationAccountID: source,
                transferPairID: pairID,
                transferDirection: .credit
            )
        )

        // Only the source drifts (700 vs expected 750); the transfer effect is
        // counted, so the account is reconciled rather than skipped.
        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.count == 1)
        let drift = try #require(drifts.first)
        #expect(drift.id == source)
        #expect(drift.expectedBalance == 750)

        let repaired = try await env.useCase.repair()
        #expect(repaired.count == 1)
        let sourceAfter = try #require(try await env.accounts.fetchByID(source))
        #expect(sourceAfter.balance == 750)
        let destinationAfter = try #require(try await env.accounts.fetchByID(destination))
        #expect(destinationAfter.balance == 250)

        // Idempotent.
        let second = try await env.useCase.detectDrift()
        #expect(second.isEmpty)
    }

    @Test("A manual balance edit re-baselines opening and causes no false drift")
    func manualBalanceEditDoesNotFalseFlag() async throws {
        let env = try makeEnv()
        let accountID = UUID()

        // opening 1000 with a 100 expense already applied → balance 900 (reconciled).
        try await env.accounts.create(
            AccountEntity(id: accountID, name: "Checking", type: .bank, balance: 900, openingBalance: 1000)
        )
        try await env.transactions.create(
            TransactionEntity(amount: 100, type: .expense, accountID: accountID)
        )
        #expect(try await env.useCase.detectDrift().isEmpty)

        // The user manually edits the balance to 1500. UpdateAccountUseCase
        // re-baselines opening by the same delta (1000 + (1500 − 900) = 1600), so
        // reconciliation must NOT flag this deliberate edit as drift.
        let updateUseCase = UpdateAccountUseCase(accountRepository: env.accounts)
        let existing = try #require(try await env.accounts.fetchByID(accountID))
        try await updateUseCase.execute(
            id: accountID,
            name: existing.name,
            type: existing.type,
            balance: 1500,
            currencyCode: existing.currencyCode,
            icon: existing.icon
        )

        let edited = try #require(try await env.accounts.fetchByID(accountID))
        #expect(edited.balance == 1500)
        #expect(edited.openingBalance == 1600)

        let drifts = try await env.useCase.detectDrift()
        #expect(drifts.isEmpty)
    }

    @Test("Reconciliation replays every row, not just the first 500")
    func reconciliationIsUncapped() async throws {
        let env = try makeEnv()
        let accountID = UUID()

        // opening 0; 600 income of 1 each → expected 600. A capped 500-row read
        // would compute 500, so asserting 600 proves the pass is uncapped.
        try await env.accounts.create(
            AccountEntity(id: accountID, name: "Busy", type: .bank, balance: 0, openingBalance: 0)
        )
        for _ in 0..<600 {
            try await env.transactions.create(
                TransactionEntity(amount: 1, type: .income, accountID: accountID)
            )
        }

        let drifts = try await env.useCase.detectDrift()
        let drift = try #require(drifts.first)
        #expect(drift.expectedBalance == 600)
    }
}
