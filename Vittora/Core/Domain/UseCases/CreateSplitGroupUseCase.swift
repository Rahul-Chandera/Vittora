import Foundation

struct CreateSplitGroupUseCase: Sendable {
    let splitGroupRepository: any SplitGroupRepository

    enum GroupError: LocalizedError {
        case nameTooShort
        case notEnoughMembers

        var errorDescription: String? {
            switch self {
            case .nameTooShort:     return String(localized: "Group name must be at least 2 characters.")
            case .notEnoughMembers: return String(localized: "A group requires at least 2 members.")
            }
        }
    }

    func execute(name: String, memberIDs: [UUID]) async throws -> SplitGroup {
        guard name.trimmingCharacters(in: .whitespaces).count >= 2 else {
            throw GroupError.nameTooShort
        }
        guard memberIDs.count >= 2 else {
            throw GroupError.notEnoughMembers
        }
        let group = SplitGroup(name: name.trimmingCharacters(in: .whitespaces), memberIDs: memberIDs)
        try await splitGroupRepository.createGroup(group)
        return group
    }

    func executeUpdate(group: SplitGroup, name: String, memberIDs: [UUID]) async throws -> SplitGroup {
        guard name.trimmingCharacters(in: .whitespaces).count >= 2 else {
            throw GroupError.nameTooShort
        }
        guard memberIDs.count >= 2 else {
            throw GroupError.notEnoughMembers
        }
        var updated = group
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.memberIDs = memberIDs
        try await splitGroupRepository.updateGroup(updated)
        return updated
    }
}
