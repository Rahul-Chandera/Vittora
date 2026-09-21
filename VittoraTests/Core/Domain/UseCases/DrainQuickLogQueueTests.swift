import Foundation
import Testing
import VittoraCore
@testable import Vittora

/// M2.7.5. The drain is where a widget tap becomes money in the ledger, so the ordering
/// and the failure paths are what these pin.
@MainActor
@Suite("Drain Quick Log Queue Tests")
struct DrainQuickLogQueueTests {

    private func makeQueue() -> QuickLogQueue {
        QuickLogQueue(defaults: UserDefaults(suiteName: "drain-\(UUID().uuidString)") ?? .standard)
    }

    private func makeUseCase(
        queue: QuickLogQueue,
        accounts: [AccountEntity],
        categories: [CategoryEntity] = []
    ) async throws -> (DrainQuickLogQueueUseCase, MockTransactionRepository) {
        let transactions = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        for account in accounts { try await accountRepository.create(account) }
        let categoryRepository = MockCategoryRepository()
        await categoryRepository.seedMany(categories)
        let useCase = DrainQuickLogQueueUseCase(
            transactionRepository: transactions,
            accountRepository: accountRepository,
            categoryRepository: categoryRepository,
            queue: queue
        )
        return (useCase, transactions)
    }

    private func account(name: String = "Cash") -> AccountEntity {
        AccountEntity(name: name, type: .cash, balance: 0)
    }

    @Test("a queued tap becomes a transaction and leaves the queue")
    func tapBecomesTransaction() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 120, note: "Coffee"))
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [account()])

        let committed = try await useCase.execute()

        #expect(committed == 1)
        #expect(await transactions.transactions.count == 1)
        #expect(await transactions.transactions.first?.amount == 120)
        #expect(await transactions.transactions.first?.type == .expense)
        #expect(queue.pending().isEmpty)
    }

    /// Without an account there is nothing to book against. The entry must survive so it
    /// lands once the user finishes setting up, rather than being dropped.
    @Test("with no account the entry stays queued")
    func noAccountKeepsTheEntry() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 50))
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [])

        let committed = try await useCase.execute()

        #expect(committed == 0)
        #expect(await transactions.transactions.isEmpty)
        #expect(queue.pending().count == 1)
    }

    /// A category deleted between the tap and the drain must not take the expense with it.
    @Test("a missing category yields an uncategorised transaction, not a lost one")
    func missingCategoryStillCommits() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 75, categoryID: UUID()))
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [account()])

        let committed = try await useCase.execute()

        #expect(committed == 1)
        #expect(await transactions.transactions.first?.categoryID == nil)
        #expect(await transactions.transactions.first?.amount == 75)
    }

    @Test("a surviving category is carried through")
    func categoryIsCarriedThrough() async throws {
        let category = CategoryEntity(
            name: "Dining",
            icon: "fork.knife",
            colorHex: "#FF0000",
            type: .expense
        )
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 75, categoryID: category.id))
        let (useCase, transactions) = try await makeUseCase(
            queue: queue,
            accounts: [account()],
            categories: [category]
        )

        _ = try await useCase.execute()
        #expect(await transactions.transactions.first?.categoryID == category.id)
    }

    @Test("draining twice does not double-post")
    func drainIsIdempotent() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 10))
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [account()])

        _ = try await useCase.execute()
        let second = try await useCase.execute()

        #expect(second == 0)
        #expect(await transactions.transactions.count == 1)
    }

    @Test("an empty queue is a no-op")
    func emptyQueueDoesNothing() async throws {
        let queue = makeQueue()
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [account()])

        #expect(try await useCase.execute() == 0)
        #expect(await transactions.transactions.isEmpty)
    }

    @Test("every queued tap is committed, in order")
    func allEntriesCommit() async throws {
        let queue = makeQueue()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<5 {
            queue.enqueue(
                QuickLogEntry(
                    amount: Decimal(index + 1),
                    createdAt: base.addingTimeInterval(Double(index))
                )
            )
        }
        let (useCase, transactions) = try await makeUseCase(queue: queue, accounts: [account()])

        #expect(try await useCase.execute() == 5)
        #expect(await transactions.transactions.map(\.amount) == (1...5).map { Decimal($0) })
        #expect(queue.pending().isEmpty)
    }
}
