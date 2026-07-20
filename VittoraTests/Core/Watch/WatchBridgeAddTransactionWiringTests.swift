#if os(iOS)
import Foundation
import Testing
import SwiftData
import VittoraCore
@testable import Vittora

@Suite("WatchBridge AddTransaction wiring", .serialized)
@MainActor
struct WatchBridgeAddTransactionWiringTests {

    @Test("invalid category surfaces error and commits no transaction via AddTransactionUseCase")
    func invalidCategoryDoesNotCommit() async throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let accountRepo = SwiftDataAccountRepository(modelContainer: container)
        let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
        let ledger = LedgerWriteStore(modelContainer: container)

        let account = AccountEntity(name: "Checking", type: .bank, currencyCode: "USD")
        try await accountRepo.create(account)

        let addUseCase = AddTransactionUseCase(
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            ledgerWriting: ledger
        )

        var presented: String?
        let bridge = WatchBridgeService(
            session: StubWatchSession(),
            buildSnapshot: {
                WatchSnapshot(
                    todaySpend: 0,
                    budgetSpent: 0,
                    budgetTotal: 0,
                    recentTransactions: [],
                    currencyCode: "USD"
                )
            },
            commitExpense: { expense in
                _ = try await addUseCase.execute(
                    amount: expense.amount,
                    type: .expense,
                    date: expense.createdAt,
                    categoryID: expense.categoryID,
                    accountID: account.id,
                    payeeID: nil,
                    note: "Apple Watch",
                    tags: [],
                    paymentMethod: .other,
                    currencyCode: "USD"
                )
            },
            presentError: { message in
                presented = message
            }
        )

        let payload = QueuedWatchExpense(
            amount: Decimal(string: "18.25") ?? 0,
            categoryID: UUID() // not in store
        )
        await bridge.handleIncomingUserInfo(payload.userInfoDictionary())

        let remaining = try await transactionRepo.fetchAll(filter: nil)
        #expect(remaining.isEmpty)
        #expect(presented != nil)
    }

    @Test("valid watch expense commits through AddTransactionUseCase")
    func validExpenseCommits() async throws {
        let container = try ModelContainerConfig.makeContainer(inMemory: true)
        let accountRepo = SwiftDataAccountRepository(modelContainer: container)
        let categoryRepo = SwiftDataCategoryRepository(modelContainer: container)
        let transactionRepo = SwiftDataTransactionRepository(modelContainer: container)
        let ledger = LedgerWriteStore(modelContainer: container)

        let account = AccountEntity(name: "Checking", type: .bank, currencyCode: "USD")
        try await accountRepo.create(account)
        let category = CategoryEntity(name: "Food", icon: "fork.knife", colorHex: "#FF9500")
        try await categoryRepo.create(category)

        let addUseCase = AddTransactionUseCase(
            accountRepository: accountRepo,
            categoryRepository: categoryRepo,
            ledgerWriting: ledger
        )

        let amount = Decimal(string: "18.25") ?? 0
        var presented: String?
        let bridge = WatchBridgeService(
            session: StubWatchSession(),
            buildSnapshot: {
                WatchSnapshot(
                    todaySpend: 0,
                    budgetSpent: 0,
                    budgetTotal: 0,
                    recentTransactions: [],
                    currencyCode: "USD"
                )
            },
            commitExpense: { expense in
                _ = try await addUseCase.execute(
                    amount: expense.amount,
                    type: .expense,
                    date: expense.createdAt,
                    categoryID: expense.categoryID,
                    accountID: account.id,
                    payeeID: nil,
                    note: "Apple Watch",
                    tags: [],
                    paymentMethod: .other,
                    currencyCode: "USD"
                )
            },
            presentError: { message in
                presented = message
            }
        )

        let payload = QueuedWatchExpense(amount: amount, categoryID: category.id)
        await bridge.handleIncomingUserInfo(payload.userInfoDictionary())

        let saved = try await transactionRepo.fetchAll(filter: nil)
        #expect(presented == nil)
        #expect(saved.count == 1)
        #expect(saved[0].amount == amount)
        #expect(saved[0].categoryID == category.id)
        #expect(saved[0].type == .expense)
    }
}

@MainActor
private final class StubWatchSession: WatchSessionClient {
    var isSupported: Bool { true }
    func setDelegate(_ delegate: any WatchSessionClientDelegate) {}
    func activate() {}
    func updateApplicationContext(_ context: [String: Any]) throws {}
}
#endif
