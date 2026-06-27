import Testing
import SwiftData
import Foundation
@testable import Vittora

/// Verifies the single-context write Unit-of-Work guarantees from A1:
/// a compound operation persists with exactly one `save()`, and an
/// operation that fails mid-way rolls back and persists nothing.
@Suite("LedgerWriteStore Unit-of-Work")
struct LedgerWriteStoreTests {

    /// Error used to simulate a failure injected partway through an operation.
    private struct InjectedFailure: Error {}

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerConfig.makeContainer(inMemory: true)
    }

    @Test("compound write persists all changes with exactly one save")
    func compoundWriteSavesOnce() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        try await store.commit { ctx in
            ctx.insert(SDTransaction(amount: 10, externalID: UUID().uuidString))
            ctx.insert(SDTransaction(amount: 20, externalID: UUID().uuidString))
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.count == 2)
    }

    @Test("mid-operation failure rolls back and persists nothing")
    func midOperationFailureRollsBack() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: InjectedFailure.self) {
            try await store.commit { ctx in
                ctx.insert(SDTransaction(amount: 99, externalID: UUID().uuidString))
                throw InjectedFailure()
            }
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 0)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.isEmpty)
    }

    @Test("store recovers after a failed operation")
    func storeRecoversAfterFailure() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: InjectedFailure.self) {
            try await store.commit { ctx in
                ctx.insert(SDTransaction(amount: 1, externalID: UUID().uuidString))
                throw InjectedFailure()
            }
        }

        try await store.commit { ctx in
            ctx.insert(SDTransaction(amount: 42, externalID: UUID().uuidString))
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verifyContext = ModelContext(container)
        let rows = try verifyContext.fetch(FetchDescriptor<SDTransaction>())
        #expect(rows.count == 1)
        #expect(rows.first?.amount == 42)
    }

    // MARK: - A6: performAdd / performSettle atomicity (real container)

    private func seedAccount(_ container: ModelContainer, balance: Decimal) throws -> UUID {
        let context = ModelContext(container)
        let account = SDAccount(name: "Checking", type: .bank, balance: balance)
        context.insert(account)
        try context.save()
        return account.id
    }

    private func seedDebt(_ container: ModelContainer, amount: Decimal, direction: DebtDirection) throws -> UUID {
        let context = ModelContext(container)
        let debt = SDDebt(payeeID: UUID(), amount: amount, direction: direction)
        context.insert(debt)
        try context.save()
        return debt.id
    }

    @Test("performAdd inserts the transaction and applies the balance in one save")
    func performAddPersistsTransactionAndBalance() async throws {
        let container = try makeContainer()
        let accountID = try seedAccount(container, balance: 1000)
        let store = LedgerWriteStore(modelContainer: container)

        try await store.performAdd(TransactionEntity(amount: 200, type: .expense, accountID: accountID))

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verify = ModelContext(container)
        let txs = try verify.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.count == 1)
        let account = try verify.fetch(FetchDescriptor<SDAccount>()).first
        #expect(account?.balance == 800)
    }

    @Test("performAdd rolls back when the account id does not resolve")
    func performAddRollsBackWhenAccountMissing() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: LedgerWriteError.self) {
            try await store.performAdd(TransactionEntity(amount: 200, type: .expense, accountID: UUID()))
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 0)
        let verify = ModelContext(container)
        let txs = try verify.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.isEmpty)
    }

    @Test("performSettle updates debt, inserts the leg, and moves balance in one save")
    func performSettlePersistsDebtTransactionAndBalance() async throws {
        let container = try makeContainer()
        let accountID = try seedAccount(container, balance: 1000)
        let debtID = try seedDebt(container, amount: 300, direction: .lent)
        let store = LedgerWriteStore(modelContainer: container)

        let leg = TransactionEntity(amount: 300, type: .income, accountID: accountID)
        try await store.performSettle(debtID: debtID, settlementAmount: 300, transaction: leg)

        let saveCount = await store.saveCount
        #expect(saveCount == 1)

        let verify = ModelContext(container)
        let debt = try verify.fetch(FetchDescriptor<SDDebt>()).first
        #expect(debt?.settledAmount == 300)
        #expect(debt?.isSettled == true)
        #expect(debt?.linkedTransactionID == leg.id)
        let account = try verify.fetch(FetchDescriptor<SDAccount>()).first
        #expect(account?.balance == 1300)
        let txs = try verify.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.count == 1)
    }

    @Test("performSettle rolls back entirely when the account id is invalid")
    func performSettleRollsBackWhenAccountMissing() async throws {
        let container = try makeContainer()
        let debtID = try seedDebt(container, amount: 300, direction: .lent)
        let store = LedgerWriteStore(modelContainer: container)

        let leg = TransactionEntity(amount: 300, type: .income, accountID: UUID())
        await #expect(throws: LedgerWriteError.self) {
            try await store.performSettle(debtID: debtID, settlementAmount: 300, transaction: leg)
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 0)
        let verify = ModelContext(container)
        let debt = try verify.fetch(FetchDescriptor<SDDebt>()).first
        #expect(debt?.settledAmount == 0)
        #expect(debt?.isSettled == false)
        #expect(debt?.linkedTransactionID == nil)
        let txs = try verify.fetch(FetchDescriptor<SDTransaction>())
        #expect(txs.isEmpty)
    }

    @Test("performSettle throws and persists nothing when the debt is missing")
    func performSettleRollsBackWhenDebtMissing() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: VittoraError.self) {
            try await store.performSettle(debtID: UUID(), settlementAmount: 100, transaction: nil)
        }

        let saveCount = await store.saveCount
        #expect(saveCount == 0)
    }

    // MARK: - A4: performDelete / performUpdate / performUpdateTransfer (real container)

    @Test("performDelete reverses a non-transfer effect and removes the row in one save")
    func performDeleteReversesNonTransfer() async throws {
        let container = try makeContainer()
        let accountID = try seedAccount(container, balance: 1000)
        let store = LedgerWriteStore(modelContainer: container)

        let tx = TransactionEntity(amount: 200, type: .expense, accountID: accountID)
        try await store.performAdd(tx) // balance -> 800

        let before = await store.saveCount
        try await store.performDelete(transactionID: tx.id)
        let after = await store.saveCount
        #expect(after - before == 1)

        let verify = ModelContext(container)
        #expect(try verify.fetch(FetchDescriptor<SDTransaction>()).isEmpty)
        #expect(try verify.fetch(FetchDescriptor<SDAccount>()).first?.balance == 1000)
    }

    @Test("performDelete removes BOTH transfer legs and reverses both balances in one save")
    func performDeleteReversesBothTransferLegs() async throws {
        let container = try makeContainer()
        let sourceID = try seedAccount(container, balance: 1000)
        let destID = try seedAccount(container, balance: 0)
        let store = LedgerWriteStore(modelContainer: container)

        try await store.performTransfer(
            sourceAccountID: sourceID, destinationAccountID: destID,
            amount: 250, date: .now, note: "", currencyCode: "USD"
        ) // source 750, dest 250, two legs

        let seed = ModelContext(container)
        let oneLegID = try #require(try seed.fetch(FetchDescriptor<SDTransaction>()).first?.id)

        try await store.performDelete(transactionID: oneLegID)

        let verify = ModelContext(container)
        #expect(try verify.fetch(FetchDescriptor<SDTransaction>()).isEmpty)
        let accounts = try verify.fetch(FetchDescriptor<SDAccount>())
        #expect(accounts.first { $0.id == sourceID }?.balance == 1000)
        #expect(accounts.first { $0.id == destID }?.balance == 0)
    }

    @Test("performDelete throws and persists nothing when the transaction is missing")
    func performDeleteThrowsWhenMissing() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        await #expect(throws: VittoraError.self) {
            try await store.performDelete(transactionID: UUID())
        }
        let saveCount = await store.saveCount
        #expect(saveCount == 0)
    }

    @Test("performUpdate nets the effect on the same account in one save")
    func performUpdateNetsSameAccount() async throws {
        let container = try makeContainer()
        let accountID = try seedAccount(container, balance: 1000)
        let store = LedgerWriteStore(modelContainer: container)

        var tx = TransactionEntity(amount: 200, type: .expense, accountID: accountID)
        try await store.performAdd(tx) // -> 800
        tx.amount = 100
        try await store.performUpdate(tx) // reverse 200, apply 100 -> 900

        let verify = ModelContext(container)
        #expect(try verify.fetch(FetchDescriptor<SDAccount>()).first?.balance == 900)
        let stored = try verify.fetch(FetchDescriptor<SDTransaction>()).first
        #expect(stored?.amount == 100)
    }

    @Test("performUpdate moves the effect when the account changes")
    func performUpdateMovesAccount() async throws {
        let container = try makeContainer()
        let oldID = try seedAccount(container, balance: 1000)
        let newID = try seedAccount(container, balance: 500)
        let store = LedgerWriteStore(modelContainer: container)

        var tx = TransactionEntity(amount: 200, type: .expense, accountID: oldID)
        try await store.performAdd(tx) // old -> 800
        tx.accountID = newID
        try await store.performUpdate(tx) // old +200 -> 1000, new -200 -> 300

        let verify = ModelContext(container)
        let accounts = try verify.fetch(FetchDescriptor<SDAccount>())
        #expect(accounts.first { $0.id == oldID }?.balance == 1000)
        #expect(accounts.first { $0.id == newID }?.balance == 300)
    }

    @Test("performUpdate rejects a transfer and rolls back")
    func performUpdateRejectsTransfer() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        let transfer = TransactionEntity(amount: 100, type: .transfer, accountID: UUID())
        await #expect(throws: LedgerWriteError.self) {
            try await store.performUpdate(transfer)
        }
        let saveCount = await store.saveCount
        #expect(saveCount == 0)
    }

    @Test("performUpdateTransfer re-amounts both legs atomically and stays balance-neutral")
    func performUpdateTransferReamountsBothLegs() async throws {
        let container = try makeContainer()
        let sourceID = try seedAccount(container, balance: 1000)
        let destID = try seedAccount(container, balance: 0)
        let store = LedgerWriteStore(modelContainer: container)

        try await store.performTransfer(
            sourceAccountID: sourceID, destinationAccountID: destID,
            amount: 250, date: .now, note: "", currencyCode: "USD"
        ) // source 750, dest 250

        let seed = ModelContext(container)
        let pairID = try #require(try seed.fetch(FetchDescriptor<SDTransaction>()).first?.transferPairID)

        // Raise the transfer to 400: source -> 600, dest -> 400.
        try await store.performUpdateTransfer(
            transferPairID: pairID,
            sourceAccountID: sourceID, destinationAccountID: destID,
            amount: 400, date: .now, note: "rent", currencyCode: "USD"
        )

        let verify = ModelContext(container)
        let accounts = try verify.fetch(FetchDescriptor<SDAccount>())
        #expect(accounts.first { $0.id == sourceID }?.balance == 600)
        #expect(accounts.first { $0.id == destID }?.balance == 400)
        // Σ balances unchanged from the original 1000 total.
        let total = accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(total == 1000)
        let legs = try verify.fetch(FetchDescriptor<SDTransaction>())
        #expect(legs.count == 2)
        #expect(legs.allSatisfy { $0.amount == 400 })
    }

    @Test("performUpdateTransfer re-points legs to new accounts and reverses the old ones")
    func performUpdateTransferMovesAccounts() async throws {
        let container = try makeContainer()
        let sourceID = try seedAccount(container, balance: 1000)
        let destID = try seedAccount(container, balance: 0)
        let newDestID = try seedAccount(container, balance: 0)
        let store = LedgerWriteStore(modelContainer: container)

        try await store.performTransfer(
            sourceAccountID: sourceID, destinationAccountID: destID,
            amount: 250, date: .now, note: "", currencyCode: "USD"
        ) // source 750, dest 250

        let seed = ModelContext(container)
        let pairID = try #require(try seed.fetch(FetchDescriptor<SDTransaction>()).first?.transferPairID)

        // Move the destination to a different account, same amount.
        try await store.performUpdateTransfer(
            transferPairID: pairID,
            sourceAccountID: sourceID, destinationAccountID: newDestID,
            amount: 250, date: .now, note: "", currencyCode: "USD"
        )

        let verify = ModelContext(container)
        let accounts = try verify.fetch(FetchDescriptor<SDAccount>())
        #expect(accounts.first { $0.id == sourceID }?.balance == 750)   // unchanged net
        #expect(accounts.first { $0.id == destID }?.balance == 0)        // old dest reversed
        #expect(accounts.first { $0.id == newDestID }?.balance == 250)   // new dest credited
    }
}
