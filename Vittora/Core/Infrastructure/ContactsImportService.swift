import Contacts
import Foundation

enum ContactsAccessStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

struct ContactPayeeCandidate: Sendable, Equatable {
    let name: String
    let type: PayeeType
    let phone: String?
    let email: String?
}

protocol ContactsImportServiceProtocol: Sendable {
    func authorizationStatus() async -> ContactsAccessStatus
    func requestAccess() async throws -> Bool
    func fetchCandidates() async throws -> [ContactPayeeCandidate]
}

actor SystemContactsImportService: ContactsImportServiceProtocol {
    private let contactStore = CNContactStore()

    func authorizationStatus() async -> ContactsAccessStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            .notDetermined
        case .authorized:
            .authorized
        case .limited:
            .authorized
        case .denied:
            .denied
        case .restricted:
            .restricted
        @unknown default:
            .restricted
        }
    }

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchCandidates() async throws -> [ContactPayeeCandidate] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactTypeKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.unifyResults = true

        var candidates: [ContactPayeeCandidate] = []
        try contactStore.enumerateContacts(with: request) { contact, _ in
            if let candidate = Self.makeCandidate(from: contact) {
                candidates.append(candidate)
            }
        }

        return candidates.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private nonisolated static func makeCandidate(from contact: CNContact) -> ContactPayeeCandidate? {
        let organizationName = normalize(contact.organizationName)
        let fullName = normalize(CNContactFormatter.string(from: contact, style: .fullName) ?? "")

        let isOrganization = contact.contactType == .organization
        let preferredName = isOrganization
            ? (organizationName.isEmpty ? fullName : organizationName)
            : (fullName.isEmpty ? organizationName : fullName)

        let normalizedName = normalize(preferredName)
        guard !normalizedName.isEmpty else {
            return nil
        }

        return ContactPayeeCandidate(
            name: normalizedName,
            type: isOrganization ? .business : .person,
            phone: sanitize(contact.phoneNumbers.first?.value.stringValue),
            email: sanitize(contact.emailAddresses.first.map { String($0.value) })
        )
    }

    private nonisolated static func sanitize(_ value: String?) -> String? {
        guard let trimmed = value.map(normalize), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func normalize(_ value: String) -> String {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
