import Foundation

struct FetchPayeesUseCase: Sendable {
    private let repository: any PayeeRepository

    init(repository: any PayeeRepository) {
        self.repository = repository
    }

    func execute() async throws -> [PayeeEntity] {
        let all = try await repository.fetchAll()
        return all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func executeSearch(query: String) async throws -> [PayeeEntity] {
        guard !query.isEmpty else { return try await execute() }
        return try await repository.search(query: query)
    }

    func executeFrequent(limit: Int = 5) async throws -> [PayeeEntity] {
        return try await repository.fetchFrequent(limit: limit)
    }
}
