import Foundation

@Observable
@MainActor
final class PayeeListViewModel {
    var payees: [PayeeEntity] = []
    var frequentPayees: [PayeeEntity] = []
    var searchQuery: String = ""
    var isLoading = false
    var error: String?

    var filteredPayees: [PayeeEntity] {
        guard !searchQuery.isEmpty else { return payees }
        return payees.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    /// Payees grouped by first letter, sorted A-Z
    var sectionedPayees: [(letter: String, payees: [PayeeEntity])] {
        let grouped = Dictionary(grouping: filteredPayees) { payee -> String in
            let first = payee.name.prefix(1).uppercased()
            return first.isEmpty ? "#" : first
        }
        return grouped.keys.sorted().map { letter in
            (letter: letter, payees: grouped[letter] ?? [])
        }
    }

    private let fetchUseCase: FetchPayeesUseCase
    private let deleteUseCase: DeletePayeeUseCase

    init(fetchUseCase: FetchPayeesUseCase, deleteUseCase: DeletePayeeUseCase) {
        self.fetchUseCase = fetchUseCase
        self.deleteUseCase = deleteUseCase
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
}
