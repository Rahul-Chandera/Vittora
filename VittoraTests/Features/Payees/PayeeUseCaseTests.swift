import Foundation
import Testing

@testable import Vittora

@Suite("Payee Use Case Tests")
struct PayeeUseCaseTests {

    // MARK: - FetchPayeesUseCase

    @Suite("FetchPayeesUseCase")
    struct FetchPayeesUseCaseTests {
        @Test("Execute returns payees sorted alphabetically")
        func testExecuteReturnsSorted() async throws {
            let repo = MockPayeeRepository()
            await repo.seed(PayeeEntity(name: "Zara", type: .business))
            await repo.seed(PayeeEntity(name: "Apple", type: .business))
            await repo.seed(PayeeEntity(name: "Microsoft", type: .business))

            let useCase = FetchPayeesUseCase(repository: repo)
            let result = try await useCase.execute()

            #expect(result.count == 3)
            #expect(result[0].name == "Apple")
            #expect(result[1].name == "Microsoft")
            #expect(result[2].name == "Zara")
        }

        @Test("ExecuteFrequent returns limited payees")
        func testExecuteFrequent() async throws {
            let repo = MockPayeeRepository()
            for i in 1...10 {
                await repo.seed(PayeeEntity(name: "Payee \(i)", type: .business))
            }

            let useCase = FetchPayeesUseCase(repository: repo)
            let frequent = try await useCase.executeFrequent(limit: 3)

            #expect(frequent.count == 3)
        }

        @Test("ExecuteSearch filters by name")
        func testExecuteSearch() async throws {
            let repo = MockPayeeRepository()
            await repo.seed(PayeeEntity(name: "Apple Inc", type: .business))
            await repo.seed(PayeeEntity(name: "Google LLC", type: .business))
            await repo.seed(PayeeEntity(name: "Apple Store", type: .business))

            let useCase = FetchPayeesUseCase(repository: repo)
            let results = try await useCase.executeSearch(query: "Apple")

            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.name.contains("Apple") })
        }
    }

    // MARK: - CreatePayeeUseCase

    @Suite("CreatePayeeUseCase")
    struct CreatePayeeUseCaseTests {
        @Test("Creates a new business payee")
        func testCreateBusinessPayee() async throws {
            let repo = MockPayeeRepository()
            let useCase = CreatePayeeUseCase(repository: repo)

            try await useCase.execute(
                name: "Apple Inc.",
                type: .business,
                phone: "+1 800-275-2273",
                email: "support@apple.com",
                notes: "Tech company"
            )

            let all = await repo.payees
            #expect(all.count == 1)
            #expect(all[0].name == "Apple Inc.")
            #expect(all[0].type == .business)
            #expect(all[0].phone == "+1 800-275-2273")
            #expect(all[0].email == "support@apple.com")
        }

        @Test("Throws validation error for empty name")
        func testThrowsForEmptyName() async throws {
            let repo = MockPayeeRepository()
            let useCase = CreatePayeeUseCase(repository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(name: "   ", type: .business)
            }
        }

        @Test("Throws duplicate entry error for same name")
        func testThrowsForDuplicateName() async throws {
            let repo = MockPayeeRepository()
            await repo.seed(PayeeEntity(name: "Apple", type: .business))
            let useCase = CreatePayeeUseCase(repository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(name: "Apple", type: .business)
            }
        }

        @Test("Trims whitespace from name")
        func testTrimWhitespaceFromName() async throws {
            let repo = MockPayeeRepository()
            let useCase = CreatePayeeUseCase(repository: repo)

            try await useCase.execute(name: "  Apple Inc.  ", type: .business)

            let all = await repo.payees
            #expect(all[0].name == "Apple Inc.")
        }
    }

    // MARK: - UpdatePayeeUseCase

    @Suite("UpdatePayeeUseCase")
    struct UpdatePayeeUseCaseTests {
        @Test("Updates payee name")
        func testUpdatePayeeName() async throws {
            let repo = MockPayeeRepository()
            var payee = PayeeEntity(name: "Old Name", type: .business)
            await repo.seed(payee)

            payee.name = "New Name"
            payee.phone = "+1 555 9876"

            let useCase = UpdatePayeeUseCase(repository: repo)
            try await useCase.execute(payee)

            let updated = await repo.payees.first { $0.id == payee.id }
            #expect(updated?.name == "New Name")
        }

        @Test("Throws when updating with empty name")
        func testThrowsForEmptyName() async throws {
            let repo = MockPayeeRepository()
            var payee = PayeeEntity(name: "Valid Name", type: .business)
            await repo.seed(payee)

            payee.name = ""
            let useCase = UpdatePayeeUseCase(repository: repo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(payee)
            }
        }
    }

    // MARK: - DeletePayeeUseCase

    @Suite("DeletePayeeUseCase")
    struct DeletePayeeUseCaseTests {
        @Test("Deletes payee with no transactions")
        func testDeletePayeeWithNoTransactions() async throws {
            let payeeRepo = MockPayeeRepository()
            let transactionRepo = MockTransactionRepository()
            let payee = PayeeEntity(name: "Old Payee", type: .business)
            await payeeRepo.seed(payee)

            let useCase = DeletePayeeUseCase(repository: payeeRepo, transactionRepository: transactionRepo)
            try await useCase.execute(id: payee.id)

            let all = await payeeRepo.payees
            #expect(all.isEmpty)
        }

        @Test("Throws when deleting non-existent payee")
        func testThrowsForNonExistentPayee() async throws {
            let payeeRepo = MockPayeeRepository()
            let transactionRepo = MockTransactionRepository()

            let useCase = DeletePayeeUseCase(repository: payeeRepo, transactionRepository: transactionRepo)

            await #expect(throws: (any Error).self) {
                try await useCase.execute(id: UUID())
            }
        }
    }

    // MARK: - PayeeAnalyticsUseCase

    @Suite("PayeeAnalyticsUseCase")
    struct PayeeAnalyticsUseCaseTests {
        @Test("Returns zero analytics for payee with no transactions")
        func testZeroAnalyticsForNoTransactions() async throws {
            let transactionRepo = MockTransactionRepository()
            let payeeID = UUID()

            let useCase = PayeeAnalyticsUseCase(transactionRepository: transactionRepo)
            let analytics = try await useCase.execute(payeeID: payeeID)

            #expect(analytics.payeeID == payeeID)
            #expect(analytics.totalSpent == 0)
            #expect(analytics.transactionCount == 0)
            #expect(analytics.averageAmount == 0)
            #expect(analytics.lastTransactionDate == nil)
        }
    }
}
