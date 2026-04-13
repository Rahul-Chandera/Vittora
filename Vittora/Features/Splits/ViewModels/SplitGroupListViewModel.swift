import Foundation

@Observable
@MainActor
final class SplitGroupListViewModel {
    private let fetchGroupsUseCase: FetchSplitGroupsUseCase
    private let createGroupUseCase: CreateSplitGroupUseCase
    private let splitGroupRepository: any SplitGroupRepository

    var summaries: [SplitGroupSummary] = []
    var isLoading = false
    var error: String?

    init(
        fetchGroupsUseCase: FetchSplitGroupsUseCase,
        createGroupUseCase: CreateSplitGroupUseCase,
        splitGroupRepository: any SplitGroupRepository
    ) {
        self.fetchGroupsUseCase = fetchGroupsUseCase
        self.createGroupUseCase = createGroupUseCase
        self.splitGroupRepository = splitGroupRepository
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            summaries = try await fetchGroupsUseCase.execute()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func deleteGroup(id: UUID) async {
        do {
            try await splitGroupRepository.deleteGroup(id)
            summaries.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
