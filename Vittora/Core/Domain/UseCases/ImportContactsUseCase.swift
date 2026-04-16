import Foundation

struct ContactsImportResult: Sendable, Equatable {
    let importedCount: Int
    let skippedCount: Int
    let importedPayees: [PayeeEntity]
}

enum ContactsImportError: LocalizedError, Sendable, Equatable {
    case accessDenied
    case accessRestricted

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "Contacts access was denied. Allow access in Settings to import payees.")
        case .accessRestricted:
            String(localized: "Contacts access is restricted on this device.")
        }
    }
}

struct ImportContactsUseCase: Sendable {
    private let repository: any PayeeRepository
    private let contactsService: any ContactsImportServiceProtocol

    init(
        repository: any PayeeRepository,
        contactsService: any ContactsImportServiceProtocol
    ) {
        self.repository = repository
        self.contactsService = contactsService
    }

    func execute() async throws -> ContactsImportResult {
        switch await contactsService.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let granted = try await contactsService.requestAccess()
            guard granted else {
                throw ContactsImportError.accessDenied
            }
        case .denied:
            throw ContactsImportError.accessDenied
        case .restricted:
            throw ContactsImportError.accessRestricted
        }

        let existingPayees = try await repository.fetchAll()
        var knownNames = Set(existingPayees.map { Self.normalizedName(for: $0.name) })

        var importedPayees: [PayeeEntity] = []
        var skippedCount = 0

        for candidate in try await contactsService.fetchCandidates() {
            let normalizedName = Self.normalizedName(for: candidate.name)
            guard !normalizedName.isEmpty else {
                skippedCount += 1
                continue
            }

            guard knownNames.insert(normalizedName).inserted else {
                skippedCount += 1
                continue
            }

            let entity = PayeeEntity(
                name: Self.normalizedDisplayName(candidate.name),
                type: candidate.type,
                phone: Self.normalizedOptional(candidate.phone),
                email: Self.normalizedOptional(candidate.email)
            )

            try await repository.create(entity)
            importedPayees.append(entity)
        }

        importedPayees.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return ContactsImportResult(
            importedCount: importedPayees.count,
            skippedCount: skippedCount,
            importedPayees: importedPayees
        )
    }

    private nonisolated static func normalizedName(for name: String) -> String {
        normalizedDisplayName(name).lowercased()
    }

    private nonisolated static func normalizedDisplayName(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private nonisolated static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = normalizedDisplayName(value)
        return normalized.isEmpty ? nil : normalized
    }
}
