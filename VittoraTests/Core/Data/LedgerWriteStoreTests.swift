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

    @Test("not-yet-wired operation entry points throw until their task lands")
    func seededEntryPointsNotImplemented() async throws {
        let container = try makeContainer()
        let store = LedgerWriteStore(modelContainer: container)

        // performAdd/performSettle are wired in A6; performTransfer (A3) and
        // performDelete (A4) remain stubs and must still surface notImplemented.
        await #expect(throws: LedgerWriteError.self) {
            try await store.performDelete(transactionID: UUID())
        }
        await #expect(throws: LedgerWriteError.self) {
            try await store.performTransfer(
                sourceAccountID: UUID(),
                destinationAccountID: UUID(),
                amount: 10,
                date: .now,
                note: "",
                currencyCode: "USD"
            )
        }
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

        await #expect(throws: VittoraError.self) {
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
        await #expect(throws: VittoraError.self) {
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
}
