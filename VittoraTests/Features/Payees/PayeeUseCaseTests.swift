import Foundation
import Testing

@testable import Vittora

@MainActor
@Suite("Payee Use Case Tests")
struct PayeeUseCaseTests {

    // MARK: - FetchPayeesUseCase

    @MainActor
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

    @MainActor
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

    @MainActor
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

    @MainActor
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

    // MARK: - ImportContactsUseCase

    @MainActor
    @Suite("ImportContactsUseCase")
    struct ImportContactsUseCaseTests {
        @Test("Imports unique contacts and skips duplicates")
        func testImportsUniqueContactsAndSkipsDuplicates() async throws {
            let repository = MockPayeeRepository()
            await repository.seed(PayeeEntity(name: "Apple", type: .business))

            let contactsService = MockContactsImportService(
                status: .authorized,
                candidates: [
                    ContactPayeeCandidate(
                        name: "  Jane Doe  ",
                        type: .person,
                        phone: "+1 555 0101",
                        email: "jane@example.com"
                    ),
                    ContactPayeeCandidate(
                        name: "Apple",
                        type: .business,
                        phone: nil,
                        email: nil
                    ),
                    ContactPayeeCandidate(
                        name: "Acme Corp",
                        type: .business,
                        phone: "555 0102",
                        email: "finance@acme.example"
                    ),
                    ContactPayeeCandidate(
                        name: "jane doe",
                        type: .person,
                        phone: nil,
                        email: nil
                    ),
                ]
            )

            let useCase = ImportContactsUseCase(
                repository: repository,
                contactsService: contactsService
            )

            let result = try await useCase.execute()
            let allPayees = await repository.payees

            #expect(result.importedCount == 2)
            #expect(result.skippedCount == 2)
            #expect(allPayees.count == 3)
            #expect(allPayees.contains {
                $0.name == "Jane Doe" &&
                $0.type == .person &&
                $0.phone == "+1 555 0101" &&
                $0.email == "jane@example.com"
            })
            #expect(allPayees.contains {
                $0.name == "Acme Corp" &&
                $0.type == .business &&
                $0.phone == "555 0102"
            })
        }

        @Test("Requests access before importing when status is not determined")
        func testRequestsAccessBeforeImporting() async throws {
            let repository = MockPayeeRepository()
            let contactsService = MockContactsImportService(
                status: .notDetermined,
                candidates: [
                    ContactPayeeCandidate(name: "Jordan Lee", type: .person, phone: nil, email: nil),
                ]
            )

            let useCase = ImportContactsUseCase(
                repository: repository,
                contactsService: contactsService
            )

            let result = try await useCase.execute()

            #expect(result.importedCount == 1)
            #expect(await contactsService.requestAccessCallCount == 1)
        }

        @Test("Throws access denied when contacts permission is unavailable")
        func testThrowsAccessDeniedWhenPermissionUnavailable() async throws {
            let repository = MockPayeeRepository()
            let contactsService = MockContactsImportService(status: .denied)
            let useCase = ImportContactsUseCase(
                repository: repository,
                contactsService: contactsService
            )

            do {
                _ = try await useCase.execute()
                Issue.record("Expected contacts import to fail when access is denied.")
            } catch let error as ContactsImportError {
                #expect(error == .accessDenied)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - PayeeAnalyticsUseCase

    @MainActor
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

private actor MockContactsImportService: ContactsImportServiceProtocol {
    private(set) var status: ContactsAccessStatus
    private let candidates: [ContactPayeeCandidate]
    private let requestAccessResult: Bool
    private(set) var requestAccessCallCount = 0

    init(
        status: ContactsAccessStatus,
        candidates: [ContactPayeeCandidate] = [],
        requestAccessResult: Bool = true
    ) {
        self.status = status
        self.candidates = candidates
        self.requestAccessResult = requestAccessResult
    }

    func authorizationStatus() async -> ContactsAccessStatus {
        status
    }

    func requestAccess() async throws -> Bool {
        requestAccessCallCount += 1
        if requestAccessResult {
            status = .authorized
        } else {
            status = .denied
        }
        return requestAccessResult
    }

    func fetchCandidates() async throws -> [ContactPayeeCandidate] {
        candidates
    }
}
