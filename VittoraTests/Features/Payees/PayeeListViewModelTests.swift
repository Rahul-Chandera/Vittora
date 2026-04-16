import Foundation
import Testing

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
                transactionRepository: transactionRepository
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
                transactionRepository: transactionRepository
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
