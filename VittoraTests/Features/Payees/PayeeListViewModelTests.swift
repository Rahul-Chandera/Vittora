import Foundation
import Testing
import VittoraCore

@testable import Vittora

@Suite("Payee List ViewModel Tests")
@MainActor
struct PayeeListViewModelTests {

    @Test("import contacts reloads payees and stores a summary")
    func importContactsReloadsPayees() async {
        let repository = MockPayeeRepository()
        let transactionRepository = MockTransactionRepository()
        let contactsService = MockContactsImportService(
            status: .authorized,
            candidates: [
                ContactPayeeCandidate(
                    name: "Alex Johnson",
                    type: .person,
                    phone: "+1 555 0100",
                    email: "alex@example.com"
                ),
                ContactPayeeCandidate(
                    name: "Northwind Traders",
                    type: .business,
                    phone: nil,
                    email: "ap@northwind.example"
                ),
            ]
        )

        let viewModel = PayeeListViewModel(
            fetchUseCase: FetchPayeesUseCase(repository: repository),
            deleteUseCase: DeletePayeeUseCase(
                repository: repository,
                transactionRepository: transactionRepository,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepository,
                    accountRepository: MockAccountRepository(),
                    payeeRepository: repository
                )
            ),
            importContactsUseCase: ImportContactsUseCase(
                repository: repository,
                contactsService: contactsService
            )
        )

        await viewModel.importContacts()

        #expect(viewModel.error == nil)
        #expect(viewModel.payees.count == 2)
        #expect(viewModel.importSummary?.importedCount == 2)
        #expect(viewModel.importSummary?.skippedCount == 0)
        #expect(viewModel.isImportingContacts == false)
    }

    @Test("import contacts surfaces permission failures")
    func importContactsSurfacesPermissionFailures() async {
        let repository = MockPayeeRepository()
        let transactionRepository = MockTransactionRepository()
        let contactsService = MockContactsImportService(status: .denied)

        let viewModel = PayeeListViewModel(
            fetchUseCase: FetchPayeesUseCase(repository: repository),
            deleteUseCase: DeletePayeeUseCase(
                repository: repository,
                transactionRepository: transactionRepository,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepository,
                    accountRepository: MockAccountRepository(),
                    payeeRepository: repository
                )
            ),
            importContactsUseCase: ImportContactsUseCase(
                repository: repository,
                contactsService: contactsService
            )
        )

        await viewModel.importContacts()

        #expect(viewModel.payees.isEmpty)
        #expect(viewModel.importSummary == nil)
        #expect(viewModel.error?.contains("Contacts access") == true)
        #expect(viewModel.isImportingContacts == false)
    }

    @Test("deleting a payee keeps its transactions, without the payee")
    func deleteKeepsTransactionsWithoutPayee() async throws {
        let (viewModel, repository, transactionRepository) = makeDeleteViewModel()
        let payee = PayeeEntity(name: "DoorDash", type: .business)
        await repository.seed(payee)
        let transaction = TransactionEntity(amount: 25, date: .now, type: .expense, payeeID: payee.id)
        try await transactionRepository.create(transaction)
        await viewModel.loadPayees()

        #expect(await viewModel.linkedTransactionCount(for: payee.id) == 1)
        #expect(await viewModel.deletePayee(id: payee.id))

        #expect(viewModel.payees.isEmpty)
        let kept = try await transactionRepository.fetchByID(transaction.id)
        #expect(kept?.amount == 25)
        #expect(kept?.payeeID == nil)
    }

    @Test("a failed delete keeps its reason and reports failure")
    func failedDeleteKeepsItsReason() async {
        let (viewModel, _, _) = makeDeleteViewModel()
        await viewModel.loadPayees()

        // The view refreshes only on success; a refresh runs loadPayees, which
        // clears the error before the alert can show it.
        #expect(await viewModel.deletePayee(id: UUID()) == false)
        #expect(viewModel.error != nil)
    }

    private func makeDeleteViewModel() -> (PayeeListViewModel, MockPayeeRepository, MockTransactionRepository) {
        let repository = MockPayeeRepository()
        let transactionRepository = MockTransactionRepository()
        let viewModel = PayeeListViewModel(
            fetchUseCase: FetchPayeesUseCase(repository: repository),
            deleteUseCase: DeletePayeeUseCase(
                repository: repository,
                transactionRepository: transactionRepository,
                ledgerWriting: MockLedgerWriting(
                    transactionRepository: transactionRepository,
                    accountRepository: MockAccountRepository(),
                    payeeRepository: repository
                )
            )
        )
        return (viewModel, repository, transactionRepository)
    }
}

private actor MockContactsImportService: ContactsImportServiceProtocol {
    private(set) var status: ContactsAccessStatus
    private let candidates: [ContactPayeeCandidate]
    private let requestAccessResult: Bool
    private let fetchError: Error?

    init(
        status: ContactsAccessStatus,
        candidates: [ContactPayeeCandidate] = [],
        requestAccessResult: Bool = true,
        fetchError: Error? = nil
    ) {
        self.status = status
        self.candidates = candidates
        self.requestAccessResult = requestAccessResult
        self.fetchError = fetchError
    }

    func authorizationStatus() async -> ContactsAccessStatus {
        status
    }

    func requestAccess() async throws -> Bool {
        if requestAccessResult {
            status = .authorized
        } else {
            status = .denied
        }
        return requestAccessResult
    }

    func fetchCandidates() async throws -> [ContactPayeeCandidate] {
        if let fetchError {
            throw fetchError
        }
        return candidates
    }
}
