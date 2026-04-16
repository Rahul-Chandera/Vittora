import Foundation

@Observable
@MainActor
final class PayeeListViewModel {
    var payees: [PayeeEntity] = []
    var frequentPayees: [PayeeEntity] = []
    var searchQuery: String = ""
    var isLoading = false
    var isImportingContacts = false
    var error: String?
    var importSummary: ContactsImportResult?

    var filteredPayees: [PayeeEntity] {
        guard !searchQuery.isEmpty else { return payees }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    var frequentSectionPayees: [PayeeEntity] {
        guard searchQuery.trimmed.isEmpty else { return [] }
        let payeeIDs = Set(payees.map(\.id))
        return frequentPayees.filter { payeeIDs.contains($0.id) }
    }

    /// Payees grouped by first letter, sorted A-Z
    var sectionedPayees: [(letter: String, payees: [PayeeEntity])] {
        let remainingPayees: [PayeeEntity]
        if searchQuery.trimmed.isEmpty {
            let frequentIDs = Set(frequentSectionPayees.map(\.id))
            remainingPayees = filteredPayees.filter { !frequentIDs.contains($0.id) }
        } else {
            remainingPayees = filteredPayees
        }

        let grouped = Dictionary(grouping: remainingPayees) { payee -> String in
            let first = payee.name.prefix(1).uppercased()
            return first.isEmpty ? "#" : first
        }
        return grouped.keys.sorted().map { letter in
            (letter: letter, payees: grouped[letter] ?? [])
        }
    }

    var importSummaryMessage: String? {
        guard let importSummary else { return nil }

        if importSummary.importedCount == 0, importSummary.skippedCount == 0 {
            return String(localized: "No contacts were available to import.")
        }

        if importSummary.importedCount == 0 {
            return String(localized: "No new payees were imported. \(importSummary.skippedCount) contacts were skipped because they already exist.")
        }

        if importSummary.skippedCount == 0 {
            return String(localized: "Imported \(importSummary.importedCount) contacts as payees.")
        }

        return String(localized: "Imported \(importSummary.importedCount) contacts as payees and skipped \(importSummary.skippedCount) duplicates.")
    }

    private let fetchUseCase: FetchPayeesUseCase
    private let deleteUseCase: DeletePayeeUseCase
    private let importContactsUseCase: ImportContactsUseCase?

    init(
        fetchUseCase: FetchPayeesUseCase,
        deleteUseCase: DeletePayeeUseCase,
        importContactsUseCase: ImportContactsUseCase? = nil
    ) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
        self.importContactsUseCase = importContactsUseCase
    }

    func loadPayees() async {
        isLoading = true
        error = nil
        do {
            payees = try await fetchUseCase.execute()
            frequentPayees = try await fetchUseCase.executeFrequent(limit: 5)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deletePayee(id: UUID) async {
        do {
            try await deleteUseCase.execute(id: id)
            await loadPayees()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func importContacts() async {
        guard let importContactsUseCase else {
            error = String(localized: "Contacts import is unavailable.")
            return
        }

        guard !isImportingContacts else { return }

        isImportingContacts = true
        error = nil
        importSummary = nil

        do {
            let result = try await importContactsUseCase.execute()
            await loadPayees()
            importSummary = result
        } catch {
            self.error = error.localizedDescription
        }

        isImportingContacts = false
    }

    func clearImportSummary() {
        importSummary = nil
    }
}
