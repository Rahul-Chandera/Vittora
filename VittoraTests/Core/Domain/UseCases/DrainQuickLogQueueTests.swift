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

    // MARK: - Shortcuts actions

    private func makeShortcutsUseCase(
        queue: QuickLogQueue,
        payees: [PayeeEntity] = []
    ) async throws -> (DrainQuickLogQueueUseCase, MockTransactionRepository) {
        let transactions = MockTransactionRepository()
        let accountRepository = MockAccountRepository()
        try await accountRepository.create(account())
        let payeeRepository = MockPayeeRepository()
        await payeeRepository.seedMany(payees)
        let useCase = DrainQuickLogQueueUseCase(
            transactionRepository: transactions,
            accountRepository: accountRepository,
            categoryRepository: MockCategoryRepository(),
            queue: queue,
            payeeRepository: payeeRepository
        )
        return (useCase, transactions)
    }

    @Test("a merchant matching a payee by name books against that payee")
    func merchantMatchesPayee() async throws {
        let queue = makeQueue()
        let starbucks = PayeeEntity(name: "Starbucks")
        queue.enqueue(QuickLogEntry(amount: 5, payeeName: "  STARBUCKS "))
        let (useCase, transactions) = try await makeShortcutsUseCase(queue: queue, payees: [starbucks])

        #expect(try await useCase.execute() == 1)
        let booked = try #require(await transactions.transactions.first)
        #expect(booked.payeeID == starbucks.id)
        #expect(booked.note == nil)
    }

    /// No payees are created from alert text; the merchant stays visible in the note.
    @Test("an unknown merchant is kept in the note, not turned into a payee")
    func unknownMerchantGoesToNote() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 9, note: "Lunch", payeeName: "Joe's Diner"))
        let (useCase, transactions) = try await makeShortcutsUseCase(queue: queue)

        #expect(try await useCase.execute() == 1)
        let booked = try #require(await transactions.transactions.first)
        #expect(booked.payeeID == nil)
        #expect(booked.note == "Joe's Diner · Lunch")
    }

    @Test("currency and payment method carry through")
    func currencyAndPaymentMethod() async throws {
        let queue = makeQueue()
        queue.enqueue(QuickLogEntry(amount: 250, currencyCode: "INR", paymentMethod: PaymentMethod.upi.rawValue))
        let (useCase, transactions) = try await makeShortcutsUseCase(queue: queue)

        #expect(try await useCase.execute() == 1)
        let booked = try #require(await transactions.transactions.first)
        #expect(booked.currencyCode == "INR")
        #expect(booked.paymentMethod == .upi)
    }

    /// Entries a widget queued before the update have none of the new keys.
    @Test("an entry queued by an older build still decodes and books")
    func legacyEntryDecodes() async throws {
        let defaults = try #require(UserDefaults(suiteName: "drain-legacy-\(UUID().uuidString)"))
        let id = UUID()
        let legacy = #"{"id":"\#(id.uuidString)","amount":42,"createdAt":700000000}"#
        defaults.set(Data(legacy.utf8), forKey: QuickLogQueue.keyPrefix + id.uuidString)
        let queue = QuickLogQueue(defaults: defaults)
        let (useCase, transactions) = try await makeShortcutsUseCase(queue: queue)

        #expect(try await useCase.execute() == 1)
        #expect(await transactions.transactions.first?.amount == 42)
        #expect(await transactions.transactions.first?.paymentMethod == .cash)
    }
}
