import Foundation
import Observation
import VittoraCore

@Observable
@MainActor
final class TransactionCSVImportViewModel {
    private let importUseCase: ImportTransactionsFromCSVUseCase
    private let fetchAccountsUseCase: FetchAccountsUseCase

    var profile: CSVImportProfile = .generic
    var selectedAccountID: UUID?
    var accounts: [AccountEntity] = []
    var preview: CSVImportPreview?
    var csvData: Data?
    var fileName: String?
    var result: CSVImportResult?
    var isLoading = false
    var error: String?

    init(
        importUseCase: ImportTransactionsFromCSVUseCase,
        fetchAccountsUseCase: FetchAccountsUseCase
    ) {
        self.importUseCase = importUseCase
        self.fetchAccountsUseCase = fetchAccountsUseCase
    }

    var canImport: Bool {
        selectedAccountID != nil && preview != nil && !(preview?.rows.isEmpty ?? true) && !isLoading
    }

    func loadAccounts() async {
        do {
            accounts = try await fetchAccountsUseCase.execute()
            if selectedAccountID == nil {
                selectedAccountID = accounts.first?.id
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadCSV(data: Data, fileName: String) async {
        csvData = data
        self.fileName = fileName
        result = nil
        await refreshPreview()
    }

    func refreshPreview() async {
        guard let csvData else {
            preview = nil
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            preview = try importUseCase.preview(csvData: csvData, profile: profile)
        } catch {
            preview = nil
            self.error = error.localizedDescription
        }
    }

    func importTransactions(currencyCode: String) async -> Bool {
        guard let csvData, let accountID = selectedAccountID else {
            error = String(localized: "Choose an account before importing.")
            return false
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            result = try await importUseCase.execute(
                csvData: csvData,
                profile: profile,
                accountID: accountID,
                currencyCode: currencyCode
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
